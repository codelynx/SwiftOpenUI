import WinSDK
import CWin32
import CWin32Bridge
import SwiftOpenUI
import Foundation

// MARK: - Win32 rendering protocol

/// Context passed through the render tree.
public struct RenderContext {
    public let parent: HWND
    public let hInstance: HINSTANCE

    public init(parent: HWND, hInstance: HINSTANCE) {
        self.parent = parent
        self.hInstance = hInstance
    }
}

/// Protocol that views implement (via extensions) to provide Win32 HWND creation.
public protocol WinRenderable {
    func winCreateWidget(in context: RenderContext) -> HWND?
}

/// Protocol for views that provide multiple Win32 child widgets.
public protocol WinMultiChildRenderable {
    func winRenderChildren(in context: RenderContext) -> [HWND]
}

// MARK: - Rendering dispatch

/// Render any SwiftOpenUI View into a Win32 HWND.
public func winRenderView<V: View>(_ view: V, in context: RenderContext) -> HWND? {
    if let renderable = view as? WinRenderable {
        return renderable.winCreateWidget(in: context)
    }

    // Composite view with reactive state — wrap in ViewHost
    if hasReactiveProperties(view) {
        return winRenderStatefulView(view, in: context)
    }

    // Stateless composite view — recurse through body
    return winRenderView(view.body, in: context)
}

/// Render children from a view.
public func winRenderChildren<V: View>(_ view: V, in context: RenderContext) -> [HWND] {
    if let multi = view as? WinMultiChildRenderable {
        return multi.winRenderChildren(in: context)
    }
    if let multi = view as? MultiChildView {
        return multi.children.compactMap { child in
            func render<C: View>(_ c: C) -> HWND? { winRenderView(c, in: context) }
            return render(child)
        }
    }
    if let hwnd = winRenderView(view, in: context) {
        return [hwnd]
    }
    return []
}

/// Render an existential (any View).
public func winRenderAnyView(_ view: any View, in context: RenderContext) -> HWND? {
    func render<V: View>(_ v: V) -> HWND? { winRenderView(v, in: context) }
    return render(view)
}

// MARK: - Stateful view rendering

private func winRenderStatefulView<V: View>(_ view: V, in context: RenderContext) -> HWND? {
    let host = Win32ViewHost(context: context, buildBody: { ctx in
        winRenderView(view.body, in: ctx)
    })

    host.captureEnvironment()
    installState(view, host: host)

    // Use the container as parent so the initial render matches rebuild behavior.
    // This is critical for parent-routed messages like WM_CTLCOLORSTATIC.
    let containerContext = RenderContext(parent: host.container, hInstance: context.hInstance)
    let childHwnd = host.buildBody(containerContext)
    if let child = childHwnd {
        host.addChild(child)
    }

    return host.container
}

// MARK: - View Win32 extensions

extension Text: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let measured = measureText(content, hwnd: context.parent)

        let hwnd = content.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_STATIC(),
                wstr,
                DWORD(SS_LEFT),
                0, 0, measured.width + 4, measured.height + 2,
                context.parent,
                nil,
                context.hInstance
            )
        }

        return hwnd
    }
}

extension EmptyView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        win32_CreateChildWindow(
            win32_WC_STATIC(), nil, 0,
            0, 0, 0, 0,
            context.parent, nil, context.hInstance
        )
    }
}

extension Spacer: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let hwnd = win32_CreateChildWindow(
            win32_WC_STATIC(), nil, 0,
            0, 0, 0, 0,
            context.parent, nil, context.hInstance
        )

        if let hwnd = hwnd {
            SetPropW(hwnd, spacerPropName, HANDLE(bitPattern: 1))
        }

        return hwnd
    }
}

extension Divider: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // Horizontal etched line — 2px tall, stretched by stack layout
        win32_CreateChildWindow(
            win32_WC_STATIC(), nil,
            DWORD(SS_ETCHEDHORZ),
            0, 0, 100, 2,
            context.parent, nil, context.hInstance
        )
    }
}

extension Color: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerColorViewClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0,
            colorViewClassName,
            nil,
            DWORD(WS_CHILD | WS_VISIBLE),
            0, 0, 20, 20,
            context.parent,
            nil,
            context.hInstance,
            nil
        )

        guard let container = container else { return nil }

        // Store the color as a COLORREF in GWLP_USERDATA for the paint proc
        let r = UInt8(self.red * 255)
        let g = UInt8(self.green * 255)
        let b = UInt8(self.blue * 255)
        let colorRef = win32_RGB(r, g, b)
        win32_SetWindowLongPtrW(container, GWLP_USERDATA, LONG_PTR(Int(colorRef)))

        return container
    }
}

