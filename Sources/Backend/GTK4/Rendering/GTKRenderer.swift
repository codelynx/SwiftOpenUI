import CGTK
import CGTKBridge
import SwiftOpenUI
import SwiftOpenUISymbols
import Foundation

/// Marker string for Spacer widgets.
let gtkSwiftSpacerMarker = "gtk-swift-spacer"
/// Marker string for Divider widgets.
let gtkSwiftDividerMarker = "gtk-swift-divider"
/// Marker string for backend-only layout helpers that should not be
/// considered rendered SwiftOpenUI content by snapshot capture.
let gtkSwiftLayoutHelperMarker = "gtk-swift-layout-helper"

private func gtkMarkLayoutHelper(_ widget: UnsafeMutablePointer<GtkWidget>) {
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    g_object_set_data(gobject, gtkSwiftLayoutHelperMarker, UnsafeMutableRawPointer(bitPattern: 1))
}

private func gtkVStackSpacing(_ spacing: Int) -> Int {
    spacing == stackDefaultSpacing ? 0 : resolveStackSpacing(spacing)
}

/// Convert a Double pixel dimension into an integer GTK size. GTK widgets
/// use integer pixels, so plain `gint(x)` truncates — a 0.5pt divider
/// collapses to 0 and becomes invisible. Round positive sub-pixel values
/// up so that hairline dividers and similar sub-pixel shapes are at least
/// one device pixel tall. Larger positive values keep their integer part
/// so existing whole-pixel layouts are unchanged.
@inline(__always)
private func gtkPixelSize(_ value: Double) -> gint {
    if value > 0 && value < 1 { return 1 }
    return gint(value)
}

// MARK: - GTK rendering protocol

/// Protocol that views implement (via extensions) to provide GTK widget creation.
/// Backend code extends each SwiftOpenUI view type to conform.
public protocol GTKRenderable {
    func gtkCreateWidget() -> OpaquePointer
}

/// Protocol for views that provide multiple GTK child widgets.
public protocol GTKMultiChildRenderable {
    func gtkRenderChildren() -> [OpaquePointer]
}

// MARK: - Rendering dispatch

/// Render any SwiftOpenUI View into a GTK widget pointer.
public func gtkRenderView<V: View>(_ view: V) -> OpaquePointer {
    // Primitive views with known GTK rendering
    if let renderable = view as? GTKRenderable {
        return renderable.gtkCreateWidget()
    }

    // MultiChildView (TupleView4-12, Group, ForEach, etc.) — render children
    // into a vertical box.  This must come before the reactive/body checks
    // because these types have Body = Never.
    if let multi = view as? MultiChildView {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        for child in multi.children {
            let widget = widgetFromOpaque(gtkRenderAnyView(child))
            gtk_box_append(boxPointer(box), widget)
        }
        return opaqueFromWidget(box)
    }

    // Composite view with reactive state — wrap in GTKViewHost
    if hasReactiveProperties(view) {
        return gtkRenderStatefulView(view)
    }

    // Stateless composite view — recurse through body
    return gtkRenderView(view.body)
}

/// Render children from a view.
public func gtkRenderChildren<V: View>(_ view: V) -> [OpaquePointer] {
    if let multi = view as? GTKMultiChildRenderable {
        return multi.gtkRenderChildren()
    }
    if let multi = view as? MultiChildView {
        return multi.children.map { child in
            func render<C: View>(_ c: C) -> OpaquePointer { gtkRenderView(c) }
            return render(child)
        }
    }
    return [gtkRenderView(view)]
}

/// Render an existential (any View).
public func gtkRenderAnyView(_ view: any View) -> OpaquePointer {
    func render<V: View>(_ v: V) -> OpaquePointer { gtkRenderView(v) }
    return render(view)
}

private struct GTKLayoutMeasureContext: LayoutMeasureContext {
    let widgets: [UnsafeMutablePointer<GtkWidget>]

    func measure(_ subview: LayoutSubview, proposal: ProposedViewSize) -> LayoutMeasurement {
        let widget = widgets[subview.index]
        return LayoutMeasurement(
            size: gtkMeasureWidgetNaturalSize(widget),
            expandsToFillWidth: gtk_widget_get_hexpand(widget) != 0,
            expandsToFillHeight: gtk_widget_get_vexpand(widget) != 0
        )
    }
}

private func gtkMeasureLayoutSubviews(
    _ widgets: [UnsafeMutablePointer<GtkWidget>]
) -> [LayoutMeasurement] {
    let context = GTKLayoutMeasureContext(widgets: widgets)
    return widgets.indices.map { index in
        context.measure(LayoutSubview(index: index), proposal: .unspecified)
    }
}

// MARK: - Deferred callback environment binding

/// Capture the current environment at registration time and restore it around
/// a deferred callback that may read `@Environment(...)`.  See
/// `docs/architecture/deferred-callback-environment-binding.md`.
func bindActionToCurrentEnvironment(_ action: @escaping () -> Void) -> () -> Void {
    let capturedEnvironment = getCurrentEnvironment()
    return {
        let previousEnvironment = getCurrentEnvironment()
        setCurrentEnvironment(capturedEnvironment)
        defer { setCurrentEnvironment(previousEnvironment) }
        action()
    }
}

func bindActionToCurrentEnvironment<T>(_ action: @escaping (T) -> Void) -> (T) -> Void {
    let capturedEnvironment = getCurrentEnvironment()
    return { value in
        let previousEnvironment = getCurrentEnvironment()
        setCurrentEnvironment(capturedEnvironment)
        defer { setCurrentEnvironment(previousEnvironment) }
        action(value)
    }
}

// MARK: - View GTK extensions

extension Text: GTKRenderable, GTKDescribable {
    public func gtkCreateWidget() -> OpaquePointer {
        let label = gtk_label_new(content)!
        gtk_swift_label_set_xalign(label, 0)
        gtk_swift_label_set_yalign(label, 0.5)
        // SwiftUI Text wraps to intrinsic size — prevent GTK expansion.
        gtk_widget_set_hexpand(label, 0)
        gtk_widget_set_vexpand(label, 0)
        gtkMarkHostedNodeKind(label, kind: .text)
        return opaqueFromWidget(label)
    }

    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(kind: .text, typeName: "Text",
                           props: .text(GTK4TextDescriptor(content: content)))
    }
}

extension EmptyView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        opaqueFromWidget(gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!)
    }
}

extension Spacer: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(kind: .spacer, typeName: "Spacer")
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let label = gtk_label_new(nil)!
        let gobject = UnsafeMutableRawPointer(label).assumingMemoryBound(to: GObject.self)
        g_object_set_data(gobject, gtkSwiftSpacerMarker, UnsafeMutableRawPointer(bitPattern: 1))
        return opaqueFromWidget(label)
    }
}

extension Divider: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(kind: .divider, typeName: "Divider")
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let sep = gtk_separator_new(GTK_ORIENTATION_HORIZONTAL)!
        gtk_widget_set_hexpand(sep, 1)
        let gobject = UnsafeMutableRawPointer(sep).assumingMemoryBound(to: GObject.self)
        g_object_set_data(gobject, gtkSwiftDividerMarker, UnsafeMutableRawPointer(bitPattern: 1))
        return opaqueFromWidget(sep)
    }
}

extension TextField: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let entry = gtk_entry_new()!
        gtk_widget_set_hexpand(entry, 1)
        let entryPtr = UnsafeMutableRawPointer(entry).assumingMemoryBound(to: GtkEntry.self)
        let bufferPtr = gtk_entry_get_buffer(entryPtr)
        gtk_entry_buffer_set_text(bufferPtr, text.wrappedValue, -1)
        if !title.isEmpty {
            gtk_entry_set_placeholder_text(entryPtr, title)
        }

        // Wire text changes back through Binding<String>.
        // Listen on the GtkEntryBuffer's "notify::text" signal so we catch
        // all changes (typing, paste, programmatic).
        let binding = text
        let box = Unmanaged.passRetained(StringClosureBox { newText in
            // Avoid feedback loop: only set if value actually changed
            if binding.wrappedValue != newText {
                binding.wrappedValue = newText
            }
        }).toOpaque()

        g_signal_connect_data(
            gpointer(bufferPtr),
            "notify::text",
            unsafeBitCast({ (buffer: gpointer?, _: gpointer?, userData: gpointer?) in
                let box = Unmanaged<StringClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                let bufPtr = UnsafeMutableRawPointer(buffer!).assumingMemoryBound(to: GtkEntryBuffer.self)
                let cStr = gtk_entry_buffer_get_text(bufPtr)!
                let text = String(cString: cStr)
                box.closure(text)
            } as @convention(c) (gpointer?, gpointer?, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<StringClosureBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        // Apply text field style from environment
        let textFieldStyleType = getCurrentEnvironment().textFieldStyle
        switch textFieldStyleType {
        case .plain:
            applyCSSToWidget(entry, properties: "border: none; outline: none; box-shadow: none;")
        case .automatic, .roundedBorder:
            break // default GTK entry styling
        }

        // Wire onSubmit: GtkEntry fires "activate" on Enter key
        if let submitAction = getCurrentEnvironment().submitAction {
            let submitBox = Unmanaged.passRetained(ClosureBox {
                submitAction()
            }).toOpaque()
            g_signal_connect_data(
                gpointer(entry), "activate",
                unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                    guard let userData else { return }
                    Unmanaged<ClosureBox>.fromOpaque(userData).takeUnretainedValue().closure()
                } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
                submitBox,
                { (data: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    guard let data else { return }
                    Unmanaged<ClosureBox>.fromOpaque(data).release()
                },
                GConnectFlags(rawValue: 0)
            )
        }

        gtkApplyEnabledState(to: entry)
        return opaqueFromWidget(entry)
    }
}

extension FocusedView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        gtk_widget_set_focusable(widget, 1)

        let state = focusState
        let controller = gtk_event_controller_focus_new()!

        // Focus-in: set @FocusState to true
        let enterBox = Unmanaged.passRetained(ClosureBox {
            if !state.wrappedValue { state.storage.setValue(true) }
        }).toOpaque()
        g_signal_connect_data(
            gpointer(controller), "enter",
            unsafeBitCast({ (_: gpointer?, ud: gpointer?) in
                Unmanaged<ClosureBox>.fromOpaque(ud!).takeUnretainedValue().closure()
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            enterBox,
            { (ud: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<ClosureBox>.fromOpaque(ud!).release()
            }, GConnectFlags(rawValue: 0))

        // Focus-out: set @FocusState to false
        let leaveBox = Unmanaged.passRetained(ClosureBox {
            if state.wrappedValue { state.storage.setValue(false) }
        }).toOpaque()
        g_signal_connect_data(
            gpointer(controller), "leave",
            unsafeBitCast({ (_: gpointer?, ud: gpointer?) in
                Unmanaged<ClosureBox>.fromOpaque(ud!).takeUnretainedValue().closure()
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            leaveBox,
            { (ud: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<ClosureBox>.fromOpaque(ud!).release()
            }, GConnectFlags(rawValue: 0))

        // Register programmatic focus handler: when user code sets
        // @FocusState = true, grab GTK focus on this widget.
        // No g_object_ref — check liveness before use to avoid leaking widgets.
        state.storage.onProgrammaticFocusChange = { [weak storage = state.storage] newValue in
            guard storage != nil else { return }
            guard gtk_swift_is_widget(widget) != 0 else { return }
            if newValue == true {
                gtk_swift_grab_focus(widget)
            } else {
                gtk_swift_clear_focus(widget)
            }
        }

        gtk_widget_add_controller(widget, controller)
        return opaqueFromWidget(widget)
    }
}

extension FocusedEqualsView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        gtk_widget_set_focusable(widget, 1)

        let state = focusState
        let matchValue = value
        let controller = gtk_event_controller_focus_new()!

        // Focus-in: set @FocusState to this value
        let enterBox = Unmanaged.passRetained(ClosureBox {
            state.storage.setValue(matchValue)
        }).toOpaque()
        g_signal_connect_data(
            gpointer(controller), "enter",
            unsafeBitCast({ (_: gpointer?, ud: gpointer?) in
                Unmanaged<ClosureBox>.fromOpaque(ud!).takeUnretainedValue().closure()
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            enterBox,
            { (ud: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<ClosureBox>.fromOpaque(ud!).release()
            }, GConnectFlags(rawValue: 0))

        // Focus-out: clear @FocusState to nil if still this value
        let leaveBox = Unmanaged.passRetained(ClosureBox {
            if state.storage.value == matchValue { state.storage.setValue(nil) }
        }).toOpaque()
        g_signal_connect_data(
            gpointer(controller), "leave",
            unsafeBitCast({ (_: gpointer?, ud: gpointer?) in
                Unmanaged<ClosureBox>.fromOpaque(ud!).takeUnretainedValue().closure()
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            leaveBox,
            { (ud: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<ClosureBox>.fromOpaque(ud!).release()
            }, GConnectFlags(rawValue: 0))

        // Register programmatic focus handler: when user code sets
        // @FocusState to this value, grab GTK focus on this widget.
        // No g_object_ref — check liveness before use to avoid leaking widgets.
        let prevHandler = state.storage.onProgrammaticFocusChange
        state.storage.onProgrammaticFocusChange = { newValue in
            if newValue == matchValue {
                guard gtk_swift_is_widget(widget) != 0 else { return }
                gtk_swift_grab_focus(widget)
            } else if newValue == nil {
                if gtk_swift_is_widget(widget) != 0 {
                    gtk_swift_clear_focus(widget)
                }
            } else {
                prevHandler?(newValue)
            }
        }

        gtk_widget_add_controller(widget, controller)
        return opaqueFromWidget(widget)
    }
}

extension Color: GTKRenderable, GTKDescribable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_widget_set_hexpand(box, 1)
        gtk_widget_set_vexpand(box, 1)
        let css = String(format: "background-color: rgba(%d, %d, %d, %.3f);",
                         Int(red * 255), Int(green * 255), Int(blue * 255), alpha)
        applyCSSToWidget(box, properties: css)
        gtkMarkHostedNodeKind(box, kind: .color)
        return opaqueFromWidget(box)
    }

    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(kind: .color, typeName: "Color",
                           props: .color(gtkColorDescriptor(self)))
    }
}

extension Button: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        // Opaque stable leaf — Button action closures are captured at widget
        // creation and do not need descriptor-level mutation.  Declaring a
        // dedicated kind prevents the narrow-mutation guard from rejecting
        // the entire tree when a Button appears alongside mutable nodes
        // (Canvas, Text, Slider, etc.).
        GTK4DescriptorNode(kind: .button, typeName: "Button")
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let button: UnsafeMutablePointer<GtkWidget>

        if let textLabel = label as? Text {
            // Simple text label — use native label button
            button = gtk_button_new_with_label(textLabel.content)!
        } else {
            // Custom label view — render it and set as button child
            button = gtk_button_new()!
            let childWidget = widgetFromOpaque(gtkRenderView(label))
            let btnPtr = UnsafeMutableRawPointer(button).assumingMemoryBound(to: GtkButton.self)
            gtk_button_set_child(btnPtr, childWidget)
            // Remove GTK default button border/padding so custom-styled
            // labels (with .background/.frame) render cleanly.
            applyCSSToWidget(button, properties: """
                border: none;
                outline: none;
                padding: 0;
                min-height: 0;
                min-width: 0;
                """)
        }

        gtk_widget_set_hexpand(button, 0)
        gtk_widget_set_halign(button, GTK_ALIGN_START)

        // Apply button style from environment
        let buttonStyleType = getCurrentEnvironment().buttonStyle
        switch buttonStyleType {
        case .plain:
            applyCSSToWidget(button, properties: """
                border: none; background: none; padding: 0;
                min-height: 0; min-width: 0;
                """)
        case .borderedProminent:
            // Concrete macOS-like accent blue with explicit overrides of
            // GTK's default button gradient and inset shadow, both of which
            // stack on top of `background-color` and render it invisible
            // otherwise. App-configurable tint via a future `.tint()`
            // modifier; theme-aware tint via `@theme_selected_bg_color` /
            // `@accent_bg_color` is a future refinement — a previous attempt
            // at a CSS cascade `background-color: X; background-color: Y;`
            // made the button vanish (GTK CSS doesn't skip undefined-named-
            // color declarations gracefully), so that's parked.
            //
            // Disabled state: use a faded translucent blue with muted text
            // so .disabled() has a visual signal. Without this override, our
            // base rules apply even when the button is insensitive, so a
            // .borderedProminent + .disabled() button looks identical to the
            // enabled version (only click handling differs).
            applyCSSToWidget(
                button,
                properties: """
                    background-color: #3584e4;
                    background-image: none;
                    color: white;
                    border: none;
                    border-radius: 6px;
                    padding: 6px 12px;
                    box-shadow: none;
                    text-shadow: none;
                    min-height: 0;
                    """,
                disabledProperties: """
                    background-color: rgba(53, 132, 228, 0.4);
                    color: rgba(255, 255, 255, 0.7);
                    """
            )
        case .bordered:
            applyCSSToWidget(button, properties: """
                border: 1px solid @borders; border-radius: 6px;
                padding: 6px 12px;
                """)
        case .automatic:
            break // default GTK button styling
        }

        let boundAction = bindActionToCurrentEnvironment(action)
        let box = Unmanaged.passRetained(ClosureBox(boundAction)).toOpaque()
        g_signal_connect_data(
            gpointer(button),
            "clicked",
            unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                let box = Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                box.closure()
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<ClosureBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )
        // Register keyboard shortcut if present in environment
        if let ks = getCurrentEnvironment().keyboardShortcut {
            let windowID = getCurrentEnvironment().windowID
            let actionClosure = bindActionToCurrentEnvironment(action)
            let regID = KeyboardShortcutRegistry.shared.register(ks, windowID: windowID, action: actionClosure)

            // Unregister by registration ID when the button widget is destroyed
            let destroyBox = Unmanaged.passRetained(ClosureBox {
                KeyboardShortcutRegistry.shared.unregister(id: regID)
            }).toOpaque()
            g_signal_connect_data(
                gpointer(button), "destroy",
                unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                    guard let userData else { return }
                    Unmanaged<ClosureBox>.fromOpaque(userData).takeUnretainedValue().closure()
                } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
                destroyBox,
                { (data: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    if let data { Unmanaged<ClosureBox>.fromOpaque(data).release() }
                },
                GConnectFlags(rawValue: 0)
            )
        }

        gtkApplyEnabledState(to: button)
        return opaqueFromWidget(button)
    }
}

// MARK: - keyboardShortcut GTK extension

extension KeyboardShortcutView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let prev = getCurrentEnvironment()
        var env = prev
        env.keyboardShortcut = shortcut
        setCurrentEnvironment(env)
        defer { setCurrentEnvironment(prev) }
        return gtkRenderView(content)
    }
}

// MARK: - focusedValue GTK extension

extension FocusedValueView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let windowID = getCurrentEnvironment().windowID
        let providerID = FocusedValuesStore.shared.register(
            windowID: windowID, key: keyType, value: value
        )

        let widget = gtkRenderView(content)

        // Unregister provider when the widget is destroyed
        let destroyBox = Unmanaged.passRetained(ClosureBox {
            FocusedValuesStore.shared.unregister(id: providerID)
        }).toOpaque()
        let widgetPtr = widgetFromOpaque(widget)
        g_signal_connect_data(
            gpointer(widgetPtr), "destroy",
            unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                guard let userData else { return }
                Unmanaged<ClosureBox>.fromOpaque(userData).takeUnretainedValue().closure()
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            destroyBox,
            { (data: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                if let data { Unmanaged<ClosureBox>.fromOpaque(data).release() }
            },
            GConnectFlags(rawValue: 0)
        )

        return widget
    }
}

// MARK: - dropDestination GTK extension

/// State for GTK4 drop target signal handlers.
private class GTKDropState {
    let action: ([URL], CGPoint) -> Bool
    let isTargeted: ((Bool) -> Void)?
    weak var host: GTKViewHost?
    var isHovering = false
    var pendingLeaveSource: guint = 0
    init(action: @escaping ([URL], CGPoint) -> Bool, isTargeted: ((Bool) -> Void)?) {
        self.action = action
        self.isTargeted = isTargeted
    }

    func beginHoverIfNeeded() {
        cancelPendingLeave()
        guard !isHovering else { return }
        isHovering = true
        host?.beginInteractiveUpdate()
        isTargeted?(true)
    }

    func endHoverIfNeeded() {
        cancelPendingLeave()
        guard isHovering else { return }
        isHovering = false
        isTargeted?(false)
        host?.endInteractiveUpdate()
    }

    func scheduleLeave() {
        cancelPendingLeave()
        let statePtr = Unmanaged.passRetained(self).toOpaque()
        pendingLeaveSource = g_timeout_add(50, { userData -> gboolean in
            guard let userData else { return 0 }
            let state = Unmanaged<GTKDropState>.fromOpaque(userData).takeRetainedValue()
            state.pendingLeaveSource = 0
            state.endHoverIfNeeded()
            return 0
        }, statePtr)
    }

    func cancelPendingLeave() {
        if pendingLeaveSource != 0 {
            g_source_remove(pendingLeaveSource)
            pendingLeaveSource = 0
        }
    }
}

/// Keep the controller's widget alive until the next main-loop turn.
/// Drop handlers often mutate Swift state, which can synchronously rebuild
/// and destroy the target widget before GTK finishes its internal drag-state
/// cleanup for the current signal dispatch.
private func gtkPinDropTargetWidgetUntilIdle(_ target: OpaquePointer?) {
    guard let target,
          let widget = gtk_swift_event_controller_get_widget(gpointer(target)) else { return }
    let raw = UnsafeMutableRawPointer(widget)
    g_object_ref(raw)
    g_idle_add({ userData -> gboolean in
        if let userData { g_object_unref(userData) }
        return 0  // G_SOURCE_REMOVE
    }, raw)
}

extension DropDestinationView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = gtkRenderView(content)
        let widgetPtr = widgetFromOpaque(widget)

        // Create GtkDropTarget for file list drops
        let dropTarget = gtk_swift_drop_target_new_for_file_list()!

        let state = GTKDropState(action: action, isTargeted: isTargeted)
        state.host = GTKViewHost.getCurrentRebuilding()
        let stateUD = Unmanaged.passRetained(state).toOpaque()

        // "enter" signal → isTargeted(true), return GDK_ACTION_COPY
        g_signal_connect_data(
            gpointer(dropTarget), "enter",
            unsafeBitCast({ (_target: OpaquePointer?, _x: Double, _y: Double, userData: gpointer?) -> Int32 in
                guard let userData else { return 0 }
                let state = Unmanaged<GTKDropState>.fromOpaque(userData).takeUnretainedValue()
                state.beginHoverIfNeeded()
                gtkPinDropTargetWidgetUntilIdle(_target)
                return 1  // GDK_ACTION_COPY
            } as @convention(c) (OpaquePointer?, Double, Double, gpointer?) -> Int32, to: GCallback.self),
            stateUD, nil,
            GConnectFlags(rawValue: 0)
        )

        // "leave" signal → isTargeted(false)
        g_signal_connect_data(
            gpointer(dropTarget), "leave",
            unsafeBitCast({ (_target: OpaquePointer?, userData: gpointer?) in
                guard let userData else { return }
                let state = Unmanaged<GTKDropState>.fromOpaque(userData).takeUnretainedValue()
                state.scheduleLeave()
                gtkPinDropTargetWidgetUntilIdle(_target)
            } as @convention(c) (OpaquePointer?, gpointer?) -> Void, to: GCallback.self),
            stateUD, nil,
            GConnectFlags(rawValue: 0)
        )

        // "drop" signal → extract file paths, call action
        g_signal_connect_data(
            gpointer(dropTarget), "drop",
            unsafeBitCast({ (_target: OpaquePointer?, value: UnsafePointer<GValue>?, x: Double, y: Double, userData: gpointer?) -> gboolean in
                guard let userData, let value else { return 0 }
                let state = Unmanaged<GTKDropState>.fromOpaque(userData).takeUnretainedValue()
                state.cancelPendingLeave()

                // Keep the widget alive through GTK's post-drop cleanup.
                gtkPinDropTargetWidgetUntilIdle(_target)

                // Extract file list from the GValue
                let fileList = gtk_swift_file_list_get_gslist(value)
                let count = gtk_swift_gslist_length(fileList)

                var urls: [URL] = []
                for i in 0..<count {
                    if let gfile = gtk_swift_gslist_nth_data(fileList, i) {
                        if let pathPtr = gtk_swift_gfile_get_path(gfile) {
                            let path = String(cString: pathPtr)
                            urls.append(URL(fileURLWithPath: path))
                            g_free(gpointer(mutating: pathPtr))
                        }
                    }
                }

                let location = CGPoint(x: x, y: y)
                let accepted = state.action(urls, location)

                // End hover after the user action has run. If GTK already
                // sent "leave", this is a no-op.
                state.endHoverIfNeeded()

                return accepted ? 1 : 0
            } as @convention(c) (OpaquePointer?, UnsafePointer<GValue>?, Double, Double, gpointer?) -> gboolean, to: GCallback.self),
            stateUD, nil,
            GConnectFlags(rawValue: 0)
        )

        // Tie GTKDropState's lifetime to the GtkDropTarget GObject, NOT to
        // the child widget's destroy signal. When `isTargeted` mutates
        // @State, SwiftOpenUI rebuilds the view and replaces the drop
        // target mid-drag — if state were released only at child-widget
        // destroy, a still-queued "drop" signal on the old controller
        // would fire with a dangling stateUD and crash in state.action().
        // With g_object_set_data_full on the drop target itself, state is
        // released exactly when the controller that references it is
        // finalized, which is after GTK has stopped dispatching signals
        // to it. Bypass the widget-destroy race entirely.
        let dropTargetGObject = UnsafeMutableRawPointer(dropTarget)
            .assumingMemoryBound(to: GObject.self)
        g_object_set_data_full(dropTargetGObject, "gtk-swift-drop-state", stateUD) { ud in
            guard let ud else { return }
            let state = Unmanaged<GTKDropState>.fromOpaque(ud).takeUnretainedValue()
            state.cancelPendingLeave()
            state.endHoverIfNeeded()
            Unmanaged<GTKDropState>.fromOpaque(ud).release()
        }

        // Attach drop target to widget. GtkDropTarget IS-A GtkEventController,
        // so gtk_widget_add_controller accepts it directly; dropTarget is
        // already OpaquePointer from gtk_swift_drop_target_new_for_file_list().
        gtk_widget_add_controller(widgetPtr, dropTarget)

        return widget
    }
}

// MARK: - Container GTK extensions

extension VStack: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        let childDescs: [GTK4DescriptorNode]
        if let multi = content as? MultiChildView {
            childDescs = multi.children.map(gtkDescribeAnyView)
        } else {
            childDescs = [gtkDescribeView(content)]
        }
        return GTK4DescriptorNode(
            kind: .vStack, typeName: "VStack",
            props: .vStack(GTK4VStackDescriptor(
                spacing: gtkVStackSpacing(spacing),
                alignment: gtkHorizontalAlignmentDescriptor(alignment))),
            children: childDescs)
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let effectiveSpacing = gtkVStackSpacing(spacing)
        let children = gtkRenderChildren(content).map(widgetFromOpaque)
        if gtkCanUseSharedVStackLayout(children) {
            return gtkRenderSharedVStack(children, spacing: effectiveSpacing, alignment: alignment)
        }

        return gtkRenderFallbackVStack(children, spacing: effectiveSpacing, alignment: alignment)
    }
}

private func gtkCanUseSharedVStackLayout(_ children: [UnsafeMutablePointer<GtkWidget>]) -> Bool {
    for widget in children {
        let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
        if g_object_get_data(gobject, gtkSwiftSpacerMarker) != nil {
            return false
        }
        if gtk_widget_get_hexpand(widget) != 0 || gtk_widget_get_vexpand(widget) != 0 {
            return false
        }
    }
    return true
}

private func gtkRenderSharedVStack(
    _ children: [UnsafeMutablePointer<GtkWidget>],
    spacing: Int,
    alignment: HorizontalAlignment
) -> OpaquePointer {
    let wrapper = gtk_swift_fixed_new()!
    let context = GTKLayoutMeasureContext(widgets: children)
    let layout = computeVStackLayout(
        subviews: children.indices.map(LayoutSubview.init(index:)),
        context: context,
        spacing: Double(spacing),
        alignment: alignment
    )

    gtk_widget_set_size_request(
        wrapper,
        gint(layout.containerSize.width),
        gint(layout.containerSize.height)
    )

    for (widget, placement) in zip(children, layout.childPlacements) {
        gtk_widget_set_halign(widget, GTK_ALIGN_START)
        gtk_widget_set_valign(widget, GTK_ALIGN_START)
        gtk_swift_fixed_put(wrapper, widget, placement.origin.x, placement.origin.y)
    }

    return opaqueFromWidget(wrapper)
}

