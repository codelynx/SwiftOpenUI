import WinSDK
import CWin32
import CWin32Bridge
import SwiftOpenUI
import Foundation

// MARK: - D2D-rendered dropdown Picker
//
// The default (`.automatic`) Picker style used to lower to a native
// `WC_COMBOBOX`, whose dropdown is the dated Win95-era list. This draws
// the whole control with Direct2D instead — a rounded trigger showing the
// selected value + a chevron, and a borderless popup list with rounded
// corners, hover highlighting, and a check on the current selection. Same
// D2D infrastructure the segmented Picker already uses (`D2DRenderer`).

private let ddPopupVPad: Int32 = 5
private let ddHPad: Int32 = 12
private let ddChevronSlot: Int32 = 28

/// Control height derived from the current font's measured text height plus
/// vertical padding, so the trigger and popup rows scale with the font/DPI
/// instead of a hardcoded pixel height. `"Ag"` samples ascender+descender.
func dropdownRowHeight(_ hwnd: HWND) -> Int32 {
    max(24, measureText("Ag", hwnd: hwnd).height + 10)
}

// MARK: - Trigger state

private final class DropdownTriggerState {
    let hwnd: HWND
    let hInstance: HINSTANCE
    let options: [String]
    var selected: Int
    let onChanged: ((Int) -> Void)?
    /// Font-derived per-row height, shared by the trigger and popup items.
    let rowHeight: Int32

    var hovered = false
    var renderTarget: D2DRenderTarget?
    var brush: D2DBrush?

    // Non-nil while the popup is open. Retained here so it outlives the
    // click that opened it; cleared when the popup closes.
    var popup: HWND?

    // Set when a click on the trigger dismissed the open popup (the popup had
    // mouse capture, so it saw the button-down and closed; the button-up then
    // lands on the trigger). Without this the trigger would immediately
    // reopen, making the dropdown impossible to close by clicking it.
    var suppressReopen = false

    init(hwnd: HWND, hInstance: HINSTANCE, options: [String], selected: Int,
         rowHeight: Int32, onChanged: ((Int) -> Void)?) {
        self.hwnd = hwnd
        self.hInstance = hInstance
        self.options = options
        self.selected = selected
        self.rowHeight = rowHeight
        self.onChanged = onChanged
    }

    var selectedText: String {
        guard selected >= 0, selected < options.count else { return "" }
        return options[selected]
    }

    func ensureTarget() {
        var r = RECT(); GetClientRect(hwnd, &r)
        let w = UInt32(max(1, r.right)); let h = UInt32(max(1, r.bottom))
        if renderTarget == nil {
            renderTarget = D2DRenderer.shared.createRenderTarget(for: hwnd, width: w, height: h)
            if let rt = renderTarget { brush = D2DRenderer.shared.createBrush(rt, r: 0, g: 0, b: 0) }
        } else if let rt = renderTarget {
            D2DRenderer.shared.resize(rt, width: w, height: h)
        }
    }