// Color view window class — paints with solid color via GDI
private let colorViewClassName: UnsafePointer<WCHAR> = {
    "SwiftUIColorView".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

private var colorViewClassRegistered = false

private func registerColorViewClassIfNeeded(hInstance: HINSTANCE) {
    guard !colorViewClassRegistered else { return }
    colorViewClassRegistered = true

    var wc = WNDCLASSEXW()
    wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
    wc.style = UINT(CS_HREDRAW | CS_VREDRAW)
    wc.lpfnWndProc = colorViewWndProc
    wc.hInstance = hInstance
    wc.hbrBackground = nil
    wc.lpszClassName = colorViewClassName
    RegisterClassExW(&wc)
}

private let colorViewWndProc: WNDPROC = { (hwnd, uMsg, wParam, lParam) in
    switch uMsg {
    case UINT(WM_PAINT):
        var ps = PAINTSTRUCT()
        let hdc = BeginPaint(hwnd, &ps)
        let colorRef = COLORREF(win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA))
        let brush = CreateSolidBrush(colorRef)
        FillRect(hdc, &ps.rcPaint, brush)
        DeleteObject(brush)
        EndPaint(hwnd, &ps)
        return 0
    case UINT(WM_ERASEBKGND):
        return 1
    default:
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
}

extension Button: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // Extract the title from the label.
        // Win32 BUTTON controls only support text, so for non-Text labels
        // we render the label view to extract its text content.
        let title: String
        if let textLabel = label as? Text {
            title = textLabel.content
        } else {
            // Walk the label view tree to find the first Text
            title = extractTextFromView(label) ?? "Button"
        }

        let measured = measureText(title, hwnd: context.parent)
        let buttonWidth = measured.width + 24
        let buttonHeight = measured.height + 12

        let controlID = nextControlID()

        let hwnd = title.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_BUTTON(),
                wstr,
                DWORD(BS_PUSHBUTTON),
                0, 0, buttonWidth, buttonHeight,
                context.parent,
                HMENU(bitPattern: UInt(controlID)),
                context.hInstance
            )
        }

        if let hwnd = hwnd {
            registerCommandHandler(controlID: controlID, action: action)
            SetWindowSubclass(hwnd, buttonCleanupProc, 0, DWORD_PTR(controlID))
        }

        return hwnd
    }
}

/// Button cleanup subclass proc — removes command handler on WM_NCDESTROY.
private let buttonCleanupProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    if uMsg == UINT(WM_NCDESTROY) {
        let controlID = WORD(dwRefData)
        unregisterCommandHandler(controlID: controlID)
        RemoveWindowSubclass(hwnd, buttonCleanupProc, uIdSubclass)
    }
    return DefSubclassProc(hwnd, uMsg, wParam, lParam)
}

// MARK: - Global command dispatch

private var commandHandlers: [WORD: () -> Void] = [:]
private var controlIDCounter: WORD = 100
private let commandLock = NSLock()

func nextControlID() -> WORD {
    commandLock.lock()
    defer { commandLock.unlock() }
    controlIDCounter &+= 1
    if controlIDCounter == 0 { controlIDCounter = 100 }
    return controlIDCounter
}

func registerCommandHandler(controlID: WORD, action: @escaping () -> Void) {
    commandLock.lock()
    commandHandlers[controlID] = action
    commandLock.unlock()
}

public func unregisterCommandHandler(controlID: WORD) {
    commandLock.lock()
    commandHandlers.removeValue(forKey: controlID)
    commandLock.unlock()
}

public func dispatchCommand(wParam: WPARAM) -> Bool {
    let controlID = win32_LOWORD(DWORD_PTR(wParam))
    let notifyCode = win32_HIWORD(DWORD_PTR(wParam))
    commandLock.lock()
    let handler = (notifyCode == 0 || notifyCode == 1) ? commandHandlers[controlID] : nil
    commandLock.unlock()
    if let handler = handler {
        handler()
        return true
    }
    return false
}

// MARK: - Container Win32 extensions

