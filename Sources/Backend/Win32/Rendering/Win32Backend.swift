import WinSDK
import CWin32
import CWin32Bridge
import SwiftOpenUI
import Foundation

private final class MainWindowState {
    let contentHwnd: HWND
    let style: DWORD
    let minClientWidth: Int32?
    let minClientHeight: Int32?
    let maxClientWidth: Int32?
    let maxClientHeight: Int32?

    init(
        contentHwnd: HWND,
        style: DWORD,
        minClientWidth: Int32?,
        minClientHeight: Int32?,
        maxClientWidth: Int32?,
        maxClientHeight: Int32?
    ) {
        self.contentHwnd = contentHwnd
        self.style = style
        self.minClientWidth = minClientWidth
        self.minClientHeight = minClientHeight
        self.maxClientWidth = maxClientWidth
        self.maxClientHeight = maxClientHeight
    }
}

private func adjustedWindowSize(clientWidth: Int32, clientHeight: Int32, style: DWORD) -> (Int32, Int32) {
    var rect = RECT(left: 0, top: 0, right: LONG(clientWidth), bottom: LONG(clientHeight))
    AdjustWindowRectEx(&rect, style, false, 0)
    return (rect.right - rect.left, rect.bottom - rect.top)
}

/// Protocol for scenes that can render onto a Win32 window.
protocol Win32WindowRenderable {
    func win32Render(hInstance: HINSTANCE)
}

extension WindowGroup: Win32WindowRenderable {
    func win32Render(hInstance: HINSTANCE) {
        // Register the main window class
        let className: [WCHAR] = Array("SwiftOpenUIMainWindow".utf16) + [0]

        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.style = UINT(CS_HREDRAW | CS_VREDRAW)
        wc.lpfnWndProc = mainWindowProc
        wc.hInstance = hInstance
        wc.hCursor = LoadCursorW(nil, win32_IDC_ARROW())
        wc.hbrBackground = GetSysColorBrush(COLOR_WINDOW)
        className.withUnsafeBufferPointer { ptr in
            wc.lpszClassName = ptr.baseAddress!
            RegisterClassExW(&wc)
        }

        var style = DWORD(WS_OVERLAPPEDWINDOW)
        switch windowResizeBehavior ?? .automatic {
        case .automatic:
            if case .contentFixed = windowSizing {
                style &= ~DWORD(WS_THICKFRAME | WS_MAXIMIZEBOX)
            }
        case .fixed:
            style &= ~DWORD(WS_THICKFRAME | WS_MAXIMIZEBOX)
        case .resizable:
            break
        }

        // Create with default size initially; we'll resize after rendering content
        let titleWide: [WCHAR] = Array(title.utf16) + [0]
        let hwnd = titleWide.withUnsafeBufferPointer { titlePtr in
            className.withUnsafeBufferPointer { classPtr in
                CreateWindowExW(
                    0,
                    classPtr.baseAddress!,
                    titlePtr.baseAddress!,
                    style,
                    Int32(CW_USEDEFAULT), Int32(CW_USEDEFAULT),
                    500, 600,
                    nil,
                    nil,
                    hInstance,
                    nil
                )
            }
        }!

        // Render the content view tree into the window
        let context = RenderContext(parent: hwnd, hInstance: hInstance)
        if let contentHwnd = winRenderView(content, in: context) {
            let contentRect: RECT = {
                var rect = RECT()
                GetWindowRect(contentHwnd, &rect)
                return rect
            }()
            let naturalContentW = contentRect.right - contentRect.left
            let naturalContentH = contentRect.bottom - contentRect.top

            let desiredClientSize: (Int32, Int32) = {
                switch windowSizing ?? .automatic {
                case .automatic, .content, .contentFixed:
                    return (naturalContentW + 20, naturalContentH + 20)
                case .size(let width, let height):
                    return (Int32(width), Int32(height))
                }
            }()

            let screenW = GetSystemMetrics(SM_CXSCREEN)
            let screenH = GetSystemMetrics(SM_CYSCREEN)
            let minClientW = minWindowWidth.map { Int32($0) } ?? 300
            let minClientH = minWindowHeight.map { Int32($0) } ?? 200
            let maxClientW = maxWindowWidth.map { Int32($0) } ?? (screenW * 3 / 4)
            let maxClientH = maxWindowHeight.map { Int32($0) } ?? (screenH * 3 / 4)

            let defaultClientW = defaultWindowWidth.map { Int32($0) }
            let defaultClientH = defaultWindowHeight.map { Int32($0) }
            let unclampedW = defaultClientW ?? desiredClientSize.0
            let unclampedH = defaultClientH ?? desiredClientSize.1
            let clientW = max(minClientW, min(unclampedW, maxClientW))
            let clientH = max(minClientH, min(unclampedH, maxClientH))

            let windowSize = adjustedWindowSize(clientWidth: clientW, clientHeight: clientH, style: style)
            SetWindowPos(hwnd, nil,
                         Int32(CW_USEDEFAULT), Int32(CW_USEDEFAULT),
                         windowSize.0,
                         windowSize.1,
                         UINT(SWP_NOMOVE | SWP_NOZORDER))

            // Size content to fill client area
            var clientRect = RECT()
            GetClientRect(hwnd, &clientRect)
            SetWindowPos(
                contentHwnd, nil,
                0, 0,
                clientRect.right - clientRect.left,
                clientRect.bottom - clientRect.top,
                UINT(SWP_NOZORDER)
            )
            let state = MainWindowState(
                contentHwnd: contentHwnd,
                style: style,
                minClientWidth: minWindowWidth.map { Int32($0) },
                minClientHeight: minWindowHeight.map { Int32($0) },
                maxClientWidth: maxWindowWidth.map { Int32($0) },
                maxClientHeight: maxWindowHeight.map { Int32($0) }
            )
            let retained = Unmanaged.passRetained(state).toOpaque()
            win32_SetWindowLongPtrW(hwnd, GWLP_USERDATA, LONG_PTR(Int(bitPattern: retained)))
        }

        ShowWindow(hwnd, SW_SHOWDEFAULT)
        UpdateWindow(hwnd)
    }
}

