import WinSDK
import CWin32
import SwiftOpenUI

/// Measure a text string's size using the system font.
public func measureText(_ text: String, hwnd: HWND) -> (width: Int32, height: Int32) {
    let hdc = GetDC(hwnd)
    defer { ReleaseDC(hwnd, hdc) }

    var size = SIZE()
    text.withCString(encodedAs: UTF16.self) { wstr in
        let len = Int32(wcslen(wstr))
        win32_GetTextExtentPoint32W(hdc, wstr, len, &size)
    }

    return (width: size.cx, height: size.cy)
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

    init(direction: StackDirection, spacing: Int32, children: [HWND], flexibleIndices: Set<Int>) {
        self.direction = direction
        self.spacing = spacing
        self.children = children
        self.flexibleIndices = flexibleIndices
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

    var fixedHeight: Int32 = 0
    for (i, child) in info.children.enumerated() {
        if !info.flexibleIndices.contains(i) {
            var childRect = RECT()
            GetWindowRect(child, &childRect)
            fixedHeight += childRect.bottom - childRect.top
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
            var childRect = RECT()
            GetWindowRect(child, &childRect)
            childHeight = childRect.bottom - childRect.top
        }

        SetWindowPos(child, nil, 0, y, totalWidth, childHeight, UINT(SWP_NOZORDER))
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
    for (i, child) in info.children.enumerated() {
        if !info.flexibleIndices.contains(i) {
            var childRect = RECT()
            GetWindowRect(child, &childRect)
            fixedWidth += childRect.right - childRect.left
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
            var childRect = RECT()
            GetWindowRect(child, &childRect)
            childWidth = childRect.right - childRect.left
        }

        SetWindowPos(child, nil, x, 0, childWidth, totalHeight, UINT(SWP_NOZORDER))
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
        if isSpacerHwnd(child) {
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