extension VStack: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0,
            stackContainerClassName,
            nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent,
            nil,
            context.hInstance,
            nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        let childHwnds = winRenderChildren(content, in: childContext)

        var flexibleIndices = Set<Int>()
        for (i, child) in childHwnds.enumerated() {
            if isSpacerHwnd(child) {
                flexibleIndices.insert(i)
            }
        }

        let info = StackLayoutInfo(
            direction: .vertical,
            spacing: Int32(spacing),
            children: childHwnds,
            flexibleIndices: flexibleIndices
        )
        let infoPtr = Unmanaged.passRetained(info).toOpaque()
        win32_SetWindowLongPtrW(container, GWLP_USERDATA, LONG_PTR(Int(bitPattern: infoPtr)))
        SetWindowSubclass(container, stackLayoutProc, 1, DWORD_PTR(UInt(bitPattern: infoPtr)))

        let naturalSize = computeNaturalSize(info: info)
        SetWindowPos(container, nil, 0, 0, naturalSize.width, naturalSize.height,
                     UINT(SWP_NOZORDER | SWP_NOMOVE))

        performVerticalLayout(container: container, info: info)

        return container
    }
}

extension HStack: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0,
            stackContainerClassName,
            nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent,
            nil,
            context.hInstance,
            nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        let childHwnds = winRenderChildren(content, in: childContext)

        var flexibleIndices = Set<Int>()
        for (i, child) in childHwnds.enumerated() {
            if isSpacerHwnd(child) {
                flexibleIndices.insert(i)
            }
        }

        let info = StackLayoutInfo(
            direction: .horizontal,
            spacing: Int32(spacing),
            children: childHwnds,
            flexibleIndices: flexibleIndices
        )
        let infoPtr = Unmanaged.passRetained(info).toOpaque()
        win32_SetWindowLongPtrW(container, GWLP_USERDATA, LONG_PTR(Int(bitPattern: infoPtr)))
        SetWindowSubclass(container, stackLayoutProc, 1, DWORD_PTR(UInt(bitPattern: infoPtr)))

        let naturalSize = computeNaturalSize(info: info)
        SetWindowPos(container, nil, 0, 0, naturalSize.width, naturalSize.height,
                     UINT(SWP_NOZORDER | SWP_NOMOVE))

        performHorizontalLayout(container: container, info: info)

        return container
    }
}

extension ZStack: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0,
            stackContainerClassName,
            nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN | WS_CLIPSIBLINGS),
            0, 0, 0, 0,
            context.parent,
            nil,
            context.hInstance,
            nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        let childHwnds = winRenderChildren(content, in: childContext)

        let info = ZStackLayoutInfo(
            alignment: alignment,
            children: childHwnds
        )
        let infoPtr = Unmanaged.passRetained(info).toOpaque()
        SetWindowSubclass(container, zStackLayoutProc, 1, DWORD_PTR(UInt(bitPattern: infoPtr)))

        let naturalSize = computeZStackNaturalSize(info: info)
        SetWindowPos(container, nil, 0, 0, naturalSize.width, naturalSize.height,
                     UINT(SWP_NOZORDER | SWP_NOMOVE))

        performZStackLayout(container: container, info: info)

        return container
    }
}

extension Group: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        let childHwnds = winRenderChildren(content, in: childContext)

        let info = StackLayoutInfo(direction: .vertical, spacing: 0, children: childHwnds, flexibleIndices: [])
        let infoPtr = Unmanaged.passRetained(info).toOpaque()
        SetWindowSubclass(container, stackLayoutProc, 1, DWORD_PTR(UInt(bitPattern: infoPtr)))

        let naturalSize = computeNaturalSize(info: info)
        SetWindowPos(container, nil, 0, 0, naturalSize.width, naturalSize.height,
                     UINT(SWP_NOZORDER | SWP_NOMOVE))

        return container
    }
}

extension ForEach: WinRenderable, WinMultiChildRenderable {
    public func winRenderChildren(in context: RenderContext) -> [HWND] {
        data.compactMap { item in
            winRenderView(content(item), in: context)
        }
    }

    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        let childHwnds = winRenderChildren(in: childContext)

        let info = StackLayoutInfo(direction: .vertical, spacing: 0, children: childHwnds, flexibleIndices: [])
        let infoPtr = Unmanaged.passRetained(info).toOpaque()
        SetWindowSubclass(container, stackLayoutProc, 1, DWORD_PTR(UInt(bitPattern: infoPtr)))

        let naturalSize = computeNaturalSize(info: info)
        SetWindowPos(container, nil, 0, 0, naturalSize.width, naturalSize.height,
                     UINT(SWP_NOZORDER | SWP_NOMOVE))

        performVerticalLayout(container: container, info: info)

        return container
    }
}

