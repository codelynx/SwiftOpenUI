import CGTK
import CGTKBridge
import Foundation

/// Process-wide sink for pointer motion/button events from the windows
/// `GTK4Backend` opens. A host (e.g. Lyrebird's Linux `MouseTracker`) installs
/// handlers here; the backend attaches a `GtkEventControllerMotion` and a
/// `GtkGestureClick` to each top-level window and forwards normalized updates.
///
/// This is the GTK4 counterpart to a global pointer monitor (AppKit's
/// `NSEvent.addGlobalMonitorForEvents`), scoped window-local: it reports while
/// the pointer is over one of the app's windows. Coordinates are normalized to
/// the window: `x` 0…1 left→right, `y` 0…1 bottom→top (y flipped from GTK's
/// top-left origin so it matches screen-up conventions). `pressed` is the
/// primary-button state.
///
/// Handlers run on the GTK main thread.
public enum GTK4PointerTracking {

    /// Normalized (x, y) move handler. Set via ``install(onMove:onButton:)``.
    nonisolated(unsafe) static var onMove: ((Double, Double) -> Void)?

    /// Primary-button state handler (`true` = pressed).
    nonisolated(unsafe) static var onButton: ((Bool) -> Void)?

    /// Install the pointer sink. Existing windows created before this call are
    /// not retrofitted, but the app's main `WindowGroup` window attaches its
    /// controllers at creation and forwards to whatever is installed here, so
    /// installing before or after `run(_:)` both work.
    ///
    /// - Parameters:
    ///   - onMove: Called with normalized `(x, y)` on pointer motion.
    ///   - onButton: Called with the primary-button state on press/release.
    public static func install(
        onMove: @escaping (Double, Double) -> Void,
        onButton: @escaping (Bool) -> Void
    ) {
        self.onMove = onMove
        self.onButton = onButton
    }
}

/// Attach motion + click controllers to `widget` (a top-level window) that
/// forward to ``GTK4PointerTracking``. Called by the window-creating paths.
func gtkAttachPointerTracking(to widget: UnsafeMutablePointer<GtkWidget>) {
    // Motion: coordinates are in the controlled widget's space; normalize by its
    // current allocation. The widget pointer rides as user_data so the handler
    // can read the live size.
    guard let motion = gtk_event_controller_motion_new() else { return }
    g_signal_connect_data(
        gpointer(motion), "motion",
        unsafeBitCast({ (_: OpaquePointer?, x: Double, y: Double, ud: gpointer?) in
            guard let ud else { return }
            let w: UnsafeMutablePointer<GtkWidget> = ud.assumingMemoryBound(to: GtkWidget.self)
            let width: Double = Double(gtk_widget_get_width(w))
            let height: Double = Double(gtk_widget_get_height(w))
            guard width > 0, height > 0 else { return }
            let nx: Double = min(max(x / width, 0), 1)
            // Flip Y so 1 = top (GTK's origin is top-left).
            let ny: Double = min(max(1 - y / height, 0), 1)
            GTK4PointerTracking.onMove?(nx, ny)
        } as @convention(c) (OpaquePointer?, Double, Double, gpointer?) -> Void,
        to: GCallback.self),
        gpointer(widget), nil,
        GConnectFlags(rawValue: 0)
    )
    gtk_widget_add_controller(widget, motion)

    // Primary-button state. A window-level GtkGestureClick in the default
    // (bubble) phase sees presses not consumed by an interactive child — enough
    // for a baseline Mouse.Click; motion (x/y) is the fully-covered case.
    guard let click = gtk_gesture_click_new() else { return }
    gtk_swift_gesture_single_set_button(click, 1) // primary button
    g_signal_connect_data(
        gpointer(click), "pressed",
        unsafeBitCast({ (_: gpointer?, _: gint, _: Double, _: Double, _: gpointer?) in
            GTK4PointerTracking.onButton?(true)
        } as @convention(c) (gpointer?, gint, Double, Double, gpointer?) -> Void,
        to: GCallback.self),
        nil, nil,
        GConnectFlags(rawValue: 0)
    )
    g_signal_connect_data(
        gpointer(click), "released",
        unsafeBitCast({ (_: gpointer?, _: gint, _: Double, _: Double, _: gpointer?) in
            GTK4PointerTracking.onButton?(false)
        } as @convention(c) (gpointer?, gint, Double, Double, gpointer?) -> Void,
        to: GCallback.self),
        nil, nil,
        GConnectFlags(rawValue: 0)
    )
    gtk_swift_add_gesture(widget, click)
}
