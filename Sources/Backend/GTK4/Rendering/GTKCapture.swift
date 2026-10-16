import CGTK
import CGTKBridge
import Foundation

// MARK: - Self-capture for scale verification

/// Environment variable naming the PNG file to write. When set, the first
/// window presented renders itself to that file and the app quits.
let gtkCaptureEnvironmentKey = "SWIFTOPENUI_GTK_CAPTURE"
/// Optional delay in milliseconds before the capture (default 1500), so
/// the window can map, lay out and settle first.
let gtkCaptureDelayEnvironmentKey = "SWIFTOPENUI_GTK_CAPTURE_DELAY_MS"

private var gtkCaptureScheduled = false

/// Schedules a one-shot capture of `window` if `SWIFTOPENUI_GTK_CAPTURE` is set.
///
/// The window renders its own snapshot at the surface's real (possibly
/// fractional) scale, so the PNG has the physical pixels the compositor
/// receives. This works where compositor screenshot APIs are unavailable,
/// such as a headless GNOME Shell used to test 150% scaling. The scale
/// values GTK reports are printed to stderr. See
/// `docs/architecture/logical-coordinates.md`.
func gtkScheduleCaptureIfRequested(_ window: UnsafeMutablePointer<GtkWindow>) {
    let environment = ProcessInfo.processInfo.environment
    guard !gtkCaptureScheduled, let path = environment[gtkCaptureEnvironmentKey], !path.isEmpty else {
        return
    }
    gtkCaptureScheduled = true
    let delay = environment[gtkCaptureDelayEnvironmentKey].flatMap { UInt32($0) } ?? 1500

    let box = Unmanaged.passRetained(ClosureBox {
        gtkCaptureWindow(window, to: path)
        if let app = gtk_window_get_application(window) {
            g_application_quit(UnsafeMutableRawPointer(app).assumingMemoryBound(to: GApplication.self))
        }
    }).toOpaque()
    g_timeout_add(delay, { userData -> gboolean in
        guard let userData else { return 0 }
        let box = Unmanaged<ClosureBox>.fromOpaque(userData).takeRetainedValue()
        box.closure()
        return 0  // G_SOURCE_REMOVE
    }, box)
}

private func gtkCaptureWindow(_ window: UnsafeMutablePointer<GtkWindow>, to path: String) {
    let widget = widgetPointer(window)
    let native = OpaquePointer(window)
    guard let surface = gtk_native_get_surface(native),
          let renderer = gtk_native_get_renderer(native) else {
        fputs("swiftopenui-capture: window has no surface or renderer\n", stderr)
        return
    }
    let scale = gdk_surface_get_scale(surface)
    let width = gtk_widget_get_width(widget)
    let height = gtk_widget_get_height(widget)

    // Snapshot the window at logical size, then scale the node to device pixels.
    let paintable = gtk_widget_paintable_new(widget)
    let logical = gtk_snapshot_new()
    gdk_paintable_snapshot(paintable, logical, Double(width), Double(height))
    g_object_unref(gpointer(paintable))
    guard let node = gtk_snapshot_free_to_node(logical) else {
        fputs("swiftopenui-capture: window produced no render node\n", stderr)
        return
    }
    let device = gtk_snapshot_new()
    gtk_snapshot_scale(device, Float(scale), Float(scale))
    gtk_snapshot_append_node(device, node)
    gsk_render_node_unref(node)
    guard let scaledNode = gtk_snapshot_free_to_node(device) else { return }

    var bounds = graphene_rect_t()
    graphene_rect_init(&bounds, 0, 0, Float(Double(width) * scale), Float(Double(height) * scale))
    let texture = gsk_renderer_render_texture(renderer, scaledNode, &bounds)
    gsk_render_node_unref(scaledNode)
    guard let texture else {
        fputs("swiftopenui-capture: render failed\n", stderr)
        return
    }
    let saved = gdk_texture_save_to_png(texture, path) != 0
    fputs(
        "swiftopenui-capture: surface-scale=\(scale) scale-factor=\(gtk_widget_get_scale_factor(widget)) "
            + "window=\(width)x\(height)pt png=\(gdk_texture_get_width(texture))x\(gdk_texture_get_height(texture))px "
            + "\(saved ? "saved" : "FAILED") \(path)\n",
        stderr
    )
    g_object_unref(gpointer(texture))
}
