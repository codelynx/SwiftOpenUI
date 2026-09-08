import CGTK
import CGTKBridge
import SwiftOpenUI
import Foundation
#if canImport(Observation)
import Observation
#endif

/// Thread-local key for the ViewHost currently performing a rebuild.
private var rebuildingViewHostKey: pthread_key_t = {
    var key: pthread_key_t = 0
    pthread_key_create(&key, nil)
    return key
}()

/// GTK4-specific ViewHost that manages a stable GtkBox container.
/// On state change, rebuilds the body and swaps children.
/// Preserves focus and cursor position across rebuilds.
public class GTKViewHost: AnyViewHost, DependencyTrackingHost {
    public var lastReadSet: Set<ObjectIdentifier>?
    public var lastInputSnapshot: [StorageSnapshot]?
    public let container: UnsafeMutablePointer<GtkWidget>
    let buildBody: () -> OpaquePointer
    /// Describes the body as a descriptor tree without creating widgets.
    var describeBody: (() -> GTK4DescriptorNode)?
    /// Retained descriptor state for narrow mutation path.
    var lastRetainedDescriptor: GTK4RetainedDescriptorNode?
    var retainedExecutor: GTK4RetainedExecutorNode?
    private let lock = NSLock()
    private var scheduled = false
    private var isContainerAlive = true
    private var suppressFocusRestoreOnce = false
    private var interactiveUpdateDepth = 0
    private var rebuildDeferredDuringInteraction = false
    private var pendingAnimation: Animation?
    /// True when the pending/next rebuild was requested by withObservationTracking's
    /// onChange callback. withObservationTracking is one-shot: once it fires, the
    /// observation is no longer registered, and the only way to re-subscribe is to
    /// run body through buildBodyWithTracking again. Therefore an observation-
    /// triggered rebuild must NOT be short-circuited by the Phase 7 inputsUnchanged
    /// optimization — that optimization only tracks @State / @Published generations
    /// and can't see @Observable mutations, so it would wrongly declare the inputs
    /// unchanged and leave observation permanently unsubscribed.
    private var observationDidFire = false
    var capturedEnvironment: EnvironmentValues

    /// Positional cache of nested stateful children's @State storages.
    /// When this host rebuilds, body re-evaluation constructs child view
    /// structs fresh — including brand-new StateStorage boxes. Without
    /// reconciliation, a nested stateful view (e.g. TaskModifierView's
    /// `hasStarted` guard) loses all state on every parent rebuild, which
    /// can re-fire `.task`/`.onAppear` work in a rebuild→refire loop.
    /// Keyed by "<render-order index>:<view type>" within one body pass —
    /// positional identity, the same approximation SwiftUI uses for
    /// unnamed structural state (and the same scheme AndroidRenderer's
    /// state cache uses). Mismatched type or storage count skips restore.
    var childStateCache: [String: [AnyStateStorage]] = [:]
    private var childStatefulCounter = 0

    /// Next positional key for a nested stateful child encountered during
    /// the current body pass. Called by `gtkRenderStatefulView` in render
    /// order; the counter resets at the start of each body evaluation.
    func nextChildStateKey(type: String) -> String {
        defer { childStatefulCounter += 1 }
        return "\(childStatefulCounter):\(type)"
    }

    /// Objects read by body via `@Environment(Type.self)` during the
    /// last successful render. Re-pushed into the environment before
    /// each rebuild so body's lookups find the same objects even when
    /// the originating `.environment(object)` modifier lives below
    /// this ViewHost in the render tree (and therefore isn't
    /// guaranteed to re-run the push before body's next read). Filled
    /// by `endEnvironmentReadTracking()` after each buildBody.
    private var capturedInjectedObjects: [ObjectIdentifier: AnyObject] = [:]

    /// Install the captured ancestor environment plus every injected
    /// object body read during its last render. Called at each
    /// rebuild entry point instead of `setCurrentEnvironment(
    /// capturedEnvironment)` alone, so descendant `@Environment(
    /// Type.self)` lookups survive even when the pushing modifier
    /// lives inside a parent's body.
    private func installRebuildEnvironment() {
        var env = capturedEnvironment
        for (typeID, object) in capturedInjectedObjects {
            env.setObjectByID(typeID, object)
        }
        setCurrentEnvironment(env)
    }