private func gtkRenderFallbackVStack(
    _ children: [UnsafeMutablePointer<GtkWidget>],
    spacing: Int,
    alignment: HorizontalAlignment
) -> OpaquePointer {
    let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, gint(spacing))!
    var needsHExpand = false
    var needsVExpand = false

    let gtkAlign: GtkAlign
    switch alignment {
    case .leading:  gtkAlign = GTK_ALIGN_START
    case .center:   gtkAlign = GTK_ALIGN_CENTER
    case .trailing: gtkAlign = GTK_ALIGN_END
    }

    for widget in children {
        let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
        if g_object_get_data(gobject, gtkSwiftSpacerMarker) != nil {
            gtk_widget_set_hexpand(widget, 0)
            gtk_widget_set_vexpand(widget, 1)
        }
        if gtk_widget_get_hexpand(widget) != 0 {
            needsHExpand = true
            gtk_widget_set_halign(widget, GTK_ALIGN_FILL)
        } else {
            gtk_widget_set_halign(widget, gtkAlign)
        }
        if gtk_widget_get_vexpand(widget) != 0 { needsVExpand = true }
        gtk_box_append(boxPointer(box), widget)
    }
    if needsHExpand { gtk_widget_set_hexpand(box, 1) }
    if needsVExpand { gtk_widget_set_vexpand(box, 1) }
    return opaqueFromWidget(box)
}

extension HStack: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        let childDescs: [GTK4DescriptorNode]
        if let multi = content as? MultiChildView {
            childDescs = multi.children.map(gtkDescribeAnyView)
        } else {
            childDescs = [gtkDescribeView(content)]
        }
        return GTK4DescriptorNode(
            kind: .hStack, typeName: "HStack",
            props: .hStack(GTK4HStackDescriptor(
                spacing: resolveStackSpacing(spacing),
                alignment: gtkVerticalAlignmentDescriptor(alignment))),
            children: childDescs)
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let effectiveSpacing = resolveStackSpacing(spacing)
        let children = gtkRenderChildren(content).map(widgetFromOpaque)
        if gtkCanUseSharedHStackLayout(children) {
            return gtkRenderSharedHStack(children, spacing: effectiveSpacing, alignment: alignment)
        }

        return gtkRenderFallbackHStack(children, spacing: effectiveSpacing, alignment: alignment)
    }
}

private func gtkCanUseSharedHStackLayout(_ children: [UnsafeMutablePointer<GtkWidget>]) -> Bool {
    for widget in children {
        let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
        if g_object_get_data(gobject, gtkSwiftSpacerMarker) != nil {
            return false
        }
        if gtk_widget_get_hexpand(widget) != 0 || gtk_widget_get_vexpand(widget) != 0 {
            return false
        }
    }
    return true
}

private func gtkRenderSharedHStack(
    _ children: [UnsafeMutablePointer<GtkWidget>],
    spacing: Int,
    alignment: VerticalAlignment
) -> OpaquePointer {
    let wrapper = gtk_swift_fixed_new()!
    let context = GTKLayoutMeasureContext(widgets: children)
    let layout = computeHStackLayout(
        subviews: children.indices.map(LayoutSubview.init(index:)),
        context: context,
        spacing: Double(spacing),
        alignment: alignment
    )

    gtk_widget_set_size_request(
        wrapper,
        gint(layout.containerSize.width),
        gint(layout.containerSize.height)
    )

    for (widget, placement) in zip(children, layout.childPlacements) {
        gtk_widget_set_halign(widget, GTK_ALIGN_START)
        gtk_widget_set_valign(widget, GTK_ALIGN_START)
        gtk_swift_fixed_put(wrapper, widget, placement.origin.x, placement.origin.y)
    }

    return opaqueFromWidget(wrapper)
}

private func gtkRenderFallbackHStack(
    _ children: [UnsafeMutablePointer<GtkWidget>],
    spacing: Int,
    alignment: VerticalAlignment
) -> OpaquePointer {
    let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, gint(spacing))!
    var needsHExpand = false
    var needsVExpand = false
    let hasNonSpacerHExpand = children.contains { widget in
        let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
        return g_object_get_data(gobject, gtkSwiftSpacerMarker) == nil
            && gtk_widget_get_hexpand(widget) != 0
    }

    let gtkAlign: GtkAlign
    switch alignment {
    case .top:    gtkAlign = GTK_ALIGN_START
    case .center: gtkAlign = GTK_ALIGN_CENTER
    case .bottom: gtkAlign = GTK_ALIGN_END
    }

    for widget in children {
        let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
        if g_object_get_data(gobject, gtkSwiftSpacerMarker) != nil {
            if hasNonSpacerHExpand {
                gtk_widget_set_size_request(widget, 8, -1)
                gtk_widget_set_hexpand(widget, 0)
            } else {
                gtk_widget_set_hexpand(widget, 1)
            }
            gtk_widget_set_vexpand(widget, 0)
        }
        if g_object_get_data(gobject, gtkSwiftDividerMarker) != nil {
            gtk_swift_orientable_set_orientation(widget, GTK_ORIENTATION_VERTICAL)
            gtk_widget_set_hexpand(widget, 0)
            gtk_widget_set_vexpand(widget, 1)
        }
        if gtk_widget_get_hexpand(widget) != 0 { needsHExpand = true }
        if gtk_widget_get_vexpand(widget) != 0 {
            needsVExpand = true
            gtk_widget_set_valign(widget, GTK_ALIGN_FILL)
        } else {
            gtk_widget_set_valign(widget, gtkAlign)
        }
        gtk_box_append(boxPointer(box), widget)
    }
    if needsHExpand { gtk_widget_set_hexpand(box, 1) }
    if needsVExpand { gtk_widget_set_vexpand(box, 1) }
    return opaqueFromWidget(box)
}

extension ZStack: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        let childDescs: [GTK4DescriptorNode]
        if let multi = content as? MultiChildView {
            childDescs = multi.children.map(gtkDescribeAnyView)
        } else {
            childDescs = [gtkDescribeView(content)]
        }
        return GTK4DescriptorNode(
            kind: .zStack, typeName: "ZStack",
            props: .zStack(GTK4ZStackDescriptor(
                alignment: gtkAlignmentDescriptor(alignment))),
            children: childDescs)
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let children = gtkRenderChildren(content).map(widgetFromOpaque)
        if gtkCanUseSharedZStackLayout(children) {
            return gtkRenderSharedZStack(children, alignment: alignment)
        }

        return gtkRenderFallbackZStack(children, alignment: alignment)
    }
}

private func gtkCanUseSharedZStackLayout(_ children: [UnsafeMutablePointer<GtkWidget>]) -> Bool {
    for widget in children {
        let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
        if g_object_get_data(gobject, gtkSwiftSpacerMarker) != nil {
            return false
        }
        if gtk_widget_get_hexpand(widget) != 0 || gtk_widget_get_vexpand(widget) != 0 {
            return false
        }
    }
    return true
}

private func gtkRenderSharedZStack(
    _ children: [UnsafeMutablePointer<GtkWidget>],
    alignment: Alignment
) -> OpaquePointer {
    let wrapper = gtk_swift_fixed_new()!
    let context = GTKLayoutMeasureContext(widgets: children)
    let layout = computeZStackLayout(
        subviews: children.indices.map(LayoutSubview.init(index:)),
        context: context,
        alignment: alignment
    )

    gtk_widget_set_size_request(
        wrapper,
        gint(layout.containerSize.width),
        gint(layout.containerSize.height)
    )

    for (widget, placement) in zip(children, layout.childPlacements) {
        gtk_widget_set_halign(widget, GTK_ALIGN_START)
        gtk_widget_set_valign(widget, GTK_ALIGN_START)
        gtk_swift_fixed_put(wrapper, widget, placement.origin.x, placement.origin.y)
    }

    return opaqueFromWidget(wrapper)
}

private func gtkRenderFallbackZStack(
    _ children: [UnsafeMutablePointer<GtkWidget>],
    alignment: Alignment
) -> OpaquePointer {
    let overlay = gtk_overlay_new()!
    let (hAlign, vAlign) = gtkAlignFromAlignment(alignment)
    var first = true
    for widget in children {
        if first {
            gtk_overlay_set_child(OpaquePointer(overlay), widget)
            // Propagate first child's expand to the overlay
            if gtk_widget_get_hexpand(widget) != 0 {
                gtk_widget_set_hexpand(overlay, 1)
            }
            if gtk_widget_get_vexpand(widget) != 0 {
                gtk_widget_set_vexpand(overlay, 1)
            }
            first = false
        } else {
            // Align non-expanding overlays according to the ZStack alignment.
            if gtk_widget_get_hexpand(widget) == 0 {
                gtk_widget_set_halign(widget, hAlign)
            }
            if gtk_widget_get_vexpand(widget) == 0 {
                gtk_widget_set_valign(widget, vAlign)
            }
            gtk_overlay_add_overlay(OpaquePointer(overlay), widget)
        }
    }
    return opaqueFromWidget(overlay)
}

extension Group: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        for child in gtkRenderChildren(content) {
            gtk_box_append(boxPointer(box), widgetFromOpaque(child))
        }
        return opaqueFromWidget(box)
    }
}

extension ForEach: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        for item in data {
            let childView = content(item)
            let widget = widgetFromOpaque(gtkRenderView(childView))
            gtk_box_append(boxPointer(box), widget)
        }
        return opaqueFromWidget(box)
    }
}

extension AnyView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        gtkRenderAnyView(wrapped)
    }
}

extension _ConditionalView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        switch self {
        case .trueContent(let view): return gtkRenderView(view)
        case .falseContent(let view): return gtkRenderView(view)
        }
    }
}

extension Optional: GTKRenderable where Wrapped: View {
    public func gtkCreateWidget() -> OpaquePointer {
        switch self {
        case .some(let view): return gtkRenderView(view)
        case .none: return opaqueFromWidget(gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!)
        }
    }
}

// MARK: - Modifier GTK extensions

extension PaddedView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(
            kind: .padding, typeName: "PaddedView",
            props: .padding(GTK4PaddingDescriptor(
                top: top, bottom: bottom, leading: leading, trailing: trailing)),
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let child = widgetFromOpaque(gtkRenderView(content))
        let wrapper = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        // Use GTK widget margins (not CSS padding) for the spacing. CSS
        // padding-X in GTK4 interacts poorly with hexpand-distributed
        // GtkBox allocations: children that inherit expand through a
        // CSS-padded wrapper end up shrunk by the padding amount during
        // natural-size distribution, producing an unfilled gap in HStacks
        // like the LayoutStress dashboard cards. Margins on the inner
        // child are respected by measurement and don't hit that path.
        gtk_widget_set_margin_top(child, gint(top))
        gtk_widget_set_margin_bottom(child, gint(bottom))
        gtk_widget_set_margin_start(child, gint(leading))
        gtk_widget_set_margin_end(child, gint(trailing))
        if gtk_widget_get_hexpand(child) != 0 { gtk_widget_set_hexpand(wrapper, 1) }
        if gtk_widget_get_vexpand(child) != 0 { gtk_widget_set_vexpand(wrapper, 1) }
        gtkMarkHostedNodeKind(wrapper, kind: .padding)
        gtk_box_append(boxPointer(wrapper), child)
        return opaqueFromWidget(wrapper)
    }
}

extension FrameView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(
            kind: .frame, typeName: "FrameView",
            props: .frame(GTK4FrameDescriptor(
                width: width, height: height,
                minWidth: minWidth, minHeight: minHeight,
                maxWidth: maxWidth, maxHeight: maxHeight,
                alignment: gtkAlignmentDescriptor(alignment))),
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let child = widgetFromOpaque(gtkRenderView(content))
        let childExpH = gtk_widget_get_hexpand(child) != 0
        let childExpV = gtk_widget_get_vexpand(child) != 0

        // Detect when the frame constrains one axis but the child wants to
        // expand on the unconstrained axis.  GtkFixed positions children at
        // fixed coordinates computed at creation time, so it can't propagate
        // the parent's allocation to the child.  Use a plain GtkBox wrapper
        // in these cases so GTK's expand/fill system handles the flexible axis.
        let heightFree = height == nil && minHeight == nil && maxHeight == nil
        let widthFree  = width == nil && minWidth == nil && (maxWidth == nil || maxWidth == .infinity)
        let widthMayGrowWithParent = width == nil
            && (
                (maxWidth != nil && maxWidth == .infinity)
                || (maxWidth == nil && childExpH)
            )
        let heightMayGrowWithParent = height == nil
            && (
                (maxHeight != nil && maxHeight == .infinity)
                || (maxHeight == nil && childExpV)
            )

        if widthMayGrowWithParent || heightMayGrowWithParent {
            return gtkFrameParentFlexibleAxes(
                child: child,
                childExpH: childExpH,
                childExpV: childExpV
            )
        }

        if !widthFree && heightFree && childExpV {
            // Width-constrained, height-flexible, child expands vertically.
            // Example: Color.blue.frame(width: 120) inside an HStack.
            return gtkFrameFlexibleAxis(child: child, childExpH: childExpH,
                                        constrainedWidth: true)
        }
        if widthFree && !heightFree && childExpH {
            // Height-constrained, width-flexible, child expands horizontally.
            return gtkFrameFlexibleAxis(child: child, childExpH: childExpH,
                                        constrainedWidth: false)
        }

        // General case: use GtkFixed for alignment positioning.
        let wrapper = gtk_swift_fixed_new()!
        let naturalSize = gtkMeasureWidgetNaturalSize(child)
        let layout = computeFrameLayout(
            childNaturalSize: naturalSize,
            width: width,
            height: height,
            minWidth: minWidth,
            minHeight: minHeight,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            alignment: alignment,
            expandsToFillWidth: childExpH,
            expandsToFillHeight: childExpV
        )
        let clampsChild =
            layout.childPlacement.size.width < naturalSize.width
            || layout.childPlacement.size.height < naturalSize.height
        let slot: UnsafeMutablePointer<GtkWidget> = clampsChild
            ? gtk_swift_scrolled_window_new()!
            : gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!

        // Expanding children should fill the slot; non-expanding ones
        // are positioned by GtkFixed placement math.
        gtk_widget_set_halign(child, childExpH ? GTK_ALIGN_FILL : GTK_ALIGN_START)
        gtk_widget_set_valign(child, childExpV ? GTK_ALIGN_FILL : GTK_ALIGN_START)
        gtk_widget_set_halign(slot, GTK_ALIGN_START)
        gtk_widget_set_valign(slot, GTK_ALIGN_START)
        if clampsChild {
            gtk_widget_set_overflow(wrapper, GTK_OVERFLOW_HIDDEN)
            if childExpH || childExpV {
                gtk_widget_set_size_request(
                    child,
                    childExpH ? gint(layout.childPlacement.size.width) : -1,
                    childExpV ? gint(layout.childPlacement.size.height) : -1
                )
            }
            gtk_swift_scrolled_window_configure_clip(
                slot,
                gint(layout.childPlacement.size.width),
                gint(layout.childPlacement.size.height)
            )
            gtk_swift_scrolled_window_set_child(slot, child)
        }
        gtk_widget_set_size_request(
            slot,
            gtkPixelSize(layout.childPlacement.size.width),
            gtkPixelSize(layout.childPlacement.size.height)
        )
        gtk_widget_set_size_request(
            wrapper,
            gtkPixelSize(layout.containerSize.width),
            gtkPixelSize(layout.containerSize.height)
        )

        if width != nil {
            gtk_widget_set_hexpand(wrapper, 0)
        }
        if height != nil {
            gtk_widget_set_vexpand(wrapper, 0)
        }
        if let xw = maxWidth, xw == .infinity {
            gtk_widget_set_hexpand(wrapper, 1)
        }
        if let xh = maxHeight, xh == .infinity {
            gtk_widget_set_vexpand(wrapper, 1)
        }
        // Propagate child expand flags to wrapper when the frame doesn't
        // constrain that axis.  Without this, a Spacer inside an HStack
        // inside .frame(height:) loses its horizontal expansion.
        if width == nil && maxWidth == nil && gtk_widget_get_hexpand(child) != 0 {
            gtk_widget_set_hexpand(wrapper, 1)
        }
        if height == nil && maxHeight == nil && gtk_widget_get_vexpand(child) != 0 {
            gtk_widget_set_vexpand(wrapper, 1)
        }
        if !clampsChild {
            gtk_box_append(boxPointer(slot), child)
        }
        gtk_swift_fixed_put(
            wrapper,
            slot,
            layout.childPlacement.origin.x,
            layout.childPlacement.origin.y
        )
        gtk_swift_fixed_move(
            wrapper,
            slot,
            layout.childPlacement.origin.x,
            layout.childPlacement.origin.y
        )
        return opaqueFromWidget(wrapper)
    }

    /// Build a frame wrapper for cases where the parent may later allocate
    /// extra space on one or both axes (`maxWidth/maxHeight == .infinity`),
    /// but the child itself does not expand on that axis. GtkFixed computes
    /// placement once at creation time, so it cannot recenter/realign the
    /// child when the wrapper grows later. A GtkBox-based wrapper keeps the
    /// child aligned inside the live parent allocation.
    private func gtkFrameParentFlexibleAxes(
        child: UnsafeMutablePointer<GtkWidget>,
        childExpH: Bool,
        childExpV: Bool
    ) -> OpaquePointer {
        let naturalSize = gtkMeasureWidgetNaturalSize(child)
        let layout = computeFrameLayout(
            childNaturalSize: naturalSize,
            width: width,
            height: height,
            minWidth: minWidth,
            minHeight: minHeight,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            alignment: alignment,
            expandsToFillWidth: childExpH,
            expandsToFillHeight: childExpV
        )

        let wrapper = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!

        let widthMayGrowWithParent = width == nil
            && (
                (maxWidth != nil && maxWidth == .infinity)
                || (maxWidth == nil && childExpH)
            )
        let heightMayGrowWithParent = height == nil
            && (
                (maxHeight != nil && maxHeight == .infinity)
                || (maxHeight == nil && childExpV)
            )

        let requestWidth = widthMayGrowWithParent ? -1 : gtkPixelSize(layout.containerSize.width)
        let requestHeight = heightMayGrowWithParent ? -1 : gtkPixelSize(layout.containerSize.height)
        gtk_widget_set_size_request(wrapper, requestWidth, requestHeight)
        if widthMayGrowWithParent {
            gtk_widget_set_hexpand(wrapper, 1)
        } else {
            // Prevent flexible children such as Color from making an
            // explicitly width-constrained frame participate as flexible
            // space in a parent HStack.
            gtk_widget_set_hexpand(wrapper, 0)
        }
        if heightMayGrowWithParent {
            gtk_widget_set_vexpand(wrapper, 1)
        } else {
            // Explicit 0: alignment spacers inside the wrapper have
            // vexpand=1 for internal vertical centering. Without an
            // explicit value, GTK auto-computes vexpand from children
            // and inherits the spacers' expansion — leaking vexpand
            // to the parent container.
            gtk_widget_set_vexpand(wrapper, 0)
        }

        let horizontalAlign: GtkAlign
        if childExpH {
            horizontalAlign = GTK_ALIGN_FILL
            gtk_widget_set_hexpand(child, 1)
        } else {
            switch alignment {
            case .topLeading, .leading, .bottomLeading:
                horizontalAlign = GTK_ALIGN_START
            case .top, .center, .bottom:
                horizontalAlign = GTK_ALIGN_CENTER
            case .topTrailing, .trailing, .bottomTrailing:
                horizontalAlign = GTK_ALIGN_END
            }
        }
        gtk_widget_set_halign(child, horizontalAlign)

        if childExpV {
            gtk_widget_set_valign(child, GTK_ALIGN_FILL)
            gtk_widget_set_vexpand(child, 1)
            gtk_box_append(boxPointer(wrapper), child)
            return opaqueFromWidget(wrapper)
        }

        if heightMayGrowWithParent {
            switch alignment {
            case .topLeading, .top, .topTrailing:
                gtk_box_append(boxPointer(wrapper), child)
            case .leading, .center, .trailing:
                let topSpacer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
                let bottomSpacer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
                gtkMarkLayoutHelper(topSpacer)
                gtkMarkLayoutHelper(bottomSpacer)
                gtk_widget_set_vexpand(topSpacer, 1)
                gtk_widget_set_vexpand(bottomSpacer, 1)
                gtk_box_append(boxPointer(wrapper), topSpacer)
                gtk_box_append(boxPointer(wrapper), child)
                gtk_box_append(boxPointer(wrapper), bottomSpacer)
            case .bottomLeading, .bottom, .bottomTrailing:
                let topSpacer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
                gtkMarkLayoutHelper(topSpacer)
                gtk_widget_set_vexpand(topSpacer, 1)
                gtk_box_append(boxPointer(wrapper), topSpacer)
                gtk_box_append(boxPointer(wrapper), child)
            }
        } else {
            // Height is fixed (minHeight / height pinned the wrapper at
            // `layout.containerSize.height`), but the child's natural
            // height may be smaller. GtkBox packs children from the
            // start of its packing axis and doesn't honor `valign` on
            // children along that axis, so just appending leaves the
            // child visually top-aligned even if the wrapper has
            // plenty of extra height. Insert vexpand spacers to split
            // the extra space according to the frame's alignment
            // intent — matching SwiftUI's default of centering when
            // the frame is larger than content.
            switch alignment {
            case .topLeading, .top, .topTrailing:
                gtk_box_append(boxPointer(wrapper), child)
            case .leading, .center, .trailing:
                let topSpacer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
                let bottomSpacer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
                gtkMarkLayoutHelper(topSpacer)
                gtkMarkLayoutHelper(bottomSpacer)
                gtk_widget_set_vexpand(topSpacer, 1)
                gtk_widget_set_vexpand(bottomSpacer, 1)
                gtk_box_append(boxPointer(wrapper), topSpacer)
                gtk_box_append(boxPointer(wrapper), child)
                gtk_box_append(boxPointer(wrapper), bottomSpacer)
            case .bottomLeading, .bottom, .bottomTrailing:
                let topSpacer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
                gtkMarkLayoutHelper(topSpacer)
                gtk_widget_set_vexpand(topSpacer, 1)
                gtk_box_append(boxPointer(wrapper), topSpacer)
                gtk_box_append(boxPointer(wrapper), child)
            }
        }

        return opaqueFromWidget(wrapper)
    }

    /// Build a frame wrapper using GtkBox instead of GtkFixed, for frames
    /// that constrain one axis while the child expands on the other.
    /// GtkFixed can't propagate allocation to children, so we let GTK's
    /// expand/fill system handle the flexible axis naturally.
    private func gtkFrameFlexibleAxis(
        child: UnsafeMutablePointer<GtkWidget>,
        childExpH: Bool,
        constrainedWidth: Bool
    ) -> OpaquePointer {
        let naturalSize = gtkMeasureWidgetNaturalSize(child)
        let layout = computeFrameLayout(
            childNaturalSize: naturalSize,
            width: width,
            height: height,
            minWidth: minWidth,
            minHeight: minHeight,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            alignment: alignment,
            expandsToFillWidth: childExpH,
            expandsToFillHeight: gtk_widget_get_vexpand(child) != 0
        )

        // Use GtkBox as wrapper — child fills the flexible axis via expand.
        let orientation = constrainedWidth ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL
        let wrapper = gtk_box_new(orientation, 0)!

        if constrainedWidth {
            // Width constrained, height flexible
            gtk_widget_set_size_request(wrapper, gtkPixelSize(layout.containerSize.width), -1)
            let hexp: gint = (maxWidth != nil && maxWidth == .infinity) ? 1 : 0
            gtk_widget_set_hexpand(wrapper, hexp)
            gtk_widget_set_vexpand(wrapper, 1)
        } else {
            // Height constrained, width flexible
            gtk_widget_set_size_request(wrapper, -1, gtkPixelSize(layout.containerSize.height))
            let vexp: gint = (maxHeight != nil && maxHeight == .infinity) ? 1 : 0
            gtk_widget_set_hexpand(wrapper, 1)
            gtk_widget_set_vexpand(wrapper, vexp)
        }

        gtk_widget_set_halign(child, GTK_ALIGN_FILL)
        gtk_widget_set_valign(child, GTK_ALIGN_FILL)
        gtk_box_append(boxPointer(wrapper), child)

        return opaqueFromWidget(wrapper)
    }
}

private func gtkMeasureWidgetNaturalSize(_ widget: UnsafeMutablePointer<GtkWidget>) -> ViewSize {
    var widthMin: Int32 = 0
    var widthNat: Int32 = 0
    var heightMin: Int32 = 0
    var heightNat: Int32 = 0
    gtk_swift_widget_measure(widget, GTK_ORIENTATION_HORIZONTAL, -1, &widthMin, &widthNat)
    gtk_swift_widget_measure(widget, GTK_ORIENTATION_VERTICAL, -1, &heightMin, &heightNat)
    let width = max(widthMin, widthNat)
    let height = max(heightMin, heightNat)
    return ViewSize(width: Double(width), height: Double(height))
}

extension ForegroundColorView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(
            kind: .foregroundColor, typeName: "ForegroundColorView",
            props: .foregroundColor(gtkColorDescriptor(color)),
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let prev = _gtkCurrentForegroundColor
        gtkSetCurrentForegroundColor(color)
        let widget = widgetFromOpaque(gtkRenderView(content))
        gtkSetCurrentForegroundColor(prev)
        applyCSSToWidget(widget, properties: "color: \(color.hex);")
        return opaqueFromWidget(widget)
    }
}

extension BackgroundView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        if let color = background as? Color {
            return GTK4DescriptorNode(
                kind: .background, typeName: "BackgroundView",
                props: .background(gtkColorDescriptor(color)),
                children: [gtkDescribeView(content)])
        }

        if gtkCanRenderNativeBackground(background) {
            return GTK4DescriptorNode(
                kind: .background, typeName: "BackgroundView",
                props: .backgroundLayout(GTK4BackgroundLayoutDescriptor(
                    alignment: gtkAlignmentDescriptor(alignment))),
                children: [
                    gtkDescribeView(content),
                    gtkDescribeView(background),
                ])
        }

        return gtkDescribeView(ZStack(alignment: alignment) {
            self.background
            content
        })
    }

    public func gtkCreateWidget() -> OpaquePointer {
        if let color = background as? Color {
            let widget = widgetFromOpaque(gtkRenderView(content))
            applyCSSToWidget(widget, properties: "background-color: \(color.hex);")
            return opaqueFromWidget(widget)
        }

        if gtkCanRenderNativeBackground(background) {
            return gtkRenderBackground(content: content, background: background, alignment: alignment)
        }

        return gtkRenderView(ZStack(alignment: alignment) {
            self.background
            content
        })
    }
}

private func gtkCanRenderNativeBackground<Background: View>(_ background: Background) -> Bool {
    background is FilledShape<RoundedRectangle>
        || background is FilledShape<Rectangle>
        || background is FilledShape<Capsule>
}

private func gtkRenderBackground<Content: View, Background: View>(
    content: Content,
    background: Background,
    alignment: Alignment
) -> OpaquePointer {
    let contentWidget = widgetFromOpaque(gtkRenderView(content))

    if let rounded = background as? FilledShape<RoundedRectangle> {
        return gtkRenderFilledShapeBackground(
            contentWidget: contentWidget,
            color: rounded.color,
            cornerRadius: rounded.shape.cornerRadius
        )
    }

    if let rectangle = background as? FilledShape<Rectangle> {
        return gtkRenderFilledShapeBackground(
            contentWidget: contentWidget,
            color: rectangle.color,
            cornerRadius: 0
        )
    }

    if let capsule = background as? FilledShape<Capsule> {
        return gtkRenderFilledShapeBackground(
            contentWidget: contentWidget,
            color: capsule.color,
            cornerRadius: 9999
        )
    }

    return gtkRenderView(ZStack(alignment: alignment) {
        background
        content
    })
}

