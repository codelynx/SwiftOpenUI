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

        // SS_LEFTNOWORDWRAP prevents wrapping (matches single-line measurement).
        // SS_NOTIFY enables WM_LBUTTONDOWN/UP delivery so gesture subclasses work.
        let hwnd = content.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_STATIC(),
                wstr,
                DWORD(SS_LEFTNOWORDWRAP | SS_NOTIFY),
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

/// Property name for retaining a TextFieldState on the HWND.
private let textFieldStatePropName: UnsafePointer<WCHAR> = {
    "SwiftUITextFieldState".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

/// Retains the SubclassHandler so it lives as long as the HWND.
/// SubclassHandler.init passRetains itself for the C callback, but Swift's
/// ARC will release the local variable when winCreateWidget returns.
/// Storing the handler here prevents premature dealloc.
private class TextFieldState {
    let handler: SubclassHandler
    init(handler: SubclassHandler) { self.handler = handler }
}

extension TextField: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let currentText = text.wrappedValue
        let measured = measureText(currentText.isEmpty ? title : currentText, hwnd: context.parent)

        let hwnd = currentText.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_EDIT(),
                wstr,
                DWORD(ES_AUTOHSCROLL | WS_BORDER | WS_TABSTOP),
                0, 0, max(measured.width + 16, 150), measured.height + 8,
                context.parent,
                nil,
                context.hInstance
            )
        }

        guard let hwnd = hwnd else { return nil }

        // Set placeholder text (cue banner) shown when field is empty
        if !title.isEmpty {
            title.withCString(encodedAs: UTF16.self) { placeholderPtr in
                _ = SendMessageW(hwnd, UINT(EM_SETCUEBANNER), 1,
                                 LPARAM(Int(bitPattern: placeholderPtr)))
            }
        }

        // Wire up @Binding: SubclassHandler routes EN_CHANGE → text.wrappedValue
        let binding = text
        let handler = SubclassHandler(hwnd: hwnd)
        handler.onTextChanged = { newValue in
            if newValue != binding.wrappedValue {
                binding.wrappedValue = newValue
            }
        }

        // Retain the handler so it lives as long as the HWND.
        // SubclassHandler.init already passRetained itself for the C callback,
        // but ARC would release the local `handler` variable when this function
        // returns, triggering deinit → remove() and unregistering the subclass.
        let state = TextFieldState(handler: handler)
        let statePtr = Unmanaged.passRetained(state).toOpaque()
        SetWindowSubclass(hwnd, textFieldCleanupProc, 41, DWORD_PTR(UInt(bitPattern: statePtr)))

        return hwnd
    }
}

/// Releases the TextFieldState (and thus the SubclassHandler) on WM_NCDESTROY.
private let textFieldCleanupProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    if uMsg == UINT(WM_NCDESTROY), dwRefData != 0 {
        Unmanaged<TextFieldState>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, textFieldCleanupProc, uIdSubclass)
    }
    return DefSubclassProc(hwnd, uMsg, wParam, lParam)
}

extension FocusedView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }

        // Install focus tracking: WM_SETFOCUS/WM_KILLFOCUS update the @FocusState<Bool>
        let storage = focusState.storage
        let hwndKey = AnyHashable(Int(bitPattern: hwnd))
        let focusInfo = FocusTrackingInfo(
            onGainFocus: { storage.setValue(true) },
            onLoseFocus: { storage.setValue(false) },
            onDestroy: { storage.removePlatformFocusCallback(key: hwndKey) }
        )
        let infoPtr = Unmanaged.passRetained(focusInfo).toOpaque()
        SetWindowSubclass(hwnd, focusTrackingProc, 40, DWORD_PTR(UInt(bitPattern: infoPtr)))

        // Register keyed callback so programmatic @FocusState changes drive SetFocus
        storage.addPlatformFocusCallback(key: hwndKey) { (newValue: Bool?) in
            if newValue == true {
                SetFocus(hwnd)
            }
        }

        return hwnd
    }
}

