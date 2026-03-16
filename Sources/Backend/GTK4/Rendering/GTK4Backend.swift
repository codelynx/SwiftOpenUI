import CGTK
import CGTKBridge
import SwiftOpenUI

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
            let scene = instance.body

            if let renderable = scene as? GTKWindowRenderable {
                renderable.gtkRender(app: appPtr)
            }
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