    public init(buildBody: @escaping () -> OpaquePointer) {
        self.buildBody = buildBody
        self.capturedEnvironment = getCurrentEnvironment()
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        self.container = box
        gtk_widget_set_hexpand(box, 0)
        gtk_widget_set_vexpand(box, 0)
        // Transparent so content backgrounds fill edge-to-edge
        applyCSSToWidget(box, properties: "background: transparent;")

        // Attach self to the GTK widget for lifetime management.
        let retained = Unmanaged.passRetained(self).toOpaque()
        let gobject = UnsafeMutableRawPointer(box).assumingMemoryBound(to: GObject.self)
        g_object_set_data_full(
            gobject,
            "gtk-swift-view-host",
            retained,
            { userData in
                let hostRef = Unmanaged<GTKViewHost>.fromOpaque(userData!)
                hostRef.takeUnretainedValue().markContainerDestroyed()
                hostRef.release()
            }
        )
    }

    private func markContainerDestroyed() {
        lock.lock()
        isContainerAlive = false
        scheduled = false
        lock.unlock()
    }

    public func scheduleRebuild() {
        lock.lock()
        let currentAnimation = getCurrentAnimation()
        defer { lock.unlock() }
        guard isContainerAlive else { return }
        // Defer rebuild while interactive: either THIS host is mid-interaction
        // (interactiveUpdateDepth, e.g. a native slider drag) or ANY host is
        // (globalInteractionDepth). A gesture drag freezes EVERY host's rebuilds,
        // because a sibling/ancestor host that observes the same model would
        // otherwise rebuild mid-drag and recreate — detaching — the dragged
        // gesture's widget. Deferred hosts are collected and flushed on end.
        if interactiveUpdateDepth > 0 || GTKViewHost.globalInteractionDepth > 0 {
            rebuildDeferredDuringInteraction = true
            if GTKViewHost.globalInteractionDepth > 0 {
                GTKViewHost.deferredDuringGlobalInteraction[ObjectIdentifier(self)] = self
            }
            return
        }
        if let currentAnimation {
            pendingAnimation = currentAnimation
        }
        guard !scheduled else { return }
        scheduled = true
        let retained = Unmanaged.passRetained(self)
        g_idle_add({ userData -> gboolean in
            let host = Unmanaged<GTKViewHost>.fromOpaque(userData!).takeRetainedValue()
            host.rebuild()
            return 0 // G_SOURCE_REMOVE
        }, retained.toOpaque())
    }

    // MARK: - Global interaction deferral

    /// While > 0, EVERY host defers its rebuilds (see `scheduleRebuild`). A
    /// gesture drag brackets itself with `begin/endGlobalInteraction` so that no
    /// host — not the dragged control's, nor a sibling/ancestor that observes the
    /// same model — rebuilds mid-drag and recreates (and thereby detaches) the
    /// dragged gesture's widget. Accessed only on the GTK main thread, so no lock.
    static var globalInteractionDepth: Int = 0

    /// Last narrow-rejection diagnostic line printed (SWIFTOPENUI_NARROW_DEBUG),
    /// to dedupe a held drag's repeated logs. Main-thread only.
    static var lastNarrowRejectLog: String = ""

    /// Hosts that deferred a rebuild during the current global interaction,
    /// flushed exactly once when the interaction ends. Strong refs are fine —
    /// entries live only for the duration of a drag.
    static var deferredDuringGlobalInteraction: [ObjectIdentifier: GTKViewHost] = [:]

    /// Enter a global interaction (drag begin). Balanced by `endGlobalInteraction`.
    static func beginGlobalInteraction() {
        globalInteractionDepth += 1
    }

    /// Leave a global interaction (drag end). When the last one ends, flush every
    /// host that deferred a rebuild during it, so the whole UI reconciles once.
    static func endGlobalInteraction() {
        guard globalInteractionDepth > 0 else { return }
        globalInteractionDepth -= 1
        guard globalInteractionDepth == 0 else { return }
        let hosts = deferredDuringGlobalInteraction
        deferredDuringGlobalInteraction = [:]
        for host in hosts.values {
            host.scheduleRebuild()
        }
    }