/// WndProc for the main application window.
private let mainWindowProc: WNDPROC = { (hwnd, uMsg, wParam, lParam) in
    switch uMsg {
    case UINT(WM_SIZE):
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0 {
            let state = Unmanaged<MainWindowState>.fromOpaque(UnsafeMutableRawPointer(bitPattern: Int(userData))!).takeUnretainedValue()
            var clientRect = RECT()
            GetClientRect(hwnd, &clientRect)
            let clientW = clientRect.right - clientRect.left
            let clientH = clientRect.bottom - clientRect.top

            // Content fills the window — centering happens within stacks
            // via cross-axis alignment (default .center).
            SetWindowPos(state.contentHwnd, nil, 0, 0, clientW, clientH, UINT(SWP_NOZORDER))
        }
        return 0

    case UINT(WM_GETMINMAXINFO):
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0, let info = UnsafeMutablePointer<MINMAXINFO>(bitPattern: Int(lParam)) {
            let state = Unmanaged<MainWindowState>.fromOpaque(UnsafeMutableRawPointer(bitPattern: Int(userData))!).takeUnretainedValue()
            if let minW = state.minClientWidth, let minH = state.minClientHeight {
                let adjusted = adjustedWindowSize(clientWidth: minW, clientHeight: minH, style: state.style)
                info.pointee.ptMinTrackSize.x = LONG(adjusted.0)
                info.pointee.ptMinTrackSize.y = LONG(adjusted.1)
            }
            if let maxW = state.maxClientWidth, let maxH = state.maxClientHeight {
                let adjusted = adjustedWindowSize(clientWidth: maxW, clientHeight: maxH, style: state.style)
                info.pointee.ptMaxTrackSize.x = LONG(adjusted.0)
                info.pointee.ptMaxTrackSize.y = LONG(adjusted.1)
            }
            return 0
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

    case UINT(WM_CTLCOLORSTATIC), UINT(WM_CTLCOLORBTN):
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetBkMode(hdc, TRANSPARENT)
        return LRESULT(Int(bitPattern: GetSysColorBrush(COLOR_WINDOW)))

    case UINT(WM_COMMAND):
        // Reflect WM_COMMAND back to the child control for EN_CHANGE etc.
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            SendMessageW(childHwnd, uMsg, wParam, lParam)
        }
        if dispatchCommand(wParam: wParam) {
            return 0
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

    case UINT(WM_HSCROLL), UINT(WM_VSCROLL):
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            return SendMessageW(childHwnd, uMsg, wParam, lParam)
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

    case UINT(WM_NOTIFY):
        let nmhdr = UnsafePointer<NMHDR>(bitPattern: Int(lParam))
        if let nmhdr = nmhdr, let controlParent = GetParent(nmhdr.pointee.hwndFrom),
           controlParent != hwnd {
            return SendMessageW(controlParent, uMsg, wParam, lParam)
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

    case WM_SWIFTUI_REBUILD:
        let ptr = UnsafeMutableRawPointer(bitPattern: Int(lParam))!
        let host = Unmanaged<Win32ViewHost>.fromOpaque(ptr).takeRetainedValue()
        host.rebuild()
        return 0

    case WM_SWIFTUI_INVOKE:
        dispatchInvoke(lParam: lParam)
        return 0

    case UINT(WM_DESTROY):
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0 {
            _ = Unmanaged<MainWindowState>.fromOpaque(UnsafeMutableRawPointer(bitPattern: Int(userData))!).takeRetainedValue()
            win32_SetWindowLongPtrW(hwnd!, GWLP_USERDATA, 0)
        }
        PostQuitMessage(0)
        return 0

    default:
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
}

/// Win32 rendering backend for SwiftOpenUI.
public struct Win32Backend: RenderBackend {
    public init() {}

    public func run<A: App>(_ appType: A.Type) {
        let hInstance = GetModuleHandleW(nil)!

        // Enable per-monitor DPI awareness
        win32_SetProcessDpiAwarenessContextPerMonitorV2()

        // Runtime workaround: enable ComCtl32 v6 visual styles via activation context.
        // Required for EM_SETCUEBANNER (TextField placeholder text).
        // Uses undocumented shell32.dll resource 124 — see shim.h for details.
        if !win32_EnableVisualStyles() {
            // Non-fatal: controls render in classic style, placeholders won't show.
            debugPrint("SwiftOpenUI: ComCtl32 v6 visual styles activation failed")
        }

        // Initialize common controls (for modern visual styles)
        win32_InitCommonControlsEx(DWORD(ICC_STANDARD_CLASSES | ICC_WIN95_CLASSES))

        let instance = A()
        let scene = instance.body
        win32RenderScene(scene, hInstance: hInstance)

        // Hybrid Win32 + Foundation run loop.
        // Swift/Foundation timers (e.g. Timer.scheduledTimer) need the main
        // RunLoop to spin, while Win32 UI needs its message queue dispatched.
        var msg = MSG()
        while true {
            while PeekMessageW(&msg, nil, 0, 0, UINT(PM_REMOVE)) {
                if msg.message == UINT(WM_QUIT) {
                    return
                }
                TranslateMessage(&msg)
                DispatchMessageW(&msg)
            }

            // Pump Foundation sources (Timer, etc.) on the main RunLoop.
            // Use RunLoop.main explicitly and pump both .default and .common modes
            // so Timer.scheduledTimer callbacks fire reliably on Windows.
            let limit = Date(timeIntervalSinceNow: 0.005)
            _ = RunLoop.main.run(mode: .default, before: limit)
            _ = RunLoop.main.run(mode: .common, before: limit)
        }
    }
}

/// Recursively render a Scene.
private func win32RenderScene<S: Scene>(_ scene: S, hInstance: HINSTANCE) {
    if let renderable = scene as? Win32WindowRenderable {
        renderable.win32Render(hInstance: hInstance)
        return
    }
    if S.Body.self != Never.self {
        win32RenderScene(scene.body, hInstance: hInstance)
    }
}