private func gtkRenderFilledShapeBackground(
    contentWidget: UnsafeMutablePointer<GtkWidget>,
    color: Color,
    cornerRadius: Double
) -> OpaquePointer {
    let wrapper = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    if gtk_widget_get_hexpand(contentWidget) != 0 { gtk_widget_set_hexpand(wrapper, 1) }
    if gtk_widget_get_vexpand(contentWidget) != 0 { gtk_widget_set_vexpand(wrapper, 1) }

    let css: String
    if cornerRadius > 0 {
        css = String(
            format: "background-color: rgba(%d, %d, %d, %.3f); border-radius: %.1fpx;",
            Int(color.red * 255),
            Int(color.green * 255),
            Int(color.blue * 255),
            color.alpha,
            cornerRadius
        )
    } else {
        css = String(
            format: "background-color: rgba(%d, %d, %d, %.3f);",
            Int(color.red * 255),
            Int(color.green * 255),
            Int(color.blue * 255),
            color.alpha
        )
    }
    applyCSSToWidget(wrapper, properties: css)
    gtk_box_append(boxPointer(wrapper), contentWidget)
    return opaqueFromWidget(wrapper)
}

extension FontModifiedView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(
            kind: .font, typeName: "FontModifiedView",
            props: .font(GTK4FontDescriptor(font: font)),
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        let css: String
        switch font {
        case .largeTitle:  css = "font-size: 28px;"
        case .title:       css = "font-size: 24px;"
        case .title2:      css = "font-size: 20px; font-weight: bold;"
        case .title3:      css = "font-size: 18px;"
        case .headline:    css = "font-weight: bold;"
        case .subheadline: css = "font-size: 12px; font-weight: bold;"
        case .body:        css = "font-size: 14px;"
        case .callout:     css = "font-size: 12px;"
        case .footnote:    css = "font-size: 10px;"
        case .caption:     css = "font-size: 12px;"
        case .caption2:    css = "font-size: 10px; font-weight: bold;"
        case .custom(let size, _, _): css = "font-size: \(Int(size))px;"
        }
        applyCSSToWidget(widget, properties: css)
        return opaqueFromWidget(widget)
    }
}

extension BorderView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(
            kind: .border, typeName: "BorderView",
            props: .border(GTK4BorderDescriptor(
                color: gtkColorDescriptor(color), width: width)),
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        applyCSSToWidget(widget, properties: "border: \(width)px solid \(color.hex);")
        return opaqueFromWidget(widget)
    }
}

// MARK: - Text Formatting GTK extensions

/// Collect all GtkLabel descendants in a widget subtree via DFS.
/// Text modifiers apply to every label in the subtree, not just the first,
/// so that container-level modifiers like VStack { ... }.lineLimit(1) work.
private func findAllGtkLabels(in widget: UnsafeMutablePointer<GtkWidget>) -> [UnsafeMutablePointer<GtkWidget>] {
    var result: [UnsafeMutablePointer<GtkWidget>] = []
    collectGtkLabels(in: widget, into: &result)
    return result
}

private func collectGtkLabels(in widget: UnsafeMutablePointer<GtkWidget>, into result: inout [UnsafeMutablePointer<GtkWidget>]) {
    guard gtk_swift_is_widget(widget) != 0 else { return }
    let typeName = String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
    if typeName == "GtkLabel" {
        result.append(widget)
        return // GtkLabel has no label children
    }
    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        collectGtkLabels(in: c, into: &result)
        child = gtk_widget_get_next_sibling(c)
    }
}

extension LineLimitView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        for label in findAllGtkLabels(in: widget) {
            let labelOp = OpaquePointer(label)
            if let limit = lineLimit {
                if limit == 1 {
                    gtk_label_set_wrap(labelOp, 0)
                    gtk_label_set_lines(labelOp, 1)
                    // Default tail truncation for single-line, but don't
                    // overwrite an explicit truncation mode already set.
                    if gtk_label_get_ellipsize(labelOp) == PANGO_ELLIPSIZE_NONE {
                        gtk_label_set_ellipsize(labelOp, PANGO_ELLIPSIZE_END)
                    }
                    // Leave hexpand/halign alone. SwiftUI semantics for
                    // Text(...).lineLimit(1) is "draw at natural size;
                    // ellipsize only if the parent allocates less than
                    // natural." The label must not grab horizontal space
                    // — a trailing `Text(value).lineLimit(1)` inside a
                    // Spacer-packed HStack (e.g. a settings row) must
                    // stay at natural width and let the Spacer fill the
                    // gap so the value ends up right-aligned.
                    //
                    // `max-width-chars = -1` keeps the natural request
                    // at the full text width so short text displays in
                    // full; ellipsize kicks in only when the allocation
                    // is smaller than natural.
                    gtk_label_set_width_chars(labelOp, -1)
                    gtk_label_set_max_width_chars(labelOp, -1)
                } else {
                    gtk_label_set_wrap(labelOp, 1)
                    gtk_label_set_wrap_mode(labelOp, PANGO_WRAP_WORD_CHAR)
                    gtk_label_set_lines(labelOp, gint(limit))
                    // Default tail truncation for multi-line overflow, but
                    // don't overwrite an explicit truncation mode already set.
                    if gtk_label_get_ellipsize(labelOp) == PANGO_ELLIPSIZE_NONE {
                        gtk_label_set_ellipsize(labelOp, PANGO_ELLIPSIZE_END)
                    }
                }
            } else {
                // nil = unlimited wrapping — reset any prior line/ellipsis constraints
                gtk_label_set_wrap(labelOp, 1)
                gtk_label_set_wrap_mode(labelOp, PANGO_WRAP_WORD_CHAR)
                gtk_label_set_lines(labelOp, -1)
                gtk_label_set_ellipsize(labelOp, PANGO_ELLIPSIZE_NONE)
            }
        }
        return opaqueFromWidget(widget)
    }
}

extension TruncationModeView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        for label in findAllGtkLabels(in: widget) {
            let labelOp = OpaquePointer(label)
            switch mode {
            case .head:   gtk_label_set_ellipsize(labelOp, PANGO_ELLIPSIZE_START)
            case .tail:   gtk_label_set_ellipsize(labelOp, PANGO_ELLIPSIZE_END)
            case .middle: gtk_label_set_ellipsize(labelOp, PANGO_ELLIPSIZE_MIDDLE)
            }
        }
        return opaqueFromWidget(widget)
    }
}

extension LineSpacingView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        let lineHeight = String(format: "%.1f", spacing)
        for label in findAllGtkLabels(in: widget) {
            applyCSSToWidget(label, properties: "line-height: calc(1em + \(lineHeight)px);")
        }
        return opaqueFromWidget(widget)
    }
}

extension MultilineTextAlignmentView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        for label in findAllGtkLabels(in: widget) {
            let labelOp = OpaquePointer(label)
            switch alignment {
            case .leading:
                gtk_label_set_justify(labelOp, GTK_JUSTIFY_LEFT)
                gtk_swift_label_set_xalign(label, 0)
            case .center:
                gtk_label_set_justify(labelOp, GTK_JUSTIFY_CENTER)
                gtk_swift_label_set_xalign(label, 0.5)
            case .trailing:
                gtk_label_set_justify(labelOp, GTK_JUSTIFY_RIGHT)
                gtk_swift_label_set_xalign(label, 1.0)
            }
        }
        return opaqueFromWidget(widget)
    }
}

// MARK: - fullScreenCover GTK extension

extension FullScreenCoverView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))

        // Use the host container as a stable anchor that survives rebuilds,
        // same pattern as SheetView. Falls back to the rendered widget if
        // not inside a rebuilding host.
        let anchor: UnsafeMutablePointer<GtkWidget>
        if let host = GTKViewHost.getCurrentRebuilding() {
            anchor = host.container
        } else {
            anchor = widget
        }
        let gobject = UnsafeMutableRawPointer(anchor).assumingMemoryBound(to: GObject.self)

        if isPresented.wrappedValue {
            // Prevent duplicate fullscreen window
            guard g_object_get_data(gobject, "swift-fullscreen-window") == nil else {
                return opaqueFromWidget(widget)
            }

            let window = gtk_window_new()!
            gtk_swift_window_set_modal(window, 1)

            // Set transient parent to the actual GtkWindow root
            if let rootWidget = gtk_widget_get_root(anchor) {
                let rootAsWidget = UnsafeMutableRawPointer(rootWidget)
                    .assumingMemoryBound(to: GtkWidget.self)
                gtk_swift_window_set_transient_for(window, rootAsWidget)
            }

            // Inject dismiss action
            let binding = isPresented
            let dismiss = onDismiss
            var env = getCurrentEnvironment()
            env.dismiss = DismissAction {
                binding.wrappedValue = false
            }
            let prevEnv = getCurrentEnvironment()
            setCurrentEnvironment(env)
            let coverWidget = widgetFromOpaque(gtkRenderView(coverContent))
            setCurrentEnvironment(prevEnv)

            gtk_swift_window_set_child(window, coverWidget)
            gtk_swift_window_fullscreen(window)

            // Store the window on the anchor for programmatic dismissal
            g_object_set_data(gobject, "swift-fullscreen-window",
                              UnsafeMutableRawPointer(window))

            // Ref anchor for safe access in close callback
            g_object_ref(gpointer(anchor))
            let anchorWidget = anchor
            // Handle close-request (Escape, window close button)
            let closeBox = Unmanaged.passRetained(ClosureBox {
                binding.wrappedValue = false
                if gtk_swift_is_widget(anchorWidget) != 0 {
                    let obj = UnsafeMutableRawPointer(anchorWidget).assumingMemoryBound(to: GObject.self)
                    g_object_set_data(obj, "swift-fullscreen-window", nil)
                }
                g_object_unref(gpointer(anchorWidget))
                dismiss?()
            }).toOpaque()
            g_signal_connect_data(
                gpointer(window), "close-request",
                unsafeBitCast({ (_: gpointer?, ud: gpointer?) -> gboolean in
                    guard let ud = ud else { return 0 }
                    Unmanaged<ClosureBox>.fromOpaque(ud).takeUnretainedValue().closure()
                    return 0
                } as @convention(c) (gpointer?, gpointer?) -> gboolean,
                to: GCallback.self),
                closeBox,
                { (data: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    guard let data = data else { return }
                    Unmanaged<ClosureBox>.fromOpaque(data).release()
                },
                GConnectFlags(rawValue: 0)
            )

            gtk_widget_set_visible(window, 1)
        } else {
            // Programmatic dismissal: destroy the fullscreen window
            if let raw = g_object_get_data(gobject, "swift-fullscreen-window") {
                let window = raw.assumingMemoryBound(to: GtkWidget.self)
                gtk_swift_window_destroy(window)
                g_object_set_data(gobject, "swift-fullscreen-window", nil)
                onDismiss?()
            }
        }

        return opaqueFromWidget(widget)
    }
}

// MARK: - onSubmit GTK extension

extension OnSubmitView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        var env = getCurrentEnvironment()
        env.submitAction = SubmitAction(handler: action)
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(env)
        defer { setCurrentEnvironment(prev) }
        return gtkRenderView(content)
    }
}

// MARK: - Tag GTK extension

extension TagView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        setCurrentTagValue(tagValue)
        defer { clearCurrentTagValue() }
        return gtkRenderView(content)
    }
}

// MARK: - Aspect ratio GTK extension

extension AspectRatioView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        var css = ""
        if let ratio {
            css += "aspect-ratio: \(ratio);"
        }
        switch contentMode {
        case .fit:
            css += " object-fit: contain;"
        case .fill:
            css += " object-fit: cover; overflow: hidden;"
        }
        if !css.isEmpty {
            applyCSSToWidget(widget, properties: css)
        }
        return opaqueFromWidget(widget)
    }
}

// MARK: - Gradient GTK extensions

private func gtkGradientStopsCSS(_ stops: [Gradient.Stop]) -> String {
    stops.map { stop in
        let c = stop.color
        let r = Int(c.red * 255)
        let g = Int(c.green * 255)
        let b = Int(c.blue * 255)
        let a = c.alpha
        return "rgba(\(r), \(g), \(b), \(a)) \(Int(stop.location * 100))%"
    }.joined(separator: ", ")
}

extension LinearGradient: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let div = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_widget_set_hexpand(div, 1)
        gtk_widget_set_vexpand(div, 1)
        let sx = Int(startPoint.x * 100)
        let sy = Int(startPoint.y * 100)
        let ex = Int(endPoint.x * 100)
        let ey = Int(endPoint.y * 100)
        let stops = gtkGradientStopsCSS(gradient.stops)
        applyCSSToWidget(div, properties: "background: linear-gradient(from \(sx)% \(sy)% to \(ex)% \(ey)%, \(stops)); min-height: 20px;")
        return opaqueFromWidget(div)
    }
}

extension RadialGradient: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let div = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_widget_set_hexpand(div, 1)
        gtk_widget_set_vexpand(div, 1)
        let cx = Int(center.x * 100)
        let cy = Int(center.y * 100)
        let stops = gtkGradientStopsCSS(gradient.stops)
        applyCSSToWidget(div, properties: "background: radial-gradient(circle at \(cx)% \(cy)%, \(stops)); min-height: 20px;")
        return opaqueFromWidget(div)
    }
}

// MARK: - Text decoration GTK extensions

private let gtkSwiftOriginalLabelTextKey = "gtk-swift-original-label-text"

private final class WidgetStringBox {
    let value: String
    init(_ value: String) { self.value = value }
}

private func storeOriginalLabelTextIfNeeded(_ label: UnsafeMutablePointer<GtkWidget>) {
    let gobject = UnsafeMutableRawPointer(label).assumingMemoryBound(to: GObject.self)
    guard g_object_get_data(gobject, gtkSwiftOriginalLabelTextKey) == nil else { return }
    let current = String(cString: gtk_label_get_text(OpaquePointer(label)))
    let retained = Unmanaged.passRetained(WidgetStringBox(current)).toOpaque()
    g_object_set_data_full(gobject, gtkSwiftOriginalLabelTextKey, retained) { userData in
        Unmanaged<WidgetStringBox>.fromOpaque(userData!).release()
    }
}

private func originalLabelText(_ label: UnsafeMutablePointer<GtkWidget>) -> String? {
    let gobject = UnsafeMutableRawPointer(label).assumingMemoryBound(to: GObject.self)
    guard let raw = g_object_get_data(gobject, gtkSwiftOriginalLabelTextKey) else { return nil }
    return Unmanaged<WidgetStringBox>.fromOpaque(raw).takeUnretainedValue().value
}

extension BoldView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        applyCSSToWidget(widget, properties: "font-weight: bold;")
        return opaqueFromWidget(widget)
    }
}

extension ItalicView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        applyCSSToWidget(widget, properties: "font-style: italic;")
        return opaqueFromWidget(widget)
    }
}

extension FontWeightView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        let css: String
        switch weight {
        case .ultraLight: css = "font-weight: 100;"
        case .thin:       css = "font-weight: 200;"
        case .light:      css = "font-weight: 300;"
        case .regular:    css = "font-weight: 400;"
        case .medium:     css = "font-weight: 500;"
        case .semibold:   css = "font-weight: 600;"
        case .bold:       css = "font-weight: 700;"
        case .heavy:      css = "font-weight: 800;"
        case .black:      css = "font-weight: 900;"
        }
        applyCSSToWidget(widget, properties: css)
        return opaqueFromWidget(widget)
    }
}

extension UnderlineView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        // GTK4 CSS does not support text-decoration. Use Pango attributes.
        for label in findAllGtkLabels(in: widget) {
            gtk_swift_label_set_underline(label, isActive ? 1 : 0)
        }
        return opaqueFromWidget(widget)
    }
}

extension StrikethroughView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        // GTK4 CSS does not support text-decoration. Use Pango attributes.
        for label in findAllGtkLabels(in: widget) {
            gtk_swift_label_set_strikethrough(label, isActive ? 1 : 0)
        }
        return opaqueFromWidget(widget)
    }
}

extension TextCaseView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        // GTK4 CSS does not support text-transform. Transform label text directly.
        // Skip markup labels — transforming markup source would break entities
        // like &amp; → &AMP; and potentially corrupt tag syntax.
        for label in findAllGtkLabels(in: widget) {
            guard gtk_swift_label_get_use_markup(label) == 0 else { continue }
            storeOriginalLabelTextIfNeeded(label)
            let base = originalLabelText(label)
                ?? String(cString: gtk_label_get_text(OpaquePointer(label)))
            switch textCase {
            case .uppercase?:
                gtk_swift_label_set_text(label, base.uppercased())
            case .lowercase?:
                gtk_swift_label_set_text(label, base.lowercased())
            case nil:
                gtk_swift_label_set_text(label, base)
            }
        }
        return opaqueFromWidget(widget)
    }
}

// MARK: - ScrollViewReader + ID GTK extensions

extension IdView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        registerViewID(id, element: widget)
        return opaqueFromWidget(widget)
    }
}

extension ScrollViewReader: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        var proxy = ScrollViewProxy()
        proxy.scrollToAction = { anyID, anchor in
            guard let widget = lookupViewID(anyID) as? UnsafeMutablePointer<GtkWidget> else { return }
            // Verify the widget is still alive before operating on it
            guard gtk_swift_is_widget(widget) != 0 else { return }
            // Find the enclosing GtkScrolledWindow and scroll to the widget.
            var parent = gtk_widget_get_parent(widget)
            while let p = parent {
                let typeName = String(cString: g_type_name(gtk_swift_get_widget_type(p)))
                if typeName == "GtkScrolledWindow" {
                    // Temporarily make the widget focusable so grab_focus
                    // triggers GTK4 auto-scroll. Restore after.
                    let wasFocusable = gtk_widget_get_focusable(widget)
                    gtk_widget_set_focusable(widget, 1)
                    gtk_widget_grab_focus(widget)
                    gtk_widget_set_focusable(widget, wasFocusable)
                    break
                }
                parent = gtk_widget_get_parent(p)
            }
        }
        return gtkRenderView(content(proxy))
    }
}

// MARK: - Popover GTK extension

extension PopoverView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let anchor = widgetFromOpaque(gtkRenderView(content))
        let gobject = UnsafeMutableRawPointer(anchor).assumingMemoryBound(to: GObject.self)

        if isPresented.wrappedValue {
            // Prevent duplicate popover
            guard g_object_get_data(gobject, "swift-popover-widget") == nil else {
                return opaqueFromWidget(anchor)
            }

            let popover = gtk_popover_new()!
            let popChild = widgetFromOpaque(gtkRenderView(popoverContent))
            gtk_swift_popover_set_child(popover, popChild)
            gtk_widget_set_parent(popover, anchor)

            // Store the popover widget on the anchor so a rebuild with
            // isPresented=false can find and dismiss it programmatically.
            g_object_set_data(gobject, "swift-popover-widget",
                              UnsafeMutableRawPointer(popover))

            let binding = isPresented
            // Ref the anchor so the closed callback can safely write back
            // even if the anchor widget is destroyed before the popover closes.
            g_object_ref(gpointer(anchor))
            let anchorWidget = anchor
            // Dismiss on close — update binding and clear stored popover
            let dismissBox = Unmanaged.passRetained(ClosureBox {
                binding.wrappedValue = false
                // Check liveness before writing GObject data — the anchor
                // may have been finalized if this fires during teardown.
                if gtk_swift_is_widget(anchorWidget) != 0 {
                    let obj = UnsafeMutableRawPointer(anchorWidget).assumingMemoryBound(to: GObject.self)
                    g_object_set_data(obj, "swift-popover-widget", nil)
                }
                g_object_unref(gpointer(anchorWidget))
            }).toOpaque()
            g_signal_connect_data(
                gpointer(popover), "closed",
                unsafeBitCast({ (_: gpointer?, ud: gpointer?) in
                    guard let ud = ud else { return }
                    Unmanaged<ClosureBox>.fromOpaque(ud).takeUnretainedValue().closure()
                } as @convention(c) (gpointer?, gpointer?) -> Void,
                to: GCallback.self),
                dismissBox,
                { (data: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    guard let data = data else { return }
                    Unmanaged<ClosureBox>.fromOpaque(data).release()
                },
                GConnectFlags(rawValue: 0)
            )

            gtk_swift_popover_popup(popover)
        } else {
            // Programmatic dismissal: if a popover was previously shown,
            // close it when the binding becomes false.
            if let raw = g_object_get_data(gobject, "swift-popover-widget") {
                let popover = raw.assumingMemoryBound(to: GtkWidget.self)
                gtk_swift_popover_popdown(popover)
                g_object_set_data(gobject, "swift-popover-widget", nil)
            }
        }

        return opaqueFromWidget(anchor)
    }
}

// MARK: - Layout modifier GTK extensions

extension PositionView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let child = widgetFromOpaque(gtkRenderView(content))
        let fixed = gtk_fixed_new()!
        // SwiftUI .position() centers the view at (x, y).
        // gtk_fixed_put places the top-left corner. Measure the child
        // and offset by half its natural size to center it.
        var natW: gint = 0
        var natH: gint = 0
        gtk_widget_measure(child, GTK_ORIENTATION_HORIZONTAL, -1, nil, &natW, nil, nil)
        gtk_widget_measure(child, GTK_ORIENTATION_VERTICAL, -1, nil, &natH, nil, nil)
        let cx = x - Double(natW) / 2
        let cy = y - Double(natH) / 2
        gtk_swift_fixed_put(fixed, child, cx, cy)
        return opaqueFromWidget(fixed)
    }
}

extension LayoutPriorityView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        // Priority value stored on the modifier — backends can read it
        // during stack layout. For now, pass through content unchanged.
        gtkRenderView(content)
    }
}

extension FixedSizeView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        // Lock the widget to its natural size so containers cannot shrink it.
        // Measure horizontal first, then measure vertical with the resolved
        // width so wrapping content gets the correct height.
        var reqW: gint = -1
        var reqH: gint = -1
        if horizontal {
            gtk_widget_measure(widget, GTK_ORIENTATION_HORIZONTAL, -1, nil, &reqW, nil, nil)
        }
        if vertical {
            // Measure height with the horizontal natural size (or -1 if not
            // fixed horizontally) so wrapping text gets the right height.
            let forWidth: gint = horizontal ? reqW : -1
            gtk_widget_measure(widget, GTK_ORIENTATION_VERTICAL, forWidth, nil, &reqH, nil, nil)
        }
        if reqW >= 0 || reqH >= 0 {
            gtk_widget_set_size_request(widget, reqW, reqH)
        }
        return opaqueFromWidget(widget)
    }
}

// MARK: - contextMenu GTK extension

extension ContextMenuView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))

        // Build GMenu model + action group reusing the existing Menu pattern
        let actionGroup = g_simple_action_group_new()!
        let menuModel = gtk_swift_menu_new()!
        let actionBox = MenuActionBox()
        var actionIndex = 0

        gtkBuildMenuModel(elements: menuElements, menu: menuModel,
                          actionGroup: actionGroup, actionBox: actionBox,
                          actionIndex: &actionIndex)

        // Create popover menu from the model
        let popover = gtk_swift_popover_menu_new_from_model(menuModel)!
        gtk_widget_set_parent(popover, widget)

        // Attach action group to the content widget so menu items can resolve actions
        gtk_swift_widget_insert_action_group(widget, "menu", gpointer(actionGroup))

        // Attach actionBox for lifetime management
        let retained = Unmanaged.passRetained(actionBox).toOpaque()
        let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
        g_object_set_data_full(gobject, "gtk-swift-context-actions", retained,
            { userData in Unmanaged<MenuActionBox>.fromOpaque(userData!).release() })

        // Right-click gesture (button 3) to show the popover at click position
        let gesture = gtk_gesture_click_new()!
        gtk_swift_gesture_single_set_button(gesture, 3)
        let popoverBox = Unmanaged.passRetained(DoubleDoubleClosureBox { x, y in
            gtk_swift_popover_set_pointing_to(popover, Int32(x), Int32(y), 1, 1)
            gtk_swift_popover_popup(popover)
        }).toOpaque()
        g_signal_connect_data(
            gpointer(gesture), "pressed",
            unsafeBitCast({ (_: gpointer?, _: gint, x: Double, y: Double, ud: gpointer?) in
                guard let ud = ud else { return }
                Unmanaged<DoubleDoubleClosureBox>.fromOpaque(ud).takeUnretainedValue().closure(x, y)
            } as @convention(c) (gpointer?, gint, Double, Double, gpointer?) -> Void,
            to: GCallback.self),
            popoverBox,
            { (data: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                guard let data = data else { return }
                Unmanaged<DoubleDoubleClosureBox>.fromOpaque(data).release()
            },
            GConnectFlags(rawValue: 0)
        )
        gtk_swift_add_gesture(widget, gesture)

        return opaqueFromWidget(widget)
    }
}

// MARK: - onChange GTK extension

extension OnChangeView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        onChangeCheckAndFire(value: value, action: action)
        return gtkRenderView(content)
    }
}

extension OnChangeTwoArgView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        onChangeCheckAndFireTwoArg(value: value, action: action)
        return gtkRenderView(content)
    }
}

// MARK: - Appearance modifier GTK extensions

extension HiddenView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let inner = widgetFromOpaque(gtkRenderView(content))
        // Wrap in a GtkBox so that the hidden opacity lives on a separate
        // widget from any .opacity() modifier applied to the content.
        // This prevents .hidden().opacity(0.5) from making the view visible.
        let wrapper = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_box_append(boxPointer(wrapper), inner)
        // Preserve layout space (unlike gtk_widget_set_visible(0) which
        // collapses layout). Opacity on the wrapper is independent of
        // any opacity on the content widget.
        gtk_widget_set_opacity(wrapper, 0)
        // Block all interaction: pointer, keyboard focus, and sensitivity
        gtk_widget_set_can_target(wrapper, 0)
        gtk_widget_set_can_focus(wrapper, 0)
        gtk_widget_set_sensitive(wrapper, 0)
        // Propagate expand flags from content
        gtk_widget_set_hexpand(wrapper, gtk_widget_get_hexpand(inner))
        gtk_widget_set_vexpand(wrapper, gtk_widget_get_vexpand(inner))
        return opaqueFromWidget(wrapper)
    }
}

extension BlurView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        if radius > 0 {
            applyCSSToWidget(widget, properties: "filter: blur(\(radius)px);")
        }
        return opaqueFromWidget(widget)
    }
}

// MARK: - Style modifier GTK extensions

extension ButtonStyleModifier: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        var env = getCurrentEnvironment()
        env.buttonStyle = style
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(env)
        let widget = gtkRenderView(content)
        setCurrentEnvironment(prev)
        return widget
    }
}

extension ToggleStyleModifier: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        var env = getCurrentEnvironment()
        env.toggleStyle = style
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(env)
        let widget = gtkRenderView(content)
        setCurrentEnvironment(prev)
        return widget
    }
}

extension TextFieldStyleModifier: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        var env = getCurrentEnvironment()
        env.textFieldStyle = style
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(env)
        let widget = gtkRenderView(content)
        setCurrentEnvironment(prev)
        return widget
    }
}

// MARK: - Gesture GTK extensions

/// Box for tap gesture that carries the required tap count.
private class TapClosureBox {
    let requiredCount: Int
    let action: () -> Void
    init(count: Int, action: @escaping () -> Void) {
        self.requiredCount = count
        self.action = action
    }
}