extension FocusedEqualsView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }

        // Install focus tracking: WM_SETFOCUS sets @FocusState to this value,
        // WM_KILLFOCUS sets it to nil (unless another FocusedEqualsView takes over)
        let storage = focusState.storage
        let matchValue = value
        let hwndKey = AnyHashable(Int(bitPattern: hwnd))
        let focusInfo = FocusTrackingInfo(
            onGainFocus: { storage.setValue(matchValue) },
            onLoseFocus: {
                // Only clear if we're still the focused value
                if storage.value == matchValue {
                    storage.setValue(nil)
                }
            },
            onDestroy: { storage.removePlatformFocusCallback(key: hwndKey) }
        )
        let infoPtr = Unmanaged.passRetained(focusInfo).toOpaque()
        SetWindowSubclass(hwnd, focusTrackingProc, 40, DWORD_PTR(UInt(bitPattern: infoPtr)))

        // Register keyed callback: only this field responds when storage matches its value
        storage.addPlatformFocusCallback(key: hwndKey) { (newValue: Value??) in
            if let nv = newValue, nv == matchValue {
                SetFocus(hwnd)
            }
        }

        return hwnd
    }
}

// MARK: - Focus tracking infrastructure

/// Info for WM_SETFOCUS/WM_KILLFOCUS subclass that bridges Win32 focus events
/// to @FocusState storage.
private class FocusTrackingInfo {
    let onGainFocus: () -> Void
    let onLoseFocus: () -> Void
    let onDestroy: () -> Void

    init(onGainFocus: @escaping () -> Void,
         onLoseFocus: @escaping () -> Void,
         onDestroy: @escaping () -> Void) {
        self.onGainFocus = onGainFocus
        self.onLoseFocus = onLoseFocus
        self.onDestroy = onDestroy
    }
}

/// Subclass proc that bridges Win32 focus events to @FocusState.
private let focusTrackingProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    guard dwRefData != 0 else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }

    let info = Unmanaged<FocusTrackingInfo>.fromOpaque(
        UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
    ).takeUnretainedValue()

    switch uMsg {
    case UINT(WM_SETFOCUS):
        info.onGainFocus()
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_KILLFOCUS):
        info.onLoseFocus()
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_NCDESTROY):
        let destroyInfo = Unmanaged<FocusTrackingInfo>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        )
        destroyInfo.takeUnretainedValue().onDestroy()
        destroyInfo.release()
        RemoveWindowSubclass(hwnd, focusTrackingProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

extension Divider: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerD2DViewClassIfNeeded(hInstance: context.hInstance)

        // 2px tall, stretched by stack layout
        let hwnd = CreateWindowExW(
            0, d2dViewClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE),
            0, 0, 100, 2,
            context.parent, nil, context.hInstance, nil
        )

        guard let hwnd = hwnd else { return nil }

        let state = D2DViewState(hwnd: hwnd, r: 210.0/255, g: 210.0/255, b: 215.0/255)
        state.drawCallback = { rt, brush, w, h in
            // Draw a 1px gray line centered in the area
            d2d1_SolidColorBrush_SetColor(brush, 210.0/255, 210.0/255, 215.0/255, 1)
            if w >= h {
                let lineY = h / 2
                d2d1_RenderTarget_FillRectangle(rt, brush, 0, lineY, w, 1)
            } else {
                let lineX = w / 2
                d2d1_RenderTarget_FillRectangle(rt, brush, lineX, 0, 1, h)
            }
        }
        let ptr = Unmanaged.passRetained(state).toOpaque()
        SetWindowSubclass(hwnd, d2dViewProc, 50, DWORD_PTR(UInt(bitPattern: ptr)))

        return hwnd
    }
}

/// Property name used to mark an HWND as an expandable Color view.
private let colorExpandPropName: UnsafePointer<WCHAR> = {
    "SwiftUIColorExpand".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

/// Check if an HWND is a Color view that should expand to fill its container.
func isColorExpandHwnd(_ hwnd: HWND) -> Bool {
    return GetPropW(hwnd, colorExpandPropName) != nil
}

extension Color: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerD2DViewClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, d2dViewClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE),
            0, 0, 20, 20,
            context.parent, nil, context.hInstance, nil
        )

        guard let container = container else { return nil }

        // Mark as expandable so ZStack and other containers know to fill
        SetPropW(container, colorExpandPropName, HANDLE(bitPattern: 1))

        let cr = Float(self.red)
        let cg = Float(self.green)
        let cb = Float(self.blue)
        let ca = Float(self.alpha)
        let state = D2DViewState(hwnd: container, r: cr, g: cg, b: cb)
        state.drawCallback = { rt, brush, w, h in
            d2d1_SolidColorBrush_SetColor(brush, cr, cg, cb, ca)
            d2d1_RenderTarget_FillRectangle(rt, brush, 0, 0, w, h)
        }
        let ptr = Unmanaged.passRetained(state).toOpaque()
        SetWindowSubclass(container, d2dViewProc, 50, DWORD_PTR(UInt(bitPattern: ptr)))

        return container
    }
}

// MARK: - D2D view infrastructure

