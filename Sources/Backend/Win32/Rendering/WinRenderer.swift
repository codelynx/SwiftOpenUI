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
    let host = Win32ViewHost(
        context: context,
        buildBody: { ctx in
            winRenderView(view.body, in: ctx)
        },
        describeBody: {
            winDescribeAnyView(view.body)
        }
    )

    host.captureEnvironment()
    installState(view, host: host)

    // Use the container as parent so the initial render matches rebuild behavior.
    // This is critical for parent-routed messages like WM_CTLCOLORSTATIC.
    let containerContext = RenderContext(parent: host.container, hInstance: context.hInstance)

    // Phase 6+7: track which storages are read during initial body evaluation
    beginDependencyTracking()
    let childHwnd = host.buildBodyWithTracking(containerContext)
    if let tracking = endDependencyTracking() {
        host.lastReadSet = tracking.readSet
        host.lastInputSnapshot = tracking.snapshots
    }

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
        // SS_NOPREFIX prevents & from being interpreted as accelerator prefix.
        let hwnd = content.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_STATIC(),
                wstr,
                DWORD(SS_LEFTNOWORDWRAP | SS_NOTIFY | SS_NOPREFIX),
                0, 0, measured.width + 4, measured.height + 2,
                context.parent,
                nil,
                context.hInstance
            )
        }

        if let hwnd {
            markHostedNodeKind(hwnd, .text)
        }

        return hwnd
    }
}

extension Text: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(
            kind: .text,
            typeName: String(describing: Self.self),
            props: .text(Win32TextDescriptor(content: content))
        )
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

        let state = D2DViewState(hwnd: hwnd, r: 60.0/255, g: 60.0/255, b: 64.0/255)
        state.drawCallback = { rt, brush, w, h in
            // Draw a subtle 1px separator centered in the area.
            d2d1_SolidColorBrush_SetColor(brush, 60.0/255, 60.0/255, 64.0/255, 1)
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
        markExpandWidth(hwnd)

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
        state.currentFillColor = Win32ColorDescriptor(
            red: self.red,
            green: self.green,
            blue: self.blue,
            opacity: self.alpha
        )
        state.drawCallback = { rt, brush, w, h in
            d2d1_SolidColorBrush_SetColor(brush, cr, cg, cb, ca)
            d2d1_RenderTarget_FillRectangle(rt, brush, 0, 0, w, h)
        }
        let ptr = Unmanaged.passRetained(state).toOpaque()
        SetPropW(container, d2dViewStatePropName, HANDLE(ptr))
        SetWindowSubclass(container, d2dViewProc, 50, DWORD_PTR(UInt(bitPattern: ptr)))
        markHostedNodeKind(container, .color)

        return container
    }
}

extension Color: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(
            kind: .color,
            typeName: String(describing: Self.self),
            props: .color(winColorDescriptor(self))
        )
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

private let d2dViewStatePropName: UnsafePointer<WCHAR> = {
    "SwiftUID2DViewState".withCString(encodedAs: UTF16.self) { ptr in
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
    var currentFillColor: Win32ColorDescriptor?

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
let d2dViewProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
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
        RemovePropW(hwnd, d2dViewStatePropName)
        Unmanaged<D2DViewState>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, d2dViewProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

func winSetColorFill(nativeSlotID: Int, color: Win32ColorDescriptor) -> Bool {
    guard let hwnd = HWND(bitPattern: nativeSlotID) else { return false }
    guard hostedNodeKind(of: hwnd) == .color else { return false }
    guard getWindowClassName(hwnd) == "SwiftUID2DView" else { return false }
    guard let rawState = GetPropW(hwnd, d2dViewStatePropName) else { return false }

    let state = Unmanaged<D2DViewState>.fromOpaque(UnsafeMutableRawPointer(rawState)).takeUnretainedValue()
    state.currentFillColor = color

    let cr = Float(color.red)
    let cg = Float(color.green)
    let cb = Float(color.blue)
    let ca = Float(color.opacity)
    state.drawCallback = { rt, brush, w, h in
        d2d1_SolidColorBrush_SetColor(brush, cr, cg, cb, ca)
        d2d1_RenderTarget_FillRectangle(rt, brush, 0, 0, w, h)
    }

    InvalidateRect(hwnd, nil, false)
    return true
}

func winCurrentColorFill(nativeSlotID: Int) -> Win32ColorDescriptor? {
    guard let hwnd = HWND(bitPattern: nativeSlotID) else { return nil }
    guard let rawState = GetPropW(hwnd, d2dViewStatePropName) else { return nil }
    let state = Unmanaged<D2DViewState>.fromOpaque(UnsafeMutableRawPointer(rawState)).takeUnretainedValue()
    return state.currentFillColor
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
        naturalW = childRect.right - childRect.left
        naturalH = childRect.bottom - childRect.top
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

/// Subclass proc that returns HTTRANSPARENT for WM_NCHITTEST,
/// making the HWND pass mouse events through to the parent.
/// Unlike WS_EX_TRANSPARENT, this does NOT affect painting.
private let mouseTransparentProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    if uMsg == UINT(WM_NCHITTEST) {
        return LRESULT(HTTRANSPARENT)
    }
    if uMsg == UINT(WM_NCDESTROY) {
        RemoveWindowSubclass(hwnd, mouseTransparentProc, uIdSubclass)
    }
    return DefSubclassProc(hwnd, uMsg, wParam, lParam)
}

/// Recursively make an HWND and all its descendants pass mouse events
/// through to the parent container, without affecting painting.
private func makeMouseTransparent(_ hwnd: HWND) {
    SetWindowSubclass(hwnd, mouseTransparentProc, 31, 0)

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
    wc.hbrBackground = GetSysColorBrush(COLOR_WINDOW)
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

        if GetFocus() == hwnd {
            var focusRect = rect
            focusRect.left += 2; focusRect.top += 2
            focusRect.right -= 2; focusRect.bottom -= 2
            DrawFocusRect(hdc, &focusRect)
        }

        EndPaint(hwnd, &ps)
        return 0

    case UINT(WM_ERASEBKGND):
        // Paint button-face background so child text with .foregroundColor(.white)
        // is visible (white text on white background is invisible otherwise)
        let eraseDC = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        var eraseRect = RECT()
        GetClientRect(hwnd, &eraseRect)
        FillRect(eraseDC, &eraseRect, GetSysColorBrush(info.pressed ? COLOR_BTNSHADOW : COLOR_BTNFACE))
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
        // Provide button-face background for child STATIC controls
        let ctlDC = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetBkMode(ctlDC, TRANSPARENT)
        return LRESULT(Int(bitPattern: GetSysColorBrush(info.pressed ? COLOR_BTNSHADOW : COLOR_BTNFACE)))

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
        markHostedNodeKind(container, .vStack)

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
        if !flexibleIndices.isEmpty {
            markExpandHeight(container)
        }

        // Use shared layout only when no children need flex expansion
        // (matches GTK4 eligibility: no Spacers AND no expanding widgets)
        let hasExpandingChild = childHwnds.contains { shouldExpandWidth($0) || shouldExpandHeight($0) }
        if flexibleIndices.isEmpty && !hasExpandingChild {
            let childSizes = info.naturalSizes.map { ViewSize(width: Double($0.width), height: Double($0.height)) }
            let result = computeVStackLayout(childSizes: childSizes, spacing: Double(spacing), alignment: alignment)
            SetWindowPos(container, nil, 0, 0,
                         Int32(result.containerSize.width), Int32(result.containerSize.height),
                         UINT(SWP_NOZORDER | SWP_NOMOVE))
            for (i, child) in childHwnds.enumerated() {
                let p = result.childPlacements[i]
                SetWindowPos(child, nil, Int32(p.origin.x), Int32(p.origin.y),
                             Int32(p.size.width), Int32(p.size.height), UINT(SWP_NOZORDER))
            }
        } else {
            // Has Spacers or expanding children — native Win32 layout
            let naturalSize = computeNaturalSize(info: info)
            SetWindowPos(container, nil, 0, 0, naturalSize.width, naturalSize.height,
                         UINT(SWP_NOZORDER | SWP_NOMOVE))
            performVerticalLayout(container: container, info: info)
        }

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
        markHostedNodeKind(container, .hStack)

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
        if !flexibleIndices.isEmpty {
            markExpandWidth(container)
        }

        // Use shared layout only when no children need flex expansion
        let hasExpandingChild = childHwnds.contains { shouldExpandWidth($0) || shouldExpandHeight($0) }
        if flexibleIndices.isEmpty && !hasExpandingChild {
            let childSizes = info.naturalSizes.map { ViewSize(width: Double($0.width), height: Double($0.height)) }
            let result = computeHStackLayout(childSizes: childSizes, spacing: Double(spacing), alignment: alignment)
            SetWindowPos(container, nil, 0, 0,
                         Int32(result.containerSize.width), Int32(result.containerSize.height),
                         UINT(SWP_NOZORDER | SWP_NOMOVE))
            for (i, child) in childHwnds.enumerated() {
                let p = result.childPlacements[i]
                SetWindowPos(child, nil, Int32(p.origin.x), Int32(p.origin.y),
                             Int32(p.size.width), Int32(p.size.height), UINT(SWP_NOZORDER))
            }
        } else {
            // Has Spacers or expanding children — native Win32 layout
            let naturalSize = computeNaturalSize(info: info)
            SetWindowPos(container, nil, 0, 0, naturalSize.width, naturalSize.height,
                         UINT(SWP_NOZORDER | SWP_NOMOVE))
            performHorizontalLayout(container: container, info: info)
        }

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
        markHostedNodeKind(container, .zStack)

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        let childHwnds = winRenderChildren(content, in: childContext)

        let info = ZStackLayoutInfo(
            alignment: alignment,
            children: childHwnds
        )
        let infoPtr = Unmanaged.passRetained(info).toOpaque()
        SetWindowSubclass(container, zStackLayoutProc, 1, DWORD_PTR(UInt(bitPattern: infoPtr)))

        // Use shared layout only when no children need expansion
        let hasExpandingChild = childHwnds.contains { shouldExpandWidth($0) || shouldExpandHeight($0) }
        if !hasExpandingChild {
            let childSizes = childHwnds.map { child -> ViewSize in
                var r = RECT()
                GetWindowRect(child, &r)
                return ViewSize(width: Double(r.right - r.left), height: Double(r.bottom - r.top))
            }
            let result = computeZStackLayout(childSizes: childSizes, alignment: alignment)
            SetWindowPos(container, nil, 0, 0,
                         Int32(result.containerSize.width), Int32(result.containerSize.height),
                         UINT(SWP_NOZORDER | SWP_NOMOVE))
            for (i, child) in childHwnds.enumerated() {
                let p = result.childPlacements[i]
                SetWindowPos(child, nil, Int32(p.origin.x), Int32(p.origin.y),
                             Int32(p.size.width), Int32(p.size.height), UINT(SWP_NOZORDER))
            }
        } else {
            // Has expanding children — fall back to native ZStack layout
            let naturalSize = computeZStackNaturalSize(info: info)
            SetWindowPos(container, nil, 0, 0, naturalSize.width, naturalSize.height,
                         UINT(SWP_NOZORDER | SWP_NOMOVE))
            performZStackLayout(container: container, info: info)
        }

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
        markHostedNodeKind(container, .padding)

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

    case UINT(WM_ERASEBKGND):
        return eraseWithInheritedBackground(hwnd: hwnd!, wParam: wParam)

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
        markHostedNodeKind(container, .frame)

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        guard let child = winRenderView(content, in: childContext) else { return container }

        // Measure child natural size
        var childRect = RECT()
        GetWindowRect(child, &childRect)
        let naturalW = Double(childRect.right - childRect.left)
        let naturalH = Double(childRect.bottom - childRect.top)

        // Space-filling views (Color) expand to fill the frame
        let expandsWidth = GetPropW(child, colorExpandPropName) != nil || shouldExpandWidth(child)
        let expandsHeight = GetPropW(child, colorExpandPropName) != nil || shouldExpandHeight(child)

        // Use shared layout computation for initial sizing
        let result = computeFrameLayout(
            childNaturalSize: ViewSize(width: naturalW, height: naturalH),
            width: width, height: height,
            minWidth: minWidth, minHeight: minHeight,
            maxWidth: maxWidth, maxHeight: maxHeight,
            alignment: alignment,
            expandsToFillWidth: expandsWidth,
            expandsToFillHeight: expandsHeight
        )

        let w = Int32(result.containerSize.width)
        let h = Int32(result.containerSize.height)
        SetWindowPos(container, nil, 0, 0, w, h, UINT(SWP_NOZORDER | SWP_NOMOVE))

        // Propagate expand flags to the FrameView container when
        // the FrameView has no explicit constraint on that axis.
        // This lets parent layouts (VStack/HStack) know that this
        // FrameView should fill available space on unconstrained axes.
        if expandsWidth && width == nil && minWidth == nil { markExpandWidth(container) }
        if expandsHeight && height == nil && minHeight == nil { markExpandHeight(container) }

        // Store info for resize-time recomputation via shared layout
        // (includes original constraints so resize reapplies min/max clamping)
        let frameInfo = FrameLayoutInfo(
            child: child,
            alignment: alignment,
            childNaturalSize: ViewSize(width: naturalW, height: naturalH),
            expandsToFillWidth: expandsWidth,
            expandsToFillHeight: expandsHeight,
            frameWidth: width, frameHeight: height,
            frameMinWidth: minWidth, frameMinHeight: minHeight,
            frameMaxWidth: maxWidth, frameMaxHeight: maxHeight
        )
        let infoPtr = Unmanaged.passRetained(frameInfo).toOpaque()
        SetWindowSubclass(container, frameLayoutProc, 3, DWORD_PTR(UInt(bitPattern: infoPtr)))

        // Initial placement
        let p = result.childPlacement
        SetWindowPos(child, nil, Int32(p.origin.x), Int32(p.origin.y),
                     Int32(p.size.width), Int32(p.size.height), UINT(SWP_NOZORDER))

        return container
    }
}

class FrameLayoutInfo {
    let child: HWND
    let alignment: Alignment
    let childNaturalSize: ViewSize
    let expandsToFillWidth: Bool
    let expandsToFillHeight: Bool
    // Original constraints for resize-time recomputation
    let frameWidth: Double?
    let frameHeight: Double?
    let frameMinWidth: Double?
    let frameMinHeight: Double?
    let frameMaxWidth: Double?
    let frameMaxHeight: Double?

    init(child: HWND, alignment: Alignment, childNaturalSize: ViewSize,
         expandsToFillWidth: Bool, expandsToFillHeight: Bool,
         frameWidth: Double? = nil, frameHeight: Double? = nil,
         frameMinWidth: Double? = nil, frameMinHeight: Double? = nil,
         frameMaxWidth: Double? = nil, frameMaxHeight: Double? = nil) {
        self.child = child
        self.alignment = alignment
        self.childNaturalSize = childNaturalSize
        self.expandsToFillWidth = expandsToFillWidth
        self.expandsToFillHeight = expandsToFillHeight
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
        self.frameMinWidth = frameMinWidth
        self.frameMinHeight = frameMinHeight
        self.frameMaxWidth = frameMaxWidth
        self.frameMaxHeight = frameMaxHeight
    }
}

/// Recompute frame child placement on resize using shared layout.
/// On resize, the parent has already decided the container's actual size.
/// We place the child within that actual size, using the shared placement
/// math (alignment + expand flags). The original min/max constraints were
/// applied during initial sizing — they don't re-clamp on parent-driven resize.
func layoutFrameChild(in container: HWND, info: FrameLayoutInfo) {
    var rect = RECT()
    GetClientRect(container, &rect)
    let containerW = Double(rect.right - rect.left)
    let containerH = Double(rect.bottom - rect.top)

    // Place child within the actual container size.
    // Use the actual container as the frame (width/height) so placement
    // is always relative to the real HWND, not a phantom clamped size.
    let result = computeFrameLayout(
        childNaturalSize: info.childNaturalSize,
        width: containerW,
        height: containerH,
        alignment: info.alignment,
        expandsToFillWidth: info.expandsToFillWidth,
        expandsToFillHeight: info.expandsToFillHeight
    )

    let p = result.childPlacement
    SetWindowPos(info.child, nil, Int32(p.origin.x), Int32(p.origin.y),
                 Int32(p.size.width), Int32(p.size.height), UINT(SWP_NOZORDER))
}

let frameLayoutProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    switch uMsg {
    case UINT(WM_SIZE):
        if dwRefData != 0 {
            let info = Unmanaged<FrameLayoutInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            ).takeUnretainedValue()
            layoutFrameChild(in: hwnd!, info: info)
        }
        return 0

    case UINT(WM_ERASEBKGND):
        return eraseWithInheritedBackground(hwnd: hwnd!, wParam: wParam)

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
        markHostedNodeKind(container, .foregroundColor)

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

func configureForegroundColorChild(_ child: HWND) {
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
        // Forward to parent so BackgroundView can provide its brush
        if let parent = GetParent(hwnd!) {
            return SendMessageW(parent, uMsg, wParam, lParam)
        }
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
        markHostedNodeKind(container, .background)

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

// MARK: - Phase 3 views

extension Toggle: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let text = label.isEmpty ? "Toggle" : label
        let measured = measureText(text, hwnd: context.parent)
        let checkWidth = measured.width + 24  // space for checkbox
        let checkHeight = max(measured.height + 4, 20)

        let hwnd = text.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_BUTTON(),
                wstr,
                DWORD(BS_AUTOCHECKBOX | WS_TABSTOP),
                0, 0, checkWidth, checkHeight,
                context.parent,
                nil,
                context.hInstance
            )
        }

        guard let hwnd = hwnd else { return nil }

        // Set initial check state from binding
        if isOn.wrappedValue {
            SendMessageW(hwnd, UINT(BM_SETCHECK), WPARAM(BST_CHECKED), 0)
        }

        // Subclass to route BN_CLICKED → binding update
        let binding = isOn
        let controlID = nextControlID()
        win32_SetWindowLongPtrW(hwnd, GWL_ID, LONG_PTR(Int(controlID)))
        registerCommandHandler(controlID: WORD(controlID)) {
            let checked = SendMessageW(hwnd, UINT(BM_GETCHECK), 0, 0) == LRESULT(BST_CHECKED)
            if checked != binding.wrappedValue {
                binding.wrappedValue = checked
            }
        }
        SetWindowSubclass(hwnd, buttonCleanupProc, 0, DWORD_PTR(controlID))

        return hwnd
    }
}