extension AnyView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        winRenderAnyView(wrapped, in: context)
    }
}

extension _ConditionalView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        switch self {
        case .trueContent(let view): return winRenderView(view, in: context)
        case .falseContent(let view): return winRenderView(view, in: context)
        }
    }
}

extension Optional: WinRenderable where Wrapped: View {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        switch self {
        case .some(let view): return winRenderView(view, in: context)
        case .none: return nil
        }
    }
}

// MARK: - Modifier Win32 extensions

extension PaddedView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        guard let child = winRenderView(content, in: childContext) else { return container }

        let padInfo = PaddingLayoutInfo(
            child: child,
            top: Int32(top), bottom: Int32(bottom),
            leading: Int32(leading), trailing: Int32(trailing)
        )
        let infoPtr = Unmanaged.passRetained(padInfo).toOpaque()
        SetWindowSubclass(container, paddingLayoutProc, 2, DWORD_PTR(UInt(bitPattern: infoPtr)))

        // Natural size = child size + padding
        var childRect = RECT()
        GetWindowRect(child, &childRect)
        let childW = childRect.right - childRect.left
        let childH = childRect.bottom - childRect.top
        let totalW = childW + Int32(leading) + Int32(trailing)
        let totalH = childH + Int32(top) + Int32(bottom)
        SetWindowPos(container, nil, 0, 0, totalW, totalH, UINT(SWP_NOZORDER | SWP_NOMOVE))

        // Initial layout
        performPaddingLayout(container: container, info: padInfo)

        return container
    }
}

class PaddingLayoutInfo {
    let child: HWND
    let top: Int32, bottom: Int32, leading: Int32, trailing: Int32

    init(child: HWND, top: Int32, bottom: Int32, leading: Int32, trailing: Int32) {
        self.child = child
        self.top = top; self.bottom = bottom
        self.leading = leading; self.trailing = trailing
    }
}

func performPaddingLayout(container: HWND, info: PaddingLayoutInfo) {
    var rect = RECT()
    GetClientRect(container, &rect)
    let containerW = rect.right - rect.left
    let containerH = rect.bottom - rect.top

    let childW = max(0, containerW - info.leading - info.trailing)
    let childH = max(0, containerH - info.top - info.bottom)
    SetWindowPos(info.child, nil, info.leading, info.top, childW, childH, UINT(SWP_NOZORDER))
}

let paddingLayoutProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    switch uMsg {
    case UINT(WM_SIZE):
        if dwRefData != 0 {
            let info = Unmanaged<PaddingLayoutInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            ).takeUnretainedValue()
            performPaddingLayout(container: hwnd!, info: info)
        }
        return 0

    case UINT(WM_CTLCOLORSTATIC), UINT(WM_CTLCOLORBTN):
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetBkMode(hdc, TRANSPARENT)
        return LRESULT(Int(bitPattern: GetSysColorBrush(COLOR_WINDOW)))

    case UINT(WM_COMMAND):
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            SendMessageW(childHwnd, uMsg, wParam, lParam)
        }
        if let root = findRootWindow(from: hwnd!) as HWND? {
            return SendMessageW(root, uMsg, wParam, lParam)
        }
        return 0

    case UINT(WM_NCDESTROY):
        if dwRefData != 0 {
            Unmanaged<PaddingLayoutInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            ).release()
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

extension FrameView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        guard let child = winRenderView(content, in: childContext) else { return container }

        // Apply size constraints
        var childRect = RECT()
        GetWindowRect(child, &childRect)
        var w = childRect.right - childRect.left
        var h = childRect.bottom - childRect.top

        if let fw = width { w = Int32(fw) }
        if let fh = height { h = Int32(fh) }
        if let mw = minWidth { w = max(w, Int32(mw)) }
        if let mh = minHeight { h = max(h, Int32(mh)) }
        if let xw = maxWidth, xw != .infinity { w = min(w, Int32(xw)) }
        if let xh = maxHeight, xh != .infinity { h = min(h, Int32(xh)) }

        SetWindowPos(container, nil, 0, 0, w, h, UINT(SWP_NOZORDER | SWP_NOMOVE))

        // Frame subclass: child fills the container
        let frameInfo = FrameLayoutInfo(child: child)
        let infoPtr = Unmanaged.passRetained(frameInfo).toOpaque()
        SetWindowSubclass(container, frameLayoutProc, 3, DWORD_PTR(UInt(bitPattern: infoPtr)))

        // Initial layout
        SetWindowPos(child, nil, 0, 0, w, h, UINT(SWP_NOZORDER))

        return container
    }
}