/// Shared window class for D2D-rendered views (Color, Divider, etc.)
private let d2dViewClassName: UnsafePointer<WCHAR> = {
    "SwiftUID2DView".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

private var d2dViewClassRegistered = false

private func registerD2DViewClassIfNeeded(hInstance: HINSTANCE) {
    guard !d2dViewClassRegistered else { return }
    d2dViewClassRegistered = true

    var wc = WNDCLASSEXW()
    wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
    wc.style = UINT(CS_HREDRAW | CS_VREDRAW)
    wc.lpfnWndProc = DefWindowProcW
    wc.hInstance = hInstance
    wc.hbrBackground = nil
    wc.lpszClassName = d2dViewClassName
    RegisterClassExW(&wc)
}

/// Per-HWND D2D state for custom-rendered views.
private class D2DViewState {
    let hwnd: HWND
    var renderTarget: D2DRenderTarget?
    var brush: D2DBrush?
    var drawCallback: ((D2DRenderTarget, D2DBrush, Float, Float) -> Void)?

    init(hwnd: HWND, r: Float, g: Float, b: Float) {
        self.hwnd = hwnd
        // Defer render target creation until first WM_SIZE/WM_PAINT
        // when the window has a non-zero size.
    }

    func ensureRenderTarget(width: UInt32, height: UInt32) {
        if renderTarget == nil && width > 0 && height > 0 {
            renderTarget = D2DRenderer.shared.createRenderTarget(for: hwnd, width: width, height: height)
            if let rt = renderTarget {
                brush = D2DRenderer.shared.createBrush(rt, r: 0, g: 0, b: 0)
            }
        }
    }

    func resize(width: UInt32, height: UInt32) {
        if let rt = renderTarget, width > 0, height > 0 {
            D2DRenderer.shared.resize(rt, width: width, height: height)
        }
    }

    func paint() {
        if renderTarget == nil {
            var r = RECT()
            GetClientRect(hwnd, &r)
            ensureRenderTarget(width: UInt32(r.right), height: UInt32(r.bottom))
        }
        guard let rt = renderTarget, let brush = brush else { return }

        var rect = RECT()
        GetClientRect(hwnd, &rect)
        let w = Float(rect.right - rect.left)
        let h = Float(rect.bottom - rect.top)
        guard w > 0, h > 0 else { return }

        d2d1_RenderTarget_BeginDraw(rt)
        // Clear with window background color
        let bgColor = GetSysColor(COLOR_WINDOW)
        d2d1_RenderTarget_Clear(rt,
            Float(win32_GetRValue(bgColor)) / 255.0,
            Float(win32_GetGValue(bgColor)) / 255.0,
            Float(win32_GetBValue(bgColor)) / 255.0, 1.0)

        drawCallback?(rt, brush, w, h)

        let hr = d2d1_RenderTarget_EndDraw(rt)
        if hr < 0 { cleanup() }
    }

    func cleanup() {
        if let b = brush { D2DRenderer.shared.releaseBrush(b); brush = nil }
        if let rt = renderTarget { D2DRenderer.shared.releaseRenderTarget(rt); renderTarget = nil }
    }

    deinit { cleanup() }
}

/// Subclass proc for D2D-rendered views — handles WM_PAINT, WM_SIZE, WM_ERASEBKGND.
private let d2dViewProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    guard dwRefData != 0 else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }

    let state = Unmanaged<D2DViewState>.fromOpaque(
        UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
    ).takeUnretainedValue()

    switch uMsg {
    case UINT(WM_SIZE):
        var rect = RECT()
        GetClientRect(hwnd, &rect)
        state.ensureRenderTarget(width: UInt32(rect.right), height: UInt32(rect.bottom))
        state.resize(width: UInt32(rect.right), height: UInt32(rect.bottom))
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    case UINT(WM_PAINT):
        state.paint()
        _ = ValidateRect(hwnd, nil)
        return 0
    case UINT(WM_ERASEBKGND):
        return 1
    case UINT(WM_NCDESTROY):
        Unmanaged<D2DViewState>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, d2dViewProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

extension Button: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        if let textLabel = label as? Text {
            // Simple text label — use native Win32 BUTTON control
            return createNativeButton(title: textLabel.content, action: action, context: context)
        } else {
            // Custom label — render the label view inside a clickable container
            return createCustomLabelButton(label: label, action: action, context: context)
        }
    }
}

