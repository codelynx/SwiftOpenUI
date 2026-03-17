import WinSDK
import CWin32
import SwiftOpenUI

/// Measure a text string's size using DirectWrite (preferred) or GDI fallback.
/// DirectWrite provides more accurate sub-pixel measurement than GDI.
public func measureText(_ text: String, hwnd: HWND) -> (width: Int32, height: Int32) {
    // Try DirectWrite first — more accurate and consistent with D2D rendering
    if let fmt = D2DRenderer.shared.textFormat() {
        let (w, h) = D2DRenderer.shared.measureText(text, format: fmt)
        if w > 0 || h > 0 {
            return (width: Int32(w) + 4, height: Int32(h) + 2)
        }
    }

    // GDI fallback
    let hdc = GetDC(hwnd)
    defer { ReleaseDC(hwnd, hdc) }

    var size = SIZE()
    text.withCString(encodedAs: UTF16.self) { wstr in
        let len = Int32(wcslen(wstr))
        win32_GetTextExtentPoint32W(hdc, wstr, len, &size)
    }

    return (width: size.cx, height: size.cy)
}

/// Measure text with a specific font using DirectWrite.
public func measureTextWithFont(_ text: String, font: SwiftOpenUI.Font, hwnd: HWND) -> (width: Int32, height: Int32) {
    let (fontSize, bold, italic) = fontParameters(for: font, hwnd: hwnd)
    if let fmt = D2DRenderer.shared.textFormat(fontSize: fontSize, bold: bold, italic: italic) {
        let (w, h) = D2DRenderer.shared.measureText(text, format: fmt)
        return (width: Int32(w) + 4, height: Int32(h) + 2)
    }
    return measureText(text, hwnd: hwnd)
}

/// Extract DirectWrite parameters from a Font enum.
func fontParameters(for font: SwiftOpenUI.Font, hwnd: HWND) -> (fontSize: Float, bold: Bool, italic: Bool) {
    let dpi = win32_GetDpiForWindow(hwnd)
    let scale = Float(dpi) / 96.0

    switch font {
    case .largeTitle:  return (28 * scale, false, false)
    case .title:       return (24 * scale, false, false)
    case .title2:      return (20 * scale, true, false)
    case .title3:      return (18 * scale, false, false)
    case .headline:    return (14 * scale, true, false)
    case .subheadline: return (12 * scale, true, false)
    case .body:        return (14 * scale, false, false)
    case .callout:     return (12 * scale, false, false)
    case .footnote:    return (10 * scale, false, false)
    case .caption:     return (12 * scale, false, false)
    case .caption2:    return (10 * scale, true, false)
    case .custom(let size, let w, _):
        let bold = w == .bold || w == .semibold || w == .heavy || w == .black
        return (Float(size) * scale, bold, false)
    }
}

// MARK: - Stack layout

enum StackDirection {
    case vertical
    case horizontal
}

/// Layout metadata stored on stack container HWNDs.
class StackLayoutInfo {
    let direction: StackDirection
    let spacing: Int32
    let children: [HWND]
    let flexibleIndices: Set<Int>
    /// Each child's natural (intrinsic) size, captured at creation time.
    /// Used to avoid stretching leaf controls to fill the cross-axis.
    let naturalSizes: [(width: Int32, height: Int32)]

    init(direction: StackDirection, spacing: Int32, children: [HWND], flexibleIndices: Set<Int>) {
        self.direction = direction
        self.spacing = spacing
        self.children = children
        self.flexibleIndices = flexibleIndices
        // Capture natural sizes now, before any layout stretches them
        self.naturalSizes = children.map { child in
            var r = RECT()
            GetWindowRect(child, &r)
            return (width: r.right - r.left, height: r.bottom - r.top)
        }
    }
}

/// Compute the natural (intrinsic) size of a stack.
func computeNaturalSize(info: StackLayoutInfo) -> (width: Int32, height: Int32) {
    var totalMain: Int32 = 0
    var maxCross: Int32 = 0

    for child in info.children {
        var childRect = RECT()
        GetWindowRect(child, &childRect)
        let w = childRect.right - childRect.left
        let h = childRect.bottom - childRect.top

        switch info.direction {
        case .vertical:
            totalMain += h
            maxCross = max(maxCross, w)
        case .horizontal:
            totalMain += w
            maxCross = max(maxCross, h)
        }
    }

    if !info.children.isEmpty {
        totalMain += info.spacing * Int32(info.children.count - 1)
    }

    switch info.direction {
    case .vertical:
        return (width: maxCross, height: totalMain)
    case .horizontal:
        return (width: totalMain, height: maxCross)
    }
}