extension TapGestureView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        // Transparent wrapper: describe content so sibling Canvas nodes
        // participate in the narrow mutation path. This preserves gesture
        // widgets across state-driven redraws.
        let childDescriptor = gtkDescribeView(content)
        return GTK4DescriptorNode(
            kind: .composite,
            typeName: "TapGestureView",
            children: [childDescriptor]
        )
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        let gesture = gtk_gesture_click_new()!

        let boundAction = bindActionToCurrentEnvironment(action)
        let box = Unmanaged.passRetained(TapClosureBox(count: count, action: boundAction)).toOpaque()
        g_signal_connect_data(
            gpointer(gesture),
            "pressed",
            unsafeBitCast({ (_: gpointer?, nPress: gint, _: gdouble, _: gdouble, userData: gpointer?) in
                let box = Unmanaged<TapClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                if Int(nPress) == box.requiredCount {
                    box.action()
                }
            } as @convention(c) (gpointer?, gint, gdouble, gdouble, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<TapClosureBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        gtk_swift_add_gesture(widget, gesture)
        return opaqueFromWidget(widget)
    }
}

extension LongPressGestureView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        let gesture = gtk_gesture_long_press_new()!

        // Set delay threshold
        g_object_set_double(gpointer(gesture), "delay-factor", minimumDuration / 0.5)

        let boundAction = bindActionToCurrentEnvironment(action)
        let box = Unmanaged.passRetained(ClosureBox(boundAction)).toOpaque()
        g_signal_connect_data(
            gpointer(gesture),
            "pressed",
            unsafeBitCast({ (_: gpointer?, _: gdouble, _: gdouble, userData: gpointer?) in
                let box = Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                box.closure()
            } as @convention(c) (gpointer?, gdouble, gdouble, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<ClosureBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        gtk_swift_add_gesture(widget, gesture)
        return opaqueFromWidget(widget)
    }
}

/// Mutable state for tracking drag start location across GTK signal callbacks.
private class GTKDragState {
    var startX: Double = 0
    var startY: Double = 0
    var dragStarted = false
}

extension DragGestureView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        // Transparent wrapper: describe content so Canvas (and other
        // describable children) participate in the narrow mutation path.
        // This preserves the gesture widget across state-driven redraws.
        let childDescriptor = gtkDescribeView(content)
        return GTK4DescriptorNode(
            kind: .composite,
            typeName: "DragGestureView",
            children: [childDescriptor]
        )
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        let gesture = gtk_gesture_drag_new()!

        let dragState = GTKDragState()

        if let onChanged = onChanged {
            let boundOnChanged = bindActionToCurrentEnvironment(onChanged)
            let state = dragState
            let minimumDistance = self.minimumDistance
            let box = Unmanaged.passRetained(DoubleDoubleClosureBox { offsetX, offsetY in
                if !state.dragStarted {
                    let distance = hypot(offsetX, offsetY)
                    guard distance >= minimumDistance else { return }
                    state.dragStarted = true
                }
                let value = DragGestureValue(
                    startLocation: (x: state.startX, y: state.startY),
                    location: (x: state.startX + offsetX, y: state.startY + offsetY),
                    translation: (width: offsetX, height: offsetY)
                )
                boundOnChanged(value)
            }).toOpaque()

            // drag-begin: record start position
            let beginBox = Unmanaged.passRetained(DoubleDoubleClosureBox { x, y in
                state.startX = x
                state.startY = y
                state.dragStarted = false
            }).toOpaque()
            g_signal_connect_data(
                gpointer(gesture),
                "drag-begin",
                unsafeBitCast({ (_: gpointer?, x: gdouble, y: gdouble, userData: gpointer?) in
                    Unmanaged<DoubleDoubleClosureBox>.fromOpaque(userData!).takeUnretainedValue().closure(x, y)
                } as @convention(c) (gpointer?, gdouble, gdouble, gpointer?) -> Void, to: GCallback.self),
                beginBox,
                { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    Unmanaged<DoubleDoubleClosureBox>.fromOpaque(userData!).release()
                },
                GConnectFlags(rawValue: 0)
            )

            // drag-update: fire onChanged
            g_signal_connect_data(
                gpointer(gesture),
                "drag-update",
                unsafeBitCast({ (_: gpointer?, offsetX: gdouble, offsetY: gdouble, userData: gpointer?) in
                    Unmanaged<DoubleDoubleClosureBox>.fromOpaque(userData!).takeUnretainedValue().closure(offsetX, offsetY)
                } as @convention(c) (gpointer?, gdouble, gdouble, gpointer?) -> Void, to: GCallback.self),
                box,
                { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    Unmanaged<DoubleDoubleClosureBox>.fromOpaque(userData!).release()
                },
                GConnectFlags(rawValue: 0)
            )
        }

        if let onEnded = onEnded {
            let boundOnEnded = bindActionToCurrentEnvironment(onEnded)
            let state = dragState
            let minimumDistance = self.minimumDistance
            // If no onChanged handler registered drag-begin, we need to capture start here too.
            if self.onChanged == nil {
                let beginBox = Unmanaged.passRetained(DoubleDoubleClosureBox { x, y in
                    state.startX = x
                    state.startY = y
                    state.dragStarted = false
                }).toOpaque()
                g_signal_connect_data(
                    gpointer(gesture),
                    "drag-begin",
                    unsafeBitCast({ (_: gpointer?, x: gdouble, y: gdouble, userData: gpointer?) in
                        Unmanaged<DoubleDoubleClosureBox>.fromOpaque(userData!).takeUnretainedValue().closure(x, y)
                    } as @convention(c) (gpointer?, gdouble, gdouble, gpointer?) -> Void, to: GCallback.self),
                    beginBox,
                    { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                        Unmanaged<DoubleDoubleClosureBox>.fromOpaque(userData!).release()
                    },
                    GConnectFlags(rawValue: 0)
                )
            }

            let endBox = Unmanaged.passRetained(DoubleDoubleClosureBox { offsetX, offsetY in
                if !state.dragStarted {
                    let distance = hypot(offsetX, offsetY)
                    guard distance >= minimumDistance else { return }
                    state.dragStarted = true
                }
                let value = DragGestureValue(
                    startLocation: (x: state.startX, y: state.startY),
                    location: (x: state.startX + offsetX, y: state.startY + offsetY),
                    translation: (width: offsetX, height: offsetY)
                )
                boundOnEnded(value)
            }).toOpaque()
            g_signal_connect_data(
                gpointer(gesture),
                "drag-end",
                unsafeBitCast({ (_: gpointer?, offsetX: gdouble, offsetY: gdouble, userData: gpointer?) in
                    Unmanaged<DoubleDoubleClosureBox>.fromOpaque(userData!).takeUnretainedValue().closure(offsetX, offsetY)
                } as @convention(c) (gpointer?, gdouble, gdouble, gpointer?) -> Void, to: GCallback.self),
                endBox,
                { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    Unmanaged<DoubleDoubleClosureBox>.fromOpaque(userData!).release()
                },
                GConnectFlags(rawValue: 0)
            )
        }

        gtk_swift_add_gesture(widget, gesture)
        return opaqueFromWidget(widget)
    }
}

// MARK: - Animation & Transform GTK extensions

/// GObject data keys for storing animatable state on widgets.
private let gtkSwiftOffsetXKey = "gtk-swift-offset-x"
private let gtkSwiftOffsetYKey = "gtk-swift-offset-y"
private let gtkSwiftScaleXKey = "gtk-swift-scale-x"
private let gtkSwiftScaleYKey = "gtk-swift-scale-y"
private let gtkSwiftRotationKey = "gtk-swift-rotation"

/// Box for storing a Double in GObject data without losing 0.0 as nil.
private final class WidgetDoubleBox {
    let value: Double
    init(_ value: Double) { self.value = value }
}

/// Store a Double value on a widget via GObject data (bit-pattern encoded).
private func setWidgetDouble(_ widget: UnsafeMutablePointer<GtkWidget>, key: String, value: Double) {
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    let retained = Unmanaged.passRetained(WidgetDoubleBox(value)).toOpaque()
    g_object_set_data_full(gobject, key, retained) { userData in
        Unmanaged<WidgetDoubleBox>.fromOpaque(userData!).release()
    }
}

/// Read a Double value from a widget via GObject data.
func getWidgetDouble(_ widget: UnsafeMutablePointer<GtkWidget>, key: String) -> Double? {
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    guard let raw = g_object_get_data(gobject, key) else { return nil }
    return Unmanaged<WidgetDoubleBox>.fromOpaque(raw).takeUnretainedValue().value
}

/// Build a combined CSS transform string from offset, scale, and rotation values.
/// Order: translate → rotate → scale (matches CSS transform application order).
func buildTransformCSS(offsetX: Double, offsetY: Double, scaleX: Double, scaleY: Double, rotation: Double = 0) -> String {
    var parts: [String] = []
    if offsetX != 0 || offsetY != 0 {
        parts.append("translate(\(Int(offsetX))px, \(Int(offsetY))px)")
    }
    if rotation != 0 {
        parts.append("rotate(\(rotation)deg)")
    }
    if scaleX != 1 || scaleY != 1 {
        parts.append("scale(\(scaleX), \(scaleY))")
    }
    guard !parts.isEmpty else { return "" }
    return "transform: \(parts.joined(separator: " "));"
}

extension OpacityView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(
            kind: .opacity, typeName: "OpacityView",
            props: .opacity(GTK4OpacityDescriptor(opacity: opacity)),
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        gtk_widget_set_opacity(widget, opacity)
        return opaqueFromWidget(widget)
    }
}

extension OffsetView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(
            kind: .offset, typeName: "OffsetView",
            props: .offset(GTK4OffsetDescriptor(x: x, y: y)),
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        setWidgetDouble(widget, key: gtkSwiftOffsetXKey, value: x)
        setWidgetDouble(widget, key: gtkSwiftOffsetYKey, value: y)
        if x != 0 || y != 0 {
            let scaleX = getWidgetDouble(widget, key: gtkSwiftScaleXKey) ?? 1
            let scaleY = getWidgetDouble(widget, key: gtkSwiftScaleYKey) ?? 1
            let rotation = getWidgetDouble(widget, key: gtkSwiftRotationKey) ?? 0
            applyCSSToWidget(widget, properties: buildTransformCSS(offsetX: x, offsetY: y, scaleX: scaleX, scaleY: scaleY, rotation: rotation))
        }
        return opaqueFromWidget(widget)
    }
}

extension ScaleEffectView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(
            kind: .scale, typeName: "ScaleEffectView",
            props: .scale(GTK4ScaleDescriptor(scaleX: scaleX, scaleY: scaleY)),
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        setWidgetDouble(widget, key: gtkSwiftScaleXKey, value: scaleX)
        setWidgetDouble(widget, key: gtkSwiftScaleYKey, value: scaleY)
        if scaleX != 1 || scaleY != 1 {
            let offsetX = getWidgetDouble(widget, key: gtkSwiftOffsetXKey) ?? 0
            let offsetY = getWidgetDouble(widget, key: gtkSwiftOffsetYKey) ?? 0
            let rotation = getWidgetDouble(widget, key: gtkSwiftRotationKey) ?? 0
            applyCSSToWidget(widget, properties: buildTransformCSS(offsetX: offsetX, offsetY: offsetY, scaleX: scaleX, scaleY: scaleY, rotation: rotation))
        }
        return opaqueFromWidget(widget)
    }
}

extension AnimatedView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        let props: GTK4DescriptorProps
        if let anim = animation {
            props = .animated(GTK4AnimatedDescriptor(
                curve: String(describing: anim.curve),
                duration: anim.duration))
        } else {
            props = .none
        }
        return GTK4DescriptorNode(
            kind: .animated, typeName: "AnimatedView",
            props: props,
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        if let animation = animation ?? getCurrentAnimation() {
            let timing: String
            switch animation.curve {
            case .linear:    timing = "linear"
            case .easeIn:    timing = "ease-in"
            case .easeOut:   timing = "ease-out"
            case .easeInOut: timing = "ease-in-out"
            case .spring:    timing = "cubic-bezier(0.5, 1.8, 0.3, 0.8)"
            }
            let duration = String(format: "%.2f", animation.duration)
            applyCSSToWidget(widget, properties: "transition: all \(duration)s \(timing);")
        }
        return opaqueFromWidget(widget)
    }
}

// MARK: - OnAppear / OnDisappear GTK extensions

extension OnAppearView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))

        // During a rebuild, the ViewHost container is already mapped.
        // Skip attaching the signal since the appear already happened.
        let isRebuild: Bool
        if let host = GTKViewHost.getCurrentRebuilding() {
            isRebuild = gtk_widget_get_mapped(host.container) != 0
        } else {
            isRebuild = false
        }

        if !isRebuild {
            let boundAction = bindActionToCurrentEnvironment(action)
            let box = Unmanaged.passRetained(ClosureBox(boundAction)).toOpaque()
            g_signal_connect_data(
                gpointer(widget),
                "map",
                unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                    let box = Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                    box.closure()
                } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
                box,
                { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    Unmanaged<ClosureBox>.fromOpaque(userData!).release()
                },
                GConnectFlags(rawValue: 0)
            )
        }

        return opaqueFromWidget(widget)
    }
}

/// Holds the disappear callback and a reference to the host container
/// for distinguishing rebuild unmaps from real disappears.
private class DisappearBox {
    let action: () -> Void
    let hostContainer: UnsafeMutablePointer<GtkWidget>?
    init(action: @escaping () -> Void, hostContainer: UnsafeMutablePointer<GtkWidget>?) {
        self.action = action
        self.hostContainer = hostContainer
    }
}

extension OnDisappearView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))

        let hostContainer: UnsafeMutablePointer<GtkWidget>?
        if let host = GTKViewHost.getCurrentRebuilding() {
            hostContainer = host.container
        } else {
            hostContainer = nil
        }

        let boundAction = bindActionToCurrentEnvironment(action)
        let box = Unmanaged.passRetained(
            DisappearBox(action: boundAction, hostContainer: hostContainer)
        ).toOpaque()
        g_signal_connect_data(
            gpointer(widget),
            "unmap",
            unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                let box = Unmanaged<DisappearBox>.fromOpaque(userData!).takeUnretainedValue()
                // If the host container is still mapped, this is a rebuild — suppress.
                if let container = box.hostContainer,
                   gtk_widget_get_mapped(container) != 0 {
                    return
                }
                box.action()
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<DisappearBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        return opaqueFromWidget(widget)
    }
}

// MARK: - Sheet GTK extension

/// Holds sheet configuration for deferred presentation.
/// Extract dismissal-confirmation configuration from a view tree.
private func gtkExtractDismissalConfig(from view: Any, depth: Int = 0) -> DismissalConfirmationConfiguration? {
    guard depth < 20 else { return nil }
    if let provider = view as? DismissalConfirmationProvider {
        if let config = provider.dismissalConfirmationConfiguration {
            return config
        }
    }
    let mirror = Mirror(reflecting: view)
    for child in mirror.children {
        if let result = gtkExtractDismissalConfig(from: child.value, depth: depth + 1) {
            return result
        }
    }
    return nil
}

/// Present a confirmation dialog directly on top of a sheet window.
private func gtkPresentConfirmationDialog(
    config: DismissalConfirmationConfiguration,
    transientFor sheetWin: UnsafeMutablePointer<GtkWindow>,
    onActualDismiss: @escaping () -> Void
) {
    let dialog = gtk_window_new()!
    let dialogWin = windowPointer(dialog)
    gtk_window_set_modal(dialogWin, 1)
    gtk_window_set_title(dialogWin, config.titleVisibility == .hidden ? "" : config.title)
    gtk_window_set_default_size(dialogWin, 300, -1)
    gtk_window_set_resizable(dialogWin, 0)
    gtk_window_set_transient_for(dialogWin, sheetWin)

    let vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8)!
    gtk_widget_set_margin_top(vbox, 20)
    gtk_widget_set_margin_bottom(vbox, 20)
    gtk_widget_set_margin_start(vbox, 20)
    gtk_widget_set_margin_end(vbox, 20)

    if config.titleVisibility != .hidden {
        let titleLabel = gtk_label_new(nil)!
        let escaped = config.title
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        gtk_swift_label_set_markup(titleLabel, "<b>\(escaped)</b>")
        gtk_box_append(boxPointer(vbox), titleLabel)
    }

    if !config.message.isEmpty {
        let msgLabel = gtk_label_new(config.message)!
        gtk_label_set_wrap(OpaquePointer(msgLabel), 1)
        gtk_box_append(boxPointer(vbox), msgLabel)
    }

    let sep = gtk_separator_new(GTK_ORIENTATION_HORIZONTAL)!
    gtk_box_append(boxPointer(vbox), sep)

    for alertButton in config.buttons {
        let btn = gtk_button_new_with_label(alertButton.label)!
        gtk_widget_set_hexpand(btn, 1)
        if alertButton.role == .destructive {
            gtk_widget_add_css_class(btn, "destructive-action")
        }
        // Non-cancel buttons confirm dismissal: run action, close confirmation, then close sheet
        let shouldDismissSheet = alertButton.role != .cancel
        let wrappedAction: () -> Void = {
            alertButton.action()
            if shouldDismissSheet {
                onActualDismiss()
            }
        }
        let actionBox = Unmanaged.passRetained(AlertActionBox(
            action: wrappedAction, dialog: dialog
        )).toOpaque()
        g_signal_connect_data(
            gpointer(btn),
            "clicked",
            unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                let box = Unmanaged<AlertActionBox>.fromOpaque(userData!).takeUnretainedValue()
                box.action()
                gtk_window_destroy(windowPointer(box.dialog))
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            actionBox,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<AlertActionBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )
        gtk_box_append(boxPointer(vbox), btn)
    }

    gtk_window_set_child(dialogWin, vbox)

    // Close confirmation dialog resets shouldPresent
    let binding = config.isPresented
    let closeBox = Unmanaged.passRetained(ClosureBox {
        binding.wrappedValue = false
    }).toOpaque()
    g_signal_connect_data(
        gpointer(dialog),
        "close-request",
        unsafeBitCast({ (_: gpointer?, userData: gpointer?) -> gboolean in
            Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue().closure()
            return 0
        } as @convention(c) (gpointer?, gpointer?) -> gboolean, to: GCallback.self),
        closeBox,
        { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
            Unmanaged<ClosureBox>.fromOpaque(userData!).release()
        },
        GConnectFlags(rawValue: 0)
    )

    gtk_window_present(dialogWin)
}

private class SheetInfo {
    let anchor: UnsafeMutablePointer<GtkWidget>
    let render: () -> OpaquePointer
    let onDismiss: () -> Void
    /// Dismissal config from sheet content, used to present confirmation dialog on intercept.
    let dismissalConfig: DismissalConfirmationConfiguration?

    init(anchor: UnsafeMutablePointer<GtkWidget>,
         render: @escaping () -> OpaquePointer,
         onDismiss: @escaping () -> Void,
         dismissalConfig: DismissalConfirmationConfiguration? = nil) {
        self.anchor = anchor
        self.render = render
        self.onDismiss = onDismiss
        self.dismissalConfig = dismissalConfig
    }
}

extension SheetModifierView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))

        let anchor: UnsafeMutablePointer<GtkWidget>
        if let host = GTKViewHost.getCurrentRebuilding() {
            anchor = host.container
        } else {
            anchor = widget
        }
        let gobject = UnsafeMutableRawPointer(anchor).assumingMemoryBound(to: GObject.self)

        if !isPresented.wrappedValue {
            // Dismiss active sheet if binding turned false
            if let dialogPtr = g_object_get_data(gobject, "swift-sheet-window") {
                let dialog = dialogPtr.assumingMemoryBound(to: GtkWindow.self)
                g_object_set_data(gobject, "swift-sheet-active", nil)
                g_object_set_data(gobject, "swift-sheet-window", nil)
                gtk_window_destroy(dialog)
                onDismiss?()
            }
            return opaqueFromWidget(widget)
        }

        // Guard against duplicate presentation on rebuild
        guard g_object_get_data(gobject, "swift-sheet-active") == nil else {
            return opaqueFromWidget(widget)
        }
        g_object_set_data(gobject, "swift-sheet-active", gpointer(bitPattern: 1))
        g_object_ref(gpointer(anchor))

        let sheetView = sheetContent
        let binding = isPresented
        let userOnDismiss = onDismiss
        let dismissalConfig = gtkExtractDismissalConfig(from: sheetView)
        let info = Unmanaged.passRetained(SheetInfo(
            anchor: anchor,
            render: { gtkRenderView(sheetView) },
            onDismiss: {
                let obj = UnsafeMutableRawPointer(anchor).assumingMemoryBound(to: GObject.self)
                // Idempotent: guard against double-dismiss from both programmatic and signal paths
                guard g_object_get_data(obj, "swift-sheet-active") != nil else { return }
                g_object_set_data(obj, "swift-sheet-active", nil)
                g_object_set_data(obj, "swift-sheet-window", nil)
                binding.wrappedValue = false
                userOnDismiss?()
            },
            dismissalConfig: dismissalConfig
        )).toOpaque()

        g_idle_add({ userData -> gboolean in
            let info = Unmanaged<SheetInfo>.fromOpaque(userData!).takeRetainedValue()
            guard let root = gtk_widget_get_root(info.anchor) else {
                info.onDismiss()
                g_object_unref(gpointer(info.anchor))
                return 0
            }

            let dialog = gtk_window_new()!
            let dialogWin = windowPointer(dialog)
            gtk_window_set_modal(dialogWin, 1)
            gtk_window_set_title(dialogWin, "")
            gtk_window_set_default_size(dialogWin, 400, 300)
            gtk_window_set_transient_for(
                dialogWin,
                UnsafeMutableRawPointer(root).assumingMemoryBound(to: GtkWindow.self)
            )

            // Inject dismiss action into environment
            let previous = getCurrentEnvironment()
            var env = previous
            if let config = info.dismissalConfig {
                // Dismiss action shows confirmation instead of destroying
                env.dismiss = DismissAction {
                    config.isPresented.wrappedValue = true
                    gtkPresentConfirmationDialog(config: config, transientFor: dialogWin, onActualDismiss: info.onDismiss)
                }
            } else {
                env.dismiss = DismissAction { gtk_window_destroy(dialogWin) }
            }
            setCurrentEnvironment(env)
            let sheetWidget = widgetFromOpaque(info.render())
            setCurrentEnvironment(previous)
            gtk_window_set_child(dialogWin, sheetWidget)

            let anchorObj = UnsafeMutableRawPointer(info.anchor).assumingMemoryBound(to: GObject.self)
            g_object_set_data(anchorObj, "swift-sheet-window", gpointer(dialogWin))

            if let config = info.dismissalConfig {
                // User-triggered close: show confirmation dialog on top of the sheet
                let closeHandler: () -> Void = {
                    config.isPresented.wrappedValue = true
                    gtkPresentConfirmationDialog(config: config, transientFor: dialogWin, onActualDismiss: info.onDismiss)
                }
                let interceptBox = Unmanaged.passRetained(ClosureBox(closeHandler)).toOpaque()
                g_signal_connect_data(
                    gpointer(dialog),
                    "close-request",
                    unsafeBitCast({ (_: gpointer?, userData: gpointer?) -> gboolean in
                        Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue().closure()
                        return 1 // suppress default close
                    } as @convention(c) (gpointer?, gpointer?) -> gboolean, to: GCallback.self),
                    interceptBox,
                    { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                        Unmanaged<ClosureBox>.fromOpaque(userData!).release()
                    },
                    GConnectFlags(rawValue: 0)
                )
            } else {
                let dismissBox = Unmanaged.passRetained(ClosureBox(info.onDismiss)).toOpaque()
                g_signal_connect_data(
                    gpointer(dialog),
                    "close-request",
                    unsafeBitCast({ (_: gpointer?, userData: gpointer?) -> gboolean in
                        Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue().closure()
                        return 0
                    } as @convention(c) (gpointer?, gpointer?) -> gboolean, to: GCallback.self),
                    dismissBox,
                    { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                        Unmanaged<ClosureBox>.fromOpaque(userData!).release()
                    },
                    GConnectFlags(rawValue: 0)
                )
            }

            gtk_window_present(dialogWin)
            g_object_unref(gpointer(info.anchor))
            return 0
        }, info)

        return opaqueFromWidget(widget)
    }
}

extension ItemSheetModifierView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))

        let anchor: UnsafeMutablePointer<GtkWidget>
        if let host = GTKViewHost.getCurrentRebuilding() {
            anchor = host.container
        } else {
            anchor = widget
        }
        let gobject = UnsafeMutableRawPointer(anchor).assumingMemoryBound(to: GObject.self)

        guard let currentItem = item.wrappedValue else {
            // Dismiss active sheet if item became nil
            if let dialogPtr = g_object_get_data(gobject, "swift-sheet-window") {
                let dialog = dialogPtr.assumingMemoryBound(to: GtkWindow.self)
                g_object_set_data(gobject, "swift-sheet-active", nil)
                g_object_set_data(gobject, "swift-sheet-window", nil)
                g_object_set_data(gobject, "swift-sheet-item-id", nil)
                gtk_window_destroy(dialog)
                onDismiss?()
            }
            return opaqueFromWidget(widget)
        }

        // Check if the item identity changed while a sheet is already active
        let currentIdHash = currentItem.id.hashValue
        if g_object_get_data(gobject, "swift-sheet-active") != nil {
            let storedHash = Int(bitPattern: g_object_get_data(gobject, "swift-sheet-item-id"))
            if storedHash == currentIdHash {
                // Same item — no change needed
                return opaqueFromWidget(widget)
            }
            // Different item — dismiss old sheet, then fall through to present new one
            if let dialogPtr = g_object_get_data(gobject, "swift-sheet-window") {
                let dialog = dialogPtr.assumingMemoryBound(to: GtkWindow.self)
                g_object_set_data(gobject, "swift-sheet-active", nil)
                g_object_set_data(gobject, "swift-sheet-window", nil)
                g_object_set_data(gobject, "swift-sheet-item-id", nil)
                gtk_window_destroy(dialog)
                onDismiss?()
            }
        }
        g_object_set_data(gobject, "swift-sheet-active", gpointer(bitPattern: 1))
        g_object_set_data(gobject, "swift-sheet-item-id", gpointer(bitPattern: currentIdHash))
        g_object_ref(gpointer(anchor))

        let sheetBuilder = sheetContent
        let itemBinding = item
        let userOnDismiss = onDismiss
        let itemDismissalConfig = gtkExtractDismissalConfig(from: sheetBuilder(currentItem))
        let info = Unmanaged.passRetained(SheetInfo(
            anchor: anchor,
            render: { gtkRenderView(sheetBuilder(currentItem)) },
            onDismiss: {
                let obj = UnsafeMutableRawPointer(anchor).assumingMemoryBound(to: GObject.self)
                // Idempotent: guard against double-dismiss from both programmatic and signal paths
                guard g_object_get_data(obj, "swift-sheet-active") != nil else { return }
                g_object_set_data(obj, "swift-sheet-active", nil)
                g_object_set_data(obj, "swift-sheet-window", nil)
                g_object_set_data(obj, "swift-sheet-item-id", nil)
                itemBinding.wrappedValue = nil
                userOnDismiss?()
            },
            dismissalConfig: itemDismissalConfig
        )).toOpaque()

        g_idle_add({ userData -> gboolean in
            let info = Unmanaged<SheetInfo>.fromOpaque(userData!).takeRetainedValue()
            guard let root = gtk_widget_get_root(info.anchor) else {
                info.onDismiss()
                g_object_unref(gpointer(info.anchor))
                return 0
            }

            let dialog = gtk_window_new()!
            let dialogWin = windowPointer(dialog)
            gtk_window_set_modal(dialogWin, 1)
            gtk_window_set_title(dialogWin, "")
            gtk_window_set_default_size(dialogWin, 400, 300)
            gtk_window_set_transient_for(
                dialogWin,
                UnsafeMutableRawPointer(root).assumingMemoryBound(to: GtkWindow.self)
            )

            let previous = getCurrentEnvironment()
            var env = previous
            if let config = info.dismissalConfig {
                env.dismiss = DismissAction {
                    config.isPresented.wrappedValue = true
                    gtkPresentConfirmationDialog(config: config, transientFor: dialogWin, onActualDismiss: info.onDismiss)
                }
            } else {
                env.dismiss = DismissAction { gtk_window_destroy(dialogWin) }
            }
            setCurrentEnvironment(env)
            let sheetWidget = widgetFromOpaque(info.render())
            setCurrentEnvironment(previous)
            gtk_window_set_child(dialogWin, sheetWidget)

            let anchorObj = UnsafeMutableRawPointer(info.anchor).assumingMemoryBound(to: GObject.self)
            g_object_set_data(anchorObj, "swift-sheet-window", gpointer(dialogWin))

            if let config = info.dismissalConfig {
                let closeHandler: () -> Void = {
                    config.isPresented.wrappedValue = true
                    gtkPresentConfirmationDialog(config: config, transientFor: dialogWin, onActualDismiss: info.onDismiss)
                }
                let interceptBox = Unmanaged.passRetained(ClosureBox(closeHandler)).toOpaque()
                g_signal_connect_data(
                    gpointer(dialog),
                    "close-request",
                    unsafeBitCast({ (_: gpointer?, userData: gpointer?) -> gboolean in
                        Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue().closure()
                        return 1
                    } as @convention(c) (gpointer?, gpointer?) -> gboolean, to: GCallback.self),
                    interceptBox,
                    { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                        Unmanaged<ClosureBox>.fromOpaque(userData!).release()
                    },
                    GConnectFlags(rawValue: 0)
                )
            } else {
                let dismissBox = Unmanaged.passRetained(ClosureBox(info.onDismiss)).toOpaque()
                g_signal_connect_data(
                    gpointer(dialog),
                    "close-request",
                    unsafeBitCast({ (_: gpointer?, userData: gpointer?) -> gboolean in
                        Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue().closure()
                        return 0
                    } as @convention(c) (gpointer?, gpointer?) -> gboolean, to: GCallback.self),
                    dismissBox,
                    { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                        Unmanaged<ClosureBox>.fromOpaque(userData!).release()
                    },
                    GConnectFlags(rawValue: 0)
                )
            }

            gtk_window_present(dialogWin)
            g_object_unref(gpointer(info.anchor))
            return 0
        }, info)

        return opaqueFromWidget(widget)
    }
}

