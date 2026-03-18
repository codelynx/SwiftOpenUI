import WinSDK
import CWin32
import CWin32Bridge
import SwiftOpenUI

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

        // Create with default size initially; we'll resize after rendering content
        let titleWide: [WCHAR] = Array(title.utf16) + [0]
        let hwnd = titleWide.withUnsafeBufferPointer { titlePtr in
            className.withUnsafeBufferPointer { classPtr in
                CreateWindowExW(
                    0,
                    classPtr.baseAddress!,
                    titlePtr.baseAddress!,
                    DWORD(WS_OVERLAPPEDWINDOW),
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
            // Auto-size window to fit content's natural size
            var contentRect = RECT()
            GetWindowRect(contentHwnd, &contentRect)
            let contentW = contentRect.right - contentRect.left
            let contentH = contentRect.bottom - contentRect.top

            // Use content natural size with minimum 300x200, maximum screen size
            let screenW = GetSystemMetrics(SM_CXSCREEN)
            let screenH = GetSystemMetrics(SM_CYSCREEN)
            let clientW = max(300, min(Int32(contentW + 20), screenW * 3 / 4))
            let clientH = max(200, min(Int32(contentH + 20), screenH * 3 / 4))

            var windowRect = RECT(left: 0, top: 0, right: LONG(clientW), bottom: LONG(clientH))
            AdjustWindowRectEx(&windowRect, DWORD(WS_OVERLAPPEDWINDOW), false, 0)
            SetWindowPos(hwnd, nil,
                         Int32(CW_USEDEFAULT), Int32(CW_USEDEFAULT),
                         windowRect.right - windowRect.left,
                         windowRect.bottom - windowRect.top,
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
            win32_SetWindowLongPtrW(hwnd, GWLP_USERDATA, LONG_PTR(Int(bitPattern: contentHwnd)))
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
        if userData != 0, let contentHwnd = HWND(bitPattern: Int(userData)) {
            var clientRect = RECT()
            GetClientRect(hwnd, &clientRect)
            let clientW = clientRect.right - clientRect.left
            let clientH = clientRect.bottom - clientRect.top

            // Content fills the window — centering happens within stacks
            // via cross-axis alignment (default .center).
            SetWindowPos(contentHwnd, nil, 0, 0, clientW, clientH, UINT(SWP_NOZORDER))
        }
        return 0

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

        // Initialize common controls (for modern visual styles)
        win32_InitCommonControlsEx(DWORD(ICC_STANDARD_CLASSES | ICC_WIN95_CLASSES))

        let instance = A()
        let scene = instance.body
        win32RenderScene(scene, hInstance: hInstance)

        // Win32 message loop
        var msg = MSG()
        while GetMessageW(&msg, nil, 0, 0) {
            TranslateMessage(&msg)
            DispatchMessageW(&msg)
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