class FrameLayoutInfo {
    let child: HWND
    init(child: HWND) { self.child = child }
}

let frameLayoutProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    switch uMsg {
    case UINT(WM_SIZE):
        if dwRefData != 0 {
            let info = Unmanaged<FrameLayoutInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            ).takeUnretainedValue()
            var rect = RECT()
            GetClientRect(hwnd, &rect)
            SetWindowPos(info.child, nil, 0, 0,
                         rect.right - rect.left, rect.bottom - rect.top, UINT(SWP_NOZORDER))
        }
        return 0

    case UINT(WM_CTLCOLORSTATIC), UINT(WM_CTLCOLORBTN):
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetBkMode(hdc, TRANSPARENT)
        return LRESULT(Int(bitPattern: GetSysColorBrush(COLOR_WINDOW)))

    case UINT(WM_COMMAND):
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            SendMessageW(childHwnd, uMsg, wParam, lParam)
        }
        if let root = findRootWindow(from: hwnd!) as HWND? {
            return SendMessageW(root, uMsg, wParam, lParam)
        }
        return 0

    case UINT(WM_NCDESTROY):
        if dwRefData != 0 {
            Unmanaged<FrameLayoutInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            ).release()
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

extension ForegroundColorView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        // Wrap the child in a container that intercepts WM_CTLCOLORSTATIC
        // to set the text color. Win32 sends WM_CTLCOLORSTATIC to the parent,
        // not the control itself, so we must be the parent.
        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        guard let child = winRenderView(content, in: childContext) else { return container }

        // Size container to child
        var childRect = RECT()
        GetWindowRect(child, &childRect)
        let w = childRect.right - childRect.left
        let h = childRect.bottom - childRect.top
        SetWindowPos(container, nil, 0, 0, w, h, UINT(SWP_NOZORDER | SWP_NOMOVE))

        let r = UInt8(color.red * 255)
        let g = UInt8(color.green * 255)
        let b = UInt8(color.blue * 255)
        let colorRef = win32_RGB(r, g, b)

        let fgInfo = ForegroundColorInfo(child: child, colorRef: colorRef)
        let infoPtr = Unmanaged.passRetained(fgInfo).toOpaque()
        configureForegroundColorChild(child)
        SetWindowSubclass(container, foregroundColorProc, 10, DWORD_PTR(UInt(bitPattern: infoPtr)))

        // Initial layout
        SetWindowPos(child, nil, 0, 0, w, h, UINT(SWP_NOZORDER))

        return container
    }
}

class ForegroundColorInfo {
    let child: HWND
    let colorRef: COLORREF

    init(child: HWND, colorRef: COLORREF) {
        self.child = child
        self.colorRef = colorRef
    }
}

private func getWindowClassName(_ hwnd: HWND) -> String {
    let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
    defer { buffer.deallocate() }
    let length = GetClassNameW(hwnd, buffer, 64)
    guard length > 0 else { return "" }
    return String(decodingCString: buffer, as: UTF16.self)
}

private func configureForegroundColorChild(_ child: HWND) {
    guard getWindowClassName(child) == "Button" else { return }

    let style = win32_GetWindowLongPtrW(child, GWL_STYLE)
    let ownerDrawStyle = style | LONG_PTR(BS_OWNERDRAW)
    if ownerDrawStyle != style {
        win32_SetWindowLongPtrW(child, GWL_STYLE, ownerDrawStyle)
        SetWindowPos(child, nil, 0, 0, 0, 0,
                     UINT(SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED))
    }
}