    func paint() {
        ensureTarget()
        guard let rt = renderTarget, let brush = brush else { return }
        var r = RECT(); GetClientRect(hwnd, &r)
        let w = Float(r.right), h = Float(r.bottom)
        guard w > 0, h > 0 else { return }
        let enabled = IsWindowEnabled(hwnd)
        let cr: Float = 5

        d2d1_RenderTarget_BeginDraw(rt)
        // Background (parent inherited color under the rounded rect).
        let bg = inheritedBackground(hwnd)
        d2d1_RenderTarget_Clear(rt, bg.r, bg.g, bg.b, 1)

        // Fill — white, subtly grayer on hover.
        if enabled && hovered {
            d2d1_SolidColorBrush_SetColor(brush, 0.96, 0.96, 0.97, 1)
        } else if enabled {
            d2d1_SolidColorBrush_SetColor(brush, 1, 1, 1, 1)
        } else {
            d2d1_SolidColorBrush_SetColor(brush, 0.94, 0.94, 0.94, 1)
        }
        d2d1_RenderTarget_FillRoundedRectangle(rt, brush, 0.5, 0.5, w - 0.5, h - 0.5, cr, cr)

        // Border.
        d2d1_SolidColorBrush_SetColor(brush, 0.78, 0.78, 0.80, 1)
        d2d1_RenderTarget_DrawRoundedRectangle(rt, brush, 0.5, 0.5, w - 1, h - 1, cr, cr, 1)

        // Selected value text (leading, vertically centered).
        if let fmt = D2DRenderer.shared.textFormat() {
            if enabled {
                d2d1_SolidColorBrush_SetColor(brush, 0.1, 0.1, 0.1, 1)
            } else {
                d2d1_SolidColorBrush_SetColor(brush, 0.6, 0.6, 0.6, 1)
            }
            dwrite_TextFormat_SetTextAlignment(fmt, 0) // leading
            D2DRenderer.shared.drawText(selectedText, target: rt, format: fmt, brush: brush,
                                        x: Float(ddHPad), y: 0,
                                        width: w - Float(ddHPad + ddChevronSlot), height: h)
        }

        // Chevron (downward), trailing.
        d2d1_SolidColorBrush_SetColor(brush, 0.45, 0.45, 0.47, 1)
        let cx = w - Float(ddChevronSlot) / 2 - 2
        let cy = h / 2
        d2d1_RenderTarget_DrawLine(rt, brush, cx - 4, cy - 2, cx, cy + 2, 1.4)
        d2d1_RenderTarget_DrawLine(rt, brush, cx, cy + 2, cx + 4, cy - 2, 1.4)

        // Focus ring — inset a full 2px so the antialiased stroke stays
        // clear of the control's edges (avoids top/right clipping).
        if enabled && GetFocus() == hwnd {
            d2d1_SolidColorBrush_SetColor(brush, 0.0, 0.48, 1.0, 0.65)
            d2d1_RenderTarget_DrawRoundedRectangle(rt, brush, 2, 2, w - 4, h - 4, cr - 1, cr - 1, 1.5)
        }
        _ = d2d1_RenderTarget_EndDraw(rt)
    }

    func cleanup() {
        if let b = brush { D2DRenderer.shared.releaseBrush(b); brush = nil }
        if let rt = renderTarget { D2DRenderer.shared.releaseRenderTarget(rt); renderTarget = nil }
    }
    deinit { cleanup() }
}

// MARK: - Popup state

private final class DropdownPopupState {
    let hwnd: HWND
    /// The trigger that owns this popup (for close-on-trigger-click detection).
    let triggerHwnd: HWND
    let options: [String]
    let initialSelection: Int
    var hovered: Int
    let itemWidth: Int32
    let itemHeight: Int32
    /// Invoked with the chosen index when an item is clicked.
    let onPick: (Int) -> Void
    /// Invoked (once) when the popup closes for any reason.
    let onClose: () -> Void
    var closed = false

    var renderTarget: D2DRenderTarget?
    var brush: D2DBrush?

    init(hwnd: HWND, triggerHwnd: HWND, options: [String], selected: Int,
         itemWidth: Int32, itemHeight: Int32,
         onPick: @escaping (Int) -> Void, onClose: @escaping () -> Void) {
        self.hwnd = hwnd
        self.triggerHwnd = triggerHwnd
        self.options = options
        self.initialSelection = selected
        self.hovered = selected
        self.itemWidth = itemWidth
        self.itemHeight = itemHeight
        self.onPick = onPick
        self.onClose = onClose
    }

    func itemAt(y: Int32) -> Int {
        guard y >= ddPopupVPad else { return -1 } // top padding, not item 0
        let idx = Int((y - ddPopupVPad) / itemHeight)
        return (idx >= 0 && idx < options.count) ? idx : -1
    }

    func ensureTarget() {
        var r = RECT(); GetClientRect(hwnd, &r)
        let w = UInt32(max(1, r.right)); let h = UInt32(max(1, r.bottom))
        if renderTarget == nil {
            renderTarget = D2DRenderer.shared.createRenderTarget(for: hwnd, width: w, height: h)
            if let rt = renderTarget { brush = D2DRenderer.shared.createBrush(rt, r: 0, g: 0, b: 0) }
        }
    }