// MARK: - Alert GTK extension

/// Holds alert button action + dialog reference for cleanup.
private class AlertActionBox {
    let action: () -> Void
    let dialog: UnsafeMutablePointer<GtkWidget>
    init(action: @escaping () -> Void, dialog: UnsafeMutablePointer<GtkWidget>) {
        self.action = action
        self.dialog = dialog
    }
}

extension AlertModifierView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))

        let anchor: UnsafeMutablePointer<GtkWidget>
        if let host = GTKViewHost.getCurrentRebuilding() {
            anchor = host.container
        } else {
            anchor = widget
        }
        let gobject = UnsafeMutableRawPointer(anchor).assumingMemoryBound(to: GObject.self)

        if !isPresented.wrappedValue {
            if let dialogPtr = g_object_get_data(gobject, "swift-alert-window") {
                let dialog = dialogPtr.assumingMemoryBound(to: GtkWindow.self)
                g_object_set_data(gobject, "swift-alert-window", nil)
                gtk_window_destroy(dialog)
            }
            return opaqueFromWidget(widget)
        }

        guard g_object_get_data(gobject, "swift-alert-active") == nil else {
            return opaqueFromWidget(widget)
        }
        g_object_set_data(gobject, "swift-alert-active", gpointer(bitPattern: 1))
        g_object_ref(gpointer(anchor))

        let alertTitle = title
        let alertMessage = message
        let alertButtons = buttons
        let binding = isPresented

        let onDismiss: () -> Void = {
            let obj = UnsafeMutableRawPointer(anchor).assumingMemoryBound(to: GObject.self)
            g_object_set_data(obj, "swift-alert-active", nil)
            g_object_set_data(obj, "swift-alert-window", nil)
            binding.wrappedValue = false
        }

        g_idle_add({ userData -> gboolean in
            let box = Unmanaged<ClosureBox>.fromOpaque(userData!).takeRetainedValue()
            // Re-read captured values from the enclosing scope via the closure
            box.closure()
            return 0
        }, Unmanaged.passRetained(ClosureBox { [anchor, alertTitle, alertMessage, alertButtons, onDismiss] in
            guard let root = gtk_widget_get_root(anchor) else {
                onDismiss()
                g_object_unref(gpointer(anchor))
                return
            }

            let dialog = gtk_window_new()!
            let dialogWin = windowPointer(dialog)
            gtk_window_set_modal(dialogWin, 1)
            gtk_window_set_title(dialogWin, alertTitle)
            gtk_window_set_default_size(dialogWin, 350, -1)
            gtk_window_set_resizable(dialogWin, 0)
            gtk_window_set_transient_for(
                dialogWin,
                UnsafeMutableRawPointer(root).assumingMemoryBound(to: GtkWindow.self)
            )

            let vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12)!
            gtk_widget_set_margin_top(vbox, 20)
            gtk_widget_set_margin_bottom(vbox, 20)
            gtk_widget_set_margin_start(vbox, 20)
            gtk_widget_set_margin_end(vbox, 20)

            if !alertMessage.isEmpty {
                let msgLabel = gtk_label_new(alertMessage)!
                gtk_label_set_wrap(OpaquePointer(msgLabel), 1)
                gtk_box_append(boxPointer(vbox), msgLabel)
            }

            let buttonBox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
            gtk_widget_set_halign(buttonBox, GTK_ALIGN_END)

            for alertButton in alertButtons {
                let btn = gtk_button_new_with_label(alertButton.label)!
                if alertButton.role == .destructive {
                    gtk_widget_add_css_class(btn, "destructive-action")
                }
                let actionBox = Unmanaged.passRetained(AlertActionBox(
                    action: alertButton.action, dialog: dialog
                )).toOpaque()
                g_signal_connect_data(
                    gpointer(btn),
                    "clicked",
                    unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                        let box = Unmanaged<AlertActionBox>.fromOpaque(userData!).takeUnretainedValue()
                        box.action()
                        gtk_window_destroy(windowPointer(box.dialog))
                    } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
                    actionBox,
                    { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                        Unmanaged<AlertActionBox>.fromOpaque(userData!).release()
                    },
                    GConnectFlags(rawValue: 0)
                )
                gtk_box_append(boxPointer(buttonBox), btn)
            }

            gtk_box_append(boxPointer(vbox), buttonBox)
            gtk_window_set_child(dialogWin, vbox)

            let anchorObj = UnsafeMutableRawPointer(anchor).assumingMemoryBound(to: GObject.self)
            g_object_set_data(anchorObj, "swift-alert-window", gpointer(dialogWin))

            let closeDismiss = Unmanaged.passRetained(ClosureBox(onDismiss)).toOpaque()
            g_signal_connect_data(
                gpointer(dialog),
                "close-request",
                unsafeBitCast({ (_: gpointer?, userData: gpointer?) -> gboolean in
                    Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue().closure()
                    return 0
                } as @convention(c) (gpointer?, gpointer?) -> gboolean, to: GCallback.self),
                closeDismiss,
                { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    Unmanaged<ClosureBox>.fromOpaque(userData!).release()
                },
                GConnectFlags(rawValue: 0)
            )

            gtk_window_present(dialogWin)
            g_object_unref(gpointer(anchor))
        }).toOpaque())

        return opaqueFromWidget(widget)
    }
}

// MARK: - Link GTK extension

extension Link: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let button = gtk_link_button_new_with_label(destination, title)!
        return opaqueFromWidget(button)
    }
}

// MARK: - SecureField GTK extension

extension SecureField: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let entry = gtk_password_entry_new()!
        gtk_swift_password_entry_set_show_peek_icon(entry, 1)

        let current = text.wrappedValue
        if !current.isEmpty {
            gtk_editable_set_text(OpaquePointer(entry), current)
        }

        if !placeholder.isEmpty {
            if let delegate = gtk_editable_get_delegate(OpaquePointer(entry)) {
                let textWidget = UnsafeMutableRawPointer(delegate).assumingMemoryBound(to: GtkText.self)
                gtk_text_set_placeholder_text(textWidget, placeholder)
            }
        }

        let binding = text
        let box = Unmanaged.passRetained(StringClosureBox { newText in
            if newText != binding.wrappedValue {
                binding.wrappedValue = newText
            }
        }).toOpaque()
        g_signal_connect_data(
            gpointer(entry),
            "changed",
            unsafeBitCast({ (editable: gpointer?, userData: gpointer?) in
                let box = Unmanaged<StringClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                let cStr = gtk_editable_get_text(OpaquePointer(editable))!
                box.closure(String(cString: cStr))
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<StringClosureBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        // Wire onSubmit action from environment (same as TextField)
        if let submitAction = getCurrentEnvironment().submitAction {
            let submitBox = Unmanaged.passRetained(ClosureBox {
                submitAction()
            }).toOpaque()
            g_signal_connect_data(
                gpointer(entry), "activate",
                unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                    guard let userData else { return }
                    Unmanaged<ClosureBox>.fromOpaque(userData).takeUnretainedValue().closure()
                } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
                submitBox,
                { (data: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    guard let data else { return }
                    Unmanaged<ClosureBox>.fromOpaque(data).release()
                },
                GConnectFlags(rawValue: 0)
            )
        }

        gtkApplyEnabledState(to: entry)
        return opaqueFromWidget(entry)
    }
}

// MARK: - TextEditor GTK extension

extension TextEditor: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let textView = gtk_text_view_new()!
        let textViewPtr = UnsafeMutableRawPointer(textView).assumingMemoryBound(to: GtkTextView.self)
        gtk_text_view_set_wrap_mode(textViewPtr, GTK_WRAP_WORD_CHAR)

        let current = text.wrappedValue
        if !current.isEmpty {
            let buffer = gtk_text_view_get_buffer(textViewPtr)
            gtk_text_buffer_set_text(buffer, current, gint(current.utf8.count))
        }

        let binding = text
        let buffer = gtk_text_view_get_buffer(textViewPtr)!
        let box = Unmanaged.passRetained(StringClosureBox { newText in
            if newText != binding.wrappedValue {
                binding.wrappedValue = newText
            }
        }).toOpaque()
        g_signal_connect_data(
            gpointer(buffer),
            "changed",
            unsafeBitCast({ (bufferPtr: gpointer?, userData: gpointer?) in
                let box = Unmanaged<StringClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                let buf = UnsafeMutableRawPointer(bufferPtr!).assumingMemoryBound(to: GtkTextBuffer.self)
                var start = GtkTextIter()
                var end = GtkTextIter()
                gtk_text_buffer_get_bounds(buf, &start, &end)
                let cStr = gtk_text_buffer_get_text(buf, &start, &end, 0)!
                let result = String(cString: cStr)
                g_free(gpointer(mutating: cStr))
                box.closure(result)
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<StringClosureBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        let scrolled = gtk_scrolled_window_new()!
        gtk_scrolled_window_set_policy(OpaquePointer(scrolled), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_set_child(OpaquePointer(scrolled), textView)
        gtk_widget_set_vexpand(scrolled, 1)
        gtk_widget_set_hexpand(scrolled, 1)

        gtkApplyEnabledState(to: textView)
        return opaqueFromWidget(scrolled)
    }
}

// MARK: - ProgressView GTK extension

extension ProgressView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let bar = gtk_progress_bar_new()!
        if let value = value {
            gtk_progress_bar_set_fraction(OpaquePointer(bar), max(0, min(1, value / total)))
        }
        // TODO: indeterminate mode (pulse) when value is nil
        gtk_widget_set_hexpand(bar, 1)
        return opaqueFromWidget(bar)
    }
}

// MARK: - Stepper GTK extension

extension Stepper: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let spin = gtk_swift_spin_button_new_with_range(
            range.lowerBound,
            range.upperBound,
            step
        )!

        gtk_swift_spin_button_set_value(spin, value.wrappedValue)

        let binding = value
        let stepVal = step
        let box = Unmanaged.passRetained(DoubleClosureBox { newValue in
            if abs(newValue - binding.wrappedValue) > stepVal * 0.01 {
                binding.wrappedValue = newValue
            }
        }).toOpaque()
        g_signal_connect_data(
            gpointer(spin),
            "value-changed",
            unsafeBitCast({ (widget: gpointer?, userData: gpointer?) in
                let box = Unmanaged<DoubleClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                let val = gtk_swift_spin_button_get_value(
                    UnsafeMutableRawPointer(widget!).assumingMemoryBound(to: GtkWidget.self)
                )
                box.closure(val)
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<DoubleClosureBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        if !label.isEmpty {
            let hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
            let lbl = gtk_label_new(label)!
            gtk_box_append(boxPointer(hbox), lbl)
            gtk_box_append(boxPointer(hbox), spin)
            gtkApplyEnabledState(to: spin)
            return opaqueFromWidget(hbox)
        }

        gtkApplyEnabledState(to: spin)
        return opaqueFromWidget(spin)
    }
}

// MARK: - Label GTK extension

extension Label: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!

        if let iconName = systemImage {
            let img = gtk_image_new_from_icon_name(iconName)!
            gtk_box_append(boxPointer(box), img)
        } else if let path = imagePath {
            let img = gtk_image_new_from_file(path)!
            gtk_box_append(boxPointer(box), img)
        }

        let lbl = gtk_label_new(title)!
        gtk_box_append(boxPointer(box), lbl)

        return opaqueFromWidget(box)
    }
}

// MARK: - Corner Radius GTK extension

extension CornerRadiusView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        applyCSSToWidget(widget, properties: "border-radius: \(Int(radius))px;")
        return opaqueFromWidget(widget)
    }
}

// MARK: - Labels hidden modifier (no-op pass-through)

extension LabelsHiddenView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        // Push `labelsHidden = true` into the env for the content
        // subtree. Picker's renderer (and any future label-bearing
        // control) consults this flag and omits its inline label
        // prefix. Restored on exit so siblings aren't affected.
        var env = getCurrentEnvironment()
        env.labelsHidden = true
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(env)
        let widget = gtkRenderView(content)
        setCurrentEnvironment(prev)
        return widget
    }
}

// MARK: - Help / tooltip modifier

extension HelpView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        // GTK interprets a non-NULL tooltip string (including empty) as
        // "show a tooltip on hover"; passing NULL clears it. Forward
        // whatever the caller provided — empty strings still register
        // so callers can intentionally clear a prior help value.
        gtk_widget_set_tooltip_text(widget, text)
        return opaqueFromWidget(widget)
    }
}

// MARK: - Clip Shape GTK extensions

extension ClippedView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let inner = widgetFromOpaque(gtkRenderView(content))
        let wrapper = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_box_append(boxPointer(wrapper), inner)
        gtk_widget_set_overflow(wrapper, GTK_OVERFLOW_HIDDEN)
        gtk_widget_set_hexpand(wrapper, gtk_widget_get_hexpand(inner))
        gtk_widget_set_vexpand(wrapper, gtk_widget_get_vexpand(inner))
        return opaqueFromWidget(wrapper)
    }
}

extension ClipShapeView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let inner = widgetFromOpaque(gtkRenderView(content))
        let wrapper = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_box_append(boxPointer(wrapper), inner)
        gtk_widget_set_overflow(wrapper, GTK_OVERFLOW_HIDDEN)
        gtk_widget_set_hexpand(wrapper, gtk_widget_get_hexpand(inner))
        gtk_widget_set_vexpand(wrapper, gtk_widget_get_vexpand(inner))

        // Map shape type to CSS border-radius for clipping.
        let css: String
        if shape is Circle || shape is Ellipse {
            css = "border-radius: 50%;"
        } else if let rr = shape as? RoundedRectangle {
            css = "border-radius: \(Int(rr.cornerRadius))px;"
        } else if shape is Capsule {
            // Capsule = fully rounded ends (half the shorter dimension).
            // Use a large fixed value; GTK clamps to half the box size.
            css = "border-radius: 9999px;"
        } else {
            // Rectangle or unknown — rect clip only, no border-radius needed
            css = ""
        }
        if !css.isEmpty {
            applyCSSToWidget(wrapper, properties: css)
        }
        return opaqueFromWidget(wrapper)
    }
}

// MARK: - Shadow GTK extension

extension ShadowView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        let r = Int(color.red * 255)
        let g = Int(color.green * 255)
        let b = Int(color.blue * 255)
        let a = String(format: "%.2f", color.alpha)
        let css = """
            box-shadow: \(Int(x))px \(Int(y))px \(Int(radius))px rgba(\(r),\(g),\(b),\(a));
            margin: \(Int(radius))px;
            """
        applyCSSToWidget(widget, properties: css)
        return opaqueFromWidget(widget)
    }
}

// MARK: - Rotation GTK extension

extension RotationView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(
            kind: .rotation, typeName: "RotationView",
            props: .rotation(GTK4RotationDescriptor(angle: angle)),
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        setWidgetDouble(widget, key: gtkSwiftRotationKey, value: angle)
        let offsetX = getWidgetDouble(widget, key: gtkSwiftOffsetXKey) ?? 0
        let offsetY = getWidgetDouble(widget, key: gtkSwiftOffsetYKey) ?? 0
        let scaleX = getWidgetDouble(widget, key: gtkSwiftScaleXKey) ?? 1
        let scaleY = getWidgetDouble(widget, key: gtkSwiftScaleYKey) ?? 1
        applyCSSToWidget(widget, properties: buildTransformCSS(offsetX: offsetX, offsetY: offsetY, scaleX: scaleX, scaleY: scaleY, rotation: angle))
        return opaqueFromWidget(widget)
    }
}

// MARK: - Overlay GTK extension

extension OverlayView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let container = gtk_overlay_new()!

        let baseWidget = widgetFromOpaque(gtkRenderView(content))
        gtk_overlay_set_child(OpaquePointer(container), baseWidget)

        if gtk_widget_get_hexpand(baseWidget) != 0 {
            gtk_widget_set_hexpand(container, 1)
        }
        if gtk_widget_get_vexpand(baseWidget) != 0 {
            gtk_widget_set_vexpand(container, 1)
        }

        let overlayWidget = widgetFromOpaque(gtkRenderView(overlay))
        let (hAlign, vAlign) = gtkAlignFromAlignment(alignment)
        // Respect the overlay widget's own expansion intent. A Shape (or any
        // view with hexpand/vexpand set via .frame(maxWidth: .infinity)) wants
        // to fill its container — overwriting halign to CENTER would shrink
        // it to its natural size (0x0 for GtkDrawingArea) and make it vanish.
        // Only apply the requested alignment on the axes where the widget
        // isn't asking to expand. This matches SwiftUI's "overlay fills when
        // its content fills" semantics; explicit alignment still governs
        // non-filling overlays like Text or Image.
        let overlayWantsHExpand = gtk_widget_get_hexpand(overlayWidget) != 0
        let overlayWantsVExpand = gtk_widget_get_vexpand(overlayWidget) != 0
        gtk_widget_set_halign(overlayWidget, overlayWantsHExpand ? GTK_ALIGN_FILL : hAlign)
        gtk_widget_set_valign(overlayWidget, overlayWantsVExpand ? GTK_ALIGN_FILL : vAlign)
        gtk_overlay_add_overlay(OpaquePointer(container), overlayWidget)

        return opaqueFromWidget(container)
    }
}

/// Convert SwiftOpenUI Alignment to GTK align pair.
private func gtkAlignFromAlignment(_ alignment: Alignment) -> (GtkAlign, GtkAlign) {
    let h: GtkAlign
    let v: GtkAlign
    switch alignment {
    case .topLeading:     h = GTK_ALIGN_START;  v = GTK_ALIGN_START
    case .top:            h = GTK_ALIGN_CENTER; v = GTK_ALIGN_START
    case .topTrailing:    h = GTK_ALIGN_END;    v = GTK_ALIGN_START
    case .leading:        h = GTK_ALIGN_START;  v = GTK_ALIGN_CENTER
    case .center:         h = GTK_ALIGN_CENTER; v = GTK_ALIGN_CENTER
    case .trailing:       h = GTK_ALIGN_END;    v = GTK_ALIGN_CENTER
    case .bottomLeading:  h = GTK_ALIGN_START;  v = GTK_ALIGN_END
    case .bottom:         h = GTK_ALIGN_CENTER; v = GTK_ALIGN_END
    case .bottomTrailing: h = GTK_ALIGN_END;    v = GTK_ALIGN_END
    }
    return (h, v)
}

// MARK: - Toggle GTK extension

extension Toggle: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let toggleStyleType = getCurrentEnvironment().toggleStyle

        if toggleStyleType == .switch {
            return gtkCreateSwitchWidget()
        }
        // .automatic and .checkbox use GtkCheckButton
        return gtkCreateCheckButtonWidget()
    }

    private func gtkCreateCheckButtonWidget() -> OpaquePointer {
        let check = label.isEmpty
            ? gtk_check_button_new()!
            : gtk_check_button_new_with_label(label)!
        let checkPtr = checkButtonPointer(check)

        gtk_check_button_set_active(checkPtr, isOn.wrappedValue ? 1 : 0)

        let binding = isOn
        let box = Unmanaged.passRetained(BoolClosureBox { newValue in
            if newValue != binding.wrappedValue {
                binding.wrappedValue = newValue
            }
        }).toOpaque()
        g_signal_connect_data(
            gpointer(check),
            "toggled",
            unsafeBitCast({ (widget: gpointer?, userData: gpointer?) in
                let box = Unmanaged<BoolClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                let ptr = UnsafeMutableRawPointer(widget!).assumingMemoryBound(to: GtkCheckButton.self)
                let active = gtk_check_button_get_active(ptr) != 0
                box.closure(active)
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<BoolClosureBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        gtkApplyEnabledState(to: check)
        return opaqueFromWidget(check)
    }

    private func gtkCreateSwitchWidget() -> OpaquePointer {
        let sw = gtk_swift_switch_new()!
        gtk_swift_switch_set_active(sw, isOn.wrappedValue ? 1 : 0)

        let binding = isOn
        let box = Unmanaged.passRetained(BoolClosureBox { newValue in
            if newValue != binding.wrappedValue {
                binding.wrappedValue = newValue
            }
        }).toOpaque()
        g_signal_connect_data(
            gpointer(sw),
            "notify::active",
            unsafeBitCast({ (widget: gpointer?, _: gpointer?, userData: gpointer?) in
                let box = Unmanaged<BoolClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                let w = UnsafeMutableRawPointer(widget!).assumingMemoryBound(to: GtkWidget.self)
                let active = gtk_swift_switch_get_active(w) != 0
                box.closure(active)
            } as @convention(c) (gpointer?, gpointer?, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<BoolClosureBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        if label.isEmpty {
            gtkApplyEnabledState(to: sw)
            return opaqueFromWidget(sw)
        }

        // Wrap switch + label in a horizontal box.
        // Add a click gesture on the box so clicking the label toggles the switch.
        let hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
        let lbl = gtk_label_new(label)!
        gtk_box_append(boxPointer(hbox), lbl)
        gtk_box_append(boxPointer(hbox), sw)

        // Add click gesture on the label (not the box) so clicking the label
        // toggles the switch. Attaching to the box would double-toggle when
        // the click lands directly on the GtkSwitch.
        let gesture = gtk_gesture_click_new()!
        let toggleBox = Unmanaged.passRetained(ClosureBox {
            let active = gtk_swift_switch_get_active(sw) != 0
            gtk_swift_switch_set_active(sw, active ? 0 : 1)
        }).toOpaque()
        g_signal_connect_data(
            gpointer(gesture),
            "released",
            unsafeBitCast({ (_: gpointer?, _: gint, _: Double, _: Double, userData: gpointer?) in
                guard let userData = userData else { return }
                Unmanaged<ClosureBox>.fromOpaque(userData).takeUnretainedValue().closure()
            } as @convention(c) (gpointer?, gint, Double, Double, gpointer?) -> Void, to: GCallback.self),
            toggleBox,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<ClosureBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )
        gtk_swift_add_gesture(lbl, gesture)

        // Apply enabled state to the whole wrapper so label dims too
        gtkApplyEnabledState(to: hbox)
        return opaqueFromWidget(hbox)
    }
}

// MARK: - Slider GTK extension

/// Debounced slider state. Accumulates value changes and commits after
/// a short delay so dragging doesn't trigger constant rebuilds.
/// Also manages interactive update deferral: suppresses host rebuilds
/// during pointer drag, commits one rebuild on pointer release.
private class SliderState {
    let closure: (Double) -> Void
    weak var host: GTKViewHost?
    var pendingValue: Double = 0
    var timerSource: guint = 0
    var dragging = false

    init(closure: @escaping (Double) -> Void) {
        self.closure = closure
    }

    func scheduleCommit(_ value: Double) {
        pendingValue = value
        if timerSource != 0 {
            g_source_remove(timerSource)
            timerSource = 0
        }
        let ptr = Unmanaged.passRetained(self).toOpaque()
        timerSource = g_timeout_add_full(
            G_PRIORITY_DEFAULT_IDLE,
            150,
            { userData -> gboolean in
                let state = Unmanaged<SliderState>.fromOpaque(userData!).takeUnretainedValue()
                state.timerSource = 0
                state.closure(state.pendingValue)
                return 0 // G_SOURCE_REMOVE
            },
            ptr,
            { userData in
                Unmanaged<SliderState>.fromOpaque(userData!).release()
            }
        )
    }
}

extension Slider: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(
            kind: .slider, typeName: "Slider",
            props: .slider(GTK4SliderDescriptor(
                value: value.wrappedValue, range: range, step: step)))
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let scale = gtk_scale_new_with_range(
            GTK_ORIENTATION_HORIZONTAL,
            range.lowerBound,
            range.upperBound,
            step
        )!

        gtk_widget_set_hexpand(scale, 1)
        gtk_range_set_value(rangePointer(scale), value.wrappedValue)
        gtkMarkHostedNodeKind(scale, kind: .slider)

        let binding = value
        let stepVal = step
        let state = SliderState { newValue in
            if abs(newValue - binding.wrappedValue) > stepVal * 0.01 {
                binding.wrappedValue = newValue
            }
        }
        state.host = GTKViewHost.getCurrentRebuilding()
        let statePtr = Unmanaged.passRetained(state).toOpaque()

        // Value-changed: debounced binding update
        g_signal_connect_data(
            gpointer(scale),
            "value-changed",
            unsafeBitCast({ (widget: gpointer?, userData: gpointer?) in
                let state = Unmanaged<SliderState>.fromOpaque(userData!).takeUnretainedValue()
                let rng = UnsafeMutableRawPointer(widget!).assumingMemoryBound(to: GtkRange.self)
                state.scheduleCommit(gtk_range_get_value(rng))
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            statePtr,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<SliderState>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        // Note: interactive deferral (beginInteractiveUpdate/endInteractiveUpdate)
        // removed — GtkGestureClick's "released" doesn't fire when the slider
        // drag starts (GTK cancels the click gesture). This left
        // interactiveUpdateDepth stuck > 0, blocking all future rebuilds.
        // The debounced commit (150ms) already prevents constant rebuilds.

        gtkApplyEnabledState(to: scale)
        return opaqueFromWidget(scale)
    }
}

// MARK: - ScrollView GTK extension

extension ScrollView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        // Transparent wrapper: describe content so child Canvas nodes
        // participate in the narrow mutation path.
        let childDescriptor = gtkDescribeView(content)
        return GTK4DescriptorNode(
            kind: .composite,
            typeName: "ScrollView",
            children: [childDescriptor]
        )
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let scrolled = gtk_scrolled_window_new()!
        let scrolledOp = OpaquePointer(scrolled)

        let hPolicy: GtkPolicyType = axes.contains(.horizontal) ? GTK_POLICY_AUTOMATIC : GTK_POLICY_NEVER
        let vPolicy: GtkPolicyType = axes.contains(.vertical) ? GTK_POLICY_AUTOMATIC : GTK_POLICY_NEVER
        gtk_scrolled_window_set_policy(scrolledOp, hPolicy, vPolicy)

        // Prevent GTK from allocating the child's full natural size
        // in the scroll direction — otherwise scrolling never activates.
        if axes.contains(.horizontal) {
            gtk_scrolled_window_set_propagate_natural_width(scrolledOp, 0)
        }
        if axes.contains(.vertical) {
            gtk_scrolled_window_set_propagate_natural_height(scrolledOp, 0)
        }

        let child = widgetFromOpaque(gtkRenderView(content))
        if axes.contains(.vertical) {
            gtk_widget_set_vexpand(child, 0)
        }
        if axes.contains(.horizontal) {
            gtk_widget_set_hexpand(child, 0)
        }
        gtk_scrolled_window_set_child(scrolledOp, child)

        gtk_widget_set_vexpand(scrolled, 1)
        gtk_widget_set_hexpand(scrolled, 1)

        return opaqueFromWidget(scrolled)
    }
}

// MARK: - Image GTK extension

extension Image: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        switch source {
        case .systemName(let sfName):
            // M-Symbols-3: route Image(systemName:) through the curated
            // SF→Material compatibility map. Mapped names render the
            // corresponding Material glyph (uniform across all GTK4
            // themes/distros); unmapped names render the "missing icon"
            // placeholder glyph so the gap is visible rather than silent.
            //
            // This replaces the previous `gtk_image_new_from_icon_name`
            // path. Any app that was passing a freedesktop-style icon
            // name (e.g. "folder-new-symbolic") — not SwiftUI-canonical —
            // will now see the placeholder; it should switch to a real
            // SF name or use `Image(material:)` for direct Material
            // names.
            let materialName = SFSymbolCompatibility.materialName(for: sfName)
                ?? SFSymbolCompatibility.missingSymbolPlaceholderName
            #if DEBUG
            if SFSymbolCompatibility.materialName(for: sfName) == nil {
                FileHandle.standardError.write(Data(
                    "[SwiftOpenUI] Image(systemName: \"\(sfName)\") has no Material mapping; rendering placeholder\n".utf8
                ))
            }
            #endif
            return opaqueFromWidget(gtkRenderMaterialSymbolLabel(materialName, scale: scale))

        case .filePath(let path):
            // Use GtkPicture (GTK4's scalable image widget) rather than
            // GtkImage (fixed-size icon widget).  GtkPicture honors its
            // parent's allocation and scales the loaded pixbuf accordingly,
            // which matches SwiftUI's `.resizable()` semantics.
            let picture = gtk_swift_picture_new_for_filename(path)!
            if isResizable {
                // Stretch to fill the surrounding frame.  GTK_CONTENT_FIT_FILL
                // disables aspect-ratio preservation to match SwiftUI.
                gtk_swift_picture_set_content_fit(picture, GTK_CONTENT_FIT_FILL)
                gtk_swift_picture_set_can_shrink(picture, 1)
                gtk_widget_set_hexpand(picture, 1)
                gtk_widget_set_vexpand(picture, 1)
                gtk_widget_set_halign(picture, GTK_ALIGN_FILL)
                gtk_widget_set_valign(picture, GTK_ALIGN_FILL)
            } else {
                // Natural size: GtkPicture reports the pixbuf's intrinsic
                // dimensions as its natural size.  Surrounding frames
                // position but do not scale the image.
                gtk_swift_picture_set_content_fit(picture, GTK_CONTENT_FIT_CONTAIN)
                gtk_swift_picture_set_can_shrink(picture, 0)
            }
            return opaqueFromWidget(picture)

        case .materialSymbol(let name):
            return opaqueFromWidget(gtkRenderMaterialSymbolLabel(name, scale: scale))
        }
    }
}

/// Render a Material Symbols glyph as a GtkLabel via Pango markup.
/// Shared helper used by both `.materialSymbol` and `.systemName` (the
/// latter via the SF→Material compatibility map). The Material Symbols
/// Rounded family is registered process-locally at backend startup by
/// `gtkRegisterBundledIconFont()`; OpenType ligatures in the font
/// substitute the literal name ("search", "folder_open", ...) into the
/// icon glyph during text shaping.
///
/// Pango's font_size attribute uses thousandths of a point, hence
/// `scale.pointSize * 1000`. The widget is clamped to a point-size box
/// for consistency with the other `gtk_image`-based Image cases.
private func gtkRenderMaterialSymbolLabel(
    _ name: String,
    scale: ImageScale
) -> UnsafeMutablePointer<GtkWidget> {
    let label = gtk_label_new(nil)!
    let familyName = gtkEscapeMarkup(MaterialSymbolsRoundedFamilyName)
    let escapedName = gtkEscapeMarkup(name)
    let markup = """
        <span font_family="\(familyName)" font_size="\(scale.pointSize * 1000)">\(escapedName)</span>
        """
    gtk_swift_label_set_markup(label, markup)
    let px = gint(scale.pointSize)
    gtk_widget_set_size_request(label, px, px)
    return label
}

/// Material Symbols Rounded font family name, resolved via SwiftOpenUISymbols.
/// Used by the .materialSymbol Image renderer. Kept as a file-scope constant
/// to keep the Pango markup construction tight.
private let MaterialSymbolsRoundedFamilyName: String =
    MaterialSymbolsResources.roundedRegularFamilyName

/// Minimal Pango-markup-safe escape. Pango's markup parser treats these
/// characters specially; escape the four that show up in user-supplied icon
/// names or family strings. Not a general-purpose XML escape; sufficient
/// for internal use where the inputs are known to be icon tokens like
/// "folder_open".
private func gtkEscapeMarkup(_ s: String) -> String {
    var out = ""
    out.reserveCapacity(s.count)
    for ch in s {
        switch ch {
        case "&": out += "&amp;"
        case "<": out += "&lt;"
        case ">": out += "&gt;"
        case "\"": out += "&quot;"
        default: out.append(ch)
        }
    }
    return out
}

// MARK: - List GTK extension

/// Track which GdkDisplays have had list CSS installed.
private var listCSSDisplays: Set<ObjectIdentifier> = []

private func ensureListCSS(_ widget: UnsafeMutablePointer<GtkWidget>) {
    let display = gtk_widget_get_display(widget)!
    let displayId = ObjectIdentifier(display as AnyObject)
    guard !listCSSDisplays.contains(displayId) else { return }
    listCSSDisplays.insert(displayId)

    let provider = gtk_css_provider_new()!
    let css = """
        .swiftopenui-list { background: @view_bg_color; border-radius: 10px; padding: 0; }
        .swiftopenui-list row { border-bottom: 1px solid alpha(currentColor, 0.18); padding: 8px 16px; }
        .swiftopenui-list row:last-child { border-bottom: none; }
        """
    gtk_css_provider_load_from_string(provider, css)
    gtk_swift_add_css_provider_to_display(
        display,
        provider,
        UInt32(GTK_STYLE_PROVIDER_PRIORITY_USER)
    )
    g_object_unref(gpointer(provider))
}

extension List: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let listBox = gtk_list_box_new()!
        let listBoxOp = OpaquePointer(listBox)
        gtk_widget_set_hexpand(listBox, 1)
        gtk_list_box_set_selection_mode(listBoxOp, GTK_SELECTION_NONE)

        ensureListCSS(listBox)
        gtk_widget_add_css_class(listBox, "swiftopenui-list")

        for child in gtkRenderChildren(content) {
            let widget = widgetFromOpaque(child)
            gtk_widget_set_hexpand(widget, 1)
            gtk_widget_set_halign(widget, GTK_ALIGN_FILL)
            let row = gtk_list_box_row_new()!
            gtk_list_box_row_set_child(
                UnsafeMutableRawPointer(row).assumingMemoryBound(to: GtkListBoxRow.self),
                widget
            )
            gtk_list_box_append(listBoxOp, row)
        }

        // Wrap in scrolled window
        let scrolled = gtk_scrolled_window_new()!
        let scrolledOp = OpaquePointer(scrolled)
        gtk_scrolled_window_set_policy(scrolledOp, GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_set_propagate_natural_width(scrolledOp, 1)
        // Mirror ScrollView: don't let the child listbox's full natural
        // height dictate the scroll's natural size. Otherwise a List
        // inside a VStack reports "I need N×row-height" as natural, and
        // the VStack's allocation pass leaves too little slack — trailing
        // siblings (status bars, footers) swallow the remainder.
        gtk_scrolled_window_set_propagate_natural_height(scrolledOp, 0)
        gtk_scrolled_window_set_child(scrolledOp, listBox)
        gtk_widget_set_vexpand(scrolled, 1)
        gtk_widget_set_hexpand(scrolled, 1)

        return opaqueFromWidget(scrolled)
    }
}

extension EnvironmentObjectModifierView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        var env = getCurrentEnvironment()
        env.setObject(object)
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(env)
        let widget = gtkRenderView(content)
        setCurrentEnvironment(prev)
        return widget
    }
}