private func drawOwnerDrawButton(_ drawInfo: UnsafePointer<DRAWITEMSTRUCT>, colorRef: COLORREF) {
    let info = drawInfo.pointee
    let hdc = info.hDC
    var rect = info.rcItem

    let pushed = (info.itemState & UINT(ODS_SELECTED)) != 0
    let disabled = (info.itemState & UINT(ODS_DISABLED)) != 0
    let focused = (info.itemState & UINT(ODS_FOCUS)) != 0

    FillRect(hdc, &rect, GetSysColorBrush(COLOR_BTNFACE))
    DrawFrameControl(
        hdc,
        &rect,
        UINT(DFC_BUTTON),
        UINT(DFCS_BUTTONPUSH | (pushed ? DFCS_PUSHED : 0) | (disabled ? DFCS_INACTIVE : 0))
    )

    let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: 256)
    defer { buffer.deallocate() }
    let length = GetWindowTextW(info.hwndItem, buffer, 256)
    guard length > 0 else { return }

    let oldBkMode = SetBkMode(hdc, TRANSPARENT)
    let oldTextColor = SetTextColor(hdc, disabled ? GetSysColor(COLOR_GRAYTEXT) : colorRef)
    defer {
        SetTextColor(hdc, oldTextColor)
        SetBkMode(hdc, oldBkMode)
    }

    var textRect = rect
    if pushed {
        textRect.left += 1
        textRect.top += 1
        textRect.right += 1
        textRect.bottom += 1
    }

    DrawTextW(hdc, buffer, length, &textRect, UINT(DT_CENTER | DT_VCENTER | DT_SINGLELINE))

    if focused {
        var focusRect = rect
        focusRect.left += 3
        focusRect.top += 3
        focusRect.right -= 3
        focusRect.bottom -= 3
        DrawFocusRect(hdc, &focusRect)
    }
}

/// Subclass on the wrapper container — intercepts WM_CTLCOLORSTATIC and WM_CTLCOLORBTN
/// to set text color. Both messages are sent by child controls to their parent.
let foregroundColorProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    guard dwRefData != 0 else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }

    let info = Unmanaged<ForegroundColorInfo>.fromOpaque(
        UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
    ).takeUnretainedValue()

    switch uMsg {
    case UINT(WM_SIZE):
        var rect = RECT()
        GetClientRect(hwnd, &rect)
        SetWindowPos(info.child, nil, 0, 0,
                     rect.right - rect.left, rect.bottom - rect.top, UINT(SWP_NOZORDER))
        return 0

    case UINT(WM_CTLCOLORSTATIC), UINT(WM_CTLCOLORBTN):
        // Set the text color on the child control's HDC.
        // WM_CTLCOLORSTATIC is sent by STATIC controls (Text labels).
        // WM_CTLCOLORBTN is sent by BUTTON controls.
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetTextColor(hdc, info.colorRef)
        SetBkMode(hdc, TRANSPARENT)
        return LRESULT(Int(bitPattern: GetSysColorBrush(COLOR_WINDOW)))

    case UINT(WM_DRAWITEM):
        let drawInfo = UnsafePointer<DRAWITEMSTRUCT>(bitPattern: Int(lParam))
        if let drawInfo = drawInfo, drawInfo.pointee.hwndItem == info.child {
            drawOwnerDrawButton(drawInfo, colorRef: info.colorRef)
            return 1
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_COMMAND):
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            SendMessageW(childHwnd, uMsg, wParam, lParam)
        }
        if let root = findRootWindow(from: hwnd!) as HWND? {
            return SendMessageW(root, uMsg, wParam, lParam)
        }
        return 0

    case UINT(WM_NCDESTROY):
        Unmanaged<ForegroundColorInfo>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, foregroundColorProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

extension BackgroundView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        // Create a container that paints itself with the background color
        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        guard let child = winRenderView(content, in: childContext) else { return container }

        // Size container to child
        var childRect = RECT()
        GetWindowRect(child, &childRect)
        let w = childRect.right - childRect.left
        let h = childRect.bottom - childRect.top
        SetWindowPos(container, nil, 0, 0, w, h, UINT(SWP_NOZORDER | SWP_NOMOVE))

        let r = UInt8(color.red * 255)
        let g = UInt8(color.green * 255)
        let b = UInt8(color.blue * 255)
        let colorRef = win32_RGB(r, g, b)

        let bgInfo = BackgroundInfo(child: child, colorRef: colorRef, brush: CreateSolidBrush(colorRef))
        let infoPtr = Unmanaged.passRetained(bgInfo).toOpaque()
        SetWindowSubclass(container, backgroundProc, 11, DWORD_PTR(UInt(bitPattern: infoPtr)))

        // Initial layout
        SetWindowPos(child, nil, 0, 0, w, h, UINT(SWP_NOZORDER))

        return container
    }
}

class BackgroundInfo {
    let child: HWND
    let colorRef: COLORREF
    let brush: HBRUSH?

    init(child: HWND, colorRef: COLORREF, brush: HBRUSH?) {
        self.child = child
        self.colorRef = colorRef
        self.brush = brush
    }

    deinit {
        if let b = brush { DeleteObject(b) }
    }
}

let backgroundProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    guard dwRefData != 0 else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }

    let info = Unmanaged<BackgroundInfo>.fromOpaque(
        UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
    ).takeUnretainedValue()

    switch uMsg {
    case UINT(WM_SIZE):
        var rect = RECT()
        GetClientRect(hwnd, &rect)
        SetWindowPos(info.child, nil, 0, 0,
                     rect.right - rect.left, rect.bottom - rect.top, UINT(SWP_NOZORDER))
        return 0

    case UINT(WM_ERASEBKGND):
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        var rect = RECT()
        GetClientRect(hwnd, &rect)
        if let brush = info.brush {
            FillRect(hdc, &rect, brush)
        }
        return 1

    case UINT(WM_CTLCOLORSTATIC), UINT(WM_CTLCOLORBTN):
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetBkMode(hdc, TRANSPARENT)
        if let brush = info.brush {
            return LRESULT(Int(bitPattern: brush))
        }
        return LRESULT(Int(bitPattern: GetSysColorBrush(COLOR_WINDOW)))

    case UINT(WM_COMMAND):
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            SendMessageW(childHwnd, uMsg, wParam, lParam)
        }
        if let root = findRootWindow(from: hwnd!) as HWND? {
            return SendMessageW(root, uMsg, wParam, lParam)
        }
        return 0

    case UINT(WM_NCDESTROY):
        Unmanaged<BackgroundInfo>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, backgroundProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

extension FontModifiedView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }

        // Create and apply HFONT
        let hfont = createHFont(for: font, hwnd: context.parent)
        if let hfont = hfont {
            // Apply font to all descendant controls, not just the root HWND.
            // The root may be a wrapper container (from padding, foregroundColor, etc.)
            // and the actual text/button controls are nested inside it.
            applyFontRecursively(hwnd: hwnd, hfont: hfont)

            // Track the font so it's deleted when the root HWND is destroyed
            let fontInfo = FontCleanupInfo(hfont: hfont)
            let infoPtr = Unmanaged.passRetained(fontInfo).toOpaque()
            SetWindowSubclass(hwnd, fontCleanupProc, 20, DWORD_PTR(UInt(bitPattern: infoPtr)))
        }

        return hwnd
    }
}

/// Apply WM_SETFONT to an HWND and all its descendants.
/// Re-measures text-bearing controls so layout picks up the new size.
private func applyFontRecursively(hwnd: HWND, hfont: HFONT) {
    SendMessageW(hwnd, UINT(WM_SETFONT), WPARAM(UInt(bitPattern: hfont)), 1)
    remeasureControlIfNeeded(hwnd: hwnd, hfont: hfont)

    var child = GetWindow(hwnd, UINT(GW_CHILD))
    while let c = child {
        applyFontRecursively(hwnd: c, hfont: hfont)
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
}

/// Prevents HFONT leak — DeleteObject on WM_NCDESTROY.
private class FontCleanupInfo {
    let hfont: HFONT
    init(hfont: HFONT) { self.hfont = hfont }
    deinit { DeleteObject(hfont) }
}

private let fontCleanupProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    if uMsg == UINT(WM_NCDESTROY), dwRefData != 0 {
        Unmanaged<FontCleanupInfo>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, fontCleanupProc, uIdSubclass)
    }
    return DefSubclassProc(hwnd, uMsg, wParam, lParam)
}

/// Create a Win32 HFONT for the given Font enum.
private func createHFont(for font: Font, hwnd: HWND) -> HFONT? {
    let dpi = win32_GetDpiForWindow(hwnd)
    let scale = Double(dpi) / 96.0

    let height: Int32
    let weight: Int32
    let italic: Bool

    switch font {
    case .largeTitle:  height = Int32(28 * scale); weight = FW_REGULAR; italic = false
    case .title:       height = Int32(24 * scale); weight = FW_REGULAR; italic = false
    case .title2:      height = Int32(20 * scale); weight = FW_BOLD; italic = false
    case .title3:      height = Int32(18 * scale); weight = FW_REGULAR; italic = false
    case .headline:    height = Int32(14 * scale); weight = FW_BOLD; italic = false
    case .subheadline: height = Int32(12 * scale); weight = FW_BOLD; italic = false
    case .body:        height = Int32(14 * scale); weight = FW_REGULAR; italic = false
    case .callout:     height = Int32(12 * scale); weight = FW_REGULAR; italic = false
    case .footnote:    height = Int32(10 * scale); weight = FW_REGULAR; italic = false
    case .caption:     height = Int32(12 * scale); weight = FW_REGULAR; italic = false
    case .caption2:    height = Int32(10 * scale); weight = FW_BOLD; italic = false
    case .custom(let size, let w, _):
        height = Int32(size * scale)
        switch w {
        case .ultraLight: weight = FW_ULTRALIGHT
        case .thin:       weight = FW_THIN
        case .light:      weight = FW_LIGHT
        case .regular:    weight = FW_REGULAR
        case .medium:     weight = FW_MEDIUM
        case .semibold:   weight = FW_SEMIBOLD
        case .bold:       weight = FW_BOLD
        case .heavy:      weight = FW_HEAVY
        case .black:      weight = FW_BLACK
        }
        italic = false
    }

    let fontName = "Segoe UI"
    return fontName.withCString(encodedAs: UTF16.self) { namePtr in
        CreateFontW(
            -height, 0, 0, 0,
            weight,
            italic ? 1 : 0, 0, 0,
            DWORD(DEFAULT_CHARSET),
            DWORD(OUT_DEFAULT_PRECIS),
            DWORD(CLIP_DEFAULT_PRECIS),
            DWORD(CLEARTYPE_QUALITY),
            DWORD(DEFAULT_PITCH) | DWORD(FF_DONTCARE),
            namePtr
        )
    }
}