// MARK: - D2D Custom Slider

/// State for a D2D-rendered slider.
private class D2DSliderState {
    let hwnd: HWND
    let binding: Binding<Double>
    let rangeMin: Double
    let rangeMax: Double
    let step: Double
    var currentValue: Double
    var dragging: Bool = false

    var renderTarget: D2DRenderTarget?
    var brush: D2DBrush?

    // Layout constants
    let trackHeight: Float = 4
    let thumbRadius: Float = 8
    let trackInset: Float = 10  // horizontal padding for thumb overhang

    init(hwnd: HWND, binding: Binding<Double>, range: ClosedRange<Double>, step: Double) {
        self.hwnd = hwnd
        self.binding = binding
        self.rangeMin = range.lowerBound
        self.rangeMax = range.upperBound
        self.step = step
        self.currentValue = binding.wrappedValue
    }

    func ensureTarget(width: UInt32, height: UInt32) {
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

    /// Fraction of the slider position (0.0 to 1.0).
    var fraction: Float {
        guard rangeMax > rangeMin else { return 0 }
        return Float((currentValue - rangeMin) / (rangeMax - rangeMin))
    }

    /// X position of the thumb center.
    func thumbX(trackWidth: Float) -> Float {
        let usable = trackWidth - trackInset * 2
        return trackInset + fraction * usable
    }

    /// Convert an x position to a value, snapped to step.
    func valueFromX(_ x: Float, trackWidth: Float) -> Double {
        let usable = trackWidth - trackInset * 2
        let frac = Double(max(0, min(1, (x - trackInset) / usable)))
        let raw = rangeMin + frac * (rangeMax - rangeMin)
        // Snap to step
        let stepped = (raw / step).rounded() * step
        return max(rangeMin, min(rangeMax, stepped))
    }

    func paint() {
        if renderTarget == nil {
            var r = RECT()
            GetClientRect(hwnd, &r)
            ensureTarget(width: UInt32(r.right), height: UInt32(r.bottom))
        }
        guard let rt = renderTarget, let brush = brush else { return }

        var rect = RECT()
        GetClientRect(hwnd, &rect)
        let w = Float(rect.right)
        let h = Float(rect.bottom)
        guard w > 0, h > 0 else { return }

        d2d1_RenderTarget_BeginDraw(rt)

        // Clear with inherited background from parent chain
        var bgR: Float = Float(win32_GetRValue(GetSysColor(COLOR_WINDOW))) / 255.0
        var bgG: Float = Float(win32_GetGValue(GetSysColor(COLOR_WINDOW))) / 255.0
        var bgB: Float = Float(win32_GetBValue(GetSysColor(COLOR_WINDOW))) / 255.0
        if let parent = GetParent(hwnd) {
            // Create a temporary memory DC to query the brush color
            let hdc = GetDC(hwnd)
            let brushResult = SendMessageW(parent, UINT(WM_CTLCOLORSTATIC),
                                            WPARAM(UInt(bitPattern: hdc)), LPARAM(Int(bitPattern: hwnd)))
            if brushResult != 0, let brush = HBRUSH(bitPattern: Int(brushResult)) {
                var logBrush = LOGBRUSH()
                GetObjectW(brush, Int32(MemoryLayout<LOGBRUSH>.size), &logBrush)
                bgR = Float(win32_GetRValue(logBrush.lbColor)) / 255.0
                bgG = Float(win32_GetGValue(logBrush.lbColor)) / 255.0
                bgB = Float(win32_GetBValue(logBrush.lbColor)) / 255.0
            }
            ReleaseDC(hwnd, hdc)
        }
        d2d1_RenderTarget_Clear(rt, bgR, bgG, bgB, 1.0)

        let centerY = h / 2
        let tx = thumbX(trackWidth: w)

        // Track background (inactive portion) — dark gray
        d2d1_SolidColorBrush_SetColor(brush, 0.35, 0.35, 0.38, 1)
        d2d1_RenderTarget_FillRoundedRectangle(rt, brush,
            trackInset, centerY - trackHeight / 2,
            w - trackInset * 2, trackHeight,
            trackHeight / 2, trackHeight / 2)

        // Track active portion (left of thumb) — accent blue
        if tx > trackInset {
            d2d1_SolidColorBrush_SetColor(brush, 0.0, 0.48, 1.0, 1)
            d2d1_RenderTarget_FillRoundedRectangle(rt, brush,
                trackInset, centerY - trackHeight / 2,
                tx - trackInset, trackHeight,
                trackHeight / 2, trackHeight / 2)
        }

        // Thumb — white circle with subtle shadow
        d2d1_SolidColorBrush_SetColor(brush, 0.2, 0.2, 0.2, 0.3)
        d2d1_RenderTarget_FillEllipse(rt, brush,
            tx, centerY + 1, thumbRadius, thumbRadius)
        d2d1_SolidColorBrush_SetColor(brush, 1.0, 1.0, 1.0, 1.0)
        d2d1_RenderTarget_FillEllipse(rt, brush,
            tx, centerY, thumbRadius, thumbRadius)

        _ = d2d1_RenderTarget_EndDraw(rt)
    }

    func cleanup() {
        if let b = brush { D2DRenderer.shared.releaseBrush(b); brush = nil }
        if let rt = renderTarget { D2DRenderer.shared.releaseRenderTarget(rt); renderTarget = nil }
    }

    deinit { cleanup() }
}

/// Subclass proc for the D2D slider HWND.
private let d2dSliderProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    guard dwRefData != 0 else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }

    let state = Unmanaged<D2DSliderState>.fromOpaque(
        UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
    ).takeUnretainedValue()

    switch uMsg {
    case UINT(WM_PAINT):
        state.paint()
        _ = ValidateRect(hwnd, nil)
        return 0

    case UINT(WM_SIZE):
        var rect = RECT()
        GetClientRect(hwnd, &rect)
        state.ensureTarget(width: UInt32(rect.right), height: UInt32(rect.bottom))
        state.resize(width: UInt32(rect.right), height: UInt32(rect.bottom))
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_ERASEBKGND):
        return 1

    case UINT(WM_LBUTTONDOWN):
        var rect = RECT()
        GetClientRect(hwnd, &rect)
        let x = Float(Int16(truncatingIfNeeded: win32_LOWORD(DWORD_PTR(lParam))))
        let newValue = state.valueFromX(x, trackWidth: Float(rect.right))
        findContainingViewHost(from: hwnd)?.beginInteractiveUpdate()
        state.currentValue = newValue
        state.binding.wrappedValue = newValue
        state.dragging = true
        SetCapture(hwnd)
        InvalidateRect(hwnd, nil, false)
        return 0

    case UINT(WM_MOUSEMOVE):
        if state.dragging {
            var rect = RECT()
            GetClientRect(hwnd, &rect)
            let x = Float(Int16(truncatingIfNeeded: win32_LOWORD(DWORD_PTR(lParam))))
            let newValue = state.valueFromX(x, trackWidth: Float(rect.right))
            if newValue != state.currentValue {
                state.currentValue = newValue
                state.binding.wrappedValue = newValue
                InvalidateRect(hwnd, nil, false)
            }
        }
        return 0

    case UINT(WM_LBUTTONUP):
        if state.dragging {
            state.dragging = false
            ReleaseCapture()
            findContainingViewHost(from: hwnd)?.endInteractiveUpdate()
        }
        return 0

    case UINT(WM_NCDESTROY):
        if state.dragging {
            findContainingViewHost(from: hwnd)?.endInteractiveUpdate()
        }
        Unmanaged<D2DSliderState>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, d2dSliderProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

extension Slider: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerD2DSurfaceClassIfNeeded(hInstance: context.hInstance)

        let hwnd = CreateWindowExW(
            0, d2dSurfaceClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE),
            0, 0, 200, 24,
            context.parent, nil, context.hInstance, nil
        )

        guard let hwnd = hwnd else { return nil }
        markHostedNodeKind(hwnd, .slider)

        let state = D2DSliderState(hwnd: hwnd, binding: value, range: range, step: step)
        let ptr = Unmanaged.passRetained(state).toOpaque()
        SetWindowSubclass(hwnd, d2dSliderProc, 47, DWORD_PTR(UInt(bitPattern: ptr)))

        return hwnd
    }
}

extension Slider: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(
            kind: .slider,
            typeName: String(describing: Self.self),
            props: .slider(
                Win32SliderDescriptor(
                    value: value.wrappedValue,
                    range: range,
                    step: step
                )
            )
        )
    }
}

extension VStack: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(
            kind: .vStack,
            typeName: String(describing: Self.self),
            props: .vStack(
                Win32VStackDescriptor(
                    spacing: spacing,
                    alignment: winHorizontalAlignmentDescriptor(alignment)
                )
            ),
            children: children.map(winDescribeAnyView)
        )
    }
}

extension HStack: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(
            kind: .hStack,
            typeName: String(describing: Self.self),
            props: .hStack(
                Win32HStackDescriptor(
                    spacing: spacing,
                    alignment: winVerticalAlignmentDescriptor(alignment)
                )
            ),
            children: children.map(winDescribeAnyView)
        )
    }
}

extension ZStack: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(
            kind: .zStack,
            typeName: String(describing: Self.self),
            props: .zStack(
                Win32ZStackDescriptor(
                    alignment: winAlignmentDescriptor(alignment)
                )
            ),
            children: children.map(winDescribeAnyView)
        )
    }
}

extension PaddedView: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(
            kind: .padding,
            typeName: String(describing: Self.self),
            props: .padding(
                Win32PaddingDescriptor(
                    top: top,
                    bottom: bottom,
                    leading: leading,
                    trailing: trailing
                )
            ),
            children: [winDescribeView(content)]
        )
    }
}

extension FrameView: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(
            kind: .frame,
            typeName: String(describing: Self.self),
            props: .frame(
                Win32FrameDescriptor(
                    width: width,
                    height: height,
                    minWidth: minWidth,
                    minHeight: minHeight,
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                    alignment: winAlignmentDescriptor(alignment)
                )
            ),
            children: [winDescribeView(content)]
        )
    }
}

extension ForegroundColorView: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(
            kind: .foregroundColor,
            typeName: String(describing: Self.self),
            props: .foregroundColor(winColorDescriptor(color)),
            children: [winDescribeView(content)]
        )
    }
}

extension BackgroundView: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(
            kind: .background,
            typeName: String(describing: Self.self),
            props: .background(winColorDescriptor(color)),
            children: [winDescribeView(content)]
        )
    }
}

extension BorderView: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(
            kind: .border,
            typeName: String(describing: Self.self),
            props: .border(
                Win32BorderDescriptor(
                    color: winColorDescriptor(color),
                    width: width
                )
            ),
            children: [winDescribeView(content)]
        )
    }
}


extension FontModifiedView: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(
            kind: .font,
            typeName: String(describing: Self.self),
            props: .font(Win32FontDescriptor(font: font)),
            children: [winDescribeView(content)]
        )
    }
}

extension Divider: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(kind: .divider, typeName: "Divider")
    }
}

extension Spacer: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(kind: .spacer, typeName: "Spacer")
    }
}

extension ScrollView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerScrollViewClassIfNeeded(hInstance: context.hInstance)

        // Vertical scrolling only — horizontal scroll is not yet implemented.
        var style = DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN)
        if axes.contains(.vertical) { style |= DWORD(WS_VSCROLL) }

        let container = CreateWindowExW(
            0, scrollViewClassName, nil,
            style,
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        // Render content into the scroll container
        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        guard let child = winRenderView(VStack(spacing: 0) { content }, in: childContext) else {
            return container
        }

        // Get content natural size
        var childRect = RECT()
        GetWindowRect(child, &childRect)
        let contentW = childRect.right - childRect.left
        let contentH = childRect.bottom - childRect.top

        // Set container natural size (clamped for layout)
        let displayH = min(contentH, 200)  // max visible height before scrolling
        SetWindowPos(container, nil, 0, 0, contentW, displayH, UINT(SWP_NOZORDER | SWP_NOMOVE))

        // Store scroll state
        let scrollState = ScrollViewState(child: child, contentHeight: contentH)
        let statePtr = Unmanaged.passRetained(scrollState).toOpaque()
        win32_SetWindowLongPtrW(container, GWLP_USERDATA, LONG_PTR(Int(bitPattern: statePtr)))

        // Size child to its natural width, full content height
        SetWindowPos(child, nil, 0, 0, contentW, contentH, UINT(SWP_NOZORDER))

        // Set initial scroll range
        updateScrollRange(container, state: scrollState)

        return container
    }
}