extension EnvironmentObservableModifierView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        var env = getCurrentEnvironment()
        env.setObject(object)
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(env)
        let widget = gtkRenderView(content)
        setCurrentEnvironment(prev)
        return widget
    }
}

extension EnvironmentModifierView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        var env = getCurrentEnvironment()
        env[keyPath: keyPath] = value
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(env)
        let widget = gtkRenderView(content)
        setCurrentEnvironment(prev)
        return widget
    }
}

extension DisabledView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(
            kind: .disabled, typeName: "DisabledView",
            props: .disabled(GTK4DisabledDescriptor(isDisabled: isDisabled)),
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        var env = getCurrentEnvironment()
        // Ancestor composition: parent disabled(true) cannot be undone by child disabled(false)
        let effectiveIsEnabled = env.isEnabled && !isDisabled
        env.isEnabled = effectiveIsEnabled
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(env)
        let widget = gtkRenderView(content)
        setCurrentEnvironment(prev)
        return widget
    }
}

/// Apply GTK sensitivity from the current environment's isEnabled state.
private func gtkApplyEnabledState(to widget: UnsafeMutablePointer<GtkWidget>) {
    let env = getCurrentEnvironment()
    if !env.isEnabled {
        gtk_widget_set_sensitive(widget, 0)
    }
}

extension _ViewModifierContent: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        gtkRenderAnyView(wrapped.wrapped)
    }
}

// MARK: - TupleView GTK extensions

extension TupleView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        for child in children {
            let widget = gtkRenderAnyView(child)
            gtk_box_append(boxPointer(box), widgetFromOpaque(widget))
        }
        return opaqueFromWidget(box)
    }
}

// MARK: - TabView GTK extension

// Note: `Tab<Content>` intentionally has no `GTKRenderable` conformance.
// `TabBuilder` wraps every `Tab` into `AnyTab` at construction time, so
// `TabView` iterates `[AnyTab]` and renders each `tab.wrapped` directly.
// This matches the Win32 backend, which also does not render bare `Tab`.

extension TabView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let stack = gtk_stack_new()!
        gtk_swift_stack_set_transition_type(stack, GTK_STACK_TRANSITION_TYPE_SLIDE_LEFT_RIGHT)

        var usedIds = Set<String>()
        var orderedIds: [String] = []
        for tab in tabs {
            var id = tab.id
            if usedIds.contains(id) {
                var suffix = 2
                while usedIds.contains("\(id)-\(suffix)") { suffix += 1 }
                id = "\(id)-\(suffix)"
            }
            usedIds.insert(id)
            orderedIds.append(id)
            let childWidget = widgetFromOpaque(gtkRenderAnyView(tab.wrapped))
            gtk_swift_stack_add_titled(stack, childWidget, id, tab.title)
        }

        if let tabIndex = initialTab, tabIndex >= 0, tabIndex < orderedIds.count {
            gtk_swift_stack_set_visible_child_name(stack, orderedIds[tabIndex])
        }

        let switcher = gtk_stack_switcher_new()!
        gtk_swift_stack_switcher_set_stack(switcher, stack)

        let vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_box_append(boxPointer(vbox), switcher)
        gtk_box_append(boxPointer(vbox), stack)
        gtk_widget_set_vexpand(stack, 1)

        return opaqueFromWidget(vbox)
    }
}

// MARK: - Grid GTK extension

extension Grid: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        if useExplicitRows {
            let rows = gtkCollectGridRows(content)
            if gtkCanUseSharedExplicitGridLayout(rows) {
                return gtkRenderSharedExplicitGrid(
                    rows,
                    hSpacing: hSpacing,
                    vSpacing: vSpacing
                )
            }
        } else {
            let children = gtkRenderChildren(content).map(widgetFromOpaque)
            if gtkCanUseSharedGridLayout(children) {
                return gtkRenderSharedAutoGrid(
                    children,
                    columns: columns,
                    hSpacing: hSpacing,
                    vSpacing: vSpacing
                )
            }
        }

        let grid = gtk_grid_new()!
        gtk_swift_grid_set_row_spacing(grid, guint(vSpacing))
        gtk_swift_grid_set_column_spacing(grid, guint(hSpacing))
        gtk_swift_grid_set_column_homogeneous(grid, 1)

        if useExplicitRows {
            gtkLayoutExplicitRows(grid: grid)
            gtk_widget_set_hexpand(grid, 1)
        } else {
            let children = gtkRenderChildren(content)
            for (index, child) in children.enumerated() {
                let row = index / columns
                let col = index % columns
                gtk_swift_grid_attach(grid, widgetFromOpaque(child), gint(col), gint(row), 1, 1)
            }
        }

        return opaqueFromWidget(grid)
    }

    private func gtkLayoutExplicitRows(grid: UnsafeMutablePointer<GtkWidget>) {
        let rowViews = gtkCollectGridRows(content)
        var row = 0
        for rowContent in rowViews {
            var col = 0
            for cell in rowContent {
                let widget = widgetFromOpaque(cell.widget)
                gtk_widget_set_hexpand(widget, 1)
                gtk_widget_set_vexpand(widget, 1)
                gtk_widget_set_halign(widget, GTK_ALIGN_FILL)
                gtk_widget_set_valign(widget, GTK_ALIGN_FILL)
                gtk_swift_grid_attach(grid, widget, gint(col), gint(row), gint(cell.columnSpan), 1)
                col += cell.columnSpan
            }
            row += 1
        }
    }
}

private func gtkCanUseSharedGridLayout(_ children: [UnsafeMutablePointer<GtkWidget>]) -> Bool {
    for widget in children {
        let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
        if g_object_get_data(gobject, gtkSwiftSpacerMarker) != nil {
            return false
        }
        if gtk_widget_get_hexpand(widget) != 0 || gtk_widget_get_vexpand(widget) != 0 {
            return false
        }
    }
    return true
}

private func gtkRenderSharedAutoGrid(
    _ children: [UnsafeMutablePointer<GtkWidget>],
    columns: Int,
    hSpacing: Int,
    vSpacing: Int
) -> OpaquePointer {
    let wrapper = gtk_swift_fixed_new()!
    let subviews = children.indices.map(LayoutSubview.init(index:))
    let context = GTKLayoutMeasureContext(widgets: children)
    let layout = computeGridLayout(
        subviews: subviews,
        context: context,
        columns: columns,
        hSpacing: Double(hSpacing),
        vSpacing: Double(vSpacing)
    )

    gtk_widget_set_size_request(
        wrapper,
        gint(layout.containerSize.width),
        gint(layout.containerSize.height)
    )

    for (widget, placement) in zip(children, layout.childPlacements) {
        gtk_widget_set_halign(widget, GTK_ALIGN_START)
        gtk_widget_set_valign(widget, GTK_ALIGN_START)
        gtk_swift_fixed_put(wrapper, widget, placement.origin.x, placement.origin.y)
    }

    return opaqueFromWidget(wrapper)
}

private func gtkCanUseSharedExplicitGridLayout(_ rows: [[GTKGridCell]]) -> Bool {
    for row in rows {
        for cell in row {
            let widget = widgetFromOpaque(cell.widget)
            let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
            if g_object_get_data(gobject, gtkSwiftSpacerMarker) != nil {
                return false
            }
            if gtk_widget_get_hexpand(widget) != 0 || gtk_widget_get_vexpand(widget) != 0 {
                return false
            }
        }
    }
    return true
}

private func gtkRenderSharedExplicitGrid(
    _ rows: [[GTKGridCell]],
    hSpacing: Int,
    vSpacing: Int
) -> OpaquePointer {
    let wrapper = gtk_swift_fixed_new()!
    let flattenedCells = rows.flatMap { $0 }
    let widgets = flattenedCells.map { widgetFromOpaque($0.widget) }
    let context = GTKLayoutMeasureContext(widgets: widgets)
    var subviewIndex = 0
    let layout = computeExplicitGridLayout(
        rows: rows.map { row in
            row.map { cell in
                let subview = LayoutSubview(index: subviewIndex)
                subviewIndex += 1
                return (
                    subview: subview,
                    columnSpan: cell.columnSpan
                )
            }
        },
        context: context,
        hSpacing: Double(hSpacing),
        vSpacing: Double(vSpacing)
    )

    gtk_widget_set_size_request(
        wrapper,
        gint(layout.containerSize.width),
        gint(layout.containerSize.height)
    )

    for (cell, placement) in zip(flattenedCells, layout.childPlacements) {
        let widget = widgetFromOpaque(cell.widget)
        gtk_widget_set_halign(widget, GTK_ALIGN_START)
        gtk_widget_set_valign(widget, GTK_ALIGN_START)
        gtk_widget_set_size_request(
            widget,
            gint(placement.size.width),
            gint(placement.size.height)
        )
        gtk_swift_fixed_put(wrapper, widget, placement.origin.x, placement.origin.y)
    }

    return opaqueFromWidget(wrapper)
}

/// Grid cell info for layout.
private struct GTKGridCell {
    let widget: OpaquePointer
    let columnSpan: Int
}

/// Flatten a view into its top-level child views using the MultiChildView
/// contract.  Stops at GridRow boundaries — GridRow is a row delimiter,
/// not a transparent container, so its children must stay grouped.
private func gtkFlattenChildren(_ view: any View) -> [any View] {
    // GridRow is a MultiChildView but must NOT be flattened — it's a
    // semantic boundary that gtkExtractRowCells needs to see intact.
    let typeName = String(describing: type(of: view))
    if typeName.contains("GridRow") {
        return [view]
    }
    if let multi = view as? MultiChildView {
        return multi.children.flatMap { gtkFlattenChildren($0) }
    }
    return [view]
}

/// Walk the content view tree and extract GridRow children with their cell spans.
private func gtkCollectGridRows<V: View>(_ view: V) -> [[GTKGridCell]] {
    let topLevel = gtkFlattenChildren(view)
    var rows: [[GTKGridCell]] = []

    for child in topLevel {
        if let rowCells = gtkExtractRowCells(child) {
            rows.append(rowCells)
        } else {
            func render<C: View>(_ c: C) -> OpaquePointer { gtkRenderView(c) }
            rows.append([GTKGridCell(widget: render(child), columnSpan: 1)])
        }
    }

    if rows.isEmpty {
        rows.append([GTKGridCell(widget: gtkRenderView(view), columnSpan: 1)])
    }

    return rows
}

/// Try to extract cells from a GridRow view.
private func gtkExtractRowCells(_ view: any View) -> [GTKGridCell]? {
    let typeName = String(describing: type(of: view))
    guard typeName.contains("GridRow") else { return nil }

    // GridRow conforms to MultiChildView — use its children for cell extraction
    if let multi = view as? MultiChildView {
        return multi.children.map { child in
            gtkMakeCell(from: child)
        }
    }

    // Fallback: render as single cell
    func render<V: View>(_ v: V) -> OpaquePointer { gtkRenderView(v) }
    return [GTKGridCell(widget: render(view), columnSpan: 1)]
}

/// Create a GTKGridCell from a view, checking for GridCellSpanProvider.
private func gtkMakeCell(from view: any View) -> GTKGridCell {
    let span = gtkFindColumnSpan(in: view)
    return GTKGridCell(widget: gtkRenderAnyView(view), columnSpan: span)
}

/// Recursively walk through modifier wrappers to find a GridCellSpanProvider.
private func gtkFindColumnSpan(in view: Any) -> Int {
    if let spanProvider = view as? GridCellSpanProvider {
        return spanProvider.gridColumnSpan
    }
    let mirror = Mirror(reflecting: view)
    for child in mirror.children {
        if child.label == "content" {
            let innerSpan = gtkFindColumnSpan(in: child.value)
            if innerSpan > 1 { return innerSpan }
        }
    }
    return 1
}

extension GridRow: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        // Fallback if used outside Grid — wrap in HStack
        let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        for child in gtkRenderChildren(content) {
            gtk_box_append(boxPointer(box), widgetFromOpaque(child))
        }
        return opaqueFromWidget(box)
    }
}

extension GridCellSpanView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        gtkRenderView(content)
    }
}

// MARK: - DisclosureGroup GTK extension

/// Closure box for expander state change.
private class ExpandedClosureBox {
    let closure: (Bool) -> Void
    init(_ closure: @escaping (Bool) -> Void) { self.closure = closure }
}

extension DisclosureGroup: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let expander: UnsafeMutablePointer<GtkWidget>
        if let labelView = labelView {
            // Custom label view — create expander without title and set
            // a custom label widget instead.
            expander = gtk_swift_expander_new("")!
            let labelWidget = widgetFromOpaque(gtkRenderView(labelView))
            gtk_swift_expander_set_label_widget(expander, labelWidget)
        } else {
            expander = gtk_swift_expander_new(title)!
        }
        gtk_swift_expander_set_expanded(expander, isExpanded ? 1 : 0)

        let childWidget = widgetFromOpaque(gtkRenderView(content))
        gtk_widget_set_margin_start(childWidget, 16)
        gtk_swift_expander_set_child(expander, childWidget)

        if let onChange = onExpandedChange {
            let boundOnChange = bindActionToCurrentEnvironment(onChange)
            let box = Unmanaged.passRetained(ExpandedClosureBox(boundOnChange)).toOpaque()
            g_signal_connect_data(
                gpointer(expander),
                "notify::expanded",
                unsafeBitCast({ (expanderPtr: gpointer?, _: gpointer?, userData: gpointer?) in
                    guard let expanderPtr = expanderPtr, let userData = userData else { return }
                    let widget = UnsafeMutableRawPointer(expanderPtr).assumingMemoryBound(to: GtkWidget.self)
                    let box = Unmanaged<ExpandedClosureBox>.fromOpaque(userData).takeUnretainedValue()
                    let expanded = gtk_swift_expander_get_expanded(widget) != 0
                    box.closure(expanded)
                } as @convention(c) (gpointer?, gpointer?, gpointer?) -> Void, to: GCallback.self),
                box,
                { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    Unmanaged<ExpandedClosureBox>.fromOpaque(userData!).release()
                },
                GConnectFlags(rawValue: 0)
            )
        }

        return opaqueFromWidget(expander)
    }
}

// MARK: - Form GTK extension

extension Form: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12)!
        let boxPtr = boxPointer(box)

        for child in gtkRenderChildren(content) {
            gtk_box_append(boxPtr, widgetFromOpaque(child))
        }

        gtk_widget_set_hexpand(box, 1)
        gtk_widget_set_vexpand(box, 1)
        applyCSSToWidget(box, properties: "padding: 16px;")

        return opaqueFromWidget(box)
    }
}

// MARK: - Section GTK extension

extension Section: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4)!
        let boxPtr = boxPointer(box)

        if let header = header {
            let label = gtk_label_new(nil)!
            let escaped = header
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            gtk_swift_label_set_markup(label, "<b>\(escaped)</b>")
            gtk_widget_set_halign(label, GTK_ALIGN_START)
            gtk_box_append(boxPtr, label)
        }

        let contentWidget = widgetFromOpaque(gtkRenderView(content))
        gtk_box_append(boxPtr, contentWidget)

        if let footer = footer {
            let label = gtk_label_new(footer)!
            gtk_widget_set_halign(label, GTK_ALIGN_START)
            applyCSSToWidget(label, properties: "font-size: 11px; opacity: 0.6;")
            gtk_box_append(boxPtr, label)
        }

        let sep = gtk_separator_new(GTK_ORIENTATION_HORIZONTAL)!
        gtk_box_append(boxPtr, sep)

        return opaqueFromWidget(box)
    }
}

// MARK: - LazyVStack / LazyHStack GTK extensions

/// Context holding item count and render closure for factory callbacks.
private class LazyListContext {
    let itemCount: Int
    let renderItem: (Int) -> UnsafeMutablePointer<GtkWidget>

    init<Data, Content: View>(items: [Data], contentBuilder: @escaping (Data) -> Content) {
        self.itemCount = items.count
        self.renderItem = { index in
            widgetFromOpaque(gtkRenderView(contentBuilder(items[index])))
        }
    }
}

/// Create a GtkListView-based lazy list widget.
private func gtkCreateLazyListWidget<Data, Content: View>(
    items: [Data],
    contentBuilder: @escaping (Data) -> Content,
    orientation: GtkOrientation
) -> OpaquePointer {
    let stringList = gtk_swift_string_list_new()!
    for i in 0..<items.count {
        gtk_swift_string_list_append(stringList, "\(i)")
    }

    let noSelection = gtk_swift_no_selection_new(stringList)
    let factory = gtk_swift_signal_list_item_factory_new()!

    let context = LazyListContext(items: items, contentBuilder: contentBuilder)
    let contextPtr = Unmanaged.passRetained(context).toOpaque()
    g_object_set_data_full(
        factory.assumingMemoryBound(to: GObject.self),
        "gtk-swift-lazy-context",
        contextPtr,
        { userData in Unmanaged<LazyListContext>.fromOpaque(userData!).release() }
    )

    g_signal_connect_data(factory, "setup",
        unsafeBitCast(lazyListSetupCallback, to: GCallback.self),
        nil, nil, GConnectFlags(rawValue: 0))
    g_signal_connect_data(factory, "bind",
        unsafeBitCast(lazyListBindCallback, to: GCallback.self),
        nil, nil, GConnectFlags(rawValue: 0))
    g_signal_connect_data(factory, "unbind",
        unsafeBitCast(lazyListUnbindCallback, to: GCallback.self),
        nil, nil, GConnectFlags(rawValue: 0))

    let listView = gtk_swift_list_view_new(noSelection, factory)!
    gtk_swift_orientable_set_orientation(listView, orientation)

    // Transparent background so parent shows through
    applyCSSToWidget(listView, properties: "background-color: transparent;")
    let rowCSS = "listview.gtk-swift-lazy-transparent row { background-color: transparent; }"
    let rowProvider = gtk_css_provider_new()!
    gtk_css_provider_load_from_string(rowProvider, rowCSS)
    gtk_swift_add_css_provider_to_display(
        gtk_widget_get_display(listView),
        rowProvider,
        UInt32(GTK_STYLE_PROVIDER_PRIORITY_USER)
    )
    g_object_unref(gpointer(rowProvider))
    gtk_widget_add_css_class(listView, "gtk-swift-lazy-transparent")

    // Wrap in scrolled window
    let scrolled = gtk_scrolled_window_new()!
    gtk_scrolled_window_set_policy(OpaquePointer(scrolled),
        GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC)
    gtk_scrolled_window_set_child(OpaquePointer(scrolled), listView)
    gtk_widget_set_vexpand(scrolled, 1)
    gtk_widget_set_hexpand(scrolled, 1)
    applyCSSToWidget(scrolled, properties: "background-color: transparent;")

    return opaqueFromWidget(scrolled)
}

// Factory callbacks for lazy lists

private let lazyListSetupCallback: @convention(c) (
    gpointer?, gpointer?, gpointer?
) -> Void = { factory, listItem, userData in
    guard let listItem = listItem else { return }
    let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    gtk_widget_set_hexpand(box, 1)
    gtk_swift_list_item_set_child(listItem, box)
}

private let lazyListBindCallback: @convention(c) (
    gpointer?, gpointer?, gpointer?
) -> Void = { factoryPtr, listItem, userData in
    guard let factoryPtr = factoryPtr, let listItem = listItem else { return }

    guard let gobject = gtk_swift_list_item_get_item(listItem) else { return }
    guard let cStr = gtk_swift_string_object_get_string(gobject) else { return }
    guard let index = Int(String(cString: cStr)) else {
        lazyListClearChild(listItem)
        return
    }

    guard let contextPtr = g_object_get_data(
        factoryPtr.assumingMemoryBound(to: GObject.self),
        "gtk-swift-lazy-context"
    ) else { return }
    let context = Unmanaged<LazyListContext>.fromOpaque(contextPtr).takeUnretainedValue()

    guard index >= 0 && index < context.itemCount else {
        lazyListClearChild(listItem)
        return
    }

    guard let box = gtk_swift_list_item_get_child(listItem) else { return }
    while let child = gtk_widget_get_first_child(box) {
        gtk_box_remove(boxPointer(box), child)
    }
    gtk_box_append(boxPointer(box), context.renderItem(index))
}

private let lazyListUnbindCallback: @convention(c) (
    gpointer?, gpointer?, gpointer?
) -> Void = { factory, listItem, userData in
    guard let listItem = listItem else { return }
    lazyListClearChild(listItem)
}

private func lazyListClearChild(_ listItem: gpointer) {
    guard let box = gtk_swift_list_item_get_child(listItem) else { return }
    while let child = gtk_widget_get_first_child(box) {
        gtk_box_remove(boxPointer(box), child)
    }
}

extension LazyVStack: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        gtkCreateLazyListWidget(items: items, contentBuilder: contentBuilder,
                                orientation: GTK_ORIENTATION_VERTICAL)
    }
}

extension LazyHStack: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        gtkCreateLazyListWidget(items: items, contentBuilder: contentBuilder,
                                orientation: GTK_ORIENTATION_HORIZONTAL)
    }
}

// MARK: - LazyVGrid / LazyHGrid GTK extensions

/// Context for lazy grid factory callbacks.
private class LazyGridContext {
    let itemCount: Int
    let renderItem: (Int) -> UnsafeMutablePointer<GtkWidget>
    let cellMinWidth: Int

    init<Data, Content: View>(items: [Data], contentBuilder: @escaping (Data) -> Content,
                              cellMinWidth: Int) {
        self.itemCount = items.count
        self.cellMinWidth = cellMinWidth
        self.renderItem = { index in
            widgetFromOpaque(gtkRenderView(contentBuilder(items[index])))
        }
    }
}