/// If the HWND is a text-bearing control, re-measure and resize it for the new font.
private func remeasureControlIfNeeded(hwnd: HWND, hfont: HFONT) {
    let className = getWindowClassName(hwnd)
    guard className == "Static" || className == "Button" else { return }

    let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: 256)
    defer { buffer.deallocate() }
    let length = GetWindowTextW(hwnd, buffer, 256)
    guard length > 0 else { return }

    let hdc = GetDC(hwnd)
    defer { ReleaseDC(hwnd, hdc) }

    let oldFont = SelectObject(hdc, hfont)
    defer { SelectObject(hdc, oldFont) }

    var size = SIZE()
    win32_GetTextExtentPoint32W(hdc, buffer, length, &size)
    let widthPadding: Int32 = className == "Button" ? 24 : 4
    let heightPadding: Int32 = className == "Button" ? 12 : 2
    SetWindowPos(hwnd, nil, 0, 0,
                 size.cx + widthPadding, size.cy + heightPadding,
                 UINT(SWP_NOZORDER | SWP_NOMOVE))
}

extension BorderView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let child = winRenderView(content, in: context) else { return nil }

        // For now, apply WS_EX_CLIENTEDGE for a simple border effect
        let currentStyle = win32_GetWindowLongPtrW(child, GWL_EXSTYLE)
        win32_SetWindowLongPtrW(child, GWL_EXSTYLE, currentStyle | LONG_PTR(WS_EX_CLIENTEDGE))
        // Force a redraw with the new style
        SetWindowPos(child, nil, 0, 0, 0, 0,
                     UINT(SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED))

        return child
    }
}

extension EnvironmentObjectModifierView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        var env = getCurrentEnvironment()
        env.setObject(object)
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(env)
        let widget = winRenderView(content, in: context)
        setCurrentEnvironment(prev)
        return widget
    }
}

extension EnvironmentModifierView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        var env = getCurrentEnvironment()
        env[keyPath: keyPath] = value
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(env)
        let widget = winRenderView(content, in: context)
        setCurrentEnvironment(prev)
        return widget
    }
}

extension _ViewModifierContent: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        winRenderAnyView(wrapped.wrapped, in: context)
    }
}

// MARK: - Helpers

/// Recursively walk a view tree to extract the first Text's content string.
/// Used by Button when the label is a non-Text view (e.g., HStack { Image; Text }).
private func extractTextFromView<V: View>(_ view: V) -> String? {
    if let text = view as? Text {
        return text.content
    }
    if let multi = view as? MultiChildView {
        for child in multi.children {
            func extract<C: View>(_ c: C) -> String? { extractTextFromView(c) }
            if let found = extract(child) {
                return found
            }
        }
    }
    // Recurse into body for composite views
    if V.Body.self != Never.self {
        return extractTextFromView(view.body)
    }
    return nil
}

// MARK: - TupleView Win32 extensions (needed when TupleViews appear at top level)

// TupleViews are already MultiChildView, so winRenderChildren handles them.
// But if they appear as standalone views (not inside a container), we need a fallback.

extension TupleView2: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let vstack = VStack(spacing: 0) { v0; v1 }
        return winRenderView(vstack, in: context)
    }
}

extension TupleView3: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let vstack = VStack(spacing: 0) { v0; v1; v2 }
        return winRenderView(vstack, in: context)
    }
}