private class ScrollViewState {
    let child: HWND
    let contentHeight: Int32
    var scrollY: Int32 = 0

    init(child: HWND, contentHeight: Int32) {
        self.child = child
        self.contentHeight = contentHeight
    }
}

private func updateScrollRange(_ hwnd: HWND, state: ScrollViewState) {
    var rect = RECT()
    GetClientRect(hwnd, &rect)
    let visibleH = rect.bottom - rect.top

    var si = SCROLLINFO()
    si.cbSize = UINT(MemoryLayout<SCROLLINFO>.size)
    si.fMask = UINT(SIF_RANGE | SIF_PAGE)
    si.nMin = 0
    si.nMax = state.contentHeight - 1
    si.nPage = UINT(visibleH)
    SetScrollInfo(hwnd, INT(SB_VERT), &si, true)
}

private let scrollViewClassName: UnsafePointer<WCHAR> = {
    "SwiftUIScrollView".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

private var scrollViewClassRegistered = false

private func registerScrollViewClassIfNeeded(hInstance: HINSTANCE) {
    guard !scrollViewClassRegistered else { return }
    scrollViewClassRegistered = true

    var wc = WNDCLASSEXW()
    wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
    wc.style = UINT(CS_HREDRAW | CS_VREDRAW)
    wc.lpfnWndProc = scrollViewWndProc
    wc.hInstance = hInstance
    wc.hbrBackground = GetSysColorBrush(COLOR_WINDOW)
    wc.lpszClassName = scrollViewClassName
    RegisterClassExW(&wc)
}

private let scrollViewWndProc: WNDPROC = { (hwnd, uMsg, wParam, lParam) in
    switch uMsg {
    case UINT(WM_SIZE):
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0 {
            let state = Unmanaged<ScrollViewState>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: Int(userData))!
            ).takeUnretainedValue()
            var rect = RECT()
            GetClientRect(hwnd, &rect)
            let visibleW = rect.right - rect.left
            // Child fills width, keeps its natural height
            SetWindowPos(state.child, nil, 0, -state.scrollY, visibleW, state.contentHeight, UINT(SWP_NOZORDER))
            updateScrollRange(hwnd!, state: state)
        }
        return 0

    case UINT(WM_VSCROLL):
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        guard userData != 0 else { return DefWindowProcW(hwnd, uMsg, wParam, lParam) }
        let state = Unmanaged<ScrollViewState>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: Int(userData))!
        ).takeUnretainedValue()

        var rect = RECT()
        GetClientRect(hwnd, &rect)
        let visibleH = rect.bottom - rect.top
        let maxScroll = max(0, state.contentHeight - visibleH)

        let action = Int32(win32_LOWORD(DWORD_PTR(wParam)))
        var newPos = state.scrollY
        switch action {
        case SB_LINEUP:    newPos -= 20
        case SB_LINEDOWN:  newPos += 20
        case SB_PAGEUP:    newPos -= visibleH
        case SB_PAGEDOWN:  newPos += visibleH
        case SB_THUMBTRACK, SB_THUMBPOSITION:
            newPos = Int32(win32_HIWORD(DWORD_PTR(wParam)))
        default: break
        }

        newPos = min(max(newPos, 0), maxScroll)
        if newPos != state.scrollY {
            state.scrollY = newPos
            SetWindowPos(state.child, nil, 0, -newPos,
                         rect.right - rect.left, state.contentHeight, UINT(SWP_NOZORDER))
            var si = SCROLLINFO()
            si.cbSize = UINT(MemoryLayout<SCROLLINFO>.size)
            si.fMask = UINT(SIF_POS)
            si.nPos = newPos
            SetScrollInfo(hwnd, INT(SB_VERT), &si, true)
        }
        return 0

    case UINT(WM_MOUSEWHEEL):
        // Forward mouse wheel to scroll
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        guard userData != 0 else { return DefWindowProcW(hwnd, uMsg, wParam, lParam) }
        let delta = Int16(bitPattern: UInt16(win32_HIWORD(DWORD_PTR(wParam))))
        let scrollAmount: WPARAM = delta > 0 ? WPARAM(SB_LINEUP) : WPARAM(SB_LINEDOWN)
        let steps = abs(Int32(delta)) / 120
        for _ in 0..<max(steps, 1) {
            SendMessageW(hwnd, UINT(WM_VSCROLL), scrollAmount, 0)
        }
        return 0

    case UINT(WM_COMMAND):
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            SendMessageW(childHwnd, uMsg, wParam, lParam)
        }
        if let root = findRootWindow(from: hwnd!) as HWND? {
            return SendMessageW(root, uMsg, wParam, lParam)
        }
        return 0

    case UINT(WM_CTLCOLORSTATIC), UINT(WM_CTLCOLORBTN):
        if let parent = GetParent(hwnd!) {
            return SendMessageW(parent, uMsg, wParam, lParam)
        }
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetBkMode(hdc, TRANSPARENT)
        return LRESULT(Int(bitPattern: GetSysColorBrush(COLOR_WINDOW)))

    case UINT(WM_NCDESTROY):
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0 {
            Unmanaged<ScrollViewState>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: Int(userData))!
            ).release()
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

    default:
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
}

extension List: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // List renders as a VStack inside a scrollable container
        let scrollView = ScrollView(.vertical) { content }
        return winRenderView(scrollView, in: context)
    }
}

/// Map SF Symbol names to Win32 stock icon resource IDs.
/// Returns nil for unknown names so the caller can fall back to text.
private func winSystemIconID(_ name: String) -> LPCWSTR? {
    switch name {
    case "info.circle", "info", "info.circle.fill":
        return win32_MAKEINTRESOURCEW(32516) // OIC_INFORMATION
    case "exclamationmark.triangle", "exclamationmark.triangle.fill", "warning":
        return win32_MAKEINTRESOURCEW(32515) // OIC_WARNING
    case "xmark.circle", "xmark.circle.fill", "xmark.octagon", "error":
        return win32_MAKEINTRESOURCEW(32513) // OIC_ERROR
    case "questionmark.circle", "questionmark.circle.fill", "questionmark":
        return win32_MAKEINTRESOURCEW(32514) // OIC_QUES
    case "shield", "shield.fill", "lock", "lock.fill":
        return win32_MAKEINTRESOURCEW(32518) // OIC_SHIELD
    case "app", "app.fill", "macwindow":
        return win32_MAKEINTRESOURCEW(32512) // IDI_APPLICATION
    default:
        return nil
    }
}

/// Subclass proc that frees an owned HBITMAP on window destruction.
private let imageBitmapCleanupProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    if uMsg == UINT(WM_NCDESTROY) {
        if dwRefData != 0, let handle = UnsafeMutableRawPointer(bitPattern: UInt(dwRefData)) {
            DeleteObject(handle.assumingMemoryBound(to: HBITMAP__.self))
        }
        RemoveWindowSubclass(hwnd, imageBitmapCleanupProc, uIdSubclass)
    }
    return DefSubclassProc(hwnd, uMsg, wParam, lParam)
}

extension Image: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        switch source {
        case .systemName(let name):
            return winCreateSystemIcon(name: name, in: context)
        case .filePath(let path):
            return winCreateFileImage(path: path, in: context)
        }
    }

    private func winCreateSystemIcon(name: String, in context: RenderContext) -> HWND? {
        let size = Int32(scale.pointSize)

        // Try to load a known stock icon; unknown names get text fallback
        var hIcon: UnsafeMutableRawPointer? = nil
        if let iconID = winSystemIconID(name) {
            hIcon = LoadImageW(
                nil, iconID,
                UINT(IMAGE_ICON),
                size, size,
                UINT(LR_SHARED)
            )
        }

        guard let hIcon = hIcon else {
            // Fallback to text label showing the requested symbol name
            let fallback = "[\(name)]"
            let measured = measureText(fallback, hwnd: context.parent)
            return fallback.withCString(encodedAs: UTF16.self) { wstr in
                win32_CreateChildWindow(
                    win32_WC_STATIC(), wstr,
                    DWORD(SS_LEFTNOWORDWRAP | SS_NOTIFY | SS_NOPREFIX),
                    0, 0, measured.width + 4, measured.height + 2,
                    context.parent, nil, context.hInstance
                )
            }
        }

        // Wrap in fixed-size container to prevent layout stretch
        registerStackClassIfNeeded(hInstance: context.hInstance)
        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, size, size,
            context.parent, nil, context.hInstance, nil
        )
        guard let container = container else { return nil }

        let iconHwnd = win32_CreateChildWindow(
            win32_WC_STATIC(), nil,
            DWORD(SS_ICON | SS_REALSIZECONTROL | SS_NOTIFY),
            0, 0, size, size,
            container, nil, context.hInstance
        )

        if let iconHwnd = iconHwnd {
            SendMessageW(iconHwnd, UINT(STM_SETICON),
                         WPARAM(UInt(bitPattern: hIcon.assumingMemoryBound(to: HICON__.self))), 0)
        }

        return container
    }

    private func winCreateFileImage(path: String, in context: RenderContext) -> HWND? {
        // Try WIC first (supports PNG, JPEG, BMP, GIF, TIFF)
        if let imageData = D2DRenderer.shared.loadImageFile(path),
           let hBitmap = D2DRenderer.shared.createHBitmap(
               pixels: imageData.pixels, width: imageData.width, height: imageData.height) {
            free(imageData.pixels)

            let displayW = Int32(imageData.width)
            let displayH = Int32(imageData.height)

            let hwnd = win32_CreateChildWindow(
                win32_WC_STATIC(), nil,
                DWORD(SS_BITMAP | SS_REALSIZECONTROL | SS_NOTIFY),
                0, 0, displayW, displayH,
                context.parent, nil, context.hInstance
            )

            if let hwnd = hwnd {
                SendMessageW(hwnd, UINT(STM_SETIMAGE), WPARAM(IMAGE_BITMAP),
                             LPARAM(Int(bitPattern: OpaquePointer(hBitmap))))
                // Attach cleanup subclass to free HBITMAP on destroy
                SetWindowSubclass(hwnd, imageBitmapCleanupProc, 46,
                                  DWORD_PTR(UInt(bitPattern: OpaquePointer(hBitmap))))
            }

            return hwnd
        }

        // Fallback: try Win32 LoadImageW for BMP/ICO
        let hBitmap = path.withCString(encodedAs: UTF16.self) { wstr in
            LoadImageW(nil, wstr, UINT(IMAGE_BITMAP), 0, 0, UINT(LR_LOADFROMFILE))
        }

        if let hBitmap = hBitmap {
            var bm = BITMAP()
            GetObjectW(hBitmap.assumingMemoryBound(to: HBITMAP__.self),
                       Int32(MemoryLayout<BITMAP>.size), &bm)
            let displayW = bm.bmWidth
            let displayH = bm.bmHeight

            let hwnd = win32_CreateChildWindow(
                win32_WC_STATIC(), nil,
                DWORD(SS_BITMAP | SS_REALSIZECONTROL | SS_NOTIFY),
                0, 0, displayW, displayH,
                context.parent, nil, context.hInstance
            )

            if let hwnd = hwnd {
                SendMessageW(hwnd, UINT(STM_SETIMAGE), WPARAM(IMAGE_BITMAP),
                             LPARAM(Int(bitPattern: hBitmap)))
                SetWindowSubclass(hwnd, imageBitmapCleanupProc, 46,
                                  DWORD_PTR(UInt(bitPattern: hBitmap)))
            }

            return hwnd
        }

        // Final fallback: text label
        let fallback = "[img: \(path)]"
        let measured = measureText(fallback, hwnd: context.parent)
        return fallback.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_STATIC(), wstr,
                DWORD(SS_LEFTNOWORDWRAP | SS_NOTIFY | SS_NOPREFIX),
                0, 0, measured.width + 4, measured.height + 2,
                context.parent, nil, context.hInstance
            )
        }
    }
}

// MARK: - Phase 4A views

extension SecureField: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let currentText = text.wrappedValue
        let measured = measureText(currentText.isEmpty ? placeholder : currentText, hwnd: context.parent)

        let hwnd = currentText.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_EDIT(), wstr,
                DWORD(ES_PASSWORD | ES_AUTOHSCROLL | WS_BORDER | WS_TABSTOP),
                0, 0, max(measured.width + 16, 150), measured.height + 8,
                context.parent, nil, context.hInstance
            )
        }

        guard let hwnd = hwnd else { return nil }

        if !placeholder.isEmpty {
            placeholder.withCString(encodedAs: UTF16.self) { ptr in
                _ = SendMessageW(hwnd, UINT(EM_SETCUEBANNER), 1, LPARAM(Int(bitPattern: ptr)))
            }
        }

        let binding = text
        let handler = SubclassHandler(hwnd: hwnd)
        handler.onTextChanged = { (newValue: String) in
            if newValue != binding.wrappedValue { binding.wrappedValue = newValue }
        }
        let state = TextFieldState(handler: handler)
        let statePtr = Unmanaged.passRetained(state).toOpaque()
        SetWindowSubclass(hwnd, textFieldCleanupProc, 41, DWORD_PTR(UInt(bitPattern: statePtr)))

        return hwnd
    }
}

extension TextEditor: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let currentText = text.wrappedValue

        let hwnd = currentText.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_EDIT(), wstr,
                DWORD(ES_MULTILINE | ES_WANTRETURN | ES_AUTOVSCROLL | WS_BORDER | WS_VSCROLL | WS_TABSTOP),
                0, 0, 200, 100,
                context.parent, nil, context.hInstance
            )
        }

        guard let hwnd = hwnd else { return nil }

        let binding = text
        let handler = SubclassHandler(hwnd: hwnd)
        handler.onTextChanged = { newValue in
            if newValue != binding.wrappedValue { binding.wrappedValue = newValue }
        }
        let state = TextFieldState(handler: handler)
        let statePtr = Unmanaged.passRetained(state).toOpaque()
        SetWindowSubclass(hwnd, textFieldCleanupProc, 41, DWORD_PTR(UInt(bitPattern: statePtr)))

        return hwnd
    }
}