    /// Repaint every host that has deferred a rebuild during the current global
    /// interaction, without rebuilding. Called on each drag-update so controls
    /// bound to the value being dragged (a linked knob and XY pad, say) track it
    /// live: their Canvas draw closures read the shared value at paint time, so a
    /// queue_draw reflects the new value even though the value-change observation
    /// is one-shot and its re-registering rebuild is deferred until drag-end.
    static func redrawDeferredInteractionHosts() {
        // Snapshot the values first: a host's narrow-mutation describe pass can
        // re-register observation whose onChange re-inserts into the dict, so we
        // must not iterate the live dictionary while mutating it.
        let hosts = Array(deferredDuringGlobalInteraction.values)
        for host in hosts where host.isContainerAlive {
            // Push narrow (text/color/canvas) in-place updates so NATIVE widgets
            // bound to the dragged value — a TextField's GtkEntry, say — track
            // live too, not just Canvas hosts. The narrow path never recreates a
            // widget, so it can't detach the in-flight gesture; structural
            // changes stay deferred to drag-end.
            host.applyDeferredNarrowMutationDuringInteraction()
            gtkQueueDrawSubtree(host.container)
        }
    }

    public func beginInteractiveUpdate() {
        lock.lock()
        defer { lock.unlock() }
        guard isContainerAlive else { return }
        interactiveUpdateDepth += 1
    }

    public func endInteractiveUpdate() {
        lock.lock()
        guard interactiveUpdateDepth > 0 else {
            lock.unlock()
            return
        }
        interactiveUpdateDepth -= 1
        guard interactiveUpdateDepth == 0,
              rebuildDeferredDuringInteraction,
              isContainerAlive,
              !scheduled else {
            lock.unlock()
            return
        }
        rebuildDeferredDuringInteraction = false
        scheduled = true
        lock.unlock()

        let retained = Unmanaged.passRetained(self)
        g_idle_add({ userData -> gboolean in
            let host = Unmanaged<GTKViewHost>.fromOpaque(userData!).takeRetainedValue()
            host.rebuild()
            return 0
        }, retained.toOpaque())
    }

    public func suppressNextFocusRestore() {
        lock.lock()
        suppressFocusRestoreOnce = true
        lock.unlock()
    }

    /// Build the body with observation tracking.  Any @Observable properties
    /// accessed during rendering are automatically tracked; when they change,
    /// scheduleRebuild() fires and the next rebuild re-registers tracking.
    func buildBodyWithTracking() -> OpaquePointer {
        // Positional keys for nested stateful children restart each pass.
        childStatefulCounter = 0

        // Track `@Environment(Type.self)` reads so we can re-push the
        // same objects into env on rebuild even if the pushing
        // modifier lives below us in the render tree. Pairs with
        // `endEnvironmentReadTracking()` after body evaluates.
        beginEnvironmentReadTracking()

        #if canImport(Observation)
        if #available(macOS 14.0, iOS 17.0, *) {
            var result: OpaquePointer!
            withObservationTracking {
                result = buildBody()
            } onChange: { [weak self] in
                guard let self else { return }
                self.lock.lock()
                self.observationDidFire = true
                self.lock.unlock()
                self.scheduleRebuild()
            }
            if let reads = endEnvironmentReadTracking() {
                capturedInjectedObjects = reads
            }
            return result
        }
        #endif

