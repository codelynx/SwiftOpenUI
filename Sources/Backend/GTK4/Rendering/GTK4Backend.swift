import CGTK
import CGTKBridge
import SwiftOpenUI
import Foundation

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

        let contentWidget = widgetFromOpaque(gtkRenderView(content))
        if let titlebarWidget = findTitlebar(in: contentWidget) {
            gtk_window_set_titlebar(winPtr, titlebarWidget)
        }

        // Apply minimum content size where configured. GTK4 window sizing is
        // largely content-driven, so min constraints are expressed on the root.
        let minReqW = minWindowWidth.map { Int32($0) } ?? -1
        let minReqH = minWindowHeight.map { Int32($0) } ?? -1
        if minReqW >= 0 || minReqH >= 0 {
            gtk_widget_set_size_request(contentWidget, minReqW, minReqH)
        }

        switch windowSizing ?? .automatic {
        case .automatic, .content:
            if let w = defaultWindowWidth, let h = defaultWindowHeight {
                gtk_window_set_default_size(winPtr, gint(w), gint(h))
            }
        case .contentFixed:
            if let w = defaultWindowWidth, let h = defaultWindowHeight {
                gtk_window_set_default_size(winPtr, gint(w), gint(h))
            }
            gtk_window_set_resizable(winPtr, 0)
        case .size(let width, let height):
            gtk_window_set_default_size(winPtr, gint(width), gint(height))
        }

        switch windowResizeBehavior ?? .automatic {
        case .automatic:
            break
        case .fixed:
            gtk_window_set_resizable(winPtr, 0)
        case .resizable:
            gtk_window_set_resizable(winPtr, 1)
        }

        // SwiftUI-compatible .windowResizability() — takes precedence
        // over windowResizeBehavior when set.
        switch windowResizability {
        case .contentSize:
            gtk_window_set_resizable(winPtr, 0)
        case .contentMinSize, .automatic:
            break  // resizable (default GTK4 behavior)
        case nil:
            break
        }

        // If the root content doesn't expand, center it in the window
        // (matches SwiftUI where root views fill the proposed size and
        // content like Text is centered by default).
        if gtk_widget_get_hexpand(contentWidget) == 0 {
            gtk_widget_set_halign(contentWidget, GTK_ALIGN_CENTER)
            gtk_widget_set_hexpand(contentWidget, 1)
        }
        if gtk_widget_get_vexpand(contentWidget) == 0 {
            gtk_widget_set_valign(contentWidget, GTK_ALIGN_CENTER)
            gtk_widget_set_vexpand(contentWidget, 1)
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
            // Inject openWindow action into the environment so views
            // can programmatically open Window scenes by id.
            var env = getCurrentEnvironment()
            env.openWindow = OpenWindowAction { id in
                GTK4WindowRegistry.shared.open(id: id)
            }
            setCurrentEnvironment(env)

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

        // Pump Foundation RunLoop sources (Timer, etc.) periodically.
        // GTK4's g_application_run blocks in GMainLoop, so Foundation
        // timers (e.g. Timer.scheduledTimer) never fire unless we
        // explicitly spin RunLoop.main from a GLib timeout source.
        g_timeout_add(5, { _ -> gboolean in
            let limit = Date(timeIntervalSinceNow: 0.001)
            _ = RunLoop.main.run(mode: .default, before: limit)
            return 1 // G_SOURCE_CONTINUE
        }, nil)

        let status = g_application_run(applicationPointer(appPtr), 0, nil)
        g_object_unref(gpointer(appPtr))

        if status != 0 {
            print("GTK application exited with status \(status)")
        }
    }
}

/// GTK4 rendering for Window scenes (single-instance, identified windows).
extension Window: GTKWindowRenderable {
    func gtkRender(app: OpaquePointer) {
        // Suppressed windows are not shown at launch — they are opened
        // programmatically via the openWindow environment action.
        if launchBehavior == .suppressed {
            // Register a factory so openWindow(id:) can create it later.
            GTK4WindowRegistry.shared.register(id: id) { [self] in
                self.gtkCreateWindow(app: app)
            }
            return
        }
        gtkCreateWindow(app: app)
    }

    func gtkCreateWindow(app: OpaquePointer) {
        let window = gtk_application_window_new(gtkApplicationPointer(app))!
        let winPtr = windowPointer(window)
        gtk_window_set_title(winPtr, title)

        let contentWidget = widgetFromOpaque(gtkRenderView(content))

        if let w = defaultWindowWidth, let h = defaultWindowHeight {
            gtk_window_set_default_size(winPtr, gint(w), gint(h))
        }

        let minReqW = minWindowWidth.map { Int32($0) } ?? -1
        let minReqH = minWindowHeight.map { Int32($0) } ?? -1
        if minReqW >= 0 || minReqH >= 0 {
            gtk_widget_set_size_request(contentWidget, minReqW, minReqH)
        }

        if gtk_widget_get_hexpand(contentWidget) == 0 {
            gtk_widget_set_halign(contentWidget, GTK_ALIGN_CENTER)
            gtk_widget_set_hexpand(contentWidget, 1)
        }
        if gtk_widget_get_vexpand(contentWidget) == 0 {
            gtk_widget_set_valign(contentWidget, GTK_ALIGN_CENTER)
            gtk_widget_set_vexpand(contentWidget, 1)
        }

        gtk_window_set_child(winPtr, contentWidget)
        gtk_window_present(winPtr)
    }
}

/// GTK4 rendering for TupleScene — renders both child scenes.
extension TupleScene: GTKWindowRenderable {
    func gtkRender(app: OpaquePointer) {
        gtkRenderScene(scene0, app: app)
        gtkRenderScene(scene1, app: app)
    }
}

/// Registry for on-demand window factories (used by suppressed Window scenes).
class GTK4WindowRegistry {
    static let shared = GTK4WindowRegistry()
    private var factories: [String: () -> Void] = [:]

    func register(id: String, factory: @escaping () -> Void) {
        factories[id] = factory
    }

    func open(id: String) {
        factories[id]?()
    }
}

/// Recursively render a Scene. Terminal scenes (WindowGroup, Window) render
/// directly; composite scenes recurse through their body.
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