extension Stepper: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        // Container: [label] [value] [▲▼]
        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 200, 24,
            context.parent, nil, context.hInstance, nil
        )!

        // Label
        let labelMeasured = measureText(label, hwnd: context.parent)
        _ = label.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_STATIC(), wstr, DWORD(SS_LEFTNOWORDWRAP | SS_NOTIFY | SS_NOPREFIX),
                0, 0, labelMeasured.width + 4, 24,
                container, nil, context.hInstance
            )
        }

        // Value display
        let valText = "\(value.wrappedValue)"
        _ = valText.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_STATIC(), wstr, DWORD(SS_CENTER | SS_CENTERIMAGE),
                labelMeasured.width + 8, 0, 40, 24,
                container, nil, context.hInstance
            )
        }

        // Minus button
        let minusID = nextControlID()
        let minusHwnd = "-".withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_BUTTON(), wstr, DWORD(BS_PUSHBUTTON),
                labelMeasured.width + 52, 0, 24, 24,
                container, HMENU(bitPattern: UInt(minusID)), context.hInstance
            )
        }

        // Plus button
        let plusID = nextControlID()
        let plusHwnd = "+".withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_BUTTON(), wstr, DWORD(BS_PUSHBUTTON),
                labelMeasured.width + 78, 0, 24, 24,
                container, HMENU(bitPattern: UInt(plusID)), context.hInstance
            )
        }

        let binding = value
        let stepVal = step
        let lo = range.lowerBound
        let hi = range.upperBound
        registerCommandHandler(controlID: minusID) {
            let newVal = max(binding.wrappedValue - stepVal, lo)
            if newVal != binding.wrappedValue { binding.wrappedValue = newVal }
        }
        registerCommandHandler(controlID: plusID) {
            let newVal = min(binding.wrappedValue + stepVal, hi)
            if newVal != binding.wrappedValue { binding.wrappedValue = newVal }
        }
        if let m = minusHwnd { SetWindowSubclass(m, buttonCleanupProc, 0, DWORD_PTR(minusID)) }
        if let p = plusHwnd { SetWindowSubclass(p, buttonCleanupProc, 0, DWORD_PTR(plusID)) }

        let totalW = labelMeasured.width + 106
        SetWindowPos(container, nil, 0, 0, totalW, 24, UINT(SWP_NOZORDER | SWP_NOMOVE))

        return container
    }
}

extension ProgressView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let progressClass: [WCHAR] = Array("msctls_progress32".utf16) + [0]
        let hwnd = progressClass.withUnsafeBufferPointer { ptr in
            CreateWindowExW(0, ptr.baseAddress!, nil, DWORD(WS_CHILD | WS_VISIBLE),
                0, 0, 200, 20, context.parent, nil, context.hInstance, nil)
        }
        guard let hwnd = hwnd else { return nil }
        if let val = value {
            SendMessageW(hwnd, UINT(PBM_SETRANGE32), 0, 1000)
            SendMessageW(hwnd, UINT(PBM_SETPOS), WPARAM(Int32((val / total) * 1000)), 0)
        } else {
            let style = win32_GetWindowLongPtrW(hwnd, GWL_STYLE)
            win32_SetWindowLongPtrW(hwnd, GWL_STYLE, style | LONG_PTR(PBS_MARQUEE))
            SendMessageW(hwnd, UINT(PBM_SETMARQUEE), 1, 30)
        }
        return hwnd
    }
}

extension Label: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let displayText: String
        if let icon = systemImage {
            displayText = "[\(icon)] \(title)"
        } else {
            displayText = title
        }
        let measured = measureText(displayText, hwnd: context.parent)
        return displayText.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_STATIC(), wstr, DWORD(SS_LEFTNOWORDWRAP | SS_NOTIFY | SS_NOPREFIX),
                0, 0, measured.width + 4, measured.height + 2,
                context.parent, nil, context.hInstance
            )
        }
    }
}

extension Link: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let url = destination
        return createNativeButton(title: title, action: {
            url.withCString(encodedAs: UTF16.self) { urlPtr in
                "open".withCString(encodedAs: UTF16.self) { verbPtr in
                    _ = ShellExecuteW(nil, verbPtr, urlPtr, nil, nil, SW_SHOWNORMAL)
                }
            }
        }, context: context)
    }
}

// MARK: - Phase 4B: Lifecycle & container modifiers

extension OnAppearView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }
        // Fire onAppear after the view is rendered (deferred to next message loop cycle)
        let appearAction = action
        let root = findRootWindow(from: context.parent)
        runOnMainThread(hwnd: root) { appearAction() }
        return hwnd
    }
}

extension OnDisappearView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }
        // Fires onDisappear when the root HWND is destroyed.
        // Known limitation: for stateful content, this fires when the
        // ViewHost container is destroyed, not on individual rebuilds.
        // Full SwiftUI disappearance semantics would require tracking
        // view identity across rebuilds, which our architecture doesn't support yet.
        let disappearAction = action
        let box = Unmanaged.passRetained(ClosureBox(disappearAction)).toOpaque()
        SetWindowSubclass(hwnd, onDisappearProc, 90, DWORD_PTR(UInt(bitPattern: box)))
        return hwnd
    }
}

private let onDisappearProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    if uMsg == UINT(WM_NCDESTROY), dwRefData != 0 {
        let box = Unmanaged<ClosureBox>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).takeRetainedValue()
        box.closure()
        RemoveWindowSubclass(hwnd, onDisappearProc, uIdSubclass)
    }
    return DefSubclassProc(hwnd, uMsg, wParam, lParam)
}

/// Sheet HWND stored on the root window (stable across rebuilds).
private let sheetPropName: UnsafePointer<WCHAR> = {
    "SwiftUISheet".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

extension SheetModifierView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }

        let root = findRootWindow(from: context.parent)
        let existingSheet = GetPropW(root, sheetPropName)

        if isPresented.wrappedValue && existingSheet == nil {
            let binding = isPresented
            let sheetBuilder = sheetContent
            let hInst = context.hInstance

            registerStackClassIfNeeded(hInstance: hInst)
            let sheetHwnd = CreateWindowExW(
                DWORD(WS_EX_TOOLWINDOW),
                stackContainerClassName, nil,
                DWORD(WS_POPUP) | DWORD(WS_VISIBLE) | DWORD(WS_CAPTION) | DWORD(WS_SYSMENU),
                Int32(CW_USEDEFAULT), Int32(CW_USEDEFAULT), 400, 300,
                root, nil, hInst, nil
            )

            if let sheetHwnd = sheetHwnd {
                // Track on root window (stable, survives presenter rebuilds)
                SetPropW(root, sheetPropName, HANDLE(bitPattern: Int(bitPattern: sheetHwnd)))

                let sheetContext = RenderContext(parent: sheetHwnd, hInstance: hInst)
                if let sheetChild = winRenderView(sheetBuilder, in: sheetContext) {
                    var rect = RECT()
                    GetClientRect(sheetHwnd, &rect)
                    SetWindowPos(sheetChild, nil, 0, 0,
                                 rect.right, rect.bottom, UINT(SWP_NOZORDER))
                }

                // Dismiss subclass: WM_CLOSE sets binding=false + destroys
                let info = SheetDismissInfo(dismiss: { binding.wrappedValue = false }, root: root)
                let infoPtr = Unmanaged.passRetained(info).toOpaque()
                SetWindowSubclass(sheetHwnd, sheetDismissProc, 91,
                                  DWORD_PTR(UInt(bitPattern: infoPtr)))
            }
        } else if !isPresented.wrappedValue, let existing = existingSheet {
            // Programmatic dismiss: isPresented set to false while sheet is open
            if let sheetHwnd = HWND(bitPattern: Int(bitPattern: existing)) {
                DestroyWindow(sheetHwnd)
            }
        }

        return hwnd
    }
}

private class SheetDismissInfo {
    let dismiss: () -> Void
    let root: HWND
    var dismissed = false
    init(dismiss: @escaping () -> Void, root: HWND) {
        self.dismiss = dismiss
        self.root = root
    }
}

private let sheetDismissProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    switch uMsg {
    case UINT(WM_CLOSE):
        if dwRefData != 0 {
            let info = Unmanaged<SheetDismissInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            ).takeUnretainedValue()
            if !info.dismissed {
                info.dismissed = true
                info.dismiss()
            }
        }
        DestroyWindow(hwnd)
        return 0

    case UINT(WM_NCDESTROY):
        if dwRefData != 0 {
            let info = Unmanaged<SheetDismissInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            )
            let val = info.takeUnretainedValue()
            RemovePropW(val.root, sheetPropName)
            if !val.dismissed {
                val.dismissed = true
                val.dismiss()
            }
            info.release()
        }
        RemoveWindowSubclass(hwnd, sheetDismissProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

extension AlertModifierView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }
        if isPresented.wrappedValue {
            let binding = isPresented
            let alertTitle = title
            let alertMsg = message.isEmpty ? title : message
            let root = findRootWindow(from: context.parent)
            // Defer alert to after rendering completes
            runOnMainThread(hwnd: root) {
                guard binding.wrappedValue else { return }
                binding.wrappedValue = false
                alertTitle.withCString(encodedAs: UTF16.self) { titlePtr in
                    alertMsg.withCString(encodedAs: UTF16.self) { msgPtr in
                        _ = MessageBoxW(root, msgPtr, titlePtr, UINT(MB_OK))
                    }
                }
            }
        }
        return hwnd
    }
}

extension OverlayView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        // Container sized to content (overlay does NOT affect size)
        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN | WS_CLIPSIBLINGS),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        guard let contentHwnd = winRenderView(content, in: childContext) else { return container }

        // Size container from content's natural size (not overlay)
        var contentRect = RECT()
        GetWindowRect(contentHwnd, &contentRect)
        let w = contentRect.right - contentRect.left
        let h = contentRect.bottom - contentRect.top
        SetWindowPos(container, nil, 0, 0, w, h, UINT(SWP_NOZORDER | SWP_NOMOVE))
        SetWindowPos(contentHwnd, nil, 0, 0, w, h, UINT(SWP_NOZORDER))

        // Render overlay on top, positioned by alignment
        if let overlayHwnd = winRenderView(overlay, in: childContext) {
            var overlayRect = RECT()
            GetWindowRect(overlayHwnd, &overlayRect)
            let ow = overlayRect.right - overlayRect.left
            let oh = overlayRect.bottom - overlayRect.top

            let ox: Int32
            let oy: Int32
            switch alignment {
            case .topLeading:     ox = 0;           oy = 0
            case .top:            ox = (w - ow) / 2; oy = 0
            case .topTrailing:    ox = w - ow;       oy = 0
            case .leading:        ox = 0;           oy = (h - oh) / 2
            case .center:         ox = (w - ow) / 2; oy = (h - oh) / 2
            case .trailing:       ox = w - ow;       oy = (h - oh) / 2
            case .bottomLeading:  ox = 0;           oy = h - oh
            case .bottom:         ox = (w - ow) / 2; oy = h - oh
            case .bottomTrailing: ox = w - ow;       oy = h - oh
            }
            SetWindowPos(overlayHwnd, nil, ox, oy, ow, oh, UINT(SWP_NOZORDER))
        }

        return container
    }
}

extension Section: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // Render as: [Header text (bold)] [Divider] [Content]
        guard let header, !header.isEmpty else {
            return winRenderView(content, in: context)
        }
        let section = VStack(alignment: .leading, spacing: 4) {
            Text(header).font(.headline)
            Divider()
            content
        }
        return winRenderView(section, in: context)
    }
}

// MARK: - Phase 4A/4B remaining

extension ConfirmationDialogView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }
        if isPresented.wrappedValue {
            let binding = isPresented
            let dlgTitle = title
            let dlgButtons = buttons
            let root = findRootWindow(from: context.parent)
            runOnMainThread(hwnd: root) {
                guard binding.wrappedValue else { return }
                binding.wrappedValue = false
                let result = dlgTitle.withCString(encodedAs: UTF16.self) { titlePtr in
                    dlgTitle.withCString(encodedAs: UTF16.self) { msgPtr in
                        MessageBoxW(root, msgPtr, titlePtr, UINT(MB_YESNO | MB_ICONQUESTION))
                    }
                }
                if result == IDYES {
                    dlgButtons.first?.action()
                } else {
                    dlgButtons.first(where: { $0.role == .cancel })?.action()
                }
            }
        }
        return hwnd
    }
}

extension Form: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // Form renders as a VStack with padding — visual grouping for controls
        let formView = VStack(alignment: .leading, spacing: 8) { content }.padding()
        return winRenderView(formView, in: context)
    }
}

extension TabView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        var tabPages: [(label: String, hwnd: HWND)] = []
        for tab in tabs {
            if let pageHwnd = winRenderAnyView(tab.wrapped, in: childContext) {
                tabPages.append((label: tab.title, hwnd: pageHwnd))
            }
        }

        guard !tabPages.isEmpty else { return container }

        // Create tab buttons at the top
        let tabBarHeight: Int32 = 28
        var buttonX: Int32 = 0
        var tabButtonIDs: [(id: WORD, index: Int)] = []

        for (i, tab) in tabPages.enumerated() {
            let measured = measureText(tab.label, hwnd: context.parent)
            let btnW = measured.width + 16
            let controlID = nextControlID()

            let btn = tab.label.withCString(encodedAs: UTF16.self) { wstr in
                win32_CreateChildWindow(
                    win32_WC_BUTTON(), wstr, DWORD(BS_PUSHBUTTON),
                    buttonX, 0, btnW, tabBarHeight,
                    container, HMENU(bitPattern: UInt(controlID)), context.hInstance
                )
            }
            // Cleanup handler on WM_NCDESTROY to prevent command handler leak
            if let btn = btn {
                SetWindowSubclass(btn, buttonCleanupProc, 0, DWORD_PTR(controlID))
            }
            tabButtonIDs.append((id: controlID, index: i))
            buttonX += btnW + 2
        }

        // Position tab pages below buttons, show only first
        // Size all pages to the max dimensions for consistent switching
        var maxW: Int32 = buttonX
        var maxH: Int32 = 0
        for tab in tabPages {
            var r = RECT()
            GetWindowRect(tab.hwnd, &r)
            maxW = max(maxW, r.right - r.left)
            maxH = max(maxH, r.bottom - r.top)
        }
        for (i, tab) in tabPages.enumerated() {
            SetWindowPos(tab.hwnd, nil, 0, tabBarHeight + 2, maxW, maxH, UINT(SWP_NOZORDER))
            ShowWindow(tab.hwnd, i == 0 ? SW_SHOW : SW_HIDE)
        }

        SetWindowPos(container, nil, 0, 0, maxW, tabBarHeight + 2 + maxH,
                     UINT(SWP_NOZORDER | SWP_NOMOVE))

        // Wire tab buttons to show/hide pages + resize selected page
        let pageAreaW = maxW
        let pageAreaH = maxH
        for entry in tabButtonIDs {
            let pages = tabPages
            let selectedIndex = entry.index
            let barH = tabBarHeight
            registerCommandHandler(controlID: entry.id) {
                for (i, page) in pages.enumerated() {
                    if i == selectedIndex {
                        SetWindowPos(page.hwnd, nil, 0, barH + 2, pageAreaW, pageAreaH, UINT(SWP_NOZORDER))
                        ShowWindow(page.hwnd, SW_SHOW)
                    } else {
                        ShowWindow(page.hwnd, SW_HIDE)
                    }
                }
            }
        }

        return container
    }
}

/// Retains per-radio-button callback info for segmented Picker.
private class SegmentedPickerInfo {
    let index: Int
    let callback: (Int) -> Void
    init(index: Int, callback: @escaping (Int) -> Void) {
        self.index = index
        self.callback = callback
    }
}