        let result = buildBody()
        if let reads = endEnvironmentReadTracking() {
            capturedInjectedObjects = reads
        }
        return result
    }

    /// Attempt an in-place text/color/canvas mutation for the current body,
    /// preserving the widget tree (and any in-flight gesture) instead of a full
    /// teardown-rebuild. Returns `true` if the plan was narrow-applicable and
    /// applied — the caller should then skip the full rebuild — or `false` if a
    /// structural rebuild is still required.
    ///
    /// Applied for both @State- and @Observable-driven changes. For an
    /// @Observable change the describe pass runs under `withObservationTracking`,
    /// so re-reading the observed properties re-registers the one-shot
    /// subscription — the same re-registration the full rebuild gets from
    /// `buildBodyWithTracking`, without the teardown.
    ///
    /// Must be called with `lock` NOT held (it runs the describe/plan/apply pass
    /// lock-free, matching the original inline placement after `lock.unlock()`).
    func tryNarrowMutation(fromObservation: Bool) -> Bool {
        guard let describeBody = describeBody,
              let oldRetained = lastRetainedDescriptor,
              let oldExecutor = retainedExecutor else {
            return false
        }

        let previousEnv = getCurrentEnvironment()
        installRebuildEnvironment()
        let described: (descriptor: GTK4DescriptorNode, canvasPayloads: [GTK4CanvasPayload])
        if fromObservation {
            #if canImport(Observation)
            if #available(macOS 14.0, iOS 17.0, *) {
                var captured: (descriptor: GTK4DescriptorNode, canvasPayloads: [GTK4CanvasPayload])!
                withObservationTracking {
                    captured = gtkDescribeCapturingCanvasPayloads(describeBody)
                } onChange: { [weak self] in
                    guard let self else { return }
                    self.lock.lock()
                    self.observationDidFire = true
                    self.lock.unlock()
                    self.scheduleRebuild()
                }
                described = captured
            } else {
                described = gtkDescribeCapturingCanvasPayloads(describeBody)
            }
            #else
            described = gtkDescribeCapturingCanvasPayloads(describeBody)
            #endif
        } else {
            described = gtkDescribeCapturingCanvasPayloads(describeBody)
        }
        setCurrentEnvironment(previousEnv)

        let newIdentified = gtkIdentifyDescriptorTree(described.descriptor)
        let canvasPayloads = gtkCanvasPayloadsByIdentity(
            descriptorRoot: newIdentified,
            payloads: described.canvasPayloads
        )
        let plan = gtkPlanDescriptorTree(old: oldRetained, new: newIdentified)

        // Diagnostics (SWIFTOPENUI_NARROW_DEBUG): during a drag, if the narrow path
        // is about to be rejected, log the offending node(s) — the reason a host
        // falls to a full rebuild instead of updating in place. Deduped so a held
        // drag doesn't flood stderr.
        if gtkNarrowDebugEnabled,
           GTKViewHost.globalInteractionDepth > 0,
           !gtkCanApplyTextColorHostMutation(plan: plan) {
            var reasons: [String] = []
            gtkCollectNonNarrowReasons(plan, into: &reasons)
            let line = "[narrow-reject] " + reasons.prefix(8).joined(separator: " | ")
            if line != GTKViewHost.lastNarrowRejectLog {
                GTKViewHost.lastNarrowRejectLog = line
                FileHandle.standardError.write(Data((line + "\n").utf8))
            }
        }

        if gtkCanApplyTextColorHostMutation(plan: plan) {
            let action = gtkExecuteDescriptorPlan(
                old: oldExecutor,
                plan: plan,
                canvasPayloadsByIdentity: canvasPayloads
            )

            // Verify all slots are still valid before mutating
            let allSlotsValid = gtkAllSlotsValid(action: action)
            if allSlotsValid {
                let result = gtkApplyHookMutation(action: action)
                if gtkHookMutationSucceeded(result) {
                    // Success — update retained state, skip full rebuild
                    lastRetainedDescriptor = gtkRetainDescriptorTree(newIdentified)
                    retainedExecutor = action.resultingNode
                    return true
                }
            }
        }
        return false
    }

    /// Apply a narrow in-place mutation for a host whose rebuild is deferred by an
    /// active drag, WITHOUT falling back to a full rebuild. Lets native widgets
    /// bound to the value being dragged (e.g. a `TextField`'s `GtkEntry`) track
    /// live during the drag, the same way Canvas hosts track via redraw — the
    /// narrow path never recreates widgets, so it cannot detach the gesture. Any
    /// structural change stays deferred to drag-end (where the full rebuild runs,
    /// picking it up because a failed narrow attempt leaves the retained
    /// descriptor untouched). Called from `redrawDeferredInteractionHosts` per
    /// drag-update. `observationDidFire` is intentionally NOT cleared here — the
    /// deferred drag-end rebuild still needs it to re-register observation.
    func applyDeferredNarrowMutationDuringInteraction() {
        lock.lock()
        guard isContainerAlive else { lock.unlock(); return }
        let fromObservation = observationDidFire
        lock.unlock()
        _ = tryNarrowMutation(fromObservation: fromObservation)
    }

    func rebuild() {
        lock.lock()
        scheduled = false
        guard isContainerAlive else {
            lock.unlock()
            return
        }
        let shouldRestoreFocus = !suppressFocusRestoreOnce
        let animation = pendingAnimation
        pendingAnimation = nil
        suppressFocusRestoreOnce = false
        let fromObservation = observationDidFire
        observationDidFire = false
        lock.unlock()

        // Narrow mutation path: try an in-place text/color/canvas update that
        // preserves the widget tree (and any in-flight gesture) instead of a
        // teardown-rebuild. If it fully applies, skip the full rebuild; otherwise
        // fall through, which re-registers observation as before.
        if tryNarrowMutation(fromObservation: fromObservation) {
            return
        }

        // Phase 7: skip body evaluation if no storage was mutated since last render.
        // But NOT when withObservationTracking's onChange fired — that callback
        // only runs once, and re-subscribing requires running body through
        // buildBodyWithTracking again. inputsUnchanged only tracks @State /
        // @Published generations, so it can't detect @Observable mutations and
        // would wrongly report "unchanged" here, leaving observation dead.
        if !fromObservation,
           let snapshot = lastInputSnapshot,
           inputsUnchanged(snapshot: snapshot) {
            return
        }

        g_object_ref(gpointer(container))
        defer { g_object_unref(gpointer(container)) }

        // Always save focus state before teardown — cursor/selection must
        // survive even when focus restore is suppressed (parity with Win32/Web).
        let focusInfo = saveFocusInfo(in: container)

        // Capture old animatable state before teardown
        var oldOpacity: Double? = nil
        var oldOffsetX: Double? = nil
        var oldOffsetY: Double? = nil
        var oldScaleX: Double? = nil
        var oldScaleY: Double? = nil
        var oldRotation: Double? = nil
        if animation != nil, let oldChild = gtk_widget_get_first_child(container) {
            oldOpacity = gtk_widget_get_opacity(oldChild)
            oldOffsetX = getWidgetDouble(oldChild, key: "gtk-swift-offset-x")
            oldOffsetY = getWidgetDouble(oldChild, key: "gtk-swift-offset-y")
            oldScaleX = getWidgetDouble(oldChild, key: "gtk-swift-scale-x")
            oldScaleY = getWidgetDouble(oldChild, key: "gtk-swift-scale-y")
            oldRotation = getWidgetDouble(oldChild, key: "gtk-swift-rotation")
        }

        // Remove old children
        while gtk_swift_is_widget(container) != 0, let child = gtk_widget_get_first_child(container) {
            gtk_box_remove(boxPointer(container), child)
        }

        // Set up rebuild context
        let previousHost = GTKViewHost.getCurrentRebuilding()
        GTKViewHost.setCurrentRebuilding(self)

        // Restore environment for the rebuild pass
        let previousEnv = getCurrentEnvironment()
        installRebuildEnvironment()
        resetOnChangeTracking()
        // Note: clearViewIDRegistry() is NOT called here because the registry
        // is global. Clearing it during one host's rebuild would wipe IDs from
        // sibling hosts. Instead, registerViewID() overwrites stale entries
        // during rebuild, and the scrollTo liveness check handles any remaining
        // stale pointers.
        beginDependencyTracking()
        let widget = buildBodyWithTracking()
        if let tracking = endDependencyTracking() {
            lastReadSet = tracking.readSet
            lastInputSnapshot = tracking.snapshots
        }
        setCurrentEnvironment(previousEnv)

        GTKViewHost.setCurrentRebuilding(previousHost)

        let newChild = widgetFromOpaque(widget)
        let childHexpand = gtk_widget_get_hexpand(newChild) != 0
        let childVexpand = gtk_widget_get_vexpand(newChild) != 0
        gtk_widget_set_hexpand(container, childHexpand ? 1 : 0)
        gtk_widget_set_vexpand(container, childVexpand ? 1 : 0)
        if childHexpand {
            gtk_widget_set_halign(newChild, GTK_ALIGN_FILL)
        }
        if childVexpand {
            gtk_widget_set_valign(newChild, GTK_ALIGN_FILL)
        }
        gtk_box_append(boxPointer(container), newChild)

        // If this subtree contains a NavigationStack titlebar, refresh it on the window.
        // We intentionally do NOT clear (pass nil) when no titlebar is found, because
        // sibling ViewHosts (e.g. GestureDemo) would clear the NavigationStack's
        // header bar that lives in a different subtree.
        if let titlebar = findTitlebarInRebuiltTree(newChild) {
            gtk_swift_set_root_window_titlebar(newChild, titlebar)
        }

        // Animate the transition: set old values, add CSS transition, then
        // schedule idle callback to apply new values — triggers CSS transition.
        if let animation = animation {
            let newOpacity = gtk_widget_get_opacity(newChild)
            let newOffsetX = getWidgetDouble(newChild, key: "gtk-swift-offset-x") ?? 0
            let newOffsetY = getWidgetDouble(newChild, key: "gtk-swift-offset-y") ?? 0
            let newScaleX = getWidgetDouble(newChild, key: "gtk-swift-scale-x") ?? 1
            let newScaleY = getWidgetDouble(newChild, key: "gtk-swift-scale-y") ?? 1
            let newRotation = getWidgetDouble(newChild, key: "gtk-swift-rotation") ?? 0

            let opacityChanged = oldOpacity != nil && oldOpacity != newOpacity
            let transformChanged = (oldOffsetX != nil && (oldOffsetX != newOffsetX || oldOffsetY != newOffsetY))
                || (oldScaleX != nil && (oldScaleX != newScaleX || oldScaleY != newScaleY))
                || (oldRotation != nil && oldRotation != newRotation)

            if opacityChanged || transformChanged {
                let timing: String
                switch animation.curve {
                case .linear:    timing = "linear"
                case .easeIn:    timing = "ease-in"
                case .easeOut:   timing = "ease-out"
                case .easeInOut: timing = "ease-in-out"
                case .spring:    timing = "cubic-bezier(0.5, 1.8, 0.3, 0.8)"
                }
                let duration = String(format: "%.2f", animation.duration)
                applyCSSToWidget(newChild, properties: "transition: all \(duration)s \(timing);")

                // Set old values on the new widget
                if opacityChanged, let oldOp = oldOpacity {
                    gtk_widget_set_opacity(newChild, oldOp)
                }
                if transformChanged {
                    let ox = oldOffsetX ?? newOffsetX
                    let oy = oldOffsetY ?? newOffsetY
                    let sx = oldScaleX ?? newScaleX
                    let sy = oldScaleY ?? newScaleY
                    let r = oldRotation ?? newRotation
                    let oldTransform = buildTransformCSS(offsetX: ox, offsetY: oy, scaleX: sx, scaleY: sy, rotation: r)
                    if !oldTransform.isEmpty {
                        applyCSSToWidget(newChild, properties: oldTransform)
                    }
                }

                // On next frame, apply final values — CSS transition interpolates
                let ctx = AnimationTransitionContext(
                    widget: newChild,
                    targetOpacity: opacityChanged ? newOpacity : nil,
                    targetTransform: transformChanged
                        ? buildTransformCSS(offsetX: newOffsetX, offsetY: newOffsetY, scaleX: newScaleX, scaleY: newScaleY, rotation: newRotation)
                        : nil
                )
                let retained = Unmanaged.passRetained(ctx).toOpaque()
                g_idle_add({ userData -> gboolean in
                    let ctx = Unmanaged<AnimationTransitionContext>.fromOpaque(userData!).takeRetainedValue()
                    guard gtk_swift_is_widget(ctx.widget) != 0 else { return 0 }
                    if let opacity = ctx.targetOpacity {
                        gtk_widget_set_opacity(ctx.widget, opacity)
                    }
                    if let transform = ctx.targetTransform {
                        applyCSSToWidget(ctx.widget, properties: transform)
                    }
                    return 0 // G_SOURCE_REMOVE
                }, retained)
            }
        }

        // Restore focus/cursor to the matching input after rebuild.
        // When suppressed, skip grab_focus but still restore cursor/selection.
        if let info = focusInfo {
            restoreFocusInfo(info, in: newChild, suppressFocus: !shouldRestoreFocus)
        }

        // Capture descriptor state for next rebuild's narrow mutation path
        if let describeBody = describeBody {
            let previousEnvForDesc = getCurrentEnvironment()
            installRebuildEnvironment()
            let described = gtkDescribeCapturingCanvasPayloads(describeBody)
            setCurrentEnvironment(previousEnvForDesc)

            let identified = gtkIdentifyDescriptorTree(described.descriptor)
            let canvasPayloads = gtkCanvasPayloadsByIdentity(
                descriptorRoot: identified,
                payloads: described.canvasPayloads
            )
            lastRetainedDescriptor = gtkRetainDescriptorTree(identified)
            var executor = gtkMakeExecutorTree(
                from: identified,
                canvasPayloadsByIdentity: canvasPayloads
            )
            executor = gtkCaptureSupportedNativeSlots(
                from: newChild,
                descriptorRoot: identified,
                executorRoot: executor
            )
            retainedExecutor = executor
        }
    }

    // MARK: - Thread-local rebuild context

    static func getCurrentRebuilding() -> GTKViewHost? {
        guard let ptr = pthread_getspecific(rebuildingViewHostKey) else { return nil }
        return Unmanaged<GTKViewHost>.fromOpaque(ptr).takeUnretainedValue()
    }

    static func setCurrentRebuilding(_ host: GTKViewHost?) {
        if let host = host {
            let ptr = Unmanaged.passUnretained(host).toOpaque()
            pthread_setspecific(rebuildingViewHostKey, ptr)
        } else {
            pthread_setspecific(rebuildingViewHostKey, nil)
        }
    }
}