/// Create a native Win32 BUTTON control with a text label.
/// Create a native Win32 BUTTON control with a text label.
func createNativeButton(title: String, action: @escaping () -> Void, context: RenderContext) -> HWND? {
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

/// Create a clickable container that renders a custom label view inside.
/// This handles Button(action:) { HStack { Text("★").foregroundColor(.yellow); Text("Star") } }
private func createCustomLabelButton<Label: View>(label: Label, action: @escaping () -> Void, context: RenderContext) -> HWND? {
    registerCustomButtonClassIfNeeded(hInstance: context.hInstance)

    // Create a clickable container with WS_TABSTOP for keyboard focus
    let container = CreateWindowExW(
        0, customButtonClassName, nil,
        DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN | WS_TABSTOP),
        0, 0, 0, 0,
        context.parent, nil, context.hInstance, nil
    )

    guard let container = container else { return nil }

    // Render the label view inside the container
    let childContext = RenderContext(parent: container, hInstance: context.hInstance)
    let childHwnd = winRenderView(label, in: childContext)

    // Size the container to fit the label + button padding
    var naturalW: Int32 = 24
    var naturalH: Int32 = 12
    if let child = childHwnd {
        var childRect = RECT()
        GetWindowRect(child, &childRect)
        naturalW = (childRect.right - childRect.left) + 16
        naturalH = (childRect.bottom - childRect.top) + 8
    }
    SetWindowPos(container, nil, 0, 0, naturalW, naturalH, UINT(SWP_NOZORDER | SWP_NOMOVE))

    // Center the label inside the container
    if let child = childHwnd {
        var childRect = RECT()
        GetWindowRect(child, &childRect)
        let cw = childRect.right - childRect.left
        let ch = childRect.bottom - childRect.top
        let x = (naturalW - cw) / 2
        let y = (naturalH - ch) / 2
        SetWindowPos(child, nil, x, y, cw, ch, UINT(SWP_NOZORDER))
    }

    // Make all descendant HWNDs mouse-transparent so clicks pass through to
    // this container. Without this, Win32 hit-testing delivers mouse events
    // to the deepest child HWND under the cursor, bypassing the container.
    if let child = childHwnd {
        makeMouseTransparent(child)
    }

    // Install click handler
    let btnInfo = CustomButtonInfo(action: action, child: childHwnd)
    let infoPtr = Unmanaged.passRetained(btnInfo).toOpaque()
    SetWindowSubclass(container, customButtonProc, 30, DWORD_PTR(UInt(bitPattern: infoPtr)))

    return container
}

