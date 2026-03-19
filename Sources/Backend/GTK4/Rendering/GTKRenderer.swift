import CGTK
import CGTKBridge
import SwiftOpenUI
import Foundation

/// Marker string for Spacer widgets.
let gtkSwiftSpacerMarker = "gtk-swift-spacer"

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

// MARK: - View GTK extensions

extension Text: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let label = gtk_label_new(content)!
        gtk_swift_label_set_xalign(label, 0)
        return opaqueFromWidget(label)
    }
}

extension EmptyView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        opaqueFromWidget(gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!)
    }
}

extension Spacer: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let label = gtk_label_new(nil)!
        let gobject = UnsafeMutableRawPointer(label).assumingMemoryBound(to: GObject.self)
        g_object_set_data(gobject, gtkSwiftSpacerMarker, UnsafeMutableRawPointer(bitPattern: 1))
        return opaqueFromWidget(label)
    }
}

extension Divider: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        opaqueFromWidget(gtk_separator_new(GTK_ORIENTATION_HORIZONTAL)!)
    }
}

extension TextField: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let entry = gtk_entry_new()!
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

extension Color: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_widget_set_hexpand(box, 1)
        gtk_widget_set_vexpand(box, 1)
        let css = String(format: "background-color: rgba(%d, %d, %d, %.3f);",
                         Int(red * 255), Int(green * 255), Int(blue * 255), alpha)
        applyCSSToWidget(box, properties: css)
        return opaqueFromWidget(box)
    }
}

extension Button: GTKRenderable {
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
        }

        gtk_widget_set_hexpand(button, 0)
        gtk_widget_set_halign(button, GTK_ALIGN_START)

        let box = Unmanaged.passRetained(ClosureBox(action)).toOpaque()
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
        return opaqueFromWidget(button)
    }
}

// MARK: - Container GTK extensions

extension VStack: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, gint(spacing))!
        var needsHExpand = false
        var needsVExpand = false

        let gtkAlign: GtkAlign
        switch alignment {
        case .leading:  gtkAlign = GTK_ALIGN_START
        case .center:   gtkAlign = GTK_ALIGN_CENTER
        case .trailing: gtkAlign = GTK_ALIGN_END
        }

        for child in gtkRenderChildren(content) {
            let widget = widgetFromOpaque(child)
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
}

extension HStack: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, gint(spacing))!
        var needsHExpand = false
        var needsVExpand = false

        let gtkAlign: GtkAlign
        switch alignment {
        case .top:    gtkAlign = GTK_ALIGN_START
        case .center: gtkAlign = GTK_ALIGN_CENTER
        case .bottom: gtkAlign = GTK_ALIGN_END
        }

        for child in gtkRenderChildren(content) {
            let widget = widgetFromOpaque(child)
            let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
            if g_object_get_data(gobject, gtkSwiftSpacerMarker) != nil {
                gtk_widget_set_hexpand(widget, 1)
                gtk_widget_set_vexpand(widget, 0)
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
}

extension ZStack: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let overlay = gtk_overlay_new()!
        var first = true
        for child in gtkRenderChildren(content) {
            let widget = widgetFromOpaque(child)
            if first {
                gtk_overlay_set_child(OpaquePointer(overlay), widget)
                first = false
            } else {
                gtk_overlay_add_overlay(OpaquePointer(overlay), widget)
            }
        }
        return opaqueFromWidget(overlay)
    }
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

extension PaddedView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let child = widgetFromOpaque(gtkRenderView(content))
        let wrapper = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        applyCSSToWidget(wrapper, properties: """
            padding-top: \(top)px;
            padding-bottom: \(bottom)px;
            padding-left: \(leading)px;
            padding-right: \(trailing)px;
            """)
        if gtk_widget_get_hexpand(child) != 0 { gtk_widget_set_hexpand(wrapper, 1) }
        if gtk_widget_get_vexpand(child) != 0 { gtk_widget_set_vexpand(wrapper, 1) }
        gtk_box_append(boxPointer(wrapper), child)
        return opaqueFromWidget(wrapper)
    }
}