/// Recursively search a rebuilt subtree for a window titlebar attachment point.
private func findTitlebarInRebuiltTree(_ widget: UnsafeMutablePointer<GtkWidget>) -> UnsafeMutablePointer<GtkWidget>? {
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    if let data = g_object_get_data(gobject, "gtk-swift-window-titlebar") {
        return UnsafeMutableRawPointer(data).assumingMemoryBound(to: GtkWidget.self)
    }

    let typeName = String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
    if typeName == "GtkStack" {
        let stackOp = OpaquePointer(widget)
        if let visibleChild = gtk_stack_get_visible_child(stackOp) {
            return findTitlebarInRebuiltTree(visibleChild)
        }
        return nil
    }

    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        if let found = findTitlebarInRebuiltTree(c) {
            return found
        }
        child = gtk_widget_get_next_sibling(c)
    }
    return nil
}

// MARK: - Animation transition context

/// Holds state for deferred animation on a rebuilt widget.
private class AnimationTransitionContext {
    let widget: UnsafeMutablePointer<GtkWidget>
    let targetOpacity: Double?
    let targetTransform: String?

    init(widget: UnsafeMutablePointer<GtkWidget>, targetOpacity: Double?, targetTransform: String?) {
        self.widget = widget
        self.targetOpacity = targetOpacity
        self.targetTransform = targetTransform
        g_object_ref(gpointer(widget))
    }