/// Create a GtkGridView-based lazy grid widget.
private func gtkCreateLazyGridWidget<Data, Content: View>(
    items: [Data],
    contentBuilder: @escaping (Data) -> Content,
    gridItems: [GridItem],
    orientation: GtkOrientation
) -> OpaquePointer {
    let stringList = gtk_swift_string_list_new()!
    for i in 0..<items.count {
        gtk_swift_string_list_append(stringList, "\(i)")
    }

    let noSelection = gtk_swift_no_selection_new(stringList)
    let factory = gtk_swift_signal_list_item_factory_new()!

    let configuration = computeLazyGridConfiguration(gridItems: gridItems)
    let cellMinWidth = configuration.adaptiveMinimum
    let context = LazyGridContext(items: items, contentBuilder: contentBuilder,
                                  cellMinWidth: cellMinWidth)
    let contextPtr = Unmanaged.passRetained(context).toOpaque()
    g_object_set_data_full(
        factory.assumingMemoryBound(to: GObject.self),
        "gtk-swift-lazy-grid-context",
        contextPtr,
        { userData in Unmanaged<LazyGridContext>.fromOpaque(userData!).release() }
    )

    g_signal_connect_data(factory, "setup",
        unsafeBitCast(lazyGridSetupCallback, to: GCallback.self),
        nil, nil, GConnectFlags(rawValue: 0))
    g_signal_connect_data(factory, "bind",
        unsafeBitCast(lazyGridBindCallback, to: GCallback.self),
        nil, nil, GConnectFlags(rawValue: 0))
    g_signal_connect_data(factory, "unbind",
        unsafeBitCast(lazyGridUnbindCallback, to: GCallback.self),
        nil, nil, GConnectFlags(rawValue: 0))

    let gridView = gtk_swift_grid_view_new(noSelection, factory)!
    gtk_swift_orientable_set_orientation(gridView, orientation)

    gtk_swift_grid_view_set_min_columns(gridView, guint(configuration.minColumns))
    gtk_swift_grid_view_set_max_columns(gridView, guint(configuration.maxColumns))

    gtk_widget_set_vexpand(gridView, 1)
    gtk_widget_set_hexpand(gridView, 1)

    return opaqueFromWidget(gridView)
}

// Factory callbacks for lazy grids

private let lazyGridSetupCallback: @convention(c) (
    gpointer?, gpointer?, gpointer?
) -> Void = { factoryPtr, listItem, userData in
    guard let listItem = listItem else { return }
    let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
    gtk_widget_set_hexpand(box, 1)

    if let factoryPtr = factoryPtr,
       let contextPtr = g_object_get_data(
           factoryPtr.assumingMemoryBound(to: GObject.self),
           "gtk-swift-lazy-grid-context") {
        let context = Unmanaged<LazyGridContext>.fromOpaque(contextPtr).takeUnretainedValue()
        if context.cellMinWidth > 0 {
            gtk_widget_set_size_request(box, gint(context.cellMinWidth), -1)
        }
    }

    gtk_swift_list_item_set_child(listItem, box)
}

private let lazyGridBindCallback: @convention(c) (
    gpointer?, gpointer?, gpointer?
) -> Void = { factoryPtr, listItem, userData in
    guard let factoryPtr = factoryPtr, let listItem = listItem else { return }

    guard let gobject = gtk_swift_list_item_get_item(listItem) else { return }
    guard let cStr = gtk_swift_string_object_get_string(gobject) else { return }
    guard let index = Int(String(cString: cStr)) else {
        lazyGridClearChild(listItem)
        return
    }

    guard let contextPtr = g_object_get_data(
        factoryPtr.assumingMemoryBound(to: GObject.self),
        "gtk-swift-lazy-grid-context"
    ) else { return }
    let context = Unmanaged<LazyGridContext>.fromOpaque(contextPtr).takeUnretainedValue()

    guard index >= 0 && index < context.itemCount else {
        lazyGridClearChild(listItem)
        return
    }

    guard let box = gtk_swift_list_item_get_child(listItem) else { return }
    while let child = gtk_widget_get_first_child(box) {
        gtk_box_remove(boxPointer(box), child)
    }
    gtk_box_append(boxPointer(box), context.renderItem(index))
}

private let lazyGridUnbindCallback: @convention(c) (
    gpointer?, gpointer?, gpointer?
) -> Void = { factory, listItem, userData in
    guard let listItem = listItem else { return }
    lazyGridClearChild(listItem)
}

private func lazyGridClearChild(_ listItem: gpointer) {
    guard let box = gtk_swift_list_item_get_child(listItem) else { return }
    while let child = gtk_widget_get_first_child(box) {
        gtk_box_remove(boxPointer(box), child)
    }
}

extension LazyVGrid: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        gtkCreateLazyGridWidget(items: items, contentBuilder: contentBuilder,
                                gridItems: gridItems, orientation: GTK_ORIENTATION_VERTICAL)
    }
}

extension LazyHGrid: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        gtkCreateLazyGridWidget(items: items, contentBuilder: contentBuilder,
                                gridItems: gridItems, orientation: GTK_ORIENTATION_HORIZONTAL)
    }
}

// MARK: - Picker GTK extension

/// Closure box for segmented picker toggle events.
private class SegmentClosureBox {
    let index: Int
    let closure: (Int) -> Void
    init(index: Int, closure: @escaping (Int) -> Void) {
        self.index = index
        self.closure = closure
    }
}

extension Picker: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget: OpaquePointer
        switch style {
        case .segmented, .palette:
            widget = gtkCreateSegmentedWidget()
        default:
            widget = gtkCreateDropdownWidget()
        }
        gtkApplyEnabledState(to: widgetFromOpaque(widget))
        return widget
    }

    /// True iff the caller wrapped us in `.labelsHidden()`. The
    /// env flag is set by `LabelsHiddenView`'s GTK renderer; when on,
    /// both the dropdown and segmented variants omit the label prefix
    /// they'd otherwise inline before the control.
    private var effectiveLabel: String {
        getCurrentEnvironment().labelsHidden ? "" : label
    }

    private func gtkCreateDropdownWidget() -> OpaquePointer {
        let cStrings: [UnsafeMutablePointer<CChar>?] = options.map { strdup($0) } + [nil]

        let dropdown = cStrings.withUnsafeBufferPointer { buf -> UnsafeMutablePointer<GtkWidget> in
            buf.baseAddress!.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buf.count) { ptr in
                gtk_drop_down_new_from_strings(ptr)!
            }
        }

        for cStr in cStrings { cStr.map { free($0) } }

        let dropdownOp = OpaquePointer(dropdown)
        let clampedSelection = max(0, min(selected, options.count - 1))
        if !options.isEmpty {
            gtk_drop_down_set_selected(dropdownOp, guint(clampedSelection))
        }

        if let onChanged = onChanged {
            let box = Unmanaged.passRetained(IntClosureBox(onChanged)).toOpaque()
            g_signal_connect_data(
                gpointer(dropdown),
                "notify::selected",
                unsafeBitCast({ (widget: gpointer?, _: gpointer?, userData: gpointer?) in
                    let box = Unmanaged<IntClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                    let sel = Int(gtk_drop_down_get_selected(OpaquePointer(widget!)))
                    box.closure(sel)
                } as @convention(c) (gpointer?, gpointer?, gpointer?) -> Void, to: GCallback.self),
                box,
                { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    Unmanaged<IntClosureBox>.fromOpaque(userData!).release()
                },
                GConnectFlags(rawValue: 0)
            )
        }

        let displayedLabel = effectiveLabel
        if !displayedLabel.isEmpty {
            let hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
            let labelWidget = gtk_label_new(displayedLabel)!
            gtk_box_append(boxPointer(hbox), labelWidget)
            gtk_box_append(boxPointer(hbox), dropdown)
            return opaqueFromWidget(hbox)
        }

        return opaqueFromWidget(dropdown)
    }

    private func gtkCreateSegmentedWidget() -> OpaquePointer {
        let hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_add_css_class(hbox, "linked")

        var firstButton: UnsafeMutablePointer<GtkWidget>?
        let clampedSelection = options.isEmpty ? 0 : max(0, min(selected, options.count - 1))
        var buttons: [UnsafeMutablePointer<GtkWidget>] = []

        for option in options {
            let button = gtk_toggle_button_new_with_label(option)!

            if let first = firstButton {
                gtk_swift_toggle_button_set_group(button, first)
            } else {
                firstButton = button
            }

            buttons.append(button)
            gtk_box_append(boxPointer(hbox), button)
        }

        if buttons.indices.contains(clampedSelection) {
            gtk_swift_toggle_button_set_active(buttons[clampedSelection], 1)
        }

        for (index, button) in buttons.enumerated() {
            if let onChanged = onChanged {
                let box = Unmanaged.passRetained(
                    SegmentClosureBox(index: index, closure: onChanged)
                ).toOpaque()
                g_signal_connect_data(
                    gpointer(button),
                    "toggled",
                    unsafeBitCast({ (buttonPtr: gpointer?, userData: gpointer?) in
                        guard let buttonPtr = buttonPtr, let userData = userData else { return }
                        let widget = UnsafeMutableRawPointer(buttonPtr)
                            .assumingMemoryBound(to: GtkWidget.self)
                        let box = Unmanaged<SegmentClosureBox>.fromOpaque(userData).takeUnretainedValue()
                        if gtk_swift_toggle_button_get_active(widget) != 0 {
                            box.closure(box.index)
                        }
                    } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
                    box,
                    { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                        Unmanaged<SegmentClosureBox>.fromOpaque(userData!).release()
                    },
                    GConnectFlags(rawValue: 0)
                )
            }
        }

        let displayedLabel = effectiveLabel
        if !displayedLabel.isEmpty {
            let outer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
            let labelWidget = gtk_label_new(displayedLabel)!
            gtk_box_append(boxPointer(outer), labelWidget)
            gtk_box_append(boxPointer(outer), hbox)
            return opaqueFromWidget(outer)
        }

        return opaqueFromWidget(hbox)
    }
}

// MARK: - DatePicker GTK extension

private class DatePickerBox {
    let calendar: UnsafeMutablePointer<GtkWidget>
    let binding: Binding<SwiftOpenUI.DateComponents>?
    let onChange: ((SwiftOpenUI.DateComponents) -> Void)?

    init(calendar: UnsafeMutablePointer<GtkWidget>,
         binding: Binding<SwiftOpenUI.DateComponents>?,
         onChange: ((SwiftOpenUI.DateComponents) -> Void)?) {
        self.calendar = calendar
        self.binding = binding
        self.onChange = onChange
    }
}

extension DatePicker: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4)!
        let boxPtr = boxPointer(box)

        if !title.isEmpty {
            let label = gtk_label_new(title)!
            gtk_widget_set_halign(label, GTK_ALIGN_START)
            gtk_box_append(boxPtr, label)
        }

        let calendar = gtk_calendar_new()!
        gtk_box_append(boxPtr, calendar)

        if let sel = selection {
            let dc = sel.wrappedValue
            gtk_swift_calendar_select_ymd(calendar, gint(dc.year), gint(dc.month), gint(dc.day))
        }

        let callbackBox = Unmanaged.passRetained(DatePickerBox(
            calendar: calendar, binding: selection, onChange: onChange
        )).toOpaque()

        g_signal_connect_data(
            gpointer(calendar),
            "day-selected",
            unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                let box = Unmanaged<DatePickerBox>.fromOpaque(userData!).takeUnretainedValue()
                var y: gint = 0, m: gint = 0, d: gint = 0
                gtk_swift_calendar_get_ymd(box.calendar, &y, &m, &d)
                let dc = SwiftOpenUI.DateComponents(year: Int(y), month: Int(m), day: Int(d))
                if let binding = box.binding, dc != binding.wrappedValue {
                    binding.wrappedValue = dc
                }
                box.onChange?(dc)
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            callbackBox,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<DatePickerBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        gtkApplyEnabledState(to: box)
        return opaqueFromWidget(box)
    }
}

// MARK: - GeometryReader GTK extension

/// Context holding the content builder for deferred rendering.
private class GeometryReaderContext {
    let renderContent: (GeometryProxy) -> OpaquePointer
    let box: UnsafeMutablePointer<GtkWidget>
    var renderScheduled = false
    var idleRetryCount = 0
    var lastWidth: Double = 0
    var lastHeight: Double = 0

    init<Content: View>(content: @escaping (GeometryProxy) -> Content,
                        box: UnsafeMutablePointer<GtkWidget>) {
        self.box = box
        self.renderContent = { proxy in
            gtkRenderView(content(proxy))
        }
    }
}

private func geometryRenderContent(_ context: GeometryReaderContext,
                                    widget: UnsafeMutablePointer<GtkWidget>,
                                    width: Double, height: Double) {
    let proxy = GeometryProxy(size: GeometrySize(width: width, height: height))
    while let child = gtk_widget_get_first_child(widget) {
        gtk_box_remove(boxPointer(widget), child)
    }
    let rendered = context.renderContent(proxy)
    gtk_box_append(boxPointer(widget), widgetFromOpaque(rendered))
}

private let geometryMapCallback: @convention(c) (
    gpointer?, gpointer?
) -> Void = { widgetPtr, _ in
    guard let widgetPtr = widgetPtr else { return }
    let widget = UnsafeMutableRawPointer(widgetPtr).assumingMemoryBound(to: GtkWidget.self)
    let gobject = UnsafeMutableRawPointer(widgetPtr).assumingMemoryBound(to: GObject.self)
    guard let contextPtr = g_object_get_data(gobject, "gtk-swift-geometry-context") else { return }
    let context = Unmanaged<GeometryReaderContext>.fromOpaque(contextPtr).takeUnretainedValue()
    guard !context.renderScheduled else { return }

    // Walk ancestors to find one with valid dimensions
    var ancestor = gtk_widget_get_parent(widget)
    while let a = ancestor {
        let aw = Double(gtk_widget_get_width(a))
        let ah = Double(gtk_widget_get_height(a))
        if aw > 1, ah > 1 {
            geometryRenderContent(context, widget: widget, width: aw, height: ah)
            return
        }
        ancestor = gtk_widget_get_parent(a)
    }

    // Defer to idle handler
    context.renderScheduled = true
    context.idleRetryCount = 0
    g_object_ref(gpointer(widgetPtr))
    g_idle_add({ userData -> gboolean in
        guard let userData = userData else { return 0 }
        let widget = UnsafeMutableRawPointer(userData).assumingMemoryBound(to: GtkWidget.self)
        guard gtk_swift_is_widget(widget) != 0 else {
            g_object_unref(userData)
            return 0
        }

        let gobject = UnsafeMutableRawPointer(userData).assumingMemoryBound(to: GObject.self)
        guard let contextPtr = g_object_get_data(gobject, "gtk-swift-geometry-context") else {
            g_object_unref(userData)
            return 0
        }
        let context = Unmanaged<GeometryReaderContext>.fromOpaque(contextPtr).takeUnretainedValue()

        let width = Double(gtk_widget_get_width(widget))
        let height = Double(gtk_widget_get_height(widget))

        if width <= 1 || height <= 1 {
            context.idleRetryCount += 1
            if context.idleRetryCount <= 10 {
                return 1 // retry
            }
            context.renderScheduled = false
            g_object_unref(userData)
            return 0
        }

        context.renderScheduled = false
        geometryRenderContent(context, widget: widget, width: width, height: height)
        g_object_unref(userData)
        return 0
    }, widgetPtr)
}

/// Tick callback: checks if the widget's allocated size changed since the last
/// render and re-renders content if so.  The tick callback fires once per frame
/// (~60 Hz) but only re-renders on actual size changes, so the cost is just two
/// integer reads per frame.  The callback is removed when the widget is unmapped.
private let geometryTickCallback: GtkTickCallback = { widget, _, userData in
    guard let widget = widget else { return 0 }
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    guard let contextPtr = g_object_get_data(gobject, "gtk-swift-geometry-context") else {
        return 0 // G_SOURCE_REMOVE
    }
    let context = Unmanaged<GeometryReaderContext>.fromOpaque(contextPtr).takeUnretainedValue()

    let w = Double(gtk_widget_get_width(widget))
    let h = Double(gtk_widget_get_height(widget))
    if w > 1, h > 1, (w != context.lastWidth || h != context.lastHeight) {
        context.lastWidth = w
        context.lastHeight = h
        geometryRenderContent(context, widget: widget, width: w, height: h)
    }
    return 1 // G_SOURCE_CONTINUE
}

extension GeometryReader: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_widget_set_hexpand(box, 1)
        gtk_widget_set_vexpand(box, 1)

        let context = GeometryReaderContext(content: content, box: box)
        let contextPtr = Unmanaged.passRetained(context).toOpaque()
        let gobject = UnsafeMutableRawPointer(box).assumingMemoryBound(to: GObject.self)
        g_object_set_data_full(gobject, "gtk-swift-geometry-context", contextPtr,
            { userData in Unmanaged<GeometryReaderContext>.fromOpaque(userData!).release() })

        // Initial render on first display
        g_signal_connect_data(
            gpointer(box), "map",
            unsafeBitCast(geometryMapCallback, to: GCallback.self),
            nil, nil, GConnectFlags(rawValue: 0))

        // Track size changes via tick callback (fires per frame, re-renders
        // only when allocated size actually changes).  The tick callback is
        // automatically paused when the widget is unmapped.
        _ = gtk_widget_add_tick_callback(
            box,
            geometryTickCallback,
            nil, nil
        )

        return opaqueFromWidget(box)
    }
}

// MARK: - Searchable GTK extension

private class SearchSuggestionActionBox {
    let completion: String
    let textBinding: Binding<String>
    let entry: UnsafeMutablePointer<GtkWidget>

    init(completion: String, textBinding: Binding<String>, entry: UnsafeMutablePointer<GtkWidget>) {
        self.completion = completion
        self.textBinding = textBinding
        self.entry = entry
    }
}

private class SearchScopeActionBox {
    let scopeID: String
    let button: UnsafeMutablePointer<GtkWidget>
    let selectScope: (String) -> Void

    init(scopeID: String, button: UnsafeMutablePointer<GtkWidget>, selectScope: @escaping (String) -> Void) {
        self.scopeID = scopeID
        self.button = button
        self.selectScope = selectScope
    }
}

private class SearchBox {
    let entry: UnsafeMutablePointer<GtkWidget>
    let binding: Binding<String>
    let isPresented: Binding<Bool>?

    init(entry: UnsafeMutablePointer<GtkWidget>, binding: Binding<String>, isPresented: Binding<Bool>? = nil) {
        self.entry = entry
        self.binding = binding
        self.isPresented = isPresented
    }
}

extension SearchableView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(
            kind: .searchable, typeName: "SearchableView",
            props: .searchable(GTK4SearchableDescriptor(
                text: text.wrappedValue,
                prompt: prompt,
                placement: placement,
                isPresented: isPresented?.wrappedValue,
                tokens: tokens,
                tokenMode: tokenMode,
                suggestions: suggestions,
                suggestionMode: suggestionMode,
                scopes: scopes,
                scopeMode: scopeMode,
                selectedScopeID: selectedScopeID)),
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        let boxPtr = boxPointer(box)

        let entry = gtk_swift_search_entry_new()!
        if !prompt.isEmpty {
            g_object_set_property_string(entry, "placeholder-text", prompt)
        }
        gtk_box_append(boxPtr, entry)

        if !text.wrappedValue.isEmpty {
            gtk_swift_editable_set_text(entry, text.wrappedValue)
        }

        // Honor isPresented: hide entire search UI surface when false
        let isDismissed = isPresented.map { !$0.wrappedValue } ?? false
        if isDismissed {
            gtk_widget_set_visible(entry, 0)
        }

        let binding = text
        let presentedBinding = isPresented
        let callbackBox = Unmanaged.passRetained(
            SearchBox(entry: entry, binding: binding, isPresented: presentedBinding)
        ).toOpaque()

        g_signal_connect_data(
            gpointer(entry),
            "search-changed",
            unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                let box = Unmanaged<SearchBox>.fromOpaque(userData!).takeUnretainedValue()
                let cStr = gtk_swift_editable_get_text(box.entry)
                let newValue = cStr.map { String(cString: $0) } ?? ""
                if newValue != box.binding.wrappedValue {
                    box.binding.wrappedValue = newValue
                }
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            callbackBox,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<SearchBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        // Render token labels between search entry and content
        if !tokens.isEmpty {
            let tokenRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4)!
            gtk_widget_set_margin_start(tokenRow, 4)
            gtk_widget_set_margin_end(tokenRow, 4)
            gtk_widget_set_margin_top(tokenRow, 2)
            gtk_widget_set_margin_bottom(tokenRow, 2)
            for token in tokens {
                let label = gtk_label_new(token.label)!
                gtk_widget_add_css_class(label, "dim-label")
                gtk_box_append(boxPointer(tokenRow), label)
            }
            if isDismissed { gtk_widget_set_visible(tokenRow, 0) }
            gtk_box_append(boxPtr, tokenRow)
        }

        // Render suggestion rows as clickable buttons
        if !suggestions.isEmpty {
            let suggestionBox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)!
            gtk_widget_set_margin_start(suggestionBox, 4)
            gtk_widget_set_margin_end(suggestionBox, 4)
            for suggestion in suggestions {
                let btn = gtk_button_new_with_label(suggestion.label)!
                gtk_widget_set_halign(btn, GTK_ALIGN_START)
                let completionText = suggestion.completion ?? suggestion.label
                let textBinding = text
                let searchEntry = entry
                let actionBox = Unmanaged.passRetained(
                    SearchSuggestionActionBox(completion: completionText, textBinding: textBinding, entry: searchEntry)
                ).toOpaque()
                g_signal_connect_data(
                    gpointer(btn),
                    "clicked",
                    unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                        let box = Unmanaged<SearchSuggestionActionBox>.fromOpaque(userData!).takeUnretainedValue()
                        box.textBinding.wrappedValue = box.completion
                        gtk_swift_editable_set_text(box.entry, box.completion)
                    } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
                    actionBox,
                    { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                        Unmanaged<SearchSuggestionActionBox>.fromOpaque(userData!).release()
                    },
                    GConnectFlags(rawValue: 0)
                )
                gtk_box_append(boxPointer(suggestionBox), btn)
            }
            if isDismissed { gtk_widget_set_visible(suggestionBox, 0) }
            gtk_box_append(boxPtr, suggestionBox)
        }

        // Render scope row as horizontal toggle buttons
        if !scopes.isEmpty {
            let scopeRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4)!
            gtk_widget_set_margin_start(scopeRow, 4)
            gtk_widget_set_margin_end(scopeRow, 4)
            gtk_widget_set_margin_top(scopeRow, 2)
            gtk_widget_set_margin_bottom(scopeRow, 2)
            let scopeSelector: (String) -> Void = { [self] id in self.selectScope(id: id) }
            var firstScopeBtn: UnsafeMutablePointer<GtkWidget>? = nil
            for scope in scopes {
                let btn = gtk_toggle_button_new_with_label(scope.label)!
                // Group all scope buttons so only one can be active
                if let group = firstScopeBtn {
                    gtk_swift_toggle_button_set_group(btn, group)
                } else {
                    firstScopeBtn = btn
                }
                if selectedScopeID == scope.id {
                    gtk_swift_toggle_button_set_active(btn, 1)
                }
                let actionBox = Unmanaged.passRetained(
                    SearchScopeActionBox(scopeID: scope.id, button: btn, selectScope: scopeSelector)
                ).toOpaque()
                g_signal_connect_data(
                    gpointer(btn),
                    "toggled",
                    unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                        let box = Unmanaged<SearchScopeActionBox>.fromOpaque(userData!).takeUnretainedValue()
                        // Only write back when toggling on, not off
                        guard gtk_swift_toggle_button_get_active(box.button) != 0 else { return }
                        box.selectScope(box.scopeID)
                    } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
                    actionBox,
                    { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                        Unmanaged<SearchScopeActionBox>.fromOpaque(userData!).release()
                    },
                    GConnectFlags(rawValue: 0)
                )
                gtk_box_append(boxPointer(scopeRow), btn)
            }
            if isDismissed { gtk_widget_set_visible(scopeRow, 0) }
            gtk_box_append(boxPtr, scopeRow)
        }

        let contentWidget = widgetFromOpaque(gtkRenderView(content))
        gtk_widget_set_vexpand(contentWidget, 1)
        gtk_box_append(boxPtr, contentWidget)

        return opaqueFromWidget(box)
    }
}

// MARK: - Menu GTK extension

/// Holds menu action closures for lifetime management.
private class MenuActionBox {
    var actions: [ClosureBox] = []
}

extension Menu: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let button = gtk_menu_button_new()!
        gtk_swift_menu_button_set_label(button, title)

        let actionGroup = g_simple_action_group_new()!
        let menuModel = gtk_swift_menu_new()!
        let actionBox = MenuActionBox()
        var actionIndex = 0

        gtkBuildMenuModel(elements: elements, menu: menuModel,
                          actionGroup: actionGroup, actionBox: actionBox,
                          actionIndex: &actionIndex)

        let popover = gtk_swift_popover_menu_new_from_model(menuModel)!
        gtk_swift_menu_button_set_popover(button, popover)

        gtk_swift_widget_insert_action_group(button, "menu", gpointer(actionGroup))

        // Attach actionBox to button for lifetime management
        let retained = Unmanaged.passRetained(actionBox).toOpaque()
        let gobject = UnsafeMutableRawPointer(button).assumingMemoryBound(to: GObject.self)
        g_object_set_data_full(gobject, "gtk-swift-menu-actions", retained,
            { userData in Unmanaged<MenuActionBox>.fromOpaque(userData!).release() })

        return opaqueFromWidget(button)
    }
}

private func gtkBuildMenuModel(elements: [MenuElement], menu: gpointer,
                                actionGroup: UnsafeMutablePointer<GSimpleActionGroup>,
                                actionBox: MenuActionBox,
                                actionIndex: inout Int) {
    // Split elements by dividers into sections for visual separation.
    var sections: [[MenuElement]] = [[]]
    for element in elements {
        if case .divider = element {
            sections.append([])
        } else {
            sections[sections.count - 1].append(element)
        }
    }

    if sections.count <= 1 {
        // No dividers — add items directly
        for element in elements {
            gtkAddMenuElement(element, to: menu, actionGroup: actionGroup,
                              actionBox: actionBox, actionIndex: &actionIndex)
        }
    } else {
        // Multiple sections — wrap each group in a GMenu section
        for section in sections where !section.isEmpty {
            let sectionMenu = gtk_swift_menu_new()!
            for element in section {
                gtkAddMenuElement(element, to: sectionMenu, actionGroup: actionGroup,
                                  actionBox: actionBox, actionIndex: &actionIndex)
            }
            gtk_swift_menu_append_section(menu, nil, sectionMenu)
        }
    }
}

private func gtkAddMenuElement(_ element: MenuElement, to menu: gpointer,
                                actionGroup: UnsafeMutablePointer<GSimpleActionGroup>,
                                actionBox: MenuActionBox,
                                actionIndex: inout Int) {
    switch element {
    case .item(let label, let action):
        let actionName = "action\(actionIndex)"
        actionIndex += 1

        let gAction = g_simple_action_new(actionName, nil)!

        let box = ClosureBox(bindActionToCurrentEnvironment(action))
        actionBox.actions.append(box)
        let boxPtr = Unmanaged.passUnretained(box).toOpaque()

        g_signal_connect_data(
            gpointer(gAction),
            "activate",
            unsafeBitCast({ (_: gpointer?, _: gpointer?, userData: gpointer?) in
                let box = Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                box.closure()
            } as @convention(c) (gpointer?, gpointer?, gpointer?) -> Void, to: GCallback.self),
            boxPtr, nil,
            GConnectFlags(rawValue: 0)
        )

        gtk_swift_action_map_add_action(gpointer(actionGroup), gpointer(gAction))
        gtk_swift_menu_append(menu, label, "menu.\(actionName)")

    case .submenu(let label, let children):
        let submenu = gtk_swift_menu_new()!
        gtkBuildMenuModel(elements: children, menu: submenu,
                          actionGroup: actionGroup, actionBox: actionBox,
                          actionIndex: &actionIndex)
        gtk_swift_menu_append_submenu(menu, label, submenu)

    case .divider:
        break // handled at section level
    }
}

// MARK: - Toolbar GTK extension

extension ToolbarItem: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        gtkRenderView(content)
    }
}

extension ToolbarView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        // Render the content; toolbar items are extracted by NavigationStack
        // via the ToolbarProvider protocol during header bar construction.
        gtkRenderView(content)
    }
}

extension ToolbarConfigurationView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        gtkRenderView(content)
    }
}

// MARK: - ConfirmationDialog GTK extension