    func paint() {
        ensureTarget()
        guard let rt = renderTarget, let brush = brush else { return }
        var r = RECT(); GetClientRect(hwnd, &r)
        let w = Float(r.right), h = Float(r.bottom)
        guard w > 0, h > 0 else { return }
        let cr: Float = 6

        d2d1_RenderTarget_BeginDraw(rt)
        d2d1_RenderTarget_Clear(rt, 1, 1, 1, 1)

        // Card background + border.
        d2d1_SolidColorBrush_SetColor(brush, 1, 1, 1, 1)
        d2d1_RenderTarget_FillRoundedRectangle(rt, brush, 0.5, 0.5, w - 0.5, h - 0.5, cr, cr)
        d2d1_SolidColorBrush_SetColor(brush, 0.72, 0.72, 0.74, 1)
        d2d1_RenderTarget_DrawRoundedRectangle(rt, brush, 0.5, 0.5, w - 1, h - 1, cr, cr, 1)

        let fmt = D2DRenderer.shared.textFormat()
        for (i, option) in options.enumerated() {
            let top = Float(ddPopupVPad + Int32(i) * itemHeight)
            let bottom = top + Float(itemHeight)

            if i == hovered {
                d2d1_SolidColorBrush_SetColor(brush, 0.90, 0.94, 1.0, 1) // light blue highlight
                d2d1_RenderTarget_FillRoundedRectangle(rt, brush,
                    3, top, w - 3, bottom, 4, 4)
            }

            // Check mark for the current selection.
            if i == initialSelection {
                d2d1_SolidColorBrush_SetColor(brush, 0.0, 0.45, 0.95, 1)
                let my = (top + bottom) / 2
                d2d1_RenderTarget_DrawLine(rt, brush, 10, my, 13, my + 3, 1.6)
                d2d1_RenderTarget_DrawLine(rt, brush, 13, my + 3, 18, my - 3, 1.6)
            }

            if let fmt = fmt {
                d2d1_SolidColorBrush_SetColor(brush, 0.1, 0.1, 0.1, 1)
                dwrite_TextFormat_SetTextAlignment(fmt, 0)
                D2DRenderer.shared.drawText(option, target: rt, format: fmt, brush: brush,
                                            x: 26, y: top, width: w - 34, height: Float(itemHeight))
            }
        }
        _ = d2d1_RenderTarget_EndDraw(rt)
    }

    /// Close the popup exactly once, running the close callback.
    func close() {
        guard !closed else { return }
        closed = true
        ReleaseCapture()
        onClose()
        DestroyWindow(hwnd)
    }

    func cleanup() {
        if let b = brush { D2DRenderer.shared.releaseBrush(b); brush = nil }
        if let rt = renderTarget { D2DRenderer.shared.releaseRenderTarget(rt); renderTarget = nil }
    }
    deinit { cleanup() }
}

/// The parent's effective background color, so a rounded control's corners
/// blend with what's behind them instead of showing white/gray.
private func inheritedBackground(_ hwnd: HWND) -> (r: Float, g: Float, b: Float) {
    var rr = Float(win32_GetRValue(GetSysColor(COLOR_WINDOW))) / 255
    var gg = Float(win32_GetGValue(GetSysColor(COLOR_WINDOW))) / 255
    var bb = Float(win32_GetBValue(GetSysColor(COLOR_WINDOW))) / 255
    if let parent = GetParent(hwnd) {
        let hdc = GetDC(hwnd)
        let res = SendMessageW(parent, UINT(WM_CTLCOLORSTATIC),
                               WPARAM(UInt(bitPattern: hdc)), LPARAM(Int(bitPattern: hwnd)))
        if res != 0, let hb = HBRUSH(bitPattern: Int(res)) {
            var lb = LOGBRUSH()
            GetObjectW(hb, Int32(MemoryLayout<LOGBRUSH>.size), &lb)
            rr = Float(win32_GetRValue(lb.lbColor)) / 255
            gg = Float(win32_GetGValue(lb.lbColor)) / 255
            bb = Float(win32_GetBValue(lb.lbColor)) / 255
        }
        ReleaseDC(hwnd, hdc)
    }
    return (rr, gg, bb)
}

// MARK: - Window classes

private let ddTriggerClass: UnsafePointer<WCHAR> = makeClassName("SwiftUIDropdownTrigger")
private let ddPopupClass: UnsafePointer<WCHAR> = makeClassName("SwiftUIDropdownPopup")

private func makeClassName(_ s: String) -> UnsafePointer<WCHAR> {
    s.withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}

private var ddClassesRegistered = false
private func registerDropdownClasses(_ hInstance: HINSTANCE) {
    guard !ddClassesRegistered else { return }
    ddClassesRegistered = true

    var t = WNDCLASSEXW()
    t.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
    t.style = UINT(CS_HREDRAW | CS_VREDRAW)
    t.lpfnWndProc = ddTriggerProc
    t.hInstance = hInstance
    t.hCursor = LoadCursorW(nil, win32_IDC_ARROW())
    t.hbrBackground = nil
    t.lpszClassName = ddTriggerClass
    RegisterClassExW(&t)

    var p = WNDCLASSEXW()
    p.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
    p.style = UINT(CS_HREDRAW | CS_VREDRAW | CS_DROPSHADOW)
    p.lpfnWndProc = ddPopupProc
    p.hInstance = hInstance
    p.hCursor = LoadCursorW(nil, win32_IDC_ARROW())
    p.hbrBackground = nil
    p.lpszClassName = ddPopupClass
    RegisterClassExW(&p)
}