    deinit {
        g_object_unref(gpointer(widget))
    }
}

// MARK: - Focus preservation across rebuilds

/// Info about a focused editable widget, used to restore focus after rebuild.
private struct FocusInfo {
    /// DFS index of the focused input within the container tree.
    let editableIndex: Int
    /// Cursor position within the editable text.
    let cursorPosition: Int
    /// Whether the focused widget was a GtkTextView (vs GtkEditable).
    let isTextView: Bool
    /// Whether the focused widget was a GtkScale/GtkRange (no cursor needed).
    let isScale: Bool
    /// Selection start offset (-1 if no selection).
    let selectionStart: Int
    /// Selection end offset (-1 if no selection).
    let selectionEnd: Int
}

/// Check if a widget is a focusable input (GtkEditable, GtkTextView, or GtkScale).
private func isFocusableInput(_ widget: UnsafeMutablePointer<GtkWidget>) -> Bool {
    guard gtk_swift_is_widget(widget) != 0 else { return false }
    if gtk_swift_widget_is_editable(widget) != 0 { return true }
    if gtk_swift_widget_is_scale(widget) != 0 { return true }
    let typeName = String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
    return typeName == "GtkTextView"
}

/// Check if a widget is a GtkScale/GtkRange.
private func isScale(_ widget: UnsafeMutablePointer<GtkWidget>) -> Bool {
    guard gtk_swift_is_widget(widget) != 0 else { return false }
    return gtk_swift_widget_is_scale(widget) != 0
}