extension ConfirmationDialogView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))

        let anchor: UnsafeMutablePointer<GtkWidget>
        if let host = GTKViewHost.getCurrentRebuilding() {
            anchor = host.container
        } else {
            anchor = widget
        }
        let gobject = UnsafeMutableRawPointer(anchor).assumingMemoryBound(to: GObject.self)

        if !isPresented.wrappedValue {
            if let dialogPtr = g_object_get_data(gobject, "swift-dialog-window") {
                let dialog = dialogPtr.assumingMemoryBound(to: GtkWindow.self)
                g_object_set_data(gobject, "swift-dialog-window", nil)
                gtk_window_destroy(dialog)
            }
            return opaqueFromWidget(widget)
        }

        guard g_object_get_data(gobject, "swift-dialog-active") == nil else {
            return opaqueFromWidget(widget)
        }
        g_object_set_data(gobject, "swift-dialog-active", gpointer(bitPattern: 1))
        g_object_ref(gpointer(anchor))

        let dialogTitle = title
        let dialogTitleVisibility = titleVisibility
        let dialogMessage = message
        let dialogButtons = buttons
        let binding = isPresented

        let onDismiss: () -> Void = {
            let obj = UnsafeMutableRawPointer(anchor).assumingMemoryBound(to: GObject.self)
            g_object_set_data(obj, "swift-dialog-active", nil)
            g_object_set_data(obj, "swift-dialog-window", nil)
            binding.wrappedValue = false
        }

        g_idle_add({ userData -> gboolean in
            let box = Unmanaged<ClosureBox>.fromOpaque(userData!).takeRetainedValue()
            box.closure()
            return 0
        }, Unmanaged.passRetained(ClosureBox { [anchor, dialogTitle, dialogTitleVisibility, dialogMessage, dialogButtons, onDismiss] in
            guard let root = gtk_widget_get_root(anchor) else {
                onDismiss()
                g_object_unref(gpointer(anchor))
                return
            }

            let dialog = gtk_window_new()!
            let dialogWin = windowPointer(dialog)
            gtk_window_set_modal(dialogWin, 1)
            gtk_window_set_title(dialogWin, dialogTitleVisibility == .hidden ? "" : dialogTitle)
            gtk_window_set_default_size(dialogWin, 300, -1)
            gtk_window_set_resizable(dialogWin, 0)
            gtk_window_set_transient_for(
                dialogWin,
                UnsafeMutableRawPointer(root).assumingMemoryBound(to: GtkWindow.self)
            )

            let vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8)!
            gtk_widget_set_margin_top(vbox, 20)
            gtk_widget_set_margin_bottom(vbox, 20)
            gtk_widget_set_margin_start(vbox, 20)
            gtk_widget_set_margin_end(vbox, 20)

            // Title — honor titleVisibility
            if dialogTitleVisibility != .hidden {
                let titleLabel = gtk_label_new(nil)!
                let escaped = dialogTitle
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                gtk_swift_label_set_markup(titleLabel, "<b>\(escaped)</b>")
                gtk_box_append(boxPointer(vbox), titleLabel)
            }

            // Message
            if !dialogMessage.isEmpty {
                let msgLabel = gtk_label_new(dialogMessage)!
                gtk_label_set_wrap(OpaquePointer(msgLabel), 1)
                gtk_box_append(boxPointer(vbox), msgLabel)
            }

            let sep = gtk_separator_new(GTK_ORIENTATION_HORIZONTAL)!
            gtk_box_append(boxPointer(vbox), sep)

            // Vertical buttons
            for alertButton in dialogButtons {
                let btn = gtk_button_new_with_label(alertButton.label)!
                gtk_widget_set_hexpand(btn, 1)

                if alertButton.role == .destructive {
                    gtk_widget_add_css_class(btn, "destructive-action")
                }

                let actionBox = Unmanaged.passRetained(AlertActionBox(
                    action: alertButton.action, dialog: dialog
                )).toOpaque()
                g_signal_connect_data(
                    gpointer(btn),
                    "clicked",
                    unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                        let box = Unmanaged<AlertActionBox>.fromOpaque(userData!).takeUnretainedValue()
                        box.action()
                        gtk_window_destroy(windowPointer(box.dialog))
                    } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
                    actionBox,
                    { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                        Unmanaged<AlertActionBox>.fromOpaque(userData!).release()
                    },
                    GConnectFlags(rawValue: 0)
                )

                gtk_box_append(boxPointer(vbox), btn)
            }

            let anchorObj = UnsafeMutableRawPointer(anchor).assumingMemoryBound(to: GObject.self)
            g_object_set_data(anchorObj, "swift-dialog-window", gpointer(dialogWin))

            let closeDismiss = Unmanaged.passRetained(ClosureBox(onDismiss)).toOpaque()
            g_signal_connect_data(
                gpointer(dialog),
                "close-request",
                unsafeBitCast({ (_: gpointer?, userData: gpointer?) -> gboolean in
                    Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue().closure()
                    return 0
                } as @convention(c) (gpointer?, gpointer?) -> gboolean, to: GCallback.self),
                closeDismiss,
                { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    Unmanaged<ClosureBox>.fromOpaque(userData!).release()
                },
                GConnectFlags(rawValue: 0)
            )

            gtk_window_set_child(dialogWin, vbox)
            gtk_window_present(dialogWin)
            g_object_unref(gpointer(anchor))
        }).toOpaque())

        return opaqueFromWidget(widget)
    }
}

// MARK: - Canvas GTK extension

/// Wraps draw closure for C callback bridging.
class DrawClosureBox {
    var closure: (DrawingContext, Int, Int) -> Void
    init(_ closure: @escaping (DrawingContext, Int, Int) -> Void) {
        self.closure = closure
    }
}

class SizedDrawClosureBox {
    var closure: (DrawingContext, Int, Int) -> Void
    var sizedClosure: ((DrawingContext, CGSize) -> Void)?
    init(_ closure: @escaping (DrawingContext, Int, Int) -> Void,
         sized: ((DrawingContext, CGSize) -> Void)? = nil) {
        self.closure = closure
        self.sizedClosure = sized
    }
}

extension DrawingContext {
    // MARK: - Color
    public func setColor(r: Double, g: Double, b: Double) {
        gtk_swift_cairo_set_source_rgb(cr, r, g, b)
    }
    public func setColor(r: Double, g: Double, b: Double, a: Double) {
        gtk_swift_cairo_set_source_rgba(cr, r, g, b, a)
    }

    // MARK: - Line style
    public func setLineWidth(_ width: Double) {
        gtk_swift_cairo_set_line_width(cr, width)
    }
    public func setLineCap(_ cap: LineCap) {
        let v: cairo_line_cap_t
        switch cap {
        case .butt:   v = CAIRO_LINE_CAP_BUTT
        case .round:  v = CAIRO_LINE_CAP_ROUND
        case .square: v = CAIRO_LINE_CAP_SQUARE
        }
        gtk_swift_cairo_set_line_cap(cr, v)
    }
    public func setLineJoin(_ join: LineJoin) {
        let v: cairo_line_join_t
        switch join {
        case .miter: v = CAIRO_LINE_JOIN_MITER
        case .round: v = CAIRO_LINE_JOIN_ROUND
        case .bevel: v = CAIRO_LINE_JOIN_BEVEL
        }
        gtk_swift_cairo_set_line_join(cr, v)
    }

    // MARK: - Path operations
    public func moveTo(x: Double, y: Double) {
        gtk_swift_cairo_move_to(cr, x, y)
    }
    public func lineTo(x: Double, y: Double) {
        gtk_swift_cairo_line_to(cr, x, y)
    }
    public func rectangle(x: Double, y: Double, width: Double, height: Double) {
        gtk_swift_cairo_rectangle(cr, x, y, width, height)
    }
    public func arc(centerX: Double, centerY: Double, radius: Double,
                    startAngle: Double = 0, endAngle: Double = .pi * 2) {
        gtk_swift_cairo_arc(cr, centerX, centerY, radius, startAngle, endAngle)
    }

    // MARK: - Drawing
    public func stroke() { gtk_swift_cairo_stroke(cr) }
    public func fill() { gtk_swift_cairo_fill(cr) }
    public func paint() { gtk_swift_cairo_paint(cr) }

    // MARK: - State
    public func save() { gtk_swift_cairo_save(cr) }
    public func restore() { gtk_swift_cairo_restore(cr) }
    public func scale(x: Double, y: Double) { gtk_swift_cairo_scale(cr, x, y) }

    // MARK: - Surface painting
    public func setSourceSurface(_ surface: OpaquePointer, x: Double = 0, y: Double = 0) {
        gtk_swift_cairo_set_source_surface(cr, surface, x, y)
    }

    // MARK: - Path-based drawing

    /// Stroke a Path with the given shading and style.
    public func stroke(_ path: Path, with shading: Shading, style: StrokeStyle = StrokeStyle()) {
        let (r, g, b, a) = shading.colorComponents
        gtk_swift_cairo_set_source_rgba(cr, r, g, b, a)
        gtk_swift_cairo_set_line_width(cr, Double(style.lineWidth))

        let cairoCap: cairo_line_cap_t
        switch style.lineCap {
        case .butt:   cairoCap = CAIRO_LINE_CAP_BUTT
        case .round:  cairoCap = CAIRO_LINE_CAP_ROUND
        case .square: cairoCap = CAIRO_LINE_CAP_SQUARE
        }
        gtk_swift_cairo_set_line_cap(cr, cairoCap)

        let cairoJoin: cairo_line_join_t
        switch style.lineJoin {
        case .miter: cairoJoin = CAIRO_LINE_JOIN_MITER
        case .bevel: cairoJoin = CAIRO_LINE_JOIN_BEVEL
        case .round: cairoJoin = CAIRO_LINE_JOIN_ROUND
        }
        gtk_swift_cairo_set_line_join(cr, cairoJoin)

        // Apply dash pattern if specified. Empty = solid; a non-empty array
        // draws alternating on/off segments (e.g. [8, 4] = 8pt dash, 4pt gap).
        if style.dash.isEmpty {
            gtk_swift_cairo_set_dash(cr, nil, 0, 0)
        } else {
            let dashes = style.dash.map { Double($0) }
            dashes.withUnsafeBufferPointer { buf in
                gtk_swift_cairo_set_dash(cr, buf.baseAddress, Int32(buf.count), Double(style.dashPhase))
            }
        }

        applyPathElements(path)
        gtk_swift_cairo_stroke(cr)
    }

    /// Fill a Path with the given shading.
    public func fill(_ path: Path, with shading: Shading) {
        let (r, g, b, a) = shading.colorComponents
        gtk_swift_cairo_set_source_rgba(cr, r, g, b, a)
        applyPathElements(path)
        gtk_swift_cairo_fill(cr)
    }

    /// Walk path elements and emit corresponding Cairo calls.
    private func applyPathElements(_ path: Path) {
        gtk_swift_cairo_new_path(cr)
        for element in path.elements {
            switch element {
            case .moveTo(let pt):
                gtk_swift_cairo_move_to(cr, Double(pt.x), Double(pt.y))
            case .lineTo(let pt):
                gtk_swift_cairo_line_to(cr, Double(pt.x), Double(pt.y))
            case .curve(let end, let c1, let c2):
                gtk_swift_cairo_curve_to(cr,
                    Double(c1.x), Double(c1.y),
                    Double(c2.x), Double(c2.y),
                    Double(end.x), Double(end.y))
            case .arc(let center, let radius, let startAngle, let endAngle, let clockwise):
                // SwiftUI clockwise = visually CW in y-down = cairo_arc_negative
                if clockwise {
                    gtk_swift_cairo_arc_negative(cr,
                        Double(center.x), Double(center.y), Double(radius),
                        Double(startAngle), Double(endAngle))
                } else {
                    gtk_swift_cairo_arc(cr,
                        Double(center.x), Double(center.y), Double(radius),
                        Double(startAngle), Double(endAngle))
                }
            case .ellipse(let center, let rx, let ry):
                guard rx > 0 && ry > 0 else { continue }
                gtk_swift_cairo_save(cr)
                gtk_swift_cairo_scale(cr, 1.0, Double(ry / rx))
                gtk_swift_cairo_arc(cr,
                    Double(center.x), Double(center.y) * Double(rx / ry), Double(rx),
                    0, 2 * .pi)
                gtk_swift_cairo_restore(cr)
            case .closeSubpath:
                gtk_swift_cairo_close_path(cr)
            }
        }
    }
}

extension Canvas: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        gtkCollectCanvasPayload(GTK4CanvasPayload(
            width: width,
            height: height,
            drawHandler: drawHandler,
            sizedDrawHandler: sizedDrawHandler
        ))
        return GTK4DescriptorNode(
            kind: .canvas,
            typeName: "Canvas",
            props: .canvas(GTK4CanvasDescriptor(width: width, height: height))
        )
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let area = gtk_drawing_area_new()!

        if width > 0 {
            gtk_swift_drawing_area_set_content_width(area, gint(width))
        }
        if height > 0 {
            gtk_swift_drawing_area_set_content_height(area, gint(height))
        }

        // When no explicit size is set, expand to fill available space
        // (matches SwiftUI Canvas which fills its proposed size).
        if width <= 0 {
            gtk_widget_set_hexpand(area, 1)
        }
        if height <= 0 {
            gtk_widget_set_vexpand(area, 1)
        }

        let box = Unmanaged.passRetained(
            SizedDrawClosureBox(drawHandler, sized: sizedDrawHandler)
        ).toOpaque()
        let gobject = UnsafeMutableRawPointer(area).assumingMemoryBound(to: GObject.self)
        g_object_set_data(gobject, "gtk-swift-canvas-draw-box", box)
        gtkMarkHostedNodeKind(area, kind: .canvas)

        gtk_swift_drawing_area_set_draw_func(
            area,
            { (widget: UnsafeMutablePointer<GtkWidget>?,
               cr: OpaquePointer?,
               w: gint, h: gint,
               userData: gpointer?) in
                guard let cr = cr, let userData = userData else { return }
                let box = Unmanaged<SizedDrawClosureBox>.fromOpaque(userData).takeUnretainedValue()
                let context = DrawingContext(cr: cr)
                if let sizedHandler = box.sizedClosure {
                    sizedHandler(context, CGSize(width: CGFloat(w), height: CGFloat(h)))
                } else {
                    box.closure(context, Int(w), Int(h))
                }
            },
            box,
            { (userData: gpointer?) in
                guard let userData = userData else { return }
                Unmanaged<SizedDrawClosureBox>.fromOpaque(userData).release()
            }
        )

        return opaqueFromWidget(area)
    }
}

// MARK: - Foreground color propagation for Cairo rendering
//
// ForegroundColorView applies CSS color: to widgets, but GtkDrawingArea
// Cairo callbacks can't read CSS properties. Track the current foreground
// color in a render-time thread-local so bare shapes can read it.

private var _gtkCurrentForegroundColor: Color?

func gtkGetCurrentForegroundColor() -> Color {
    _gtkCurrentForegroundColor ?? Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0)
}

func gtkSetCurrentForegroundColor(_ color: Color?) {
    _gtkCurrentForegroundColor = color
}

// MARK: - Shape view rendering

/// Closure box for shape draw callbacks. Holds the path generator and
/// fill/stroke configuration so the Cairo callback can render the shape.
private class ShapeDrawBox {
    enum Mode {
        case fill(r: Double, g: Double, b: Double, a: Double)
        case stroke(r: Double, g: Double, b: Double, a: Double, style: StrokeStyle)
    }
    let pathGenerator: (CGRect) -> Path
    let mode: Mode

    init(pathGenerator: @escaping (CGRect) -> Path, mode: Mode) {
        self.pathGenerator = pathGenerator
        self.mode = mode
    }
}

/// Create a GtkDrawingArea that renders a shape via Cairo.
private func gtkCreateShapeWidget(box: ShapeDrawBox) -> OpaquePointer {
    let area = gtk_drawing_area_new()!
    gtk_widget_set_hexpand(area, 1)
    gtk_widget_set_vexpand(area, 1)

    let retained = Unmanaged.passRetained(box).toOpaque()

    gtk_swift_drawing_area_set_draw_func(
        area,
        { (widget: UnsafeMutablePointer<GtkWidget>?,
           cr: OpaquePointer?,
           w: gint, h: gint,
           userData: gpointer?) in
            guard let cr = cr, let userData = userData else { return }
            let box = Unmanaged<ShapeDrawBox>.fromOpaque(userData).takeUnretainedValue()
            let rect = CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
            let path = box.pathGenerator(rect)
            let context = DrawingContext(cr: cr)

            switch box.mode {
            case .fill(let r, let g, let b, let a):
                context.fill(path, with: .color(Color(red: r, green: g, blue: b, opacity: a)))
            case .stroke(let r, let g, let b, let a, let style):
                context.stroke(path, with: .color(Color(red: r, green: g, blue: b, opacity: a)), style: style)
            }
        },
        retained,
        { (userData: gpointer?) in
            guard let userData = userData else { return }
            Unmanaged<ShapeDrawBox>.fromOpaque(userData).release()
        }
    )

    return opaqueFromWidget(area)
}

/// Render a bare shape (no .fill() or .stroke()) filled with the current
/// foreground color (default black).
private func gtkRenderBareShape<S: Shape>(_ shape: S) -> OpaquePointer {
    let fg = gtkGetCurrentForegroundColor()
    let box = ShapeDrawBox(
        pathGenerator: { rect in shape.path(in: rect) },
        mode: .fill(r: fg.red, g: fg.green, b: fg.blue, a: fg.alpha))
    return gtkCreateShapeWidget(box: box)
}

extension Circle: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer { gtkRenderBareShape(self) }
}

extension Rectangle: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer { gtkRenderBareShape(self) }
}

extension RoundedRectangle: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer { gtkRenderBareShape(self) }
}

extension Capsule: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer { gtkRenderBareShape(self) }
}

extension Ellipse: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer { gtkRenderBareShape(self) }
}

extension FilledShape: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = ShapeDrawBox(
            pathGenerator: { rect in self.shape.path(in: rect) },
            mode: .fill(r: color.red, g: color.green, b: color.blue, a: color.alpha))
        return gtkCreateShapeWidget(box: box)
    }
}

extension StrokedShape: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = ShapeDrawBox(
            pathGenerator: { rect in self.shape.path(in: rect) },
            mode: .stroke(r: color.red, g: color.green, b: color.blue, a: color.alpha, style: style))
        return gtkCreateShapeWidget(box: box)
    }
}

// MARK: - Stateful view rendering

private func gtkRenderStatefulView<V: View>(_ view: V) -> OpaquePointer {
    let host = GTKViewHost(buildBody: {
        gtkRenderView(view.body)
    })
    host.describeBody = {
        gtkDescribeView(view.body)
    }

    installState(view, host: host)

    let previousHost = GTKViewHost.getCurrentRebuilding()
    GTKViewHost.setCurrentRebuilding(host)
    beginDependencyTracking()
    let widget = host.buildBodyWithTracking()
    if let tracking = endDependencyTracking() {
        host.lastReadSet = tracking.readSet
        host.lastInputSnapshot = tracking.snapshots
    }
    GTKViewHost.setCurrentRebuilding(previousHost)

    let child = widgetFromOpaque(widget)
    let childHexpand = gtk_widget_get_hexpand(child) != 0
    let childVexpand = gtk_widget_get_vexpand(child) != 0
    gtk_widget_set_hexpand(host.container, childHexpand ? 1 : 0)
    gtk_widget_set_vexpand(host.container, childVexpand ? 1 : 0)
    if childHexpand {
        gtk_widget_set_halign(child, GTK_ALIGN_FILL)
    }
    if childVexpand {
        gtk_widget_set_valign(child, GTK_ALIGN_FILL)
    }
    gtk_box_append(boxPointer(host.container), child)

    // Capture initial descriptor state so the narrow mutation path is
    // available from the very first @State change.  Without this, the
    // first rebuild always takes the full-teardown path, which destroys
    // gesture recognisers attached to child widgets (e.g. Canvas + onDrag).
    if let describeBody = host.describeBody {
        let previousEnvForDesc = getCurrentEnvironment()
        setCurrentEnvironment(host.capturedEnvironment)
        let described = gtkDescribeCapturingCanvasPayloads(describeBody)
        setCurrentEnvironment(previousEnvForDesc)

        let identified = gtkIdentifyDescriptorTree(described.descriptor)
        let canvasPayloads = gtkCanvasPayloadsByIdentity(
            descriptorRoot: identified,
            payloads: described.canvasPayloads
        )
        host.lastRetainedDescriptor = gtkRetainDescriptorTree(identified)
        var executor = gtkMakeExecutorTree(
            from: identified,
            canvasPayloadsByIdentity: canvasPayloads
        )
        executor = gtkCaptureSupportedNativeSlots(
            from: child,
            descriptorRoot: identified,
            executorRoot: executor
        )
        host.retainedExecutor = executor
    }

    return opaqueFromWidget(host.container)
}

// MARK: - Safe Area GTK extensions

extension IgnoresSafeAreaView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        GTK4DescriptorNode(
            kind: .composite, typeName: "IgnoresSafeAreaView",
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        // Passthrough in Batch 1 — GTK has no native safe-area reservation yet
        gtkRenderView(content)
    }
}

extension SafeAreaInsetView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        let insetFirst = edge == .top || edge == .leading
        let children = insetFirst
            ? [gtkDescribeView(inset), gtkDescribeView(content)]
            : [gtkDescribeView(content), gtkDescribeView(inset)]
        return GTK4DescriptorNode(
            kind: .safeAreaInset, typeName: "SafeAreaInsetView",
            props: .safeAreaInset(GTK4SafeAreaInsetDescriptor(
                edge: edge, alignment: alignment, spacing: spacing)),
            children: children)
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let isVertical: Bool
        let insetFirst: Bool

        switch edge {
        case .top:
            isVertical = true
            insetFirst = true
        case .bottom:
            isVertical = true
            insetFirst = false
        case .leading:
            isVertical = false
            insetFirst = true
        case .trailing:
            isVertical = false
            insetFirst = false
        }

        let orientation = isVertical ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL
        let box = gtk_box_new(orientation, gint(spacing))!

        let contentWidget = widgetFromOpaque(gtkRenderView(content))
        let insetWidget = widgetFromOpaque(gtkRenderView(inset))

        // Cross-axis alignment for the inset content
        let crossAlign: GtkAlign
        switch alignment {
        case .horizontal(let hAlign):
            switch hAlign {
            case .leading:  crossAlign = GTK_ALIGN_START
            case .center:   crossAlign = GTK_ALIGN_CENTER
            case .trailing: crossAlign = GTK_ALIGN_END
            }
        case .vertical(let vAlign):
            switch vAlign {
            case .top:    crossAlign = GTK_ALIGN_START
            case .center: crossAlign = GTK_ALIGN_CENTER
            case .bottom: crossAlign = GTK_ALIGN_END
            }
        }

        if isVertical {
            gtk_widget_set_halign(insetWidget, crossAlign)
        } else {
            gtk_widget_set_valign(insetWidget, crossAlign)
        }

        if insetFirst {
            gtk_box_append(boxPointer(box), insetWidget)
            gtk_box_append(boxPointer(box), contentWidget)
        } else {
            gtk_box_append(boxPointer(box), contentWidget)
            gtk_box_append(boxPointer(box), insetWidget)
        }

        // Preserve expand flags from content — do not manufacture expansion
        if gtk_widget_get_hexpand(contentWidget) != 0 { gtk_widget_set_hexpand(box, 1) }
        if gtk_widget_get_vexpand(contentWidget) != 0 { gtk_widget_set_vexpand(box, 1) }

        return opaqueFromWidget(box)
    }
}

/// Synthetic safe-area padding default when length is nil (Batch A).
private let gtkSyntheticSafeAreaPadding = 16

/// Resolve per-edge safe-area padding. Negative lengths clamp to 0.
private func gtkResolveSafeAreaPadding(edges: Edge.Set, length: Int?) -> (top: Int, bottom: Int, leading: Int, trailing: Int) {
    let resolved = max(0, length ?? gtkSyntheticSafeAreaPadding)
    return (
        top: edges.contains(.top) ? resolved : 0,
        bottom: edges.contains(.bottom) ? resolved : 0,
        leading: edges.contains(.leading) ? resolved : 0,
        trailing: edges.contains(.trailing) ? resolved : 0
    )
}

extension SafeAreaPaddingView: GTKRenderable, GTKDescribable {
    public func gtkDescribeNode() -> GTK4DescriptorNode {
        let p = gtkResolveSafeAreaPadding(edges: edges, length: length)
        return GTK4DescriptorNode(
            kind: .safeAreaPadding, typeName: "SafeAreaPaddingView",
            props: .safeAreaPadding(GTK4SafeAreaPaddingDescriptor(
                top: p.top, bottom: p.bottom, leading: p.leading, trailing: p.trailing)),
            children: [gtkDescribeView(content)])
    }

    public func gtkCreateWidget() -> OpaquePointer {
        let p = gtkResolveSafeAreaPadding(edges: edges, length: length)

        let child = widgetFromOpaque(gtkRenderView(content))
        let wrapper = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        applyCSSToWidget(wrapper, properties: """
            padding-top: \(p.top)px;
            padding-bottom: \(p.bottom)px;
            padding-left: \(p.leading)px;
            padding-right: \(p.trailing)px;
            """)
        if gtk_widget_get_hexpand(child) != 0 { gtk_widget_set_hexpand(wrapper, 1) }
        if gtk_widget_get_vexpand(child) != 0 { gtk_widget_set_vexpand(wrapper, 1) }
        gtk_box_append(boxPointer(wrapper), child)
        return opaqueFromWidget(wrapper)
    }
}

// MARK: - ViewThatFits GTK extension

private class GTKViewThatFitsContext {
    let stack: UnsafeMutablePointer<GtkWidget>
    let childWidgets: [UnsafeMutablePointer<GtkWidget>]
    let childCount: Int
    private var currentIndex: Int = 0
    private var lastWidth: Int = -1
    private var lastHeight: Int = -1

    init(stack: UnsafeMutablePointer<GtkWidget>,
         childWidgets: [UnsafeMutablePointer<GtkWidget>],
         childCount: Int) {
        self.stack = stack
        self.childWidgets = childWidgets
        self.childCount = childCount
    }

    /// Called each frame via tick callback. Re-evaluates only when size changes.
    func tickCheck() {
        guard childCount > 0 else { return }
        let w = Int(gtk_widget_get_width(stack))
        let h = Int(gtk_widget_get_height(stack))
        guard w > 0 && h > 0 else { return }
        guard w != lastWidth || h != lastHeight else { return }
        lastWidth = w
        lastHeight = h
        selectBestFit(allocWidth: w, allocHeight: h)
    }

    private func selectBestFit(allocWidth: Int, allocHeight: Int) {
        var bestIndex = childCount - 1 // fallback to last
        for i in 0..<childCount {
            let child = childWidgets[i]
            var naturalWidth: gint = 0
            var naturalHeight: gint = 0
            gtk_widget_measure(child, GTK_ORIENTATION_HORIZONTAL, -1,
                               nil, &naturalWidth, nil, nil)
            gtk_widget_measure(child, GTK_ORIENTATION_VERTICAL, gint(allocWidth),
                               nil, &naturalHeight, nil, nil)

            if Int(naturalWidth) <= allocWidth && Int(naturalHeight) <= allocHeight {
                bestIndex = i
                break
            }
        }

        if bestIndex != currentIndex {
            currentIndex = bestIndex
            gtk_stack_set_visible_child_name(
                OpaquePointer(stack), "vtf-\(bestIndex)")
        }
    }
}

/// Tick callback for ViewThatFits — re-evaluates child selection on size changes.
private func gtkViewThatFitsTickCallback(
    _ widget: UnsafeMutablePointer<GtkWidget>?,
    _ frameClock: OpaquePointer?,
    _ userData: gpointer?
) -> gboolean {
    guard let userData = userData else { return 1 }
    let ctx = Unmanaged<GTKViewThatFitsContext>.fromOpaque(userData).takeUnretainedValue()
    ctx.tickCheck()
    return 1 // keep running
}

extension ViewThatFits: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let stack = gtk_stack_new()!
        let stackOp = OpaquePointer(stack)
        gtk_stack_set_transition_type(stackOp, GTK_STACK_TRANSITION_TYPE_NONE)

        var childWidgets: [UnsafeMutablePointer<GtkWidget>] = []
        for (i, child) in children.enumerated() {
            let widget = widgetFromOpaque(gtkRenderAnyView(child))
            gtk_stack_add_named(stackOp, widget, "vtf-\(i)")
            childWidgets.append(widget)
        }

        if !children.isEmpty {
            gtk_stack_set_visible_child_name(stackOp, "vtf-0")
        }

        let context = GTKViewThatFitsContext(
            stack: stack,
            childWidgets: childWidgets,
            childCount: children.count
        )

        // Tick callback re-evaluates which child fits on each frame when size changes.
        // Automatically paused when the widget is unmapped.
        let contextPtr = Unmanaged.passRetained(context).toOpaque()
        _ = gtk_widget_add_tick_callback(
            stack,
            gtkViewThatFitsTickCallback,
            contextPtr,
            { userData in Unmanaged<GTKViewThatFitsContext>.fromOpaque(userData!).release() }
        )

        return opaqueFromWidget(stack)
    }
}
