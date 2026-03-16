import WinSDK
import CWin32

/// Custom message ID for coalesced view rebuilds.
public let WM_SWIFTUI_REBUILD: UINT = UINT(WM_APP) + 1

/// Custom message ID for running arbitrary closures on the UI thread.
public let WM_SWIFTUI_INVOKE: UINT = UINT(WM_APP) + 2

/// Post a closure to run on the UI thread via the message loop.
public func runOnMainThread(hwnd: HWND, _ work: @escaping () -> Void) {
    let box = Unmanaged.passRetained(ClosureBox(work)).toOpaque()
    PostMessageW(hwnd, WM_SWIFTUI_INVOKE, 0, LPARAM(Int(bitPattern: box)))
}

/// Dispatch a WM_SWIFTUI_INVOKE message. Call from WndProc.
public func dispatchInvoke(lParam: LPARAM) {
    let ptr = UnsafeMutableRawPointer(bitPattern: Int(lParam))!
    let box = Unmanaged<ClosureBox>.fromOpaque(ptr).takeRetainedValue()
    box.closure()
}