/// Recursively set WS_EX_TRANSPARENT on an HWND and all its descendants
/// so mouse events pass through to the parent container.
private func makeMouseTransparent(_ hwnd: HWND) {
    let exStyle = win32_GetWindowLongPtrW(hwnd, GWL_EXSTYLE)
    win32_SetWindowLongPtrW(hwnd, GWL_EXSTYLE, exStyle | LONG_PTR(WS_EX_TRANSPARENT))

    var child = GetWindow(hwnd, UINT(GW_CHILD))
    while let c = child {
        makeMouseTransparent(c)
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
}

private class CustomButtonInfo {
    let action: () -> Void
    let child: HWND?
    var pressed: Bool = false
    init(action: @escaping () -> Void, child: HWND?) {
        self.action = action
        self.child = child
    }
}

private let customButtonClassName: UnsafePointer<WCHAR> = {
    "SwiftUICustomButton".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

private var customButtonClassRegistered = false

private func registerCustomButtonClassIfNeeded(hInstance: HINSTANCE) {
    guard !customButtonClassRegistered else { return }
    customButtonClassRegistered = true

    var wc = WNDCLASSEXW()
    wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
    wc.style = UINT(CS_HREDRAW | CS_VREDRAW)
    wc.lpfnWndProc = DefWindowProcW
    wc.hInstance = hInstance
    wc.hCursor = LoadCursorW(nil, win32_IDC_ARROW())
    wc.hbrBackground = GetSysColorBrush(COLOR_BTNFACE)
    wc.lpszClassName = customButtonClassName
    RegisterClassExW(&wc)
}

/// Subclass proc for custom-label buttons.
/// Handles mouse clicks, keyboard activation (Space/Enter), focus cues,
/// and tab navigation to match native BUTTON behavior.
private let customButtonProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    guard dwRefData != 0 else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }

    let info = Unmanaged<CustomButtonInfo>.fromOpaque(
        UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
    ).takeUnretainedValue()

    switch uMsg {
    // --- Mouse activation ---
    case UINT(WM_LBUTTONDOWN):
        // Capture mouse and take focus so we get the matching LBUTTONUP
        SetCapture(hwnd)
        SetFocus(hwnd)
        info.pressed = true
        InvalidateRect(hwnd, nil, true)
        return 0

    case UINT(WM_LBUTTONUP):
        ReleaseCapture()
        let wasPressed = info.pressed
        info.pressed = false
        InvalidateRect(hwnd, nil, true)
        // Only fire if mouse is still inside the button
        if wasPressed {
            var rect = RECT()
            GetClientRect(hwnd, &rect)
            let x = Int32(win32_GET_X_LPARAM(lParam))
            let y = Int32(win32_GET_Y_LPARAM(lParam))
            if x >= 0 && x < rect.right && y >= 0 && y < rect.bottom {
                info.action()
            }
        }
        return 0

    // --- Keyboard activation (Space / Enter) ---
    case UINT(WM_KEYDOWN):
        if wParam == WPARAM(VK_SPACE) || wParam == WPARAM(VK_RETURN) {
            info.pressed = true
            InvalidateRect(hwnd, nil, true)
            return 0
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_KEYUP):
        if wParam == WPARAM(VK_SPACE) || wParam == WPARAM(VK_RETURN) {
            if info.pressed {
                info.pressed = false
                InvalidateRect(hwnd, nil, true)
                info.action()
            }
            return 0
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    // --- Tab-stop and dialog code ---
    case UINT(WM_GETDLGCODE):
        // Tell the dialog manager we want Tab stops and arrow keys
        return LRESULT(DLGC_BUTTON | DLGC_WANTALLKEYS)

    // --- Focus cues ---
    case UINT(WM_SETFOCUS), UINT(WM_KILLFOCUS):
        InvalidateRect(hwnd, nil, true)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    // --- Paint: draw button frame + focus rectangle ---
    case UINT(WM_PAINT):
        var ps = PAINTSTRUCT()
        let hdc = BeginPaint(hwnd, &ps)

        var rect = RECT()
        GetClientRect(hwnd, &rect)

        // Draw button face background
        FillRect(hdc, &rect, GetSysColorBrush(info.pressed ? COLOR_BTNSHADOW : COLOR_BTNFACE))

        // Draw 3D button edge (BF_RECT = BF_LEFT|BF_TOP|BF_RIGHT|BF_BOTTOM = 0xF)
        DrawEdge(hdc, &rect, info.pressed ? UINT(BDR_SUNKEN) : UINT(BDR_RAISED), UINT(0x000F))

        // Draw focus rectangle when focused
        if GetFocus() == hwnd {
            var focusRect = rect
            focusRect.left += 3; focusRect.top += 3
            focusRect.right -= 3; focusRect.bottom -= 3
            DrawFocusRect(hdc, &focusRect)
        }

        EndPaint(hwnd, &ps)
        // Don't return 0 — let children paint on top via WS_CLIPCHILDREN
        return 0

    case UINT(WM_ERASEBKGND):
        return 1

    // --- Layout ---
    case UINT(WM_SIZE):
        if let child = info.child {
            var containerRect = RECT()
            GetClientRect(hwnd, &containerRect)
            var childRect = RECT()
            GetWindowRect(child, &childRect)
            let cw = childRect.right - childRect.left
            let ch = childRect.bottom - childRect.top
            let containerW = containerRect.right - containerRect.left
            let containerH = containerRect.bottom - containerRect.top
            let x = (containerW - cw) / 2
            let y = (containerH - ch) / 2
            SetWindowPos(child, nil, x, y, cw, ch, UINT(SWP_NOZORDER))
        }
        return 0

    case UINT(WM_CTLCOLORSTATIC), UINT(WM_CTLCOLORBTN):
        if let parent = GetParent(hwnd!) {
            return SendMessageW(parent, uMsg, wParam, lParam)
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_NCDESTROY):
        Unmanaged<CustomButtonInfo>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, customButtonProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
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

        // Map SwiftOpenUI HorizontalAlignment to cross-axis int
        let crossAlign: Int
        switch alignment {
        case .leading:  crossAlign = 0
        case .center:   crossAlign = 1
        case .trailing: crossAlign = 2
        }

        let info = StackLayoutInfo(
            direction: .vertical,
            spacing: Int32(spacing),
            children: childHwnds,
            flexibleIndices: flexibleIndices,
            crossAlignment: crossAlign
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

        // Map SwiftOpenUI VerticalAlignment to cross-axis int
        let crossAlign: Int
        switch alignment {
        case .top:    crossAlign = 0
        case .center: crossAlign = 1
        case .bottom: crossAlign = 2
        }

        let info = StackLayoutInfo(
            direction: .horizontal,
            spacing: Int32(spacing),
            children: childHwnds,
            flexibleIndices: flexibleIndices,
            crossAlignment: crossAlign
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
        // Forward to parent so BackgroundView ancestors can set their brush.
        if let parent = GetParent(hwnd!) {
            return SendMessageW(parent, uMsg, wParam, lParam)
        }
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
        // Forward to parent so BackgroundView ancestors can set their brush.
        if let parent = GetParent(hwnd!) {
            return SendMessageW(parent, uMsg, wParam, lParam)
        }
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

// MARK: - Animation/effect stubs (render content, ignore effects for now)

extension OpacityView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // If the content is fully D2D-renderable, render onto a D2D surface
        // with the specified opacity. Otherwise fall through to HWND rendering
        // (opacity ignored — native controls can't be alpha-blended).
        if isD2DRenderable(content) {
            return createD2DSurface(view: content, opacity: Float(opacity), context: context)
        }
        return winRenderView(content, in: context)
    }
}

extension OffsetView: WinRenderable {
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
        guard x != 0 || y != 0 else { return child }

        var childRect = RECT()
        GetWindowRect(child, &childRect)
        let childW = childRect.right - childRect.left
        let childH = childRect.bottom - childRect.top

        let offsetX = Int32(x.rounded())
        let offsetY = Int32(y.rounded())
        SetWindowPos(container, nil, 0, 0, childW, childH, UINT(SWP_NOZORDER | SWP_NOMOVE))
        SetWindowPos(child, nil, offsetX, offsetY, childW, childH, UINT(SWP_NOZORDER))

        // Keep the offset stable when the wrapper is resized by parent layout.
        let offsetInfo = OffsetLayoutInfo(
            child: child,
            offsetX: offsetX,
            offsetY: offsetY,
            childWidth: childW,
            childHeight: childH
        )
        let infoPtr = Unmanaged.passRetained(offsetInfo).toOpaque()
        SetWindowSubclass(container, offsetLayoutProc, 70, DWORD_PTR(UInt(bitPattern: infoPtr)))

        return container
    }
}

private class OffsetLayoutInfo {
    let child: HWND
    let offsetX: Int32
    let offsetY: Int32
    let childWidth: Int32
    let childHeight: Int32
    init(child: HWND, offsetX: Int32, offsetY: Int32, childWidth: Int32, childHeight: Int32) {
        self.child = child
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.childWidth = childWidth
        self.childHeight = childHeight
    }
}

private let offsetLayoutProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    switch uMsg {
    case UINT(WM_SIZE):
        if dwRefData != 0 {
            let info = Unmanaged<OffsetLayoutInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            ).takeUnretainedValue()
            SetWindowPos(info.child, nil, info.offsetX, info.offsetY,
                         info.childWidth, info.childHeight, UINT(SWP_NOZORDER))
        }
        return 0
    case UINT(WM_NCDESTROY):
        if dwRefData != 0 {
            Unmanaged<OffsetLayoutInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            ).release()
            RemoveWindowSubclass(hwnd, offsetLayoutProc, uIdSubclass)
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

extension ScaleEffectView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // If content is D2D-renderable, render onto D2D surface with animated scale.
        // Otherwise fall through (scale ignored on native HWND controls).
        if isD2DRenderable(content) {
            let scale = Float(max(scaleX, scaleY))
            return createD2DSurface(view: content, opacity: 1.0, scale: scale, context: context)
        }
        return winRenderView(content, in: context)
    }
}