extension FrameView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let child = widgetFromOpaque(gtkRenderView(content))
        let wrapper = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        var css = ""
        if let w = width {
            css += "min-width: \(Int(w))px; max-width: \(Int(w))px; "
            gtk_widget_set_hexpand(wrapper, 0)
        }
        if let h = height {
            css += "min-height: \(Int(h))px; max-height: \(Int(h))px; "
            gtk_widget_set_vexpand(wrapper, 0)
        }
        if let mw = minWidth { css += "min-width: \(Int(mw))px; " }
        if let mh = minHeight { css += "min-height: \(Int(mh))px; " }
        if let xw = maxWidth {
            if xw == .infinity { gtk_widget_set_hexpand(wrapper, 1) }
            else { css += "max-width: \(Int(xw))px; " }
        }
        if let xh = maxHeight {
            if xh == .infinity { gtk_widget_set_vexpand(wrapper, 1) }
            else { css += "max-height: \(Int(xh))px; " }
        }
        if !css.isEmpty { applyCSSToWidget(wrapper, properties: css) }
        gtk_box_append(boxPointer(wrapper), child)
        return opaqueFromWidget(wrapper)
    }
}

extension ForegroundColorView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        applyCSSToWidget(widget, properties: "color: \(color.hex);")
        return opaqueFromWidget(widget)
    }
}

extension BackgroundView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        applyCSSToWidget(widget, properties: "background-color: \(color.hex);")
        return opaqueFromWidget(widget)
    }
}

extension FontModifiedView: GTKRenderable {
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

extension BorderView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        applyCSSToWidget(widget, properties: "border: \(width)px solid \(color.hex);")
        return opaqueFromWidget(widget)
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

extension TapGestureView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        let gesture = gtk_gesture_click_new()!

        let box = Unmanaged.passRetained(TapClosureBox(count: count, action: action)).toOpaque()
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

        let box = Unmanaged.passRetained(ClosureBox(action)).toOpaque()
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

extension DragGestureView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        let gesture = gtk_gesture_drag_new()!

        let dragState = GTKDragState()

        if let onChanged = onChanged {
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
                onChanged(value)
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
                onEnded(value)
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

/// Build a combined CSS transform string from offset and scale values.
func buildTransformCSS(offsetX: Double, offsetY: Double, scaleX: Double, scaleY: Double) -> String {
    var parts: [String] = []
    if offsetX != 0 || offsetY != 0 {
        parts.append("translate(\(Int(offsetX))px, \(Int(offsetY))px)")
    }
    if scaleX != 1 || scaleY != 1 {
        parts.append("scale(\(scaleX), \(scaleY))")
    }
    guard !parts.isEmpty else { return "" }
    return "transform: \(parts.joined(separator: " "));"
}

extension OpacityView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        gtk_widget_set_opacity(widget, opacity)
        return opaqueFromWidget(widget)
    }
}

extension OffsetView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        setWidgetDouble(widget, key: gtkSwiftOffsetXKey, value: x)
        setWidgetDouble(widget, key: gtkSwiftOffsetYKey, value: y)
        if x != 0 || y != 0 {
            let scaleX = getWidgetDouble(widget, key: gtkSwiftScaleXKey) ?? 1
            let scaleY = getWidgetDouble(widget, key: gtkSwiftScaleYKey) ?? 1
            applyCSSToWidget(widget, properties: buildTransformCSS(offsetX: x, offsetY: y, scaleX: scaleX, scaleY: scaleY))
        }
        return opaqueFromWidget(widget)
    }
}

extension ScaleEffectView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        setWidgetDouble(widget, key: gtkSwiftScaleXKey, value: scaleX)
        setWidgetDouble(widget, key: gtkSwiftScaleYKey, value: scaleY)
        if scaleX != 1 || scaleY != 1 {
            let offsetX = getWidgetDouble(widget, key: gtkSwiftOffsetXKey) ?? 0
            let offsetY = getWidgetDouble(widget, key: gtkSwiftOffsetYKey) ?? 0
            applyCSSToWidget(widget, properties: buildTransformCSS(offsetX: offsetX, offsetY: offsetY, scaleX: scaleX, scaleY: scaleY))
        }
        return opaqueFromWidget(widget)
    }
}

