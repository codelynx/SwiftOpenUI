import WinSDK
import CWin32
import CWin32Bridge
import SwiftOpenUI
import Foundation

/// Hosts a stateful view's Win32 HWND subtree. The container HWND
/// is stable across re-renders — only its children are replaced.
///
/// Uses PostMessage(WM_SWIFTUI_REBUILD) for coalesced scheduling
/// instead of GTK's g_idle_add.
public class Win32ViewHost: AnyViewHost {
    /// The stable container HWND that persists across rebuilds.
    public let container: HWND

    /// Closure that builds the view body and returns the root child HWND.
    public let buildBody: (RenderContext) -> HWND?

    /// The render context for creating child windows.
    private let context: RenderContext

    /// Captured environment at initial render time, restored during rebuilds.
    private var capturedEnvironment: EnvironmentValues?

    private let lock = NSLock()
    private var scheduled = false
    private var isContainerAlive = true
    private var suppressFocusRestoreOnce = false

    /// Current child HWND inside the container.
    private var currentChild: HWND?

    /// The root window to post rebuild messages to.
    private var rootWindow: HWND?

    public init(context: RenderContext, buildBody: @escaping (RenderContext) -> HWND?) {
        self.context = context
        self.buildBody = buildBody

        // Register the container window class once.
        Win32ViewHost.registerContainerClass(hInstance: context.hInstance)

        let containerHwnd = CreateWindowExW(
            0,
            Win32ViewHost.containerClassName,
            nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent,
            nil,
            context.hInstance,
            nil
        )!

        self.container = containerHwnd

        // Store self in the container's user data for retrieval in WndProc
        let retained = Unmanaged.passRetained(self).toOpaque()
        win32_SetWindowLongPtrW(containerHwnd, GWLP_USERDATA, LONG_PTR(Int(bitPattern: retained)))

        // Find the root window for PostMessage
        self.rootWindow = findRootWindow(from: context.parent)
    }

    /// Add the initial child HWND to the container.
    /// Sizes the container to match the child's natural size (not the other way around).
    /// This is critical: the container starts at 0x0, so layoutChild() would crush
    /// the child to zero if we didn't size the container first.
    public func addChild(_ child: HWND) {
        currentChild = child
        SetParent(child, container)

        // Propagate child's natural size up to the container
        var childRect = RECT()
        GetWindowRect(child, &childRect)
        let w = childRect.right - childRect.left
        let h = childRect.bottom - childRect.top
        if w > 0 || h > 0 {
            SetWindowPos(container, nil, 0, 0, w, h, UINT(SWP_NOZORDER | SWP_NOMOVE))
        }
        layoutChild()
    }

    /// Schedule a coalesced rebuild via PostMessage.
    public func scheduleRebuild() {
        lock.lock()
        defer { lock.unlock() }
        guard isContainerAlive else { return }
        guard !scheduled else { return }
        scheduled = true

        if let root = rootWindow {
            let ptr = Unmanaged.passRetained(self).toOpaque()
            PostMessageW(root, WM_SWIFTUI_REBUILD, 0, LPARAM(Int(bitPattern: ptr)))
        }
    }

    public func suppressNextFocusRestore() {
        lock.lock()
        suppressFocusRestoreOnce = true
        lock.unlock()
    }

    /// Capture the current environment.
    public func captureEnvironment() {
        capturedEnvironment = getCurrentEnvironment()
    }

    /// Perform the rebuild.
    public func rebuild() {
        lock.lock()
        scheduled = false
        guard isContainerAlive else {
            lock.unlock()
            return
        }
        let shouldSuppressFocus = suppressFocusRestoreOnce
        suppressFocusRestoreOnce = false
        lock.unlock()

        // Suppress painting during rebuild
        SendMessageW(container, UINT(WM_SETREDRAW), 0, 0)

        // Save focus state (only if we're not suppressing)
        let focusState = shouldSuppressFocus ? nil : saveFocusState(in: container)

        // Build the replacement subtree
        let childContext = RenderContext(parent: container, hInstance: context.hInstance)

        if let old = currentChild {
            DestroyWindow(old)
            currentChild = nil
        }

        let previousEnv = getCurrentEnvironment()
        defer { setCurrentEnvironment(previousEnv) }
        if let captured = capturedEnvironment {
            setCurrentEnvironment(captured)
        }
        let newChild = buildBody(childContext)

        if let newChild = newChild {
            currentChild = newChild
            layoutChild()
        }

        // Restore focus (unless suppressed by @FocusState clearing)
        if let focusState = focusState {
            restoreFocusState(focusState, in: container)
        }

        // Re-enable painting
        SendMessageW(container, UINT(WM_SETREDRAW), 1, 0)
        RedrawWindow(container, nil, nil,
                     UINT(RDW_ERASE | RDW_FRAME | RDW_INVALIDATE | RDW_ALLCHILDREN))
    }

    /// Layout the current child to fill the container.
    func layoutChild() {
        guard let child = currentChild else { return }
        var rect = RECT()
        GetClientRect(container, &rect)
        SetWindowPos(child, nil, 0, 0, rect.right - rect.left, rect.bottom - rect.top, UINT(SWP_NOZORDER))
    }