/// Check if a widget is a GtkTextView.
private func isTextView(_ widget: UnsafeMutablePointer<GtkWidget>) -> Bool {
    guard gtk_swift_is_widget(widget) != 0 else { return false }
    let typeName = String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
    return typeName == "GtkTextView"
}

/// Walk the widget subtree and find the focused editable, recording its DFS index and cursor.
private func saveFocusInfo(in container: UnsafeMutablePointer<GtkWidget>) -> FocusInfo? {
    var index = 0
    return findFocusedEditable(in: container, index: &index)
}

private func findFocusedEditable(in widget: UnsafeMutablePointer<GtkWidget>, index: inout Int) -> FocusInfo? {
    guard gtk_swift_is_widget(widget) != 0 else { return nil }
    if gtk_widget_is_focus(widget) != 0 && isFocusableInput(widget) {
        if isScale(widget) {
            // Scale/Range widgets need focus restored but have no cursor or selection.
            return FocusInfo(editableIndex: index, cursorPosition: 0, isTextView: false,
                             isScale: true, selectionStart: -1, selectionEnd: -1)
        } else if isTextView(widget) {
            let tvPtr = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GtkTextView.self)
            let buffer = gtk_text_view_get_buffer(tvPtr)!
            var iter = GtkTextIter()
            gtk_text_buffer_get_iter_at_mark(buffer, &iter, gtk_text_buffer_get_insert(buffer))
            let pos = Int(gtk_text_iter_get_offset(&iter))
            // Check for text selection
            var selStart = GtkTextIter()
            var selEnd = GtkTextIter()
            let hasSel = gtk_text_buffer_get_selection_bounds(buffer, &selStart, &selEnd)
            let ss = hasSel != 0 ? Int(gtk_text_iter_get_offset(&selStart)) : -1
            let se = hasSel != 0 ? Int(gtk_text_iter_get_offset(&selEnd)) : -1
            return FocusInfo(editableIndex: index, cursorPosition: pos, isTextView: true,
                             isScale: false, selectionStart: ss, selectionEnd: se)
        } else {
            let editable = OpaquePointer(widget)
            let pos = Int(gtk_editable_get_position(editable))
            // Check for text selection
            var ss: gint = 0
            var se: gint = 0
            let hasSel = gtk_editable_get_selection_bounds(editable, &ss, &se)
            let selStart = hasSel != 0 ? Int(ss) : -1
            let selEnd = hasSel != 0 ? Int(se) : -1
            return FocusInfo(editableIndex: index, cursorPosition: pos, isTextView: false,
                             isScale: false, selectionStart: selStart, selectionEnd: selEnd)
        }
    }
    if isFocusableInput(widget) {
        index += 1
    }

    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        if let info = findFocusedEditable(in: c, index: &index) {
            return info
        }
        child = gtk_widget_get_next_sibling(c)
    }
    return nil
}

