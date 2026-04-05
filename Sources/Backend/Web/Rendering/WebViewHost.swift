import JavaScriptKit
import SwiftOpenUI
#if canImport(Observation)
import Observation
#endif

/// Web-specific ViewHost that manages a stable DOM container element.
/// On state change, rebuilds the body and swaps children.
/// Supports narrow mutation path for text/color in-place updates.
public class WebViewHost: AnyViewHost, DependencyTrackingHost {
    public var lastReadSet: Set<ObjectIdentifier>?
    public var lastInputSnapshot: [StorageSnapshot]?
    let container: JSValue
    let buildBody: () -> JSValue
    /// Describes the body as a descriptor tree without creating DOM elements.
    var describeBody: (() -> WebDescriptorNode)?
    /// Retained descriptor state for narrow mutation path.
    var lastRetainedDescriptor: WebRetainedDescriptorNode?
    var retainedExecutor: WebRetainedExecutorNode?
    /// Retained JSClosure instances for event handlers and callbacks.
    /// Cleared at the start of each full rebuild.
    var retainedClosures: [JSClosure] = []
    /// Per-host slot table — isolates slot ownership so rebuilding
    /// one host does not invalidate slots for unrelated hosts.
    let slotTable = WebSlotTable()
    /// Per-host sheet dismiss tracking for detecting programmatic dismissal.
    /// Keyed by render-order counter — stable as long as the view tree structure
    /// is deterministic (same as SwiftUI's structural identity model).
    var previousSheetState: [Int: (() -> Void)?] = [:]
    var currentSheetState: [Int: (() -> Void)?] = [:]
    var sheetCounter: Int = 0

    func nextSheetKey() -> Int {
        let key = sheetCounter
        sheetCounter += 1
        return key
    }

    private var scheduled = false
    private var interactiveUpdateDepth = 0
    private var rebuildDeferredDuringInteraction = false
    var capturedEnvironment: EnvironmentValues

    /// Animation from wrapping .animation() modifier — persistent across rebuilds.
    private var capturedAnimation: Animation?

    /// Animation from withAnimation() — one-shot, consumed during next rebuild.
    private var pendingAnimation: Animation?

    public init(buildBody: @escaping () -> JSValue) {
        self.buildBody = buildBody
        self.capturedEnvironment = getCurrentEnvironment()
        self.container = document.createElement("div")
    }

    /// Capture the current animation context (from a wrapping .animation()).
    public func captureAnimation() {
        capturedAnimation = getCurrentAnimation()
    }

    public func scheduleRebuild() {
        // Capture animation token now — by the time the RAF callback fires,
        // withAnimation() will have restored TLS to nil.
        if let anim = getCurrentAnimation() {
            pendingAnimation = anim
        }

        // Defer rebuild while interactive (e.g. slider drag)
        if interactiveUpdateDepth > 0 {
            rebuildDeferredDuringInteraction = true
            return
        }

        guard !scheduled else { return }
        scheduled = true

        // Use requestAnimationFrame for coalesced rebuilds
        let callback = webMakeClosure { [weak self] _ in
            self?.rebuild()
            return .undefined
        }
        _ = JSObject.global.requestAnimationFrame!(callback)
    }

    public func beginInteractiveUpdate() {
        interactiveUpdateDepth += 1
    }

    public func endInteractiveUpdate() {
        guard interactiveUpdateDepth > 0 else { return }
        interactiveUpdateDepth -= 1
        guard interactiveUpdateDepth == 0,
              rebuildDeferredDuringInteraction,
              !scheduled else { return }

        // Only capture animation when actually posting the deferred rebuild.
        if let anim = getCurrentAnimation() {
            pendingAnimation = anim
        }
        rebuildDeferredDuringInteraction = false
        scheduled = true

        let callback = webMakeClosure { [weak self] _ in
            self?.rebuild()
            return .undefined
        }
        _ = JSObject.global.requestAnimationFrame!(callback)
    }

    private var suppressFocusRestoreOnce = false

    public func suppressNextFocusRestore() {
        suppressFocusRestoreOnce = true
    }

