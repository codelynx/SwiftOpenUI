import CGTK
import CGTKBridge
import SwiftOpenUI

/// Recursively search a widget tree for a navigation-provided window titlebar.
private func findTitlebar(in widget: UnsafeMutablePointer<GtkWidget>) -> UnsafeMutablePointer<GtkWidget>? {
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    if let data = g_object_get_data(gobject, "gtk-swift-window-titlebar") {
        return UnsafeMutableRawPointer(data).assumingMemoryBound(to: GtkWidget.self)
    }

    // Search only the visible child of GtkStack to avoid stale titlebars.
    let typeName = String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
    if typeName == "GtkStack" {
        let stackOp = OpaquePointer(widget)
        if let visibleChild = gtk_stack_get_visible_child(stackOp) {
            return findTitlebar(in: visibleChild)
        }
        return nil
    }

    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        if let found = findTitlebar(in: c) {
            return found
        }
        child = gtk_widget_get_next_sibling(c)
    }
    return nil
}

/// Box for passing an activate closure through C user_data.
private class AppActivateBox {
    let activate: (OpaquePointer) -> Void
    init(_ activate: @escaping (OpaquePointer) -> Void) {
        self.activate = activate
    }
}

/// Protocol for scenes that can render onto a GtkApplication.
protocol GTKWindowRenderable {
    func gtkRender(app: OpaquePointer)
}

extension WindowGroup: GTKWindowRenderable {
    func gtkRender(app: OpaquePointer) {
        let window = gtk_application_window_new(gtkApplicationPointer(app))!
        let winPtr = windowPointer(window)
        gtk_window_set_title(winPtr, title)
        gtk_window_set_default_size(winPtr, 400, 300)

        let contentWidget = widgetFromOpaque(gtkRenderView(content))
        if let titlebarWidget = findTitlebar(in: contentWidget) {
            gtk_window_set_titlebar(winPtr, titlebarWidget)
        }
        gtk_window_set_child(winPtr, contentWidget)
        gtk_window_present(winPtr)
    }
}

/// GTK4 rendering backend for SwiftOpenUI.
public struct GTK4Backend: RenderBackend {
    public init() {}

    public func run<A: App>(_ appType: A.Type) {
        let gtkApp = gtk_application_new(nil, G_APPLICATION_DEFAULT_FLAGS)!
        let appPtr = OpaquePointer(gtkApp)

        let factory: (OpaquePointer) -> Void = { appPtr in
            let instance = A()
            gtkRenderScene(instance.body, app: appPtr)
        }

        let box = Unmanaged.passRetained(AppActivateBox(factory)).toOpaque()
        g_signal_connect_data(
            gpointer(appPtr),
            "activate",
            unsafeBitCast({ (app: gpointer?, userData: gpointer?) in
                let box = Unmanaged<AppActivateBox>.fromOpaque(userData!).takeUnretainedValue()
                box.activate(OpaquePointer(app!))
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<AppActivateBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        let status = g_application_run(applicationPointer(appPtr), 0, nil)
        g_object_unref(gpointer(appPtr))

        if status != 0 {
            print("GTK application exited with status \(status)")
        }
    }
}

/// Recursively render a Scene. Terminal scenes (WindowGroup) render directly;
/// composite scenes recurse through their body.
private func gtkRenderScene<S: Scene>(_ scene: S, app: OpaquePointer) {
    if let renderable = scene as? GTKWindowRenderable {
        renderable.gtkRender(app: app)
        return
    }
    // Composite scene — recurse through body
    if S.Body.self != Never.self {
        gtkRenderScene(scene.body, app: app)
    }
}
