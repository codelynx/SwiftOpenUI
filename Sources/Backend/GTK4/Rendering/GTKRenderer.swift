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
        // Use g_object_ref so the widget stays alive for the closure.
        g_object_ref(gpointer(widget))
        state.storage.onProgrammaticFocusChange = { [weak storage = state.storage] newValue in
            guard storage != nil else { return }
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
        g_object_ref(gpointer(widget))
        let prevHandler = state.storage.onProgrammaticFocusChange
        state.storage.onProgrammaticFocusChange = { newValue in
            if newValue == matchValue {
                gtk_swift_grab_focus(widget)
            } else if newValue == nil {
                gtk_swift_clear_focus(widget)
            } else {
                // Different value — let another FocusedEqualsView handle it
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
        if let w = width { css += "min-width: \(Int(w))px; max-width: \(Int(w))px; " }
        if let h = height { css += "min-height: \(Int(h))px; max-height: \(Int(h))px; " }
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