    /// Called when the container is about to be destroyed.
    public func markDestroyed() {
        lock.lock()
        isContainerAlive = false
        scheduled = false
        lock.unlock()
    }

    // MARK: - Container window class

    private static let containerClassName: UnsafePointer<WCHAR> = {
        "SwiftUIContainer".withCString(encodedAs: UTF16.self) { ptr in
            let len = wcslen(ptr) + 1
            let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
            buf.initialize(from: ptr, count: len)
            return UnsafePointer(buf)
        }
    }()

    private static var classRegistered = false
    private static let classLock = NSLock()

    private static func registerContainerClass(hInstance: HINSTANCE) {
        classLock.lock()
        defer { classLock.unlock() }
        guard !classRegistered else { return }
        classRegistered = true

        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.style = UINT(CS_HREDRAW | CS_VREDRAW)
        wc.lpfnWndProc = containerWndProc
        wc.hInstance = hInstance
        wc.hbrBackground = GetSysColorBrush(COLOR_WINDOW)
        wc.lpszClassName = containerClassName

        RegisterClassExW(&wc)
    }
}

/// WndProc for ViewHost container windows.
private let containerWndProc: WNDPROC = { (hwnd, uMsg, wParam, lParam) in
    switch uMsg {
    case UINT(WM_SIZE):
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0 {
            let host = Unmanaged<Win32ViewHost>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: Int(userData))!
            ).takeUnretainedValue()
            host.layoutChild()
        }
        return 0

    case UINT(WM_COMMAND):
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            SendMessageW(childHwnd, uMsg, wParam, lParam)
        }
        let root = findRootWindow(from: hwnd!)
        return SendMessageW(root, uMsg, wParam, lParam)

    case UINT(WM_HSCROLL), UINT(WM_VSCROLL):
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            return SendMessageW(childHwnd, uMsg, wParam, lParam)
        }
        return 0

    case UINT(WM_CTLCOLORSTATIC), UINT(WM_CTLCOLORBTN):
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetBkMode(hdc, TRANSPARENT)
        return LRESULT(Int(bitPattern: GetSysColorBrush(COLOR_WINDOW)))

    case UINT(WM_NCDESTROY):
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0 {
            let host = Unmanaged<Win32ViewHost>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: Int(userData))!
            )
            host.takeUnretainedValue().markDestroyed()
            host.release()
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

    default:
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
}

// MARK: - Focus save/restore

struct FocusSnapshot {
    let className: String
    let classIndex: Int
    let selStart: Int
    let selEnd: Int
    let hasFocus: Bool
}

func saveFocusState(in container: HWND) -> FocusSnapshot {
    guard let focused = GetFocus() else {
        return FocusSnapshot(className: "", classIndex: 0, selStart: 0, selEnd: 0, hasFocus: false)
    }
    guard IsChild(container, focused) else {
        return FocusSnapshot(className: "", classIndex: 0, selStart: 0, selEnd: 0, hasFocus: false)
    }

    let className = getWindowClassName(focused)
    let classIndex = findClassIndex(hwnd: focused, in: container, className: className)

    var selStart: Int = 0
    var selEnd: Int = 0
    if className == "Edit" {
        let sel = SendMessageW(focused, UINT(EM_GETSEL), 0, 0)
        selStart = Int(win32_LOWORD(DWORD_PTR(sel)))
        selEnd = Int(win32_HIWORD(DWORD_PTR(sel)))
    }

    return FocusSnapshot(className: className, classIndex: classIndex,
                         selStart: selStart, selEnd: selEnd, hasFocus: true)
}

func restoreFocusState(_ snapshot: FocusSnapshot, in parent: HWND) {
    guard snapshot.hasFocus else { return }
    if let target = findNthControlByClass(className: snapshot.className,
                                           index: snapshot.classIndex, in: parent) {
        SetFocus(target)
        if snapshot.className == "Edit" {
            SendMessageW(target, UINT(EM_SETSEL),
                         WPARAM(snapshot.selStart), LPARAM(snapshot.selEnd))
        }
    }
}

private func getWindowClassName(_ hwnd: HWND) -> String {
    let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: 256)
    defer { buffer.deallocate() }
    let length = GetClassNameW(hwnd, buffer, 256)
    guard length > 0 else { return "" }
    return String(decodingCString: buffer, as: UTF16.self)
}

private func findClassIndex(hwnd target: HWND, in parent: HWND, className: String) -> Int {
    var controls: [HWND] = []
    collectControlsByClass(parent: parent, className: className, into: &controls)
    return controls.firstIndex(of: target) ?? 0
}

private func findNthControlByClass(className: String, index: Int, in parent: HWND) -> HWND? {
    var controls: [HWND] = []
    collectControlsByClass(parent: parent, className: className, into: &controls)
    guard index < controls.count else { return nil }
    return controls[index]
}

private func collectControlsByClass(parent: HWND, className: String, into result: inout [HWND]) {
    var child = GetWindow(parent, UINT(GW_CHILD))
    while let c = child {
        if getWindowClassName(c) == className {
            result.append(c)
        }
        collectControlsByClass(parent: c, className: className, into: &result)
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
}