    /// Build the body with observation tracking for @Observable support.
    func buildBodyWithTracking() -> JSValue {
        #if canImport(Observation)
        if #available(macOS 14.0, iOS 17.0, *) {
            var result: JSValue = .undefined
            withObservationTracking {
                result = buildBody()
            } onChange: { [weak self] in
                self?.scheduleRebuild()
            }
            return result
        }
        #endif
        return buildBody()
    }

    /// Release old descriptor state and closures to free memory during new render.
    func clear() {
        lastRetainedDescriptor = nil
        retainedExecutor = nil
        retainedClosures.removeAll()
        slotTable.clear()
        // Removed: webClearFallbackClosures() — unsafe to clear root-level closures
    }

    func rebuild() {
        scheduled = false

        // --- Narrow mutation path: try text/color in-place update ---
        /*
        if let describeBody = describeBody,
           let oldRetained = lastRetainedDescriptor,
           let oldExecutor = retainedExecutor {

            let previousEnv = getCurrentEnvironment()
            setCurrentEnvironment(capturedEnvironment)
            let newDescriptor = describeBody()
            setCurrentEnvironment(previousEnv)

            let newIdentified = webIdentifyDescriptorTree(newDescriptor)
            let plan = webPlanDescriptorTree(old: oldRetained, new: newIdentified)

            if webCanApplyTextColorHostMutation(plan: plan) {
                let action = webExecuteDescriptorPlan(old: oldExecutor, plan: plan)

                // Set this host's slot table as current for validation + mutation
                _webCurrentSlotTable = slotTable
                defer { _webCurrentSlotTable = nil }

                // Verify all slots are still valid before mutating
                if webAllSlotsValid(action: action) {
                    let result = webApplyHookMutation(action: action)
                    if webHookMutationSucceeded(result) {
                        // Success — update retained state, skip full rebuild
                        lastRetainedDescriptor = webRetainDescriptorTree(newIdentified)
                        retainedExecutor = action.resultingNode
                        return
                    }
                }
            }
            // Fall through to full rebuild
        }
        */

        // Consume one-shot tokens before any early return,
        // so they cannot leak into a later unrelated rebuild.
        let rebuildAnim = pendingAnimation ?? capturedAnimation
        pendingAnimation = nil
        let suppressFocus = suppressFocusRestoreOnce
        suppressFocusRestoreOnce = false

        // Phase 7: skip body evaluation if no storage was mutated since last render
        if let snapshot = lastInputSnapshot,
           inputsUnchanged(snapshot: snapshot) {
            return
        }

        var oldSnapshots: [WebAnimatableSnapshot] = []
        if rebuildAnim != nil {
            if let oldChild = container.firstChild.object {
                oldSnapshots = webCollectAnimatableSnapshots(from: JSValue.object(oldChild))
            }
        }

        // --- Focus: save input state before DOM teardown ---
        let focusSnapshot = webSaveFocusState(in: container)

        // Release old state before new render pass to free memory
        clear()

        // Prepare sheet transition tracking for this render pass
        previousSheetState = currentSheetState
        currentSheetState = [:]
        sheetCounter = 0

        // Remove old children
        container.innerHTML = ""

        // Restore animation context for this rebuild so subtree renderers
        // (OpacityView, etc.) see the active animation in TLS.
        let previousAnim = getCurrentAnimation()
        if let rebuildAnim {
            setCurrentAnimation(rebuildAnim)
        }

        WebViewHost.withHost(self) {
            let previousEnv = getCurrentEnvironment()
            setCurrentEnvironment(capturedEnvironment)
            resetOnChangeTracking()
            // ID registry not cleared — global, overwrite + liveness handles stale entries
            beginDependencyTracking()
            let element = buildBodyWithTracking()
            if let tracking = endDependencyTracking() {
                lastReadSet = tracking.readSet
                lastInputSnapshot = tracking.snapshots
            }
            setCurrentEnvironment(previousEnv)

            _ = container.appendChild(element)
        }

        // --- Focus: restore input state after new DOM is in place ---
        // suppressFocus was consumed before Phase 7 early return (same
        // lifecycle as pendingAnimation) so it cannot leak.
        if let snapshot = focusSnapshot {
            webRestoreFocusState(snapshot, in: container, suppressFocus: suppressFocus)
        }

        setCurrentAnimation(previousAnim)

        // --- Animation: two-phase CSS transition ---
        if let anim = rebuildAnim, !oldSnapshots.isEmpty {
            if let newChild = container.firstChild.object {
                let newWrappers = webCollectAnimatableWrappers(from: JSValue.object(newChild))

                // STRICT GUARD: only animate when key sequences match exactly
                // AND all keys are unique. Keys are "role@depth" — if any two
                // wrappers share the same key (same-role siblings at the same
                // depth), we cannot reliably pair old↔new, so bail out.
                let oldKeys = oldSnapshots.map { $0.key }
                let newKeys = newWrappers.map { $0.key }
                let keysMatch = oldKeys == newKeys
                    && Set(oldKeys).count == oldKeys.count

                if keysMatch {
                    let timing = webCSSTimingFunction(anim.curve)
                    let transitionValue = "all \(anim.duration)s \(timing)"

                    // Phase 1: save new computed values, apply old values + transition.
                    var savedNewValues: [(opacity: String, transform: String)] = []
                    for (i, wrapper) in newWrappers.enumerated() {
                        let el = wrapper.element
                        let old = oldSnapshots[i]

                        // Read the new (renderer-set) computed values before overwriting
                        let computed = JSObject.global.getComputedStyle!(el)
                        let newOpacity = computed.opacity.string ?? "1"
                        let newTransform = computed.transform.string ?? "none"
                        savedNewValues.append((opacity: newOpacity, transform: newTransform))

                        // Apply old values
                        if let opacity = old.opacity {
                            _ = el.style.setProperty("opacity", opacity)
                        }
                        if let transform = old.transform {
                            _ = el.style.setProperty("transform", transform)
                        }
                        _ = el.style.setProperty("transition", transitionValue)
                    }

                    // Phase 2: on next frame, apply saved new values explicitly.
                    // CSS transition interpolates from old → new.
                    let refs = newWrappers.map { $0.element }
                    let saved = savedNewValues
                    let callback = webMakeClosure { _ in
                        for (i, el) in refs.enumerated() {
                            let newVals = saved[i]
                            if oldSnapshots[i].role == "opacity" {
                                _ = el.style.setProperty("opacity", newVals.opacity)
                            } else {
                                _ = el.style.setProperty("transform", newVals.transform)
                            }
                        }
                        return .undefined
                    }
                    _ = JSObject.global.requestAnimationFrame!(callback)
                }
            }
        }

        // Detect sheet transitions: fire onDismiss for sheets that were
        // presenting last render but are not presenting now.
        for (key, callback) in previousSheetState {
            if currentSheetState[key] == nil, let dismiss = callback {
                dismiss()
            }
        }

        // Capture descriptor state for next rebuild's narrow mutation path
        /* Temporarily disabled to isolate OOM
        if let describeBody = describeBody {
            let previousEnvForDesc = getCurrentEnvironment()
            setCurrentEnvironment(capturedEnvironment)
            let descriptor = describeBody()
            setCurrentEnvironment(previousEnvForDesc)

            let identified = webIdentifyDescriptorTree(descriptor)
            lastRetainedDescriptor = webRetainDescriptorTree(identified)
            var executor = webMakeExecutorTree(from: identified)
            _webCurrentSlotTable = slotTable
            executor = webCaptureSupportedNativeSlots(
                from: container,
                descriptorRoot: identified,
                executorRoot: executor
            )
            _webCurrentSlotTable = nil
            retainedExecutor = executor
        }
        */
    }

    // MARK: - Rebuild context

    private static var hostStack: [WebViewHost] = []

    public static var currentRebuilding: WebViewHost? {
        hostStack.last
    }

    public static func withHost<T>(_ host: WebViewHost, _ body: () -> T) -> T {
        hostStack.append(host)
        defer { hostStack.removeLast() }
        return body()
    }
}