func performVerticalLayout(container: HWND, info: StackLayoutInfo) {
    var rect = RECT()
    GetClientRect(container, &rect)
    let totalWidth = rect.right - rect.left
    let totalHeight = rect.bottom - rect.top

    guard !info.children.isEmpty else { return }

    let totalSpacing = info.spacing * Int32(info.children.count - 1)

    // Use natural sizes for fixed height calculation
    var fixedHeight: Int32 = 0
    for (i, _) in info.children.enumerated() {
        if !info.flexibleIndices.contains(i) {
            fixedHeight += info.naturalSizes[i].height
        }
    }

    let remainingHeight = max(0, totalHeight - fixedHeight - totalSpacing)
    let flexCount = Int32(info.flexibleIndices.count)
    let flexHeight = flexCount > 0 ? remainingHeight / flexCount : 0

    var y: Int32 = 0
    for (i, child) in info.children.enumerated() {
        let childHeight: Int32
        if info.flexibleIndices.contains(i) {
            childHeight = flexHeight
        } else {
            childHeight = info.naturalSizes[i].height
        }

        // VStack: children keep their natural width unless they're a container
        // that should expand (stacks, viewhosts, etc.)
        let naturalW = info.naturalSizes[i].width
        let childWidth: Int32
        let childX: Int32

        if isContainerHwnd(child) || naturalW == 0 || info.flexibleIndices.contains(i) {
            // Containers and spacers fill the width
            childWidth = totalWidth
            childX = 0
        } else {
            // Leaf controls keep natural width, left-aligned
            childWidth = min(naturalW, totalWidth)
            childX = 0
        }

        SetWindowPos(child, nil, childX, y, childWidth, childHeight, UINT(SWP_NOZORDER))
        y += childHeight + info.spacing
    }
}

func performHorizontalLayout(container: HWND, info: StackLayoutInfo) {
    var rect = RECT()
    GetClientRect(container, &rect)
    let totalWidth = rect.right - rect.left
    let totalHeight = rect.bottom - rect.top

    guard !info.children.isEmpty else { return }

    let totalSpacing = info.spacing * Int32(info.children.count - 1)

    var fixedWidth: Int32 = 0
    for (i, _) in info.children.enumerated() {
        if !info.flexibleIndices.contains(i) {
            fixedWidth += info.naturalSizes[i].width
        }
    }

    let remainingWidth = max(0, totalWidth - fixedWidth - totalSpacing)
    let flexCount = Int32(info.flexibleIndices.count)
    let flexWidth = flexCount > 0 ? remainingWidth / flexCount : 0

    var x: Int32 = 0
    for (i, child) in info.children.enumerated() {
        let childWidth: Int32
        if info.flexibleIndices.contains(i) {
            childWidth = flexWidth
        } else {
            childWidth = info.naturalSizes[i].width
        }

        // HStack: children keep their natural height unless they're a container
        let naturalH = info.naturalSizes[i].height
        let childHeight: Int32
        let childY: Int32

        if isContainerHwnd(child) || naturalH == 0 || info.flexibleIndices.contains(i) {
            childHeight = totalHeight
            childY = 0
        } else {
            childHeight = min(naturalH, totalHeight)
            childY = 0
        }

        SetWindowPos(child, nil, x, childY, childWidth, childHeight, UINT(SWP_NOZORDER))
        x += childWidth + info.spacing
    }
}

// MARK: - ZStack layout

class ZStackLayoutInfo {
    let alignment: SwiftOpenUI.Alignment
    let children: [HWND]

    init(alignment: SwiftOpenUI.Alignment, children: [HWND]) {
        self.alignment = alignment
        self.children = children
    }
}

func computeZStackNaturalSize(info: ZStackLayoutInfo) -> (width: Int32, height: Int32) {
    var maxW: Int32 = 0
    var maxH: Int32 = 0

    for child in info.children {
        var childRect = RECT()
        GetWindowRect(child, &childRect)
        maxW = max(maxW, childRect.right - childRect.left)
        maxH = max(maxH, childRect.bottom - childRect.top)
    }

    return (width: maxW, height: maxH)
}

