import WinSDK
import CWin32

/// Manages the lifecycle of an HWND created by the framework.
///
/// Unlike GObject (ref-counted), Win32 HWNDs are destroyed with DestroyWindow
/// and child windows are auto-destroyed with their parent. HWNDRef tracks
/// ownership to prevent double-destroy.
public class HWNDRef {
    /// The underlying window handle. Nil after destruction.
    public private(set) var hwnd: HWND?

    /// Whether this ref owns the HWND (responsible for calling DestroyWindow).
    public let ownsWindow: Bool

    /// Create an HWNDRef that owns the given window handle.
    public init(owning hwnd: HWND) {
        self.hwnd = hwnd
        self.ownsWindow = true
    }

    /// Create an HWNDRef for a child window (parent will auto-destroy).
    public init(child hwnd: HWND) {
        self.hwnd = hwnd
        self.ownsWindow = false
    }

    /// Mark the HWND as destroyed (called from WM_NCDESTROY handler).
    public func markDestroyed() {
        hwnd = nil
    }

    /// Destroy the window if we own it and it hasn't been destroyed yet.
    public func destroy() {
        guard let hwnd = hwnd, ownsWindow else { return }
        DestroyWindow(hwnd)
        self.hwnd = nil
    }

    deinit {
        destroy()
    }
}