// MARK: - Animation helpers

/// Snapshot of an animatable wrapper's identity and computed style values.
struct WebAnimatableSnapshot {
    /// Composite key: "role@depth" (e.g. "opacity@3") for pairing old↔new.
    let key: String
    let role: String
    /// Computed opacity string (e.g. "0.5") — only for role "opacity".
    let opacity: String?
    /// Computed transform string (e.g. "translate(10px, 20px)") — for offset/scale/rotation.
    let transform: String?
}

/// Wrapper reference with its identity key, for post-rebuild pairing.
struct WebAnimatableWrapper {
    /// Composite key: "role@depth" — must match the snapshot key for pairing.
    let key: String
    let role: String
    let element: JSValue
}

/// Collect animatable snapshots from the old DOM subtree before teardown.
/// Only considers elements explicitly marked with `data-anim-role`.
/// Uses DOM depth as an additional identity signal to distinguish
/// duplicate roles at different tree positions.
func webCollectAnimatableSnapshots(from root: JSValue) -> [WebAnimatableSnapshot] {
    var result: [WebAnimatableSnapshot] = []
    webCollectAnimatableSnapshotsRecursive(root, depth: 0, into: &result)
    return result
}

private func webCollectAnimatableSnapshotsRecursive(
    _ node: JSValue, depth: Int, into result: inout [WebAnimatableSnapshot]
) {
    if let role = node.getAttribute.function.flatMap({ _ in node.getAttribute("data-anim-role").string }) {
        let computed = JSObject.global.getComputedStyle!(node)
        let snapshot = WebAnimatableSnapshot(
            key: "\(role)@\(depth)",
            role: role,
            opacity: role == "opacity" ? computed.opacity.string : nil,
            transform: (role == "offset" || role == "scale" || role == "rotation")
                ? computed.transform.string : nil
        )
        result.append(snapshot)
    }
    guard let obj = node.object else { return }
    let childrenVal = obj.children
    let count = Int(childrenVal.length.number ?? 0)
    for i in 0..<count {
        webCollectAnimatableSnapshotsRecursive(childrenVal[i], depth: depth + 1, into: &result)
    }
}