/// Find the nth focusable input in the new subtree and grab focus + set cursor/selection.
private func restoreFocusInfo(_ info: FocusInfo, in widget: UnsafeMutablePointer<GtkWidget>, suppressFocus: Bool = false) {
    var index = 0
    if let target = findNthEditable(in: widget, targetIndex: info.editableIndex, index: &index) {
        if !suppressFocus {
            gtk_widget_grab_focus(target)
        }
        if info.isScale {
            // Scale only needs focus, no cursor or selection to restore.
            return
        }
        if info.isTextView {
            let tvPtr = UnsafeMutableRawPointer(target).assumingMemoryBound(to: GtkTextView.self)
            let buffer = gtk_text_view_get_buffer(tvPtr)!
            if info.selectionStart >= 0 && info.selectionEnd >= 0 {
                // Restore selection range
                var selStart = GtkTextIter()
                var selEnd = GtkTextIter()
                gtk_text_buffer_get_iter_at_offset(buffer, &selStart, gint(info.selectionStart))
                gtk_text_buffer_get_iter_at_offset(buffer, &selEnd, gint(info.selectionEnd))
                gtk_text_buffer_select_range(buffer, &selStart, &selEnd)
            } else {
                // Restore cursor position only
                var iter = GtkTextIter()
                gtk_text_buffer_get_iter_at_offset(buffer, &iter, gint(info.cursorPosition))
                gtk_text_buffer_place_cursor(buffer, &iter)
            }
        } else {
            let editable = OpaquePointer(target)
            if info.selectionStart >= 0 && info.selectionEnd >= 0 {
                // Restore selection range (also moves cursor to selectionEnd)
                gtk_editable_select_region(editable, gint(info.selectionStart), gint(info.selectionEnd))
            } else {
                // Restore cursor position only
                gtk_editable_set_position(editable, gint(info.cursorPosition))
            }
        }
    }
}

private func findNthEditable(in widget: UnsafeMutablePointer<GtkWidget>, targetIndex: Int, index: inout Int) -> UnsafeMutablePointer<GtkWidget>? {
    guard gtk_swift_is_widget(widget) != 0 else { return nil }
    if isFocusableInput(widget) {
        if index == targetIndex {
            return widget
        }
        index += 1
    }

    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        if let found = findNthEditable(in: c, targetIndex: targetIndex, index: &index) {
            return found
        }
        child = gtk_widget_get_next_sibling(c)
    }
    return nil
}