/// Subclass proc for radio buttons in a segmented Picker.
private let segmentedRadioProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    switch uMsg {
    case UINT(WM_COMMAND):
        let code = Int32(win32_HIWORD(DWORD_PTR(wParam)))
        if code == BN_CLICKED {
            let childHwnd = HWND(bitPattern: UInt(lParam))
            if let childHwnd = childHwnd {
                let ptr = GetPropW(childHwnd, segmentedPickerPropName)
                if let ptr = ptr {
                    let info = Unmanaged<SegmentedPickerInfo>.fromOpaque(ptr).takeUnretainedValue()
                    info.callback(info.index)
                }
            }
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_CTLCOLORSTATIC):
        // Forward to parent for background color propagation
        let parentHwnd = GetParent(hwnd)
        if let parentHwnd = parentHwnd {
            return SendMessageW(parentHwnd, uMsg, wParam, lParam)
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_NCDESTROY):
        RemoveWindowSubclass(hwnd, segmentedRadioProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

/// Cleanup proc for radio buttons — releases the SegmentedPickerInfo.
private let segmentedRadioCleanupProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    if uMsg == UINT(WM_NCDESTROY) {
        let ptr = GetPropW(hwnd, segmentedPickerPropName)
        if let ptr = ptr {
            Unmanaged<SegmentedPickerInfo>.fromOpaque(ptr).release()
            RemovePropW(hwnd, segmentedPickerPropName)
        }
        RemoveWindowSubclass(hwnd, segmentedRadioCleanupProc, uIdSubclass)
    }
    return DefSubclassProc(hwnd, uMsg, wParam, lParam)
}

private let segmentedPickerPropName: UnsafePointer<WCHAR> = {
    "SwiftUISegPicker".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

extension Picker: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        switch style {
        case .segmented, .palette:
            return winCreateSegmentedWidget(in: context)
        case .automatic:
            return winCreateDropdownWidget(in: context)
        }
    }

    private func winCreateDropdownWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 250, 24,
            context.parent, nil, context.hInstance, nil
        )!

        // Label
        let labelMeasured = measureText(label, hwnd: context.parent)
        _ = label.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_STATIC(), wstr, DWORD(SS_LEFTNOWORDWRAP | SS_NOTIFY | SS_NOPREFIX),
                0, 2, labelMeasured.width + 4, 20,
                container, nil, context.hInstance
            )
        }

        // ComboBox
        let comboX = labelMeasured.width + 8
        let comboHwnd = win32_CreateChildWindow(
            win32_WC_COMBOBOX(), nil,
            DWORD(CBS_DROPDOWNLIST | WS_TABSTOP),
            comboX, 0, 150, 200,  // height 200 = dropdown list height
            container, nil, context.hInstance
        )

        guard let comboHwnd = comboHwnd else { return container }

        // Populate combobox from options array
        for option in options {
            _ = option.withCString(encodedAs: UTF16.self) { wstr in
                SendMessageW(comboHwnd, UINT(CB_ADDSTRING), 0, LPARAM(Int(bitPattern: wstr)))
            }
        }

        SendMessageW(comboHwnd, UINT(CB_SETCURSEL), WPARAM(selected), 0)

        // Wire CBN_SELCHANGE to callback
        let callback = onChanged
        let handler = SubclassHandler(hwnd: comboHwnd)
        handler.onCommand = {
            let sel = Int(SendMessageW(comboHwnd, UINT(CB_GETCURSEL), 0, 0))
            if sel >= 0 { callback?(sel) }
        }
        let state = TextFieldState(handler: handler)
        let statePtr = Unmanaged.passRetained(state).toOpaque()
        SetWindowSubclass(comboHwnd, textFieldCleanupProc, 41, DWORD_PTR(UInt(bitPattern: statePtr)))

        SetWindowPos(container, nil, 0, 0, comboX + 150, 24, UINT(SWP_NOZORDER | SWP_NOMOVE))

        return container
    }

    private func winCreateSegmentedWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        var x: Int32 = 0
        let buttonHeight: Int32 = 24
        let clampedSel = options.isEmpty ? 0 : max(0, min(selected, options.count - 1))

        // Optional label
        if !label.isEmpty {
            let labelMeasured = measureText(label, hwnd: context.parent)
            _ = label.withCString(encodedAs: UTF16.self) { wstr in
                win32_CreateChildWindow(
                    win32_WC_STATIC(), wstr, DWORD(SS_LEFTNOWORDWRAP | SS_NOTIFY | SS_NOPREFIX),
                    x, 2, labelMeasured.width + 4, 20,
                    container, nil, context.hInstance
                )
            }
            x += labelMeasured.width + 8
        }

        // Radio buttons — first gets WS_GROUP for keyboard grouping
        for (index, option) in options.enumerated() {
            let measured = measureText(option, hwnd: context.parent)
            let btnWidth = measured.width + 24  // extra space for radio circle
            let groupStyle: Int32 = (index == 0) ? WS_GROUP : 0

            let radioHwnd = option.withCString(encodedAs: UTF16.self) { wstr in
                win32_CreateChildWindow(
                    win32_WC_BUTTON(), wstr,
                    DWORD(BS_AUTORADIOBUTTON | WS_TABSTOP | groupStyle),
                    x, 0, btnWidth, buttonHeight,
                    container, nil, context.hInstance
                )
            }

            if let radioHwnd = radioHwnd {
                if index == clampedSel {
                    SendMessageW(radioHwnd, UINT(BM_SETCHECK), WPARAM(BST_CHECKED), 0)
                }

                // Attach callback info via window property
                if let callback = onChanged {
                    let info = SegmentedPickerInfo(index: index, callback: callback)
                    let infoPtr = Unmanaged.passRetained(info).toOpaque()
                    SetPropW(radioHwnd, segmentedPickerPropName, HANDLE(infoPtr))
                    SetWindowSubclass(radioHwnd, segmentedRadioCleanupProc, 42, 0)
                }
            }

            x += btnWidth + 4
        }

        // Subclass container to handle WM_COMMAND from radio buttons
        SetWindowSubclass(container, segmentedRadioProc, 42, 0)

        SetWindowPos(container, nil, 0, 0, x > 0 ? x - 4 : 0, buttonHeight,
                     UINT(SWP_NOZORDER | SWP_NOMOVE))

        return container
    }
}

// MARK: - Toolbar

extension ToolbarView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }

        // Extract toolbar items and render them into the navigation header.
        // If we're inside a NavigationStack, add buttons to the header bar.
        // Otherwise, create a toolbar bar above the content.
        guard let navCtx = getCurrentNavigationContext() else {
            // Not inside NavigationStack — render toolbar items as an HStack above content
            return renderToolbarWithContent(hwnd: hwnd, context: context)
        }

        // Inside NavigationStack — add items to the header bar
        renderToolbarItems(into: navCtx, context: context)
        return hwnd
    }

    private func renderToolbarWithContent(hwnd: HWND, context: RenderContext) -> HWND? {
        guard !toolbarItems.isEmpty else { return hwnd }
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        // Render toolbar items with placement: leading left, trailing/primary right
        let toolbarContext = RenderContext(parent: container, hInstance: context.hInstance)
        var leadingX: Int32 = 0
        var trailingRendered: [(hwnd: HWND, width: Int32)] = []
        let barH: Int32 = 28

        for item in toolbarItems {
            guard let itemHwnd = winRenderAnyView(item.wrapped, in: toolbarContext) else { continue }
            var r = RECT()
            GetWindowRect(itemHwnd, &r)
            let w = r.right - r.left
            switch item.placement {
            case .leading:
                SetWindowPos(itemHwnd, nil, leadingX, 0, w, barH, UINT(SWP_NOZORDER))
                leadingX += w + 4
            case .trailing, .primaryAction:
                trailingRendered.append((hwnd: itemHwnd, width: w))
            }
        }

        SetParent(hwnd, container)
        var contentRect = RECT()
        GetWindowRect(hwnd, &contentRect)
        let contentW = max(contentRect.right - contentRect.left, leadingX + 100)

        // Position trailing items from right edge
        var trailingX = contentW - 4
        for item in trailingRendered.reversed() {
            trailingX -= item.width
            SetWindowPos(item.hwnd, nil, trailingX, 0, item.width, barH, UINT(SWP_NOZORDER))
            trailingX -= 4
        }
        let contentH = contentRect.bottom - contentRect.top
        SetWindowPos(container, nil, 0, 0, contentW, barH + contentH,
                     UINT(SWP_NOZORDER | SWP_NOMOVE))
        SetWindowPos(hwnd, nil, 0, barH, contentW, contentH, UINT(SWP_NOZORDER))
        return container
    }

    private func renderToolbarItems(into navCtx: Win32NavigationContext, context: RenderContext) {
        clearToolbarItems(from: navCtx.headerContainer)
        let headerContext = RenderContext(parent: navCtx.headerContainer, hInstance: context.hInstance)
        var leadingX: Int32 = 68
        var trailingItems: [(hwnd: HWND, width: Int32)] = []

        for item in toolbarItems {
            guard let itemHwnd = winRenderAnyView(item.wrapped, in: headerContext) else { continue }
            SetPropW(itemHwnd, toolbarItemPropName, HANDLE(bitPattern: 1))
            var r = RECT()
            GetWindowRect(itemHwnd, &r)
            let w = r.right - r.left
            switch item.placement {
            case .leading:
                SetWindowPos(itemHwnd, nil, leadingX, 2, w, 24, UINT(SWP_NOZORDER))
                leadingX += w + 4
            case .trailing, .primaryAction:
                trailingItems.append((hwnd: itemHwnd, width: w))
            }
        }

        var headerRect = RECT()
        GetClientRect(navCtx.headerContainer, &headerRect)
        var trailingX = headerRect.right - headerRect.left - 4
        for item in trailingItems.reversed() {
            trailingX -= item.width
            SetWindowPos(item.hwnd, nil, trailingX, 2, item.width, 24, UINT(SWP_NOZORDER))
            trailingX -= 4
        }
    }
}

private let toolbarItemPropName: UnsafePointer<WCHAR> = {
    "SwiftUIToolbarItem".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

private func clearToolbarItems(from container: HWND) {
    var toRemove: [HWND] = []
    var child = GetWindow(container, UINT(GW_CHILD))
    while let c = child {
        if GetPropW(c, toolbarItemPropName) != nil { toRemove.append(c) }
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
    for hwnd in toRemove { DestroyWindow(hwnd) }
}

extension ToolbarItem: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        winRenderView(content, in: context)
    }
}

// MARK: - Phase 4D views

extension Menu: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let menuElements = elements
        return createNativeButton(title: "☰ \(title)", action: {
            guard let hMenu = CreatePopupMenu() else { return }
            var menuID: UINT = 50000
            var menuActions: [UINT: () -> Void] = [:]

            func addElementsTo(_ targetMenu: HMENU, _ elems: [MenuElement]) {
                for elem in elems {
                    switch elem {
                    case .item(let label, let action):
                        let id = menuID; menuID += 1
                        _ = label.withCString(encodedAs: UTF16.self) { wstr in
                            AppendMenuW(targetMenu, UINT(MF_STRING), UINT_PTR(id), wstr)
                        }
                        menuActions[id] = action
                    case .divider:
                        AppendMenuW(targetMenu, UINT(MF_SEPARATOR), 0, nil)
                    case .submenu(let label, let children):
                        if let subMenu = CreatePopupMenu() {
                            addElementsTo(subMenu, children)
                            _ = label.withCString(encodedAs: UTF16.self) { wstr in
                                AppendMenuW(targetMenu, UINT(MF_POPUP), UINT_PTR(Int(bitPattern: subMenu)), wstr)
                            }
                        }
                    }
                }
            }
            addElementsTo(hMenu, menuElements)

            var pt = POINT()
            GetCursorPos(&pt)
            let root = findRootWindow(from: context.parent)
            for (id, action) in menuActions {
                registerCommandHandler(controlID: WORD(id), action: action)
            }
            _ = TrackPopupMenu(hMenu, 0, pt.x, pt.y, 0, root, nil)
            DestroyMenu(hMenu)
            for id in menuActions.keys {
                unregisterCommandHandler(controlID: WORD(id))
            }
        }, context: context)
    }
}

extension DisclosureGroup: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        // Toggle button
        let arrow = isExpanded ? "▼" : "▶"
        let btnText = "\(arrow) \(title)"
        let controlID = nextControlID()
        let measured = measureText(btnText, hwnd: context.parent)

        _ = btnText.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_BUTTON(), wstr, DWORD(BS_PUSHBUTTON),
                0, 0, measured.width + 16, measured.height + 8,
                container, HMENU(bitPattern: UInt(controlID)), context.hInstance
            )
        }

        let expandCallback = onExpandedChange
        let currentExpanded = isExpanded
        registerCommandHandler(controlID: controlID) {
            expandCallback?(!currentExpanded)
        }

        // Content (shown only if expanded)
        var totalH = measured.height + 12
        if isExpanded {
            let childContext = RenderContext(parent: container, hInstance: context.hInstance)
            if let childHwnd = winRenderView(content, in: childContext) {
                var r = RECT()
                GetWindowRect(childHwnd, &r)
                let ch = r.bottom - r.top
                let cw = r.right - r.left
                SetWindowPos(childHwnd, nil, 8, totalH, cw, ch, UINT(SWP_NOZORDER))
                totalH += ch
            }
        }

        SetWindowPos(container, nil, 0, 0, max(measured.width + 20, 200), totalH,
                     UINT(SWP_NOZORDER | SWP_NOMOVE))

        return container
    }
}

extension DatePicker: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)
        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 250, 24,
            context.parent, nil, context.hInstance, nil
        )!

        let labelText = title
        let labelMeasured = measureText(labelText, hwnd: context.parent)
        _ = labelText.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_STATIC(), wstr, DWORD(SS_LEFTNOWORDWRAP | SS_NOTIFY | SS_NOPREFIX),
                0, 2, labelMeasured.width + 4, 20,
                container, nil, context.hInstance
            )
        }

        let dtpClass: [WCHAR] = Array("SysDateTimePick32".utf16) + [0]
        let dtp = dtpClass.withUnsafeBufferPointer { ptr in
            CreateWindowExW(
                0, ptr.baseAddress!, nil,
                DWORD(WS_CHILD | WS_VISIBLE | WS_TABSTOP),
                labelMeasured.width + 8, 0, 150, 24,
                container, nil, context.hInstance, nil
            )
        }

        // Initialize control from binding value
        if let dtp = dtp, let sel = selection {
            let dc = sel.wrappedValue
            var st = SYSTEMTIME()
            st.wYear = WORD(dc.year); st.wMonth = WORD(dc.month); st.wDay = WORD(dc.day)
            withUnsafePointer(to: st) { stPtr in
                _ = SendMessageW(dtp, UINT(DTM_SETSYSTEMTIME), 0,
                                 LPARAM(Int(bitPattern: stPtr)))
            }
        }

        // Wire DTN_DATETIMECHANGE → DateComponents binding/callback
        if let dtp = dtp {
            let sel = selection
            let cb = onChange
            let info = DatePickerNotifyInfo(selection: sel, onChange: cb, dtp: dtp)
            let infoPtr = Unmanaged.passRetained(info).toOpaque()
            SetWindowSubclass(container, datePickerNotifyProc, 43, DWORD_PTR(UInt(bitPattern: infoPtr)))
        }
        return container
    }
}

private class DatePickerNotifyInfo {
    let selection: Binding<SwiftOpenUI.DateComponents>?
    let onChange: ((SwiftOpenUI.DateComponents) -> Void)?
    let dtp: HWND
    init(selection: Binding<SwiftOpenUI.DateComponents>?, onChange: ((SwiftOpenUI.DateComponents) -> Void)?, dtp: HWND) {
        self.selection = selection
        self.onChange = onChange
        self.dtp = dtp
    }
}