extension AnimatedView: GTKRenderable {
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
            return opaqueFromWidget(hbox)
        }

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

extension RotationView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let inner = widgetFromOpaque(gtkRenderView(content))
        let wrapper = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_box_append(boxPointer(wrapper), inner)
        applyCSSToWidget(wrapper, properties: "transform: rotate(\(angle)deg);")
        return opaqueFromWidget(wrapper)
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
        gtk_widget_set_halign(overlayWidget, hAlign)
        gtk_widget_set_valign(overlayWidget, vAlign)
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

        return opaqueFromWidget(check)
    }
}

// MARK: - Slider GTK extension

/// Debounced slider state. Accumulates value changes and commits after
/// a short delay so dragging doesn't trigger constant rebuilds.
private class SliderState {
    let closure: (Double) -> Void
    var pendingValue: Double = 0
    var timerSource: guint = 0

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

extension Slider: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let scale = gtk_scale_new_with_range(
            GTK_ORIENTATION_HORIZONTAL,
            range.lowerBound,
            range.upperBound,
            step
        )!

        gtk_widget_set_hexpand(scale, 1)
        gtk_range_set_value(rangePointer(scale), value.wrappedValue)

        let binding = value
        let stepVal = step
        let state = SliderState { newValue in
            if abs(newValue - binding.wrappedValue) > stepVal * 0.01 {
                binding.wrappedValue = newValue
            }
        }
        let statePtr = Unmanaged.passRetained(state).toOpaque()

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

        return opaqueFromWidget(scale)
    }
}

// MARK: - ScrollView GTK extension

extension ScrollView: GTKRenderable {
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
        let image: UnsafeMutablePointer<GtkWidget>
        switch source {
        case .systemName(let name):
            image = gtk_image_new_from_icon_name(name)!
            gtk_swift_image_set_pixel_size(image, gint(scale.pointSize))
        case .filePath(let path):
            image = gtk_image_new_from_file(path)!
            let size = gint(scale.pointSize)
            gtk_widget_set_size_request(image, size, size)
        }
        return opaqueFromWidget(image)
    }
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

extension _ViewModifierContent: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        gtkRenderAnyView(wrapped.wrapped)
    }
}

// MARK: - TupleView GTK extensions

extension TupleView2: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        for child in [gtkRenderView(v0), gtkRenderView(v1)] {
            gtk_box_append(boxPointer(box), widgetFromOpaque(child))
        }
        return opaqueFromWidget(box)
    }
}

extension TupleView3: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        for child in [gtkRenderView(v0), gtkRenderView(v1), gtkRenderView(v2)] {
            gtk_box_append(boxPointer(box), widgetFromOpaque(child))
        }
        return opaqueFromWidget(box)
    }
}

// MARK: - Stateful view rendering

private func gtkRenderStatefulView<V: View>(_ view: V) -> OpaquePointer {
    let host = GTKViewHost(buildBody: {
        gtkRenderView(view.body)
    })

    installState(view, host: host)

    let previousHost = GTKViewHost.getCurrentRebuilding()
    GTKViewHost.setCurrentRebuilding(host)
    let widget = host.buildBody()
    GTKViewHost.setCurrentRebuilding(previousHost)

    let child = widgetFromOpaque(widget)
    let childHexpand = gtk_widget_get_hexpand(child) != 0
    let childVexpand = gtk_widget_get_vexpand(child) != 0
    gtk_widget_set_hexpand(host.container, childHexpand ? 1 : 0)
    gtk_widget_set_vexpand(host.container, childVexpand ? 1 : 0)
    gtk_box_append(boxPointer(host.container), child)

    return opaqueFromWidget(host.container)
}