private func ddTriggerStateRef(_ hwnd: HWND?) -> DropdownTriggerState? {
    guard let hwnd else { return nil }
    let ud = win32_GetWindowLongPtrW(hwnd, GWLP_USERDATA)
    guard ud != 0 else { return nil }
    return Unmanaged<DropdownTriggerState>
        .fromOpaque(UnsafeMutableRawPointer(bitPattern: Int(ud))!).takeUnretainedValue()
}

private func ddPopupStateRef(_ hwnd: HWND?) -> DropdownPopupState? {
    guard let hwnd else { return nil }
    let ud = win32_GetWindowLongPtrW(hwnd, GWLP_USERDATA)
    guard ud != 0 else { return nil }
    return Unmanaged<DropdownPopupState>
        .fromOpaque(UnsafeMutableRawPointer(bitPattern: Int(ud))!).takeUnretainedValue()
}

// MARK: - Trigger wndproc

private let ddTriggerProc: WNDPROC = { (hwnd, uMsg, wParam, lParam) in
    switch uMsg {
    case UINT(WM_PAINT):
        var ps = PAINTSTRUCT(); BeginPaint(hwnd, &ps)
        ddTriggerStateRef(hwnd)?.paint()
        EndPaint(hwnd, &ps)
        return 0
    case UINT(WM_SIZE):
        ddTriggerStateRef(hwnd)?.paint(); return 0
    case UINT(WM_GETDLGCODE):
        return LRESULT(DLGC_WANTARROWS | DLGC_WANTCHARS)
    case UINT(WM_MOUSEMOVE):
        if let s = ddTriggerStateRef(hwnd), !s.hovered {
            s.hovered = true
            var tme = TRACKMOUSEEVENT()
            tme.cbSize = UINT(MemoryLayout<TRACKMOUSEEVENT>.size)
            tme.dwFlags = UINT(TME_LEAVE)
            tme.hwndTrack = hwnd
            tme.dwHoverTime = 0
            TrackMouseEvent(&tme)
            InvalidateRect(hwnd, nil, false)
        }
        return 0
    case UINT(WM_MOUSELEAVE):
        if let s = ddTriggerStateRef(hwnd) {
            s.hovered = false
            // Clear a stale close-guard: if the user pressed on the trigger to
            // dismiss the popup but released off it, the trigger never got its
            // button-up, so the flag would otherwise swallow the next open.
            s.suppressReopen = false
            InvalidateRect(hwnd, nil, false)
        }
        return 0
    case UINT(WM_LBUTTONUP):
        if let s = ddTriggerStateRef(hwnd) {
            if s.suppressReopen {
                // This click just dismissed the open popup — don't reopen.
                s.suppressReopen = false
            } else {
                SetFocus(hwnd)
                ddTogglePopup(s)
            }
        }
        return 0
    case UINT(WM_KEYDOWN):
        let vk = Int32(truncatingIfNeeded: wParam)
        if let s = ddTriggerStateRef(hwnd) {
            // While the popup is open (trigger keeps focus — the popup is
            // WS_EX_NOACTIVATE), drive it from the keyboard.
            if let popup = s.popup, let ps = ddPopupStateRef(popup) {
                switch vk {
                case VK_ESCAPE:
                    // NB: a `fullScreenCover` installs a global WH_KEYBOARD hook
                    // that eats VK_ESCAPE before this WndProc (see WinRenderer's
                    // fullScreenCover). Synca hosts this in a real top-level
                    // Window, not a cover, so the hook isn't active — but if a
                    // dropdown is ever placed inside a cover, Esc would close
                    // the cover instead of the popup.
                    ps.close(); return 0
                case VK_DOWN:
                    ps.hovered = min(ps.hovered + 1, ps.options.count - 1)
                    InvalidateRect(ps.hwnd, nil, false); return 0
                case VK_UP:
                    ps.hovered = max(ps.hovered - 1, 0)
                    InvalidateRect(ps.hwnd, nil, false); return 0
                case VK_RETURN:
                    if ps.hovered >= 0 { ps.onPick(ps.hovered) }
                    ps.close(); return 0
                default:
                    return DefWindowProcW(hwnd, uMsg, wParam, lParam)
                }
            }
            // Closed: these open it.
            if vk == VK_SPACE || vk == VK_RETURN || vk == VK_DOWN || vk == VK_F4 {
                ddTogglePopup(s); return 0
            }
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    case UINT(WM_SETFOCUS), UINT(WM_KILLFOCUS):
        InvalidateRect(hwnd, nil, false)
        return 0
    case UINT(WM_NCDESTROY):
        let ud = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if ud != 0 {
            Unmanaged<DropdownTriggerState>.fromOpaque(UnsafeMutableRawPointer(bitPattern: Int(ud))!).release()
            win32_SetWindowLongPtrW(hwnd!, GWLP_USERDATA, 0)
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    default:
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
}

/// Open the popup if closed, or close it if already open (toggle).
private func ddTogglePopup(_ s: DropdownTriggerState) {
    if s.popup != nil {
        ddPopupStateRef(s.popup)?.close()
        return
    }
    guard !s.options.isEmpty else { return }

    // Popup geometry: width = max(trigger width, widest option + padding).
    var tr = RECT(); GetWindowRect(s.hwnd, &tr)
    let triggerW = tr.right - tr.left
    var widest: Int32 = 0
    for opt in s.options { widest = max(widest, measureText(opt, hwnd: s.hwnd).width) }
    let popupW = max(triggerW, widest + 26 + ddHPad)
    let popupH = ddPopupVPad * 2 + Int32(s.options.count) * s.rowHeight

    // Place below the trigger, or above if it would run off the bottom of the
    // trigger's monitor work area (handles multi-monitor / non-primary /
    // vertically-stacked displays — SM_CYSCREEN only covers the primary).
    var y = tr.bottom + 2
    var mi = MONITORINFO()
    mi.cbSize = DWORD(MemoryLayout<MONITORINFO>.size)
    let mon = MonitorFromWindow(s.hwnd, DWORD(MONITOR_DEFAULTTONEAREST))
    let haveWork = GetMonitorInfoW(mon, &mi)
    let workBottom: Int32 = haveWork ? mi.rcWork.bottom : GetSystemMetrics(SM_CYSCREEN)
    if y + popupH > workBottom {
        y = tr.top - 2 - popupH
        // Clamp to the work-area top (only bites a long list near the top edge).
        if haveWork, y < mi.rcWork.top { y = mi.rcWork.top }
    }

    registerDropdownClasses(s.hInstance)
    guard let popup = CreateWindowExW(
        DWORD(WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_NOACTIVATE),
        ddPopupClass, nil,
        DWORD(WS_POPUP),
        tr.left, y, popupW, popupH,
        s.hwnd, nil, s.hInstance, nil
    ) else { return }

    let triggerHwnd = s.hwnd
    let popupState = DropdownPopupState(
        hwnd: popup, triggerHwnd: triggerHwnd, options: s.options, selected: s.selected,
        itemWidth: popupW, itemHeight: s.rowHeight,
        onPick: { idx in
            if let st = ddTriggerStateRef(triggerHwnd), idx != st.selected {
                st.selected = idx
                st.onChanged?(idx)
                InvalidateRect(triggerHwnd, nil, false)
            }
        },
        onClose: {
            if let st = ddTriggerStateRef(triggerHwnd) { st.popup = nil }
        }
    )
    let ptr = Unmanaged.passRetained(popupState).toOpaque()
    win32_SetWindowLongPtrW(popup, GWLP_USERDATA, LONG_PTR(Int(bitPattern: ptr)))
    s.popup = popup

    // Clip the window itself to a rounded rect so the square window corners
    // don't show around the D2D rounded card. Radius matches the card's.
    let rgn = CreateRoundRectRgn(0, 0, popupW + 1, popupH + 1, 12, 12)
    SetWindowRgn(popup, rgn, true) // window takes ownership of the region

    ShowWindow(popup, SW_SHOWNA)
    SetCapture(popup)
    InvalidateRect(popup, nil, false)
}

// MARK: - Popup wndproc

private let ddPopupProc: WNDPROC = { (hwnd, uMsg, wParam, lParam) in
    switch uMsg {
    case UINT(WM_PAINT):
        var ps = PAINTSTRUCT(); BeginPaint(hwnd, &ps)
        ddPopupStateRef(hwnd)?.paint()
        EndPaint(hwnd, &ps)
        return 0
    case UINT(WM_MOUSEMOVE):
        if let s = ddPopupStateRef(hwnd) {
            let x = Int32(Int16(truncatingIfNeeded: lParam))
            let y = Int32(Int16(truncatingIfNeeded: lParam >> 16))
            var r = RECT(); GetClientRect(hwnd, &r)
            let inside = x >= 0 && x < r.right && y >= 0 && y < r.bottom
            let h = inside ? s.itemAt(y: y) : -1
            if h != s.hovered { s.hovered = h; InvalidateRect(hwnd, nil, false) }
        }
        return 0
    case UINT(WM_LBUTTONDOWN):
        if let s = ddPopupStateRef(hwnd) {
            let x = Int32(Int16(truncatingIfNeeded: lParam))
            let y = Int32(Int16(truncatingIfNeeded: lParam >> 16))
            var r = RECT(); GetClientRect(hwnd, &r)
            let inside = x >= 0 && x < r.right && y >= 0 && y < r.bottom
            if inside {
                let idx = s.itemAt(y: y)
                if idx >= 0 { s.onPick(idx) }
            } else {
                // Outside click. If it's on the owning trigger, tell the
                // trigger to swallow the upcoming button-up (else it reopens
                // the popup we're about to close).
                var pt = POINT(); GetCursorPos(&pt)
                var tr = RECT(); GetWindowRect(s.triggerHwnd, &tr)
                if pt.x >= tr.left, pt.x < tr.right, pt.y >= tr.top, pt.y < tr.bottom {
                    ddTriggerStateRef(s.triggerHwnd)?.suppressReopen = true
                }
            }
            s.close() // inside → pick+close; outside → dismiss
        }
        return 0
    case UINT(WM_CAPTURECHANGED):
        // Lost capture (e.g. another window took it) — dismiss.
        if let s = ddPopupStateRef(hwnd) { s.close() }
        return 0
    case UINT(WM_NCDESTROY):
        let ud = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if ud != 0 {
            Unmanaged<DropdownPopupState>.fromOpaque(UnsafeMutableRawPointer(bitPattern: Int(ud))!).release()
            win32_SetWindowLongPtrW(hwnd!, GWLP_USERDATA, 0)
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    default:
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
}

// MARK: - Transparent container

/// Subclass for the Picker's stack container so it (and its "Strategy"
/// label STATIC) inherits the parent's background instead of painting the
/// stack class's opaque white brush — otherwise the label sits on a white
/// box over the gray footer.
private let ddContainerProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uId, _) in
    switch uMsg {
    case UINT(WM_ERASEBKGND):
        return eraseWithInheritedBackground(hwnd: hwnd!, wParam: wParam)
    case UINT(WM_CTLCOLORSTATIC):
        if let parent = GetParent(hwnd!) { return SendMessageW(parent, uMsg, wParam, lParam) }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    case UINT(WM_NCDESTROY):
        RemoveWindowSubclass(hwnd, ddContainerProc, uId)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

/// Makes the dropdown Picker's container background-transparent.
func winMakeDropdownContainerTransparent(_ hwnd: HWND) {
    SetWindowSubclass(hwnd, ddContainerProc, 80, 0)
}

// MARK: - Builder (used by Picker's dropdown path)

/// Creates the D2D dropdown trigger control (the modern replacement for a
/// `WC_COMBOBOX`). `width` is the trigger's pixel width; height is fixed.
func winCreateD2DDropdown(options: [String], selected: Int, width: Int32,
                         onChanged: ((Int) -> Void)?, in context: RenderContext) -> HWND? {
    registerDropdownClasses(context.hInstance)
    let rowHeight = dropdownRowHeight(context.parent)
    guard let hwnd = CreateWindowExW(
        0, ddTriggerClass, nil,
        DWORD(WS_CHILD | WS_VISIBLE | WS_TABSTOP),
        0, 0, width, rowHeight,
        context.parent, nil, context.hInstance, nil
    ) else { return nil }

    let clamped = options.isEmpty ? 0 : max(0, min(selected, options.count - 1))
    let state = DropdownTriggerState(hwnd: hwnd, hInstance: context.hInstance,
                                     options: options, selected: clamped, rowHeight: rowHeight,
                                     onChanged: onChanged.map(bindActionToCurrentEnvironment))
    let ptr = Unmanaged.passRetained(state).toOpaque()
    win32_SetWindowLongPtrW(hwnd, GWLP_USERDATA, LONG_PTR(Int(bitPattern: ptr)))
    return hwnd
}