extension AnimatedView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // Stub: animation timing not yet implemented on Win32.
        // withAnimation() state changes work (views rebuild), but
        // transitions are instant rather than animated.
        winRenderView(content, in: context)
    }
}

// MARK: - Gesture Win32 extensions
//
// Gestures use recursive subclassing: the same subclass proc is installed on
// the root HWND AND every descendant. This means clicks on any child (Button,
// TextField, Text, etc.) fire the gesture without requiring WM_PARENTNOTIFY
// forwarding in every container proc. Child controls remain interactive because
// the gesture procs always call DefSubclassProc to pass messages through.
//
// The handler object is shared across all subclassed HWNDs. Each HWND holds
// its own retain via Unmanaged.passRetained; WM_NCDESTROY releases it.

/// Install a subclass proc recursively on an HWND and all its descendants.
/// The handler is passRetained for each HWND, so WM_NCDESTROY must release.
private func installGestureRecursively<T: AnyObject>(
    on hwnd: HWND, handler: T, proc: SUBCLASSPROC, subclassID: UINT_PTR
) {
    let ptr = Unmanaged.passRetained(handler).toOpaque()
    SetWindowSubclass(hwnd, proc, subclassID, DWORD_PTR(UInt(bitPattern: ptr)))

    var child = GetWindow(hwnd, UINT(GW_CHILD))
    while let c = child {
        installGestureRecursively(on: c, handler: handler, proc: proc, subclassID: subclassID)
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
}

// --- Tap gesture ---

private let tapGestureSubclassID: UINT_PTR = 60

extension TapGestureView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }

        let handler = TapGestureHandler(requiredCount: count, action: action)
        installGestureRecursively(on: hwnd, handler: handler,
                                  proc: tapGestureProc, subclassID: tapGestureSubclassID)
        return hwnd
    }
}