private let datePickerNotifyProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    switch uMsg {
    case UINT(WM_NOTIFY):
        if dwRefData != 0 {
            let nmhdr = UnsafePointer<NMHDR>(bitPattern: Int(lParam))
            if let nmhdr = nmhdr, nmhdr.pointee.code == UINT(DTN_DATETIMECHANGE) {
                let info = Unmanaged<DatePickerNotifyInfo>.fromOpaque(
                    UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
                ).takeUnretainedValue()
                var st = SYSTEMTIME()
                withUnsafeMutablePointer(to: &st) { stPtr in
                    _ = SendMessageW(info.dtp, UINT(DTM_GETSYSTEMTIME), 0,
                                     LPARAM(Int(bitPattern: stPtr)))
                }
                let dc = SwiftOpenUI.DateComponents(year: Int(st.wYear), month: Int(st.wMonth), day: Int(st.wDay))
                info.selection?.wrappedValue = dc
                info.onChange?(dc)
            }
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    case UINT(WM_NCDESTROY):
        if dwRefData != 0 {
            Unmanaged<DatePickerNotifyInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            ).release()
        }
        RemoveWindowSubclass(hwnd, datePickerNotifyProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

extension LazyVStack: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // Non-virtualized: render all items in a ScrollView + VStack
        let vstack = VStack(spacing: 0) {
            ForEach(0..<items.count) { i in contentBuilder(items[i]) }
        }
        let scrollView = ScrollView(.vertical) { vstack }
        return winRenderView(scrollView, in: context)
    }
}

extension LazyHStack: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let hstack = HStack(spacing: 0) {
            ForEach(0..<items.count) { i in contentBuilder(items[i]) }
        }
        return winRenderView(hstack, in: context)
    }
}

/// A rendered grid cell: its HWND, column span, and natural size.
private struct GridCellInfo {
    let hwnd: HWND
    let span: Int
    let naturalWidth: Int32
    let naturalHeight: Int32
}

/// Extract cells from a GridRow, unwrapping GridCellSpanView to get span metadata.
private func extractGridCells(from view: any View, in context: RenderContext) -> [GridCellInfo] {
    // If the view is a GridRow, get its children
    func getCells<V: View>(_ v: V) -> [any View] {
        if let gridRow = v as? MultiChildView {
            return gridRow.children
        }
        return [v]
    }
    let cellViews = getCells(view)

    var cells: [GridCellInfo] = []
    for cellView in cellViews {
        func renderCell<C: View>(_ c: C) {
            // Check if the cell has a column span via GridCellSpanView
            let span: Int
            let viewToRender: any View
            if let spanView = c as? GridCellSpanProvider {
                span = spanView.gridColumnSpan
                // Unwrap the GridCellSpanView to get the actual content
                let mirror = Mirror(reflecting: c)
                if let content = mirror.children.first(where: { $0.label == "content" })?.value as? any View {
                    viewToRender = content
                } else {
                    viewToRender = c
                }
            } else {
                span = 1
                viewToRender = c
            }

            if let hwnd = winRenderAnyView(viewToRender, in: context) {
                var r = RECT()
                GetWindowRect(hwnd, &r)
                cells.append(GridCellInfo(
                    hwnd: hwnd,
                    span: span,
                    naturalWidth: r.right - r.left,
                    naturalHeight: r.bottom - r.top
                ))
            }
        }
        renderCell(cellView)
    }
    return cells
}

extension Grid: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)

        if useExplicitRows {
            // Explicit rows mode: each child should be a GridRow
            var rowChildren: [any View] = []
            if let multi = content as? MultiChildView {
                rowChildren = multi.children
            } else {
                rowChildren = [content]
            }

            // Pass 1: Extract all cells per row to determine max column count
            //         and measure natural column widths
            var allRowCells: [[GridCellInfo]] = []
            var maxLogicalCols = 0

            for child in rowChildren {
                let cells = extractGridCells(from: child, in: childContext)
                let logicalCols = cells.reduce(0) { $0 + $1.span }
                maxLogicalCols = max(maxLogicalCols, logicalCols)
                allRowCells.append(cells)
            }

            // Pass 2: Compute the natural width for each logical column
            //         by finding the max width among cells that span exactly 1 column
            var colWidths = [Int32](repeating: 0, count: maxLogicalCols)
            for cells in allRowCells {
                var col = 0
                for cell in cells {
                    if cell.span == 1 {
                        colWidths[col] = max(colWidths[col], cell.naturalWidth)
                    }
                    col += cell.span
                }
            }
            // Ensure all columns have at least some minimum width
            for i in 0..<colWidths.count {
                if colWidths[i] == 0 { colWidths[i] = 40 }
            }

            // Pass 3: Position each row's cells using computed column widths
            var totalH: Int32 = 0
            let totalW = colWidths.reduce(0, +) + Int32(hSpacing) * Int32(max(maxLogicalCols - 1, 0))

            for cells in allRowCells {
                var x: Int32 = 0
                var rowH: Int32 = 0
                var col = 0

                for cell in cells {
                    // Width for this cell = sum of spanned columns + spacing between them
                    var cellW: Int32 = 0
                    for s in 0..<cell.span {
                        let colIdx = col + s
                        if colIdx < colWidths.count {
                            cellW += colWidths[colIdx]
                        }
                    }
                    cellW += Int32(hSpacing) * Int32(max(cell.span - 1, 0))

                    SetWindowPos(cell.hwnd, nil, x, totalH, cellW, cell.naturalHeight,
                                 UINT(SWP_NOZORDER))
                    x += cellW + Int32(hSpacing)
                    rowH = max(rowH, cell.naturalHeight)
                    col += cell.span
                }

                totalH += rowH + Int32(vSpacing)
            }

            // Remove trailing vSpacing
            if !allRowCells.isEmpty { totalH -= Int32(vSpacing) }

            SetWindowPos(container, nil, 0, 0, totalW, totalH,
                         UINT(SWP_NOZORDER | SWP_NOMOVE))
        } else {
            // Auto-wrap mode: group flat children into rows of `columns` items
            var allChildren: [any View] = []
            if let multi = content as? MultiChildView {
                allChildren = multi.children
            } else {
                allChildren = [content]
            }

            var maxW: Int32 = 0
            var totalH: Int32 = 0
            var i = 0
            while i < allChildren.count {
                let end = min(i + columns, allChildren.count)
                let rowContainer = CreateWindowExW(
                    0, stackContainerClassName, nil,
                    DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
                    0, 0, 0, 0, container, nil, context.hInstance, nil
                )!
                let rowContext = RenderContext(parent: rowContainer, hInstance: context.hInstance)
                var rowHwnds: [HWND] = []
                for j in i..<end {
                    if let h = winRenderAnyView(allChildren[j], in: rowContext) {
                        rowHwnds.append(h)
                    }
                }
                let rowInfo = StackLayoutInfo(direction: .horizontal, spacing: Int32(hSpacing),
                                              children: rowHwnds, flexibleIndices: [])
                let rowInfoPtr = Unmanaged.passRetained(rowInfo).toOpaque()
                SetWindowSubclass(rowContainer, stackLayoutProc, 1, DWORD_PTR(UInt(bitPattern: rowInfoPtr)))
                let rowSize = computeNaturalSize(info: rowInfo)
                SetWindowPos(rowContainer, nil, 0, totalH, rowSize.width, rowSize.height,
                             UINT(SWP_NOZORDER))
                maxW = max(maxW, rowSize.width)
                totalH += rowSize.height + Int32(vSpacing)
                i = end
            }

            // Remove trailing vSpacing
            if !allChildren.isEmpty && totalH > 0 { totalH -= Int32(vSpacing) }

            SetWindowPos(container, nil, 0, 0, maxW, totalH,
                         UINT(SWP_NOZORDER | SWP_NOMOVE))
        }

        return container
    }
}

extension GridRow: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // When rendered standalone (not inside Grid's explicit rows mode),
        // render cells as an HStack with span-aware layout
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        let cellContext = RenderContext(parent: container, hInstance: context.hInstance)
        let cells = extractGridCells(from: self, in: cellContext)

        var x: Int32 = 0
        var maxH: Int32 = 0
        for cell in cells {
            SetWindowPos(cell.hwnd, nil, x, 0, cell.naturalWidth, cell.naturalHeight,
                         UINT(SWP_NOZORDER))
            x += cell.naturalWidth + 4
            maxH = max(maxH, cell.naturalHeight)
        }

        SetWindowPos(container, nil, 0, 0, x > 0 ? x - 4 : 0, maxH,
                     UINT(SWP_NOZORDER | SWP_NOMOVE))

        return container
    }
}

extension GridCellSpanView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // Render the wrapped content — span metadata is consumed by Grid
        return winRenderView(content, in: context)
    }
}

extension LazyVGrid: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let cols = max(gridItems.count, 1)
        // Group items into rows of `cols` columns
        let grid = Grid(columns: cols, spacing: 0) {
            ForEach(0..<items.count) { i in
                AnyView(contentBuilder(items[i]))
            }
        }
        let scrollView = ScrollView(.vertical) { grid }
        return winRenderView(scrollView, in: context)
    }
}

extension LazyHGrid: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // Horizontal grid: items distributed across `gridItems.count` rows
        // Each row is an HStack; items fill rows left-to-right, top-to-bottom
        let rowCount = max(gridItems.count, 1)
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        var maxW: Int32 = 0
        var totalH: Int32 = 0

        // Distribute items across rows
        let itemsPerRow = max(1, (items.count + rowCount - 1) / rowCount)
        var itemIdx = 0
        for _ in 0..<rowCount {
            guard itemIdx < items.count else { break }
            let rowEnd = min(itemIdx + itemsPerRow, items.count)

            let rowContainer = CreateWindowExW(
                0, stackContainerClassName, nil,
                DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
                0, 0, 0, 0, container, nil, context.hInstance, nil
            )!
            let rowCtx = RenderContext(parent: rowContainer, hInstance: context.hInstance)
            var rowHwnds: [HWND] = []
            for j in itemIdx..<rowEnd {
                if let h = winRenderView(contentBuilder(items[j]), in: rowCtx) {
                    rowHwnds.append(h)
                }
            }
            let rowInfo = StackLayoutInfo(direction: .horizontal, spacing: 0,
                                          children: rowHwnds, flexibleIndices: [])
            let rowInfoPtr = Unmanaged.passRetained(rowInfo).toOpaque()
            SetWindowSubclass(rowContainer, stackLayoutProc, 1, DWORD_PTR(UInt(bitPattern: rowInfoPtr)))
            let rowSize = computeNaturalSize(info: rowInfo)
            SetWindowPos(rowContainer, nil, 0, totalH, rowSize.width, rowSize.height,
                         UINT(SWP_NOZORDER))
            maxW = max(maxW, rowSize.width)
            totalH += rowSize.height

            itemIdx = rowEnd
        }

        SetWindowPos(container, nil, 0, 0, maxW, totalH, UINT(SWP_NOZORDER | SWP_NOMOVE))
        return container
    }
}

// MARK: - NavigationSplitView state and layout

/// Extract column width provider from a view tree via Mirror walking.
private func winExtractColumnWidthProvider(from view: Any, depth: Int = 0) -> NavigationSplitViewColumnWidthProvider? {
    guard depth < 20 else { return nil }
    if let provider = view as? NavigationSplitViewColumnWidthProvider {
        return provider
    }
    let mirror = Mirror(reflecting: view)
    for child in mirror.children {
        if let provider = child.value as? NavigationSplitViewColumnWidthProvider {
            return provider
        }
    }
    for child in mirror.children {
        if child.value is any View {
            if let result = winExtractColumnWidthProvider(from: child.value, depth: depth + 1) {
                return result
            }
        }
    }
    return nil
}

/// State for a NavigationSplitView container HWND.
private class SplitViewState {
    var sidebarHwnd: HWND?
    var contentHwnd: HWND?   // nil in 2-column mode
    var detailHwnd: HWND?

    // Column widths (in pixels)
    var sidebarWidth: Int32
    var contentWidth: Int32  // 0 in 2-column mode

    // Constraints from .navigationSplitViewColumnWidth()
    var sidebarMinWidth: Int32
    var sidebarMaxWidth: Int32
    var contentMinWidth: Int32
    var contentMaxWidth: Int32

    // Divider dragging
    var draggingDivider: Int = 0  // 0=none, 1=first divider, 2=second divider
    let dividerWidth: Int32 = 4  // visible divider width
    let hasContentColumn: Bool

    // Actual laid-out widths (after clamping to container), used for hit-testing
    var layoutSidebarW: Int32 = 0
    var layoutContentW: Int32 = 0

    // Visibility
    var visibility: NavigationSplitViewVisibility = .automatic

    init(hasContentColumn: Bool, sidebarWidth: Int32, contentWidth: Int32) {
        self.hasContentColumn = hasContentColumn
        self.sidebarWidth = sidebarWidth
        self.contentWidth = contentWidth
        self.sidebarMinWidth = 100
        self.sidebarMaxWidth = 600
        self.contentMinWidth = 100
        self.contentMaxWidth = 600
    }

    /// Perform layout: position sidebar, content, and detail within the container.
    /// Updates `layoutSidebarW` / `layoutContentW` for accurate hit-testing.
    func layout(containerW: Int32, containerH: Int32) {
        let effectiveVisibility = visibility

        switch effectiveVisibility {
        case .detailOnly:
            layoutSidebarW = 0
            layoutContentW = 0
            if let sh = sidebarHwnd { ShowWindow(sh, SW_HIDE) }
            if let ch = contentHwnd { ShowWindow(ch, SW_HIDE) }
            if let dh = detailHwnd {
                ShowWindow(dh, SW_SHOW)
                SetWindowPos(dh, nil, 0, 0, containerW, containerH, UINT(SWP_NOZORDER))
            }

        case .doubleColumn where hasContentColumn:
            // Show sidebar + detail, hide content
            if let ch = contentHwnd { ShowWindow(ch, SW_HIDE) }
            let sw = min(sidebarWidth, containerW - 50)
            layoutSidebarW = sw
            layoutContentW = 0
            if let sh = sidebarHwnd {
                ShowWindow(sh, SW_SHOW)
                SetWindowPos(sh, nil, 0, 0, sw, containerH, UINT(SWP_NOZORDER))
            }
            if let dh = detailHwnd {
                ShowWindow(dh, SW_SHOW)
                let detailX = sw + dividerWidth
                SetWindowPos(dh, nil, detailX, 0, max(0, containerW - detailX), containerH,
                             UINT(SWP_NOZORDER))
            }

        default:
            // .automatic, .all, .doubleColumn (2-col)
            if hasContentColumn {
                let sw = min(sidebarWidth, containerW / 3)
                let cw = min(contentWidth, containerW / 3)
                layoutSidebarW = sw
                layoutContentW = cw
                let detailX = sw + dividerWidth + cw + dividerWidth

                if let sh = sidebarHwnd {
                    ShowWindow(sh, SW_SHOW)
                    SetWindowPos(sh, nil, 0, 0, sw, containerH, UINT(SWP_NOZORDER))
                }
                if let ch = contentHwnd {
                    ShowWindow(ch, SW_SHOW)
                    SetWindowPos(ch, nil, sw + dividerWidth, 0, cw, containerH, UINT(SWP_NOZORDER))
                }
                if let dh = detailHwnd {
                    ShowWindow(dh, SW_SHOW)
                    SetWindowPos(dh, nil, detailX, 0, max(0, containerW - detailX), containerH,
                                 UINT(SWP_NOZORDER))
                }
            } else {
                let sw = min(sidebarWidth, containerW - 50)
                layoutSidebarW = sw
                layoutContentW = 0
                if let sh = sidebarHwnd {
                    ShowWindow(sh, SW_SHOW)
                    SetWindowPos(sh, nil, 0, 0, sw, containerH, UINT(SWP_NOZORDER))
                }
                if let dh = detailHwnd {
                    ShowWindow(dh, SW_SHOW)
                    let detailX = sw + dividerWidth
                    SetWindowPos(dh, nil, detailX, 0, max(0, containerW - detailX), containerH,
                                 UINT(SWP_NOZORDER))
                }
            }
        }
    }