/// Collect animatable wrapper references from the new DOM subtree after rebuild.
/// Only considers elements explicitly marked with `data-anim-role`.
func webCollectAnimatableWrappers(from root: JSValue) -> [WebAnimatableWrapper] {
    var result: [WebAnimatableWrapper] = []
    webCollectAnimatableWrappersRecursive(root, depth: 0, into: &result)
    return result
}

private func webCollectAnimatableWrappersRecursive(
    _ node: JSValue, depth: Int, into result: inout [WebAnimatableWrapper]
) {
    if let role = node.getAttribute.function.flatMap({ _ in node.getAttribute("data-anim-role").string }) {
        result.append(WebAnimatableWrapper(key: "\(role)@\(depth)", role: role, element: node))
    }
    guard let obj = node.object else { return }
    let childrenVal = obj.children
    let count = Int(childrenVal.length.number ?? 0)
    for i in 0..<count {
        webCollectAnimatableWrappersRecursive(childrenVal[i], depth: depth + 1, into: &result)
    }
}

// MARK: - Focus state preservation

/// Snapshot of the focused element's identity and selection state.
struct WebFocusSnapshot {
    let tag: String              // "input" or "textarea"
    let inputType: String        // "text", "password", "range", etc.
    let typeIndex: Int           // Nth element of this tag+type
    let typeCount: Int           // Total count of this tag+type (bail guard)
    let selectionStart: Int?     // Only for text-selectable types
    let selectionEnd: Int?
    let selectionDirection: String?
}

/// Input types that support selectionStart/selectionEnd/setSelectionRange.
private let textSelectableTypes: Set<String> = ["text", "password", "search", "textarea"]

/// Save the focused element's identity and selection state before DOM teardown.
/// Returns nil if no element inside the container is focused.
func webSaveFocusState(in container: JSValue) -> WebFocusSnapshot? {
    guard let docObj = document.object else { return nil }
    let activeElement = docObj.activeElement
    guard let activeObj = activeElement.object else { return nil }

    // Check the focused element is inside our container
    guard container.contains.function != nil else { return nil }
    let contains = container.contains(activeElement)
    guard contains.boolean == true else { return nil }

    // Read tag and type
    let tag = (activeObj.tagName.string ?? "").lowercased()
    guard tag == "input" || tag == "textarea" else { return nil }

    let inputType: String
    if tag == "textarea" {
        inputType = "textarea"
    } else {
        inputType = (activeObj.type.string ?? "text").lowercased()
    }

    // Count elements of this tag+type and find the index of the active one
    let allMatching = webCollectElementsByTagAndType(in: container, tag: tag, inputType: inputType)
    var typeIndex = -1
    for (i, el) in allMatching.enumerated() {
        if activeElement == el {
            typeIndex = i
            break
        }
    }
    guard typeIndex >= 0 else { return nil }

    // Read selection if text-selectable
    var selStart: Int? = nil
    var selEnd: Int? = nil
    var selDir: String? = nil
    if textSelectableTypes.contains(inputType) {
        selStart = activeObj.selectionStart.number.map { Int($0) }
        selEnd = activeObj.selectionEnd.number.map { Int($0) }
        selDir = activeObj.selectionDirection.string
    }

    return WebFocusSnapshot(
        tag: tag,
        inputType: inputType,
        typeIndex: typeIndex,
        typeCount: allMatching.count,
        selectionStart: selStart,
        selectionEnd: selEnd,
        selectionDirection: selDir
    )
}