private class TapGestureHandler {
    let requiredCount: Int
    let action: () -> Void
    var clickCount: Int = 0
    var lastClickTime: DWORD = 0
    /// True after WM_LBUTTONDOWN on any subclassed HWND.
    /// Prevents stray WM_LBUTTONUP from firing the action.
    var armed: Bool = false

    init(requiredCount: Int, action: @escaping () -> Void) {
        self.requiredCount = requiredCount
        self.action = action
    }
}

private let tapGestureProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    guard dwRefData != 0 else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }

    let handler = Unmanaged<TapGestureHandler>.fromOpaque(
        UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
    ).takeUnretainedValue()

    switch uMsg {
    case UINT(WM_LBUTTONDOWN), UINT(WM_LBUTTONDBLCLK):
        // WM_LBUTTONDBLCLK is sent instead of WM_LBUTTONDOWN for the second
        // click of a double-click when the window class has CS_DBLCLKS.
        // STATIC controls have this by default.
        handler.armed = true
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_LBUTTONUP):
        guard handler.armed else {
            return DefSubclassProc(hwnd, uMsg, wParam, lParam)
        }
        handler.armed = false

        let now = GetTickCount()
        if handler.requiredCount <= 1 {
            handler.action()
        } else {
            let doubleClickTime = GetDoubleClickTime()
            if (now - handler.lastClickTime) <= doubleClickTime {
                handler.clickCount += 1
            } else {
                handler.clickCount = 1
            }
            handler.lastClickTime = now
            if handler.clickCount >= handler.requiredCount {
                handler.action()
                handler.clickCount = 0
            }
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_NCDESTROY):
        Unmanaged<TapGestureHandler>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, tapGestureProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

// --- Long press gesture ---

private let longPressSubclassID: UINT_PTR = 61
private let longPressTimerID: UINT_PTR = 9001

extension LongPressGestureView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }

        let durationMs = UInt32(minimumDuration * 1000)
        let handler = LongPressGestureHandler(action: action, durationMs: durationMs, rootHwnd: hwnd)
        installGestureRecursively(on: hwnd, handler: handler,
                                  proc: longPressGestureProc, subclassID: longPressSubclassID)
        return hwnd
    }
}

private class LongPressGestureHandler {
    let action: () -> Void
    let durationMs: UInt32
    let rootHwnd: HWND
    var timerActive: Bool = false

    init(action: @escaping () -> Void, durationMs: UInt32, rootHwnd: HWND) {
        self.action = action
        self.durationMs = durationMs
        self.rootHwnd = rootHwnd
    }

    func startTimer() {
        guard !timerActive else { return }
        // Timer is always on the root HWND so WM_TIMER is delivered consistently
        SetTimer(rootHwnd, longPressTimerID, durationMs, nil)
        timerActive = true
        SetCapture(rootHwnd)
    }

    func cancelTimer() {
        guard timerActive else { return }
        KillTimer(rootHwnd, longPressTimerID)
        timerActive = false
        if GetCapture() == rootHwnd { ReleaseCapture() }
    }
}

private let longPressGestureProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    guard dwRefData != 0 else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }

    let handler = Unmanaged<LongPressGestureHandler>.fromOpaque(
        UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
    ).takeUnretainedValue()

    switch uMsg {
    case UINT(WM_LBUTTONDOWN):
        handler.startTimer()
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_MOUSEMOVE):
        // Cancel if pointer moves outside the root view bounds
        if handler.timerActive {
            var rect = RECT()
            GetClientRect(handler.rootHwnd, &rect)
            // Convert mouse pos to root's client coords
            var pt = POINT(x: LONG(win32_GET_X_LPARAM(lParam)), y: LONG(win32_GET_Y_LPARAM(lParam)))
            if hwnd != handler.rootHwnd {
                ClientToScreen(hwnd, &pt)
                ScreenToClient(handler.rootHwnd, &pt)
            }
            if pt.x < 0 || pt.y < 0 || pt.x >= rect.right || pt.y >= rect.bottom {
                handler.cancelTimer()
            }
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_LBUTTONUP):
        handler.cancelTimer()
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_CAPTURECHANGED):
        handler.cancelTimer()
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_TIMER):
        if UINT_PTR(wParam) == longPressTimerID && hwnd == handler.rootHwnd {
            handler.cancelTimer()
            handler.action()
            return 0
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_NCDESTROY):
        if hwnd == handler.rootHwnd { handler.cancelTimer() }
        Unmanaged<LongPressGestureHandler>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, longPressGestureProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