func performZStackLayout(container: HWND, info: ZStackLayoutInfo) {
    var rect = RECT()
    GetClientRect(container, &rect)
    let containerW = rect.right - rect.left
    let containerH = rect.bottom - rect.top

    for child in info.children {
        if isSpacerHwnd(child) || isColorExpandHwnd(child) {
            // Spacers and Color views fill the entire container in ZStack
            SetWindowPos(child, nil, 0, 0, containerW, containerH, UINT(SWP_NOZORDER))
            continue
        }

        var childRect = RECT()
        GetWindowRect(child, &childRect)
        let childW = childRect.right - childRect.left
        let childH = childRect.bottom - childRect.top

        let x: Int32
        let y: Int32

        switch info.alignment {
        case .topLeading:
            x = 0; y = 0
        case .top:
            x = (containerW - childW) / 2; y = 0
        case .topTrailing:
            x = containerW - childW; y = 0
        case .leading:
            x = 0; y = (containerH - childH) / 2
        case .center:
            x = (containerW - childW) / 2; y = (containerH - childH) / 2
        case .trailing:
            x = containerW - childW; y = (containerH - childH) / 2
        case .bottomLeading:
            x = 0; y = containerH - childH
        case .bottom:
            x = (containerW - childW) / 2; y = containerH - childH
        case .bottomTrailing:
            x = containerW - childW; y = containerH - childH
        }

        SetWindowPos(child, nil, x, y, childW, childH, UINT(SWP_NOZORDER))
    }
}

// MARK: - Spacer detection

/// Property name used to mark an HWND as a Spacer.
let spacerPropName: UnsafePointer<WCHAR> = {
    "SwiftUISpacer".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

/// Check if an HWND is a Spacer.
func isSpacerHwnd(_ hwnd: HWND) -> Bool {
    return GetPropW(hwnd, spacerPropName) != nil
}

/// Check if an HWND is a container (stack, viewhost, padding wrapper, etc.)
/// that should expand to fill the cross-axis in stack layout.
/// Leaf controls (Button, Static) keep their natural size.
func isContainerHwnd(_ hwnd: HWND) -> Bool {
    let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
    defer { buffer.deallocate() }
    let length = GetClassNameW(hwnd, buffer, 64)
    guard length > 0 else { return false }
    let cls = String(decodingCString: buffer, as: UTF16.self)
    // Our custom container classes should expand; native controls should not
    return cls.hasPrefix("SwiftUI") || cls.hasPrefix("SwiftOpenUI")
}

// MARK: - Stack container class

let stackContainerClassName: UnsafePointer<WCHAR> = {
    "SwiftUIStack".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

private var stackClassRegistered = false

func registerStackClassIfNeeded(hInstance: HINSTANCE) {
    guard !stackClassRegistered else { return }
    stackClassRegistered = true

    var wc = WNDCLASSEXW()
    wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
    wc.style = UINT(CS_HREDRAW | CS_VREDRAW)
    wc.lpfnWndProc = DefWindowProcW
    wc.hInstance = hInstance
    wc.hbrBackground = GetSysColorBrush(COLOR_WINDOW)
    wc.lpszClassName = stackContainerClassName

    RegisterClassExW(&wc)
}

// MARK: - Subclass proc for stack containers

/// Subclass proc for stack containers — handles WM_SIZE to re-layout children.
let stackLayoutProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    switch uMsg {
    case UINT(WM_SIZE):
        if dwRefData != 0 {
            let info = Unmanaged<StackLayoutInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            ).takeUnretainedValue()

            switch info.direction {
            case .vertical:
                performVerticalLayout(container: hwnd!, info: info)
            case .horizontal:
                performHorizontalLayout(container: hwnd!, info: info)
            }
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

    case UINT(WM_HSCROLL), UINT(WM_VSCROLL):
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            return SendMessageW(childHwnd, uMsg, wParam, lParam)
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

    case UINT(WM_NCDESTROY):
        if dwRefData != 0 {
            Unmanaged<StackLayoutInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            ).release()
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

/// Subclass proc for ZStack containers.
let zStackLayoutProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    switch uMsg {
    case UINT(WM_SIZE):
        if dwRefData != 0 {
            let info = Unmanaged<ZStackLayoutInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            ).takeUnretainedValue()
            performZStackLayout(container: hwnd!, info: info)
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
        // Forward to parent so BackgroundView ancestors can set their brush.
        if let parent = GetParent(hwnd!) {
            return SendMessageW(parent, uMsg, wParam, lParam)
        }
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetBkMode(hdc, TRANSPARENT)
        return LRESULT(Int(bitPattern: GetSysColorBrush(COLOR_WINDOW)))

    case UINT(WM_NCDESTROY):
        if dwRefData != 0 {
            Unmanaged<ZStackLayoutInfo>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
            ).release()
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

/// Walk the HWND parent chain to find the top-level window.
func findRootWindow(from hwnd: HWND) -> HWND {
    var current = hwnd
    while let parent = GetParent(current) {
        current = parent
    }
    return current
}