/// Restore focus and selection state after DOM rebuild.
/// Bails silently if the element cannot be matched confidently.
///
/// When `suppressFocus` is true, focus() is skipped but selection is still
/// restored if the target is a text-selectable type. This matches Win32
/// behavior where edit cursors survive even when focus restore is suppressed.
///
/// **Known limitation:** The count-based bail guard detects insertions and
/// removals but does NOT detect same-type reorders. If two `input[type="text"]`
/// peers swap positions while the count stays the same, the restore may
/// target the wrong control. This is a structural identity limitation
/// shared with the animation pairing scheme.
func webRestoreFocusState(_ snapshot: WebFocusSnapshot, in container: JSValue, suppressFocus: Bool = false) {
    let newMatching = webCollectElementsByTagAndType(
        in: container, tag: snapshot.tag, inputType: snapshot.inputType)

    // Bail guard: if count changed, structure shifted — can't match safely
    guard newMatching.count == snapshot.typeCount else { return }
    guard snapshot.typeIndex < newMatching.count else { return }

    let target = newMatching[snapshot.typeIndex]

    // Restore focus unless suppressed — silently skip if focus() is not available
    if !suppressFocus, target.focus.function != nil {
        _ = target.focus()
    }

    // Restore selection for text-selectable types even when focus is suppressed.
    // On Web, setSelectionRange() works on the element regardless of focus state.
    if textSelectableTypes.contains(snapshot.inputType),
       let start = snapshot.selectionStart,
       let end = snapshot.selectionEnd,
       target.setSelectionRange.function != nil {
        let dir = snapshot.selectionDirection ?? "none"
        _ = target.setSelectionRange(start, end, dir)
    }
}

/// Collect all elements matching a given tag and input type within a container.
/// For textarea, inputType is "textarea". DFS order.
private func webCollectElementsByTagAndType(
    in container: JSValue, tag: String, inputType: String
) -> [JSValue] {
    // Use querySelectorAll for efficient DOM traversal
    let selector: String
    if tag == "textarea" {
        selector = "textarea"
    } else {
        selector = "input[type=\"\(inputType)\"]"
    }
    let nodeList = container.querySelectorAll(selector)
    guard let count = nodeList.length.number.map({ Int($0) }) else { return [] }

    var result: [JSValue] = []
    for i in 0..<count {
        result.append(nodeList[i])
    }
    return result
}

// MARK: - Stateful view rendering

/// Render a stateful composite view wrapped in a WebViewHost.
public func webRenderStatefulView<V: View>(_ view: V) -> JSValue {
    let mutableView = view

    // Install mutation hooks on first use
    webInstallMutationHooks()

    let host = WebViewHost {
        webRenderView(mutableView.body)
    }
    host.describeBody = {
        webDescribeView(mutableView.body)
    }
    installState(mutableView, host: host)
    host.captureAnimation()

    // Retain the host so it survives beyond this function.
    // Without this, the host is deallocated and scheduleRebuild
    // (via requestAnimationFrame) finds a nil weak self.
    _webRetainedHosts.append(host)

    // Initial render — set currentRebuilding so child views (e.g. Slider)
    // can find their containing host for interactive update hooks.
    return WebViewHost.withHost(host) {
        let previousEnv = getCurrentEnvironment()
        host.capturedEnvironment = previousEnv
        resetOnChangeTracking()
        // ID registry not cleared — global, overwrite + liveness handles stale entries
        beginDependencyTracking()
        let element = host.buildBodyWithTracking()
        if let tracking = endDependencyTracking() {
            host.lastReadSet = tracking.readSet
            host.lastInputSnapshot = tracking.snapshots
        }
        _ = host.container.appendChild(element)

        // Capture initial descriptor state for narrow mutation path
        /* Temporarily disabled to isolate OOM
        let descriptor = webDescribeView(mutableView.body)
        let identified = webIdentifyDescriptorTree(descriptor)
        host.lastRetainedDescriptor = webRetainDescriptorTree(identified)
        var executor = webMakeExecutorTree(from: identified)
        _webCurrentSlotTable = host.slotTable
        executor = webCaptureSupportedNativeSlots(
            from: host.container,
            descriptorRoot: identified,
            executorRoot: executor
        )
        _webCurrentSlotTable = nil
        host.retainedExecutor = executor
        */

        return host.container
    }
}
