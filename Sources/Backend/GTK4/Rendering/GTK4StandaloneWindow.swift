import CGTK
import CGTKBridge
import SwiftOpenUI
import Foundation

/// Handle to a standalone GTK window opened imperatively via
/// ``GTK4Backend/openStandaloneWindow(title:width:height:onClose:content:)``.
///
/// The caller retains the handle to keep control of the window's lifetime. The
/// window is owned by GTK; ``close()`` destroys it, and a user close (WM close
/// button) is reported through the `onClose` callback and flips ``isOpen`` to
/// `false`. This is the GTK4 analogue of the AppKit `NSWindow` + delegate that
/// backs `LyrebirdWindow` on macOS.
public final class GTK4StandaloneWindowHandle {

    /// Live GTK window pointer, or `nil` once the window has been closed
    /// (either via ``close()`` or by the user). Cleared by the destroy signal,
    /// so it is a single source of truth for "is this window still open".
    fileprivate var winPtr: UnsafeMutablePointer<GtkWindow>?

    fileprivate init(winPtr: UnsafeMutablePointer<GtkWindow>) {
        self.winPtr = winPtr
    }

    /// Whether the window is still open.
    public var isOpen: Bool { winPtr != nil }

    /// Bring the window to the front (no-op once closed).
    public func present() {
        guard let win: UnsafeMutablePointer<GtkWindow> = winPtr else { return }
        gtk_window_present(win)
    }

    /// Close and destroy the window. The destroy signal clears ``winPtr`` and
    /// fires the `onClose` callback, so calling this more than once is safe.
    public func close() {
        guard let win: UnsafeMutablePointer<GtkWindow> = winPtr else { return }
        gtk_window_destroy(win)
    }
}

extension GTK4Backend {

    /// Open a standalone top-level GTK window hosting `content`, parented to the
    /// running `GtkApplication` started by ``run(_:)``.
    ///
    /// This is the imperative counterpart to the declarative `Window` /scene
    /// path: it opens a window at runtime from outside the App/Scene tree, which
    /// is what a host like `LyrebirdWindow`'s "Open Window" buttons need.
    ///
    /// - Important: A `GtkApplication` must already be running (i.e. you are
    ///   inside a ``run(_:)`` main loop). If there is no default application,
    ///   this returns `nil`.
    ///
    /// - Parameters:
    ///   - title: Window title-bar text.
    ///   - width: Initial window width in points.
    ///   - height: Initial window height in points.
    ///   - onClose: Invoked (once) when the window is closed, whether by
    ///     ``GTK4StandaloneWindowHandle/close()`` or by the user. Runs on the
    ///     GTK main thread.
    ///   - content: The SwiftOpenUI view to host.
    /// - Returns: A handle for controlling/closing the window, or `nil` if no
    ///   `GtkApplication` is running.
    public static func openStandaloneWindow<Content: View>(
        title: String,
        width: Int,
        height: Int,
        onClose: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> GTK4StandaloneWindowHandle? {
        guard let appPtr: UnsafeMutablePointer<GtkApplication> = gtk_swift_get_default_gtk_application() else {
            return nil
        }

        guard let rawWindow = gtk_application_window_new(appPtr) else { return nil }
        let winPtr: UnsafeMutablePointer<GtkWindow> = windowPointer(rawWindow)
        gtk_window_set_title(winPtr, title)
        gtk_window_set_default_size(winPtr, gint(width), gint(height))

        let contentWidget: UnsafeMutablePointer<GtkWidget> = widgetFromOpaque(gtkRenderView(content()))
        gtkConfigureRootContentToFillWindow(contentWidget)
        gtk_window_set_child(winPtr, contentWidget)

        let handle: GTK4StandaloneWindowHandle = GTK4StandaloneWindowHandle(winPtr: winPtr)

        // Single teardown path: the destroy signal clears the handle and fires
        // onClose exactly once, covering both close() and the WM close button.
        // The handle is captured weakly so dropping the caller's reference does
        // not keep it alive; onClose is captured strongly so it still fires.
        let box: ClosureBox = ClosureBox { [weak handle] in
            handle?.winPtr = nil
            onClose?()
        }
        let userData: UnsafeMutableRawPointer = Unmanaged.passRetained(box).toOpaque()
        g_signal_connect_data(
            gpointer(winPtr), "destroy",
            unsafeBitCast({ (_: gpointer?, ud: gpointer?) in
                guard let ud else { return }
                Unmanaged<ClosureBox>.fromOpaque(ud).takeUnretainedValue().closure()
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            userData,
            { (data: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                if let data { Unmanaged<ClosureBox>.fromOpaque(data).release() }
            },
            GConnectFlags(rawValue: 0)
        )

        gtk_window_present(winPtr)
        return handle
    }
}