    /// Returns which divider (1 or 2) is at the given x position, or 0 if none.
    /// Uses the actual laid-out widths, not the unclamped stored widths.
    func hitTestDivider(x: Int32) -> Int {
        let hitSlop = dividerWidth + 2
        if hasContentColumn && visibility != .doubleColumn && visibility != .detailOnly {
            // 3-column: two dividers at actual laid-out positions
            let div1 = layoutSidebarW
            let div2 = layoutSidebarW + dividerWidth + layoutContentW
            if abs(x - div1) <= hitSlop { return 1 }
            if abs(x - div2) <= hitSlop { return 2 }
        } else if visibility != .detailOnly {
            let div1 = layoutSidebarW
            if abs(x - div1) <= hitSlop { return 1 }
        }
        return 0
    }

    /// Clamp sidebar/content width to min/max constraints.
    func clampWidths() {
        sidebarWidth = max(sidebarMinWidth, min(sidebarMaxWidth, sidebarWidth))
        if hasContentColumn {
            contentWidth = max(contentMinWidth, min(contentMaxWidth, contentWidth))
        }
    }
}

/// Subclass proc for NavigationSplitView container — handles resize, divider drag, and message forwarding.
private let splitViewLayoutProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    guard dwRefData != 0 else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }

    let state = Unmanaged<SplitViewState>.fromOpaque(
        UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
    ).takeUnretainedValue()

    switch uMsg {
    case UINT(WM_SIZE):
        var rect = RECT()
        GetClientRect(hwnd, &rect)
        state.layout(containerW: rect.right, containerH: rect.bottom)
        InvalidateRect(hwnd, nil, false)  // repaint dividers
        return 0

    case UINT(WM_PAINT):
        // Draw visible divider lines
        var ps = PAINTSTRUCT()
        let hdc = BeginPaint(hwnd, &ps)

        var rect = RECT()
        GetClientRect(hwnd, &rect)
        let h = rect.bottom

        let dividerBrush = CreateSolidBrush(win32_RGB(210, 210, 215))

        if state.visibility != .detailOnly {
            // First divider after sidebar
            let div1X = state.layoutSidebarW
            if div1X > 0 {
                var divRect = RECT(left: div1X, top: 0,
                                   right: div1X + state.dividerWidth, bottom: h)
                FillRect(hdc, &divRect, dividerBrush)
            }

            // Second divider after content (3-column only)
            if state.hasContentColumn && state.layoutContentW > 0
               && state.visibility != .doubleColumn {
                let div2X = state.layoutSidebarW + state.dividerWidth + state.layoutContentW
                var divRect = RECT(left: div2X, top: 0,
                                   right: div2X + state.dividerWidth, bottom: h)
                FillRect(hdc, &divRect, dividerBrush)
            }
        }

        DeleteObject(dividerBrush)
        EndPaint(hwnd, &ps)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_LBUTTONDOWN):
        let x = Int32(win32_LOWORD(DWORD_PTR(lParam)))
        let divider = state.hitTestDivider(x: x)
        if divider > 0 {
            state.draggingDivider = divider
            SetCapture(hwnd)
            return 0
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_MOUSEMOVE):
        let x = Int32(win32_LOWORD(DWORD_PTR(lParam)))
        if state.draggingDivider > 0 {
            if state.draggingDivider == 1 {
                state.sidebarWidth = max(state.sidebarMinWidth, x)
                state.clampWidths()
            } else if state.draggingDivider == 2, state.hasContentColumn {
                let contentStart = state.layoutSidebarW + state.dividerWidth
                state.contentWidth = max(state.contentMinWidth, x - contentStart)
                state.clampWidths()
            }
            var rect = RECT()
            GetClientRect(hwnd, &rect)
            state.layout(containerW: rect.right, containerH: rect.bottom)
            return 0
        }
        // Set resize cursor when hovering over divider
        let divider = state.hitTestDivider(x: x)
        if divider > 0 {
            SetCursor(LoadCursorW(nil, win32_IDC_SIZEWE()))
            return 0
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_LBUTTONUP):
        if state.draggingDivider > 0 {
            state.draggingDivider = 0
            ReleaseCapture()
            return 0
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_SETCURSOR):
        // Let WM_MOUSEMOVE handle cursor changes for divider area
        if state.draggingDivider > 0 {
            SetCursor(LoadCursorW(nil, win32_IDC_SIZEWE()))
            return 1  // handled
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_COMMAND):
        if let parent = GetParent(hwnd) {
            return SendMessageW(parent, uMsg, wParam, lParam)
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_CTLCOLORSTATIC):
        let parentHwnd = GetParent(hwnd)
        if let parentHwnd = parentHwnd {
            return SendMessageW(parentHwnd, uMsg, wParam, lParam)
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_NCDESTROY):
        Unmanaged<SplitViewState>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, splitViewLayoutProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

extension NavigationSplitView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)

        // Render columns
        let sidebarHwnd = winRenderView(sidebar, in: childContext)
        let contentHwnd = hasContentColumn ? winRenderView(content, in: childContext) : nil
        let detailHwnd = winRenderView(detail, in: childContext)

        // Extract column width constraints from modifier chain
        let sidebarProvider = winExtractColumnWidthProvider(from: sidebar)
        let sidebarW = Int32(sidebarProvider?.columnIdealWidth ?? Double(sidebarWidth))

        let contentW: Int32
        if hasContentColumn {
            let contentProvider = winExtractColumnWidthProvider(from: content)
            contentW = Int32(contentProvider?.columnIdealWidth ?? 250)
        } else {
            contentW = 0
        }

        // Create state
        let state = SplitViewState(
            hasContentColumn: hasContentColumn,
            sidebarWidth: sidebarW,
            contentWidth: contentW
        )
        state.sidebarHwnd = sidebarHwnd
        state.contentHwnd = contentHwnd
        state.detailHwnd = detailHwnd

        // Apply min/max constraints
        if let provider = sidebarProvider {
            if let minW = provider.columnMinWidth { state.sidebarMinWidth = Int32(minW) }
            if let maxW = provider.columnMaxWidth { state.sidebarMaxWidth = Int32(maxW) }
        }
        if hasContentColumn, let contentProvider = winExtractColumnWidthProvider(from: content) {
            if let minW = contentProvider.columnMinWidth { state.contentMinWidth = Int32(minW) }
            if let maxW = contentProvider.columnMaxWidth { state.contentMaxWidth = Int32(maxW) }
        }

        // Apply visibility
        if let visBinding = columnVisibility {
            state.visibility = visBinding.wrappedValue
        }

        // Install subclass for layout + divider dragging
        let ptr = Unmanaged.passRetained(state).toOpaque()
        SetWindowSubclass(container, splitViewLayoutProc, 50, DWORD_PTR(UInt(bitPattern: ptr)))

        // Set initial size from parent
        var parentRect = RECT()
        GetClientRect(context.parent, &parentRect)
        let w = parentRect.right - parentRect.left
        let h = parentRect.bottom - parentRect.top
        SetWindowPos(container, nil, 0, 0, max(w, 400), max(h, 300),
                     UINT(SWP_NOZORDER | SWP_NOMOVE))

        return container
    }
}

extension NavigationSplitViewColumnWidthView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // Render the wrapped content — width constraints are consumed by NavigationSplitView
        winRenderView(content, in: context)
    }
}

// MARK: - GeometryReader

extension GeometryReader: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        // Create container that fills available space
        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        // Measure the parent to get available size
        var parentRect = RECT()
        GetClientRect(context.parent, &parentRect)
        let availW = Double(parentRect.right - parentRect.left)
        let availH = Double(parentRect.bottom - parentRect.top)

        // Use parent size or a default if parent hasn't been sized yet
        let proxyW = availW > 0 ? availW : 300
        let proxyH = availH > 0 ? availH : 200

        let proxy = GeometryProxy(size: GeometrySize(width: proxyW, height: proxyH))
        let childView = content(proxy)

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        if let childHwnd = winRenderView(childView, in: childContext) {
            SetWindowPos(childHwnd, nil, 0, 0, Int32(proxyW), Int32(proxyH), UINT(SWP_NOZORDER))
        }

        SetWindowPos(container, nil, 0, 0, Int32(proxyW), Int32(proxyH),
                     UINT(SWP_NOZORDER | SWP_NOMOVE))

        return container
    }
}

// MARK: - Searchable

extension SearchableView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        // Search field at top — initialized with current binding value
        let searchHeight: Int32 = 24
        let currentText = text.wrappedValue
        let searchHwnd = currentText.withCString(encodedAs: UTF16.self) { wstr in
            win32_CreateChildWindow(
                win32_WC_EDIT(), wstr,
                DWORD(ES_AUTOHSCROLL | WS_BORDER | WS_TABSTOP),
                0, 0, 0, searchHeight,
                container, nil, context.hInstance
            )
        }

        if let searchHwnd = searchHwnd {
            // Placeholder
            prompt.withCString(encodedAs: UTF16.self) { ptr in
                _ = SendMessageW(searchHwnd, UINT(EM_SETCUEBANNER), 1,
                                 LPARAM(Int(bitPattern: ptr)))
            }

            // Wire binding
            let binding = text
            let handler = SubclassHandler(hwnd: searchHwnd)
            handler.onTextChanged = { newValue in
                if newValue != binding.wrappedValue {
                    binding.wrappedValue = newValue
                }
            }
            let state = TextFieldState(handler: handler)
            let statePtr = Unmanaged.passRetained(state).toOpaque()
            SetWindowSubclass(searchHwnd, textFieldCleanupProc, 41,
                              DWORD_PTR(UInt(bitPattern: statePtr)))
        }

        // Content below search field
        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        let contentHwnd = winRenderView(content, in: childContext)

        // Size container
        var contentW: Int32 = 200
        var contentH: Int32 = 100
        if let ch = contentHwnd {
            var r = RECT()
            GetWindowRect(ch, &r)
            contentW = max(r.right - r.left, 200)
            contentH = r.bottom - r.top
        }

        SetWindowPos(container, nil, 0, 0, contentW, searchHeight + 4 + contentH,
                     UINT(SWP_NOZORDER | SWP_NOMOVE))

        // Position children
        if let sh = searchHwnd {
            SetWindowPos(sh, nil, 0, 0, contentW, searchHeight, UINT(SWP_NOZORDER))
        }
        if let ch = contentHwnd {
            SetWindowPos(ch, nil, 0, searchHeight + 4, contentW, contentH, UINT(SWP_NOZORDER))
        }

        return container
    }
}

// MARK: - Phase 4C: Shape modifiers

extension CornerRadiusView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }
        if radius > 0 {
            // Use Win32 region clipping to round corners on any HWND
            var r = RECT()
            GetWindowRect(hwnd, &r)
            let w = r.right - r.left
            let h = r.bottom - r.top
            let rx = Int32(radius)
            let ry = Int32(radius)
            let rgn = CreateRoundRectRgn(0, 0, w + 1, h + 1, rx * 2, ry * 2)
            // SetWindowRgn takes ownership of the region — do not delete
            SetWindowRgn(hwnd, rgn, true)
        }
        return hwnd
    }
}

/// Property name for shadow info on container HWNDs.
private let shadowInfoPropName: UnsafePointer<WCHAR> = {
    "SwiftUIShadowInfo".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

/// Shadow metadata stored on the container HWND.
private class ShadowInfo {
    let colorR: Float
    let colorG: Float
    let colorB: Float
    let colorA: Float
    let radius: Int32
    let offsetX: Int32
    let offsetY: Int32

    init(color: Color, radius: Double, x: Double, y: Double) {
        self.colorR = Float(color.red)
        self.colorG = Float(color.green)
        self.colorB = Float(color.blue)
        self.colorA = Float(color.alpha)
        self.radius = Int32(max(1, radius))
        self.offsetX = Int32(x)
        self.offsetY = Int32(y)
    }
}

/// Subclass proc that draws a shadow rectangle behind children.
private let shadowContainerProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    switch uMsg {
    case UINT(WM_PAINT):
        // Shadow is drawn via GDI with alpha-blended color approximation.
        // A real gaussian blur would need D2D effects (ID2D1Effect).
        // We simulate softness by drawing multiple offset rects with
        // decreasing opacity mapped to lighter colors.
        var ps = PAINTSTRUCT()
        let hdc = BeginPaint(hwnd, &ps)

        let ptr = GetPropW(hwnd, shadowInfoPropName)
        if let ptr = ptr {
            let info = Unmanaged<ShadowInfo>.fromOpaque(ptr).takeUnretainedValue()

            var clientRect = RECT()
            GetClientRect(hwnd, &clientRect)

            // Query actual parent background color (falls back to system window color)
            let bgColorRef = GetSysColor(COLOR_WINDOW)
            let bgR = Float(win32_GetRValue(bgColorRef)) / 255.0
            let bgG = Float(win32_GetGValue(bgColorRef)) / 255.0
            let bgB = Float(win32_GetBValue(bgColorRef)) / 255.0

            let shadowPad = info.radius
            let layers = max(1, shadowPad)

            // Draw shadow layers from outermost (lightest) to innermost (darkest)
            for i in (0..<layers).reversed() {
                let fraction = Float(i + 1) / Float(layers)
                let layerAlpha = info.colorA * fraction * 0.5
                // Blend shadow color with actual background color
                let r = UInt8(max(0, min(255, (info.colorR * layerAlpha + bgR * (1 - layerAlpha)) * 255)))
                let g = UInt8(max(0, min(255, (info.colorG * layerAlpha + bgG * (1 - layerAlpha)) * 255)))
                let b = UInt8(max(0, min(255, (info.colorB * layerAlpha + bgB * (1 - layerAlpha)) * 255)))

                let expand = i
                var shadowRect = RECT(
                    left: shadowPad + info.offsetX - expand,
                    top: shadowPad + info.offsetY - expand,
                    right: clientRect.right - shadowPad + info.offsetX + expand,
                    bottom: clientRect.bottom - shadowPad + info.offsetY + expand
                )
                let shadowBrush = CreateSolidBrush(win32_RGB(r, g, b))
                FillRect(hdc, &shadowRect, shadowBrush)
                DeleteObject(shadowBrush)
            }
        }

        EndPaint(hwnd, &ps)
        // Let children paint on top via DefSubclassProc
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_CTLCOLORSTATIC):
        let parentHwnd = GetParent(hwnd)
        if let parentHwnd = parentHwnd {
            return SendMessageW(parentHwnd, uMsg, wParam, lParam)
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_NCDESTROY):
        let ptr = GetPropW(hwnd, shadowInfoPropName)
        if let ptr = ptr {
            Unmanaged<ShadowInfo>.fromOpaque(ptr).release()
            RemovePropW(hwnd, shadowInfoPropName)
        }
        RemoveWindowSubclass(hwnd, shadowContainerProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

extension ShadowView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let childHwnd = winRenderView(content, in: context) else { return nil }

        // Get content size
        var r = RECT()
        GetWindowRect(childHwnd, &r)
        let cw = r.right - r.left
        let ch = r.bottom - r.top

        // Create a container slightly larger to accommodate the shadow
        let shadowOffset = Int32(max(radius, max(abs(x), abs(y))))
        let containerW = cw + shadowOffset * 2
        let containerH = ch + shadowOffset * 2

        registerStackClassIfNeeded(hInstance: context.hInstance)
        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, containerW, containerH,
            context.parent, nil, context.hInstance, nil
        )!

        // Re-parent the child into the container, centered with padding for shadow
        SetParent(childHwnd, container)
        SetWindowPos(childHwnd, nil, shadowOffset, shadowOffset, cw, ch, UINT(SWP_NOZORDER))

        // Attach shadow info and install paint subclass
        let info = ShadowInfo(color: color, radius: radius, x: x, y: y)
        let infoPtr = Unmanaged.passRetained(info).toOpaque()
        SetPropW(container, shadowInfoPropName, HANDLE(infoPtr))
        SetWindowSubclass(container, shadowContainerProc, 44, 0)

        return container
    }
}