// --- Drag gesture ---

private let dragGestureSubclassID: UINT_PTR = 62

extension DragGestureView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }

        let handler = DragGestureHandler(
            onChanged: onChanged, onEnded: onEnded,
            minimumDistance: minimumDistance, rootHwnd: hwnd
        )
        installGestureRecursively(on: hwnd, handler: handler,
                                  proc: dragGestureProc, subclassID: dragGestureSubclassID)
        return hwnd
    }
}

private class DragGestureHandler {
    let onChanged: ((DragGestureValue) -> Void)?
    let onEnded: ((DragGestureValue) -> Void)?
    let minimumDistance: Double
    let rootHwnd: HWND
    var tracking: Bool = false  // mouse is down, but drag may not have started
    var dragging: Bool = false  // distance threshold exceeded, drag is active
    var startX: Double = 0
    var startY: Double = 0

    init(onChanged: ((DragGestureValue) -> Void)?, onEnded: ((DragGestureValue) -> Void)?,
         minimumDistance: Double, rootHwnd: HWND) {
        self.onChanged = onChanged
        self.onEnded = onEnded
        self.minimumDistance = minimumDistance
        self.rootHwnd = rootHwnd
    }
}

private let dragGestureProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    guard dwRefData != 0 else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }

    let handler = Unmanaged<DragGestureHandler>.fromOpaque(
        UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
    ).takeUnretainedValue()

    switch uMsg {
    case UINT(WM_LBUTTONDOWN):
        // Convert to root coords for consistent start position
        var pt = POINT(x: LONG(win32_GET_X_LPARAM(lParam)), y: LONG(win32_GET_Y_LPARAM(lParam)))
        if hwnd != handler.rootHwnd {
            ClientToScreen(hwnd, &pt)
            ScreenToClient(handler.rootHwnd, &pt)
        }
        handler.startX = Double(pt.x)
        handler.startY = Double(pt.y)
        handler.tracking = true
        handler.dragging = false
        SetCapture(handler.rootHwnd)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_MOUSEMOVE):
        if handler.tracking && hwnd == handler.rootHwnd {
            let x = Double(win32_GET_X_LPARAM(lParam))
            let y = Double(win32_GET_Y_LPARAM(lParam))
            let dx = x - handler.startX
            let dy = y - handler.startY
            let dist = (dx * dx + dy * dy).squareRoot()

            // Only start dragging once minimumDistance is exceeded
            if !handler.dragging {
                guard dist >= handler.minimumDistance else {
                    return DefSubclassProc(hwnd, uMsg, wParam, lParam)
                }
                handler.dragging = true
            }

            let value = DragGestureValue(
                startLocation: (x: handler.startX, y: handler.startY),
                location: (x: x, y: y),
                translation: (width: dx, height: dy)
            )
            handler.onChanged?(value)
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_LBUTTONUP):
        if handler.tracking {
            let wasDragging = handler.dragging
            handler.tracking = false
            handler.dragging = false
            ReleaseCapture()
            if wasDragging {
                var pt = POINT(x: LONG(win32_GET_X_LPARAM(lParam)), y: LONG(win32_GET_Y_LPARAM(lParam)))
                if hwnd != handler.rootHwnd {
                    ClientToScreen(hwnd, &pt)
                    ScreenToClient(handler.rootHwnd, &pt)
                }
                let x = Double(pt.x), y = Double(pt.y)
                let value = DragGestureValue(
                    startLocation: (x: handler.startX, y: handler.startY),
                    location: (x: x, y: y),
                    translation: (width: x - handler.startX, height: y - handler.startY)
                )
                handler.onEnded?(value)
            }
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_CAPTURECHANGED):
        handler.tracking = false
        handler.dragging = false
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_NCDESTROY):
        Unmanaged<DragGestureHandler>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, dragGestureProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
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