extension RotationView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        // For D2D-renderable content (Text, Color, Divider), render with rotation
        // via D2D SetTransform. Native HWND controls can't be rotated.
        if isD2DRenderable(content) && angle != 0 {
            return createD2DSurface(view: self, context: context)
        }
        // Pass through for non-D2D content
        return winRenderView(content, in: context)
    }
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

// MARK: - Canvas Win32 extension

// MARK: - D2D Canvas Context

/// Path element for deferred stroke/fill rendering.
enum CanvasPathElement {
    case moveTo(Float, Float)
    case lineTo(Float, Float)
    case rectangle(Float, Float, Float, Float)
    case ellipse(Float, Float, Float, Float)  // centerX, centerY, radiusX, radiusY
    case arc(Float, Float, Float, Float, Float)  // centerX, centerY, radius, startAngle, endAngle
}

/// Saved graphics state for save/restore.
struct CanvasGraphicsState {
    let colorR, colorG, colorB, colorA: Float
    let lineWidth: Float
    let currentX, currentY: Float
    // Transform matrix (row-major 3x2)
    let m11, m12, m21, m22, dx, dy: Float
}

/// D2D-backed drawing context state. Stored as a retained class;
/// DrawingContext.cr holds an OpaquePointer to this instance.
class D2DCanvasContext {
    let renderTarget: D2DRenderTarget
    let brush: D2DBrush

    // Current drawing state
    var colorR: Float = 0
    var colorG: Float = 0
    var colorB: Float = 0
    var colorA: Float = 1
    var lineWidth: Float = 1
    var currentX: Float = 0
    var currentY: Float = 0

    // Current transform
    var m11: Float = 1, m12: Float = 0
    var m21: Float = 0, m22: Float = 1
    var dx: Float = 0, dy: Float = 0

    // Accumulated path for deferred stroke/fill
    var path: [CanvasPathElement] = []

    // State stack for save/restore (full graphics state including transform)
    var stateStack: [CanvasGraphicsState] = []

    init(renderTarget: D2DRenderTarget, brush: D2DBrush) {
        self.renderTarget = renderTarget
        self.brush = brush
    }

    func applyColor() {
        d2d1_SolidColorBrush_SetColor(brush, colorR, colorG, colorB, colorA)
    }
}

/// Holds draw closure + D2D resources for the Canvas HWND.
private class CanvasDrawState {
    let drawHandler: (DrawingContext, Int, Int) -> Void
    var renderTarget: D2DRenderTarget?
    var brush: D2DBrush?

    init(_ handler: @escaping (DrawingContext, Int, Int) -> Void) {
        self.drawHandler = handler
    }

    func ensureTarget(hwnd: HWND, width: UInt32, height: UInt32) {
        if renderTarget == nil && width > 0 && height > 0 {
            renderTarget = D2DRenderer.shared.createRenderTarget(for: hwnd, width: width, height: height)
            if let rt = renderTarget {
                brush = D2DRenderer.shared.createBrush(rt, r: 0, g: 0, b: 0)
            }
        }
    }

    func cleanup() {
        if let b = brush { D2DRenderer.shared.releaseBrush(b); brush = nil }
        if let rt = renderTarget { D2DRenderer.shared.releaseRenderTarget(rt); renderTarget = nil }
    }

    deinit { cleanup() }
}

/// Property name for CanvasDrawState on the Canvas HWND.
private let canvasStatePropName: UnsafePointer<WCHAR> = {
    "SwiftUICanvasState".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

/// Subclass proc for Canvas — invokes draw closure with D2D-backed DrawingContext.
private let canvasPaintProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    switch uMsg {
    case UINT(WM_PAINT):
        var ps = PAINTSTRUCT()
        _ = BeginPaint(hwnd, &ps)

        var rect = RECT()
        GetClientRect(hwnd, &rect)
        let w = UInt32(rect.right)
        let h = UInt32(rect.bottom)

        let ptr = GetPropW(hwnd, canvasStatePropName)
        if let ptr = ptr, let hwnd = hwnd, w > 0, h > 0 {
            let state = Unmanaged<CanvasDrawState>.fromOpaque(ptr).takeUnretainedValue()
            state.ensureTarget(hwnd: hwnd, width: w, height: h)

            if let rt = state.renderTarget, let brush = state.brush {
                d2d1_RenderTarget_BeginDraw(rt)
                // Clear with window background
                let bgColor = GetSysColor(COLOR_WINDOW)
                d2d1_RenderTarget_Clear(rt,
                    Float(win32_GetRValue(bgColor)) / 255.0,
                    Float(win32_GetGValue(bgColor)) / 255.0,
                    Float(win32_GetBValue(bgColor)) / 255.0, 1.0)

                let d2dCtx = D2DCanvasContext(renderTarget: rt, brush: brush)
                let ctxPtr = Unmanaged.passRetained(d2dCtx).toOpaque()
                let context = DrawingContext(cr: OpaquePointer(ctxPtr))
                state.drawHandler(context, Int(w), Int(h))
                Unmanaged<D2DCanvasContext>.fromOpaque(ctxPtr).release()

                _ = d2d1_RenderTarget_EndDraw(rt)
            }
        }

        EndPaint(hwnd, &ps)
        return 0

    case UINT(WM_SIZE):
        var rect = RECT()
        GetClientRect(hwnd, &rect)
        let ptr = GetPropW(hwnd, canvasStatePropName)
        if let ptr = ptr {
            let state = Unmanaged<CanvasDrawState>.fromOpaque(ptr).takeUnretainedValue()
            if let rt = state.renderTarget {
                D2DRenderer.shared.resize(rt, width: UInt32(rect.right), height: UInt32(rect.bottom))
            }
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    case UINT(WM_ERASEBKGND):
        return 1  // D2D handles background clearing

    case UINT(WM_NCDESTROY):
        let ptr = GetPropW(hwnd, canvasStatePropName)
        if let ptr = ptr {
            Unmanaged<CanvasDrawState>.fromOpaque(ptr).release()
            RemovePropW(hwnd, canvasStatePropName)
        }
        RemoveWindowSubclass(hwnd, canvasPaintProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

extension Canvas: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerD2DSurfaceClassIfNeeded(hInstance: context.hInstance)

        let w = width > 0 ? Int32(width) : 200
        let h = height > 0 ? Int32(height) : 200

        let hwnd = CreateWindowExW(
            0, d2dSurfaceClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE),
            0, 0, w, h,
            context.parent, nil, context.hInstance, nil
        )

        guard let hwnd = hwnd else { return nil }

        let state = CanvasDrawState(drawHandler)
        let statePtr = Unmanaged.passRetained(state).toOpaque()
        SetPropW(hwnd, canvasStatePropName, HANDLE(statePtr))
        SetWindowSubclass(hwnd, canvasPaintProc, 45, 0)

        return hwnd
    }
}

/// Win32 D2D-backed DrawingContext extensions.
/// The `cr` field stores a retained pointer to a D2DCanvasContext.
/// Path operations accumulate elements; stroke()/fill() execute them.
extension DrawingContext {
    /// Get the underlying D2DCanvasContext.
    private var ctx: D2DCanvasContext {
        Unmanaged<D2DCanvasContext>.fromOpaque(UnsafeMutableRawPointer(cr)).takeUnretainedValue()
    }

    // MARK: - Color

    public func setColor(r: Double, g: Double, b: Double) {
        ctx.colorR = Float(r)
        ctx.colorG = Float(g)
        ctx.colorB = Float(b)
        ctx.colorA = 1.0
    }

    public func setColor(r: Double, g: Double, b: Double, a: Double) {
        ctx.colorR = Float(r)
        ctx.colorG = Float(g)
        ctx.colorB = Float(b)
        ctx.colorA = Float(a)
    }

    // MARK: - Line style

    public func setLineWidth(_ width: Double) {
        ctx.lineWidth = Float(width)
    }

    public func setLineCap(_ cap: LineCap) {
        // D2D supports line caps via stroke style — for basic usage, ignored.
        // Full support would require ID2D1StrokeStyle creation.
    }

    public func setLineJoin(_ join: LineJoin) {
        // D2D supports line joins via stroke style — for basic usage, ignored.
    }

    // MARK: - Path operations (deferred — drawn on stroke/fill)

    public func moveTo(x: Double, y: Double) {
        ctx.currentX = Float(x)
        ctx.currentY = Float(y)
        ctx.path.append(.moveTo(Float(x), Float(y)))
    }

    public func lineTo(x: Double, y: Double) {
        ctx.path.append(.lineTo(Float(x), Float(y)))
        ctx.currentX = Float(x)
        ctx.currentY = Float(y)
    }

    public func rectangle(x: Double, y: Double, width: Double, height: Double) {
        ctx.path.append(.rectangle(Float(x), Float(y), Float(width), Float(height)))
    }

    public func arc(centerX: Double, centerY: Double, radius: Double,
                    startAngle: Double = 0, endAngle: Double = .pi * 2) {
        let span = abs(endAngle - startAngle)
        if span >= .pi * 2 - 0.01 {
            // Full circle — use ellipse primitive
            ctx.path.append(.ellipse(Float(centerX), Float(centerY), Float(radius), Float(radius)))
        } else {
            // Partial arc — stored for line-segment approximation
            ctx.path.append(.arc(Float(centerX), Float(centerY), Float(radius),
                                 Float(startAngle), Float(endAngle)))
        }
    }

    // MARK: - Drawing (execute accumulated path)

    public func stroke() {
        let c = ctx
        c.applyColor()
        var lastX: Float = c.currentX
        var lastY: Float = c.currentY

        for element in c.path {
            switch element {
            case .moveTo(let x, let y):
                lastX = x
                lastY = y

            case .lineTo(let x, let y):
                d2d1_RenderTarget_DrawLine(c.renderTarget, c.brush,
                                            lastX, lastY, x, y, c.lineWidth)
                lastX = x
                lastY = y

            case .rectangle(let x, let y, let w, let h):
                d2d1_RenderTarget_DrawRectangle(c.renderTarget, c.brush,
                                                 x, y, w, h, c.lineWidth)

            case .ellipse(let cx, let cy, let rx, let ry):
                d2d1_RenderTarget_DrawEllipse(c.renderTarget, c.brush,
                                               cx, cy, rx, ry, c.lineWidth)

            case .arc(let cx, let cy, let r, let start, let end):
                // Approximate arc with line segments
                let segments = max(8, Int(abs(end - start) / (Float.pi / 16)))
                let step = (end - start) / Float(segments)
                var prevX = cx + r * cos(start)
                var prevY = cy + r * sin(start)
                for i in 1...segments {
                    let angle = start + step * Float(i)
                    let nx = cx + r * cos(angle)
                    let ny = cy + r * sin(angle)
                    d2d1_RenderTarget_DrawLine(c.renderTarget, c.brush,
                                                prevX, prevY, nx, ny, c.lineWidth)
                    prevX = nx
                    prevY = ny
                }
                lastX = prevX
                lastY = prevY
            }
        }
        c.path.removeAll()
    }

    public func fill() {
        let c = ctx
        c.applyColor()

        for element in c.path {
            switch element {
            case .moveTo, .lineTo, .arc:
                break  // Lines and arcs don't fill (would need ID2D1PathGeometry)

            case .rectangle(let x, let y, let w, let h):
                d2d1_RenderTarget_FillRectangle(c.renderTarget, c.brush, x, y, w, h)

            case .ellipse(let cx, let cy, let rx, let ry):
                d2d1_RenderTarget_FillEllipse(c.renderTarget, c.brush, cx, cy, rx, ry)
            }
        }
        c.path.removeAll()
    }

    public func paint() {
        let c = ctx
        c.applyColor()
        // Fill the entire render target
        d2d1_RenderTarget_FillRectangle(c.renderTarget, c.brush, 0, 0, 10000, 10000)
    }

    // MARK: - State

    public func save() {
        let c = ctx
        c.stateStack.append(CanvasGraphicsState(
            colorR: c.colorR, colorG: c.colorG, colorB: c.colorB, colorA: c.colorA,
            lineWidth: c.lineWidth, currentX: c.currentX, currentY: c.currentY,
            m11: c.m11, m12: c.m12, m21: c.m21, m22: c.m22, dx: c.dx, dy: c.dy
        ))
    }

    public func restore() {
        let c = ctx
        guard let state = c.stateStack.popLast() else { return }
        c.colorR = state.colorR
        c.colorG = state.colorG
        c.colorB = state.colorB
        c.colorA = state.colorA
        c.lineWidth = state.lineWidth
        c.currentX = state.currentX
        c.currentY = state.currentY
        // Restore transform
        c.m11 = state.m11; c.m12 = state.m12
        c.m21 = state.m21; c.m22 = state.m22
        c.dx = state.dx; c.dy = state.dy
        d2d1_RenderTarget_SetTransform(c.renderTarget,
            c.m11, c.m12, c.m21, c.m22, c.dx, c.dy)
    }

    public func scale(x: Double, y: Double) {
        let c = ctx
        // Compose with current transform: new = current * scale
        c.m11 *= Float(x); c.m12 *= Float(y)
        c.m21 *= Float(x); c.m22 *= Float(y)
        d2d1_RenderTarget_SetTransform(c.renderTarget,
            c.m11, c.m12, c.m21, c.m22, c.dx, c.dy)
    }
}

// MARK: - TupleView Win32 extensions (needed when TupleViews appear at top level)

// TupleViews are already MultiChildView, so winRenderChildren handles them.
// But if they appear as standalone views (not inside a container), we need a fallback.

extension ViewList: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        registerStackClassIfNeeded(hInstance: context.hInstance)

        let container = CreateWindowExW(
            0, stackContainerClassName, nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent, nil, context.hInstance, nil
        )!

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)
        var y: Int32 = 0
        var maxW: Int32 = 0

        for child in children {
            if let hwnd = winRenderAnyView(child, in: childContext) {
                var r = RECT()
                GetWindowRect(hwnd, &r)
                let w = r.right - r.left
                let h = r.bottom - r.top
                SetWindowPos(hwnd, nil, 0, y, w, h, UINT(SWP_NOZORDER))
                y += h
                maxW = max(maxW, w)
            }
        }

        SetWindowPos(container, nil, 0, 0, maxW, y, UINT(SWP_NOZORDER | SWP_NOMOVE))
        return container
    }
}

extension TupleView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let list = ViewList(children)
        return winRenderView(list, in: context)
    }
}
