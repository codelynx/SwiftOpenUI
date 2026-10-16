import WinSDK
import CWin32
import SwiftOpenUI

/// Default body text size in logical points. Text is measured and drawn at
/// this size × DPI scale unless a font is given, so keep every use on it.
let defaultBodyFontSize: Double = 14

/// Ratio of `hwnd`'s DPI to the 96-DPI baseline (1.5 at 150%).
func dpiScaleFactor(for hwnd: HWND) -> Double {
    Double(win32_GetDpiForWindow(hwnd)) / 96.0
}

// MARK: - Points ↔ pixels (RFC #16 chokepoint)
//
// Every dimension in the core API is a logical point (1pt = 1px at 96 DPI).
// Win32 layout and the 96-DPI-pinned D2D targets work in physical pixels,
// so API values are converted once, where a view is created, with these
// helpers. At 100% they are the identity.

/// Logical points → physical pixels, rounded to the nearest pixel.
func px(_ points: Double, for hwnd: HWND) -> Int32 {
    Int32((points * dpiScaleFactor(for: hwnd)).rounded())
}

/// Logical points → physical pixels for a window that doesn't exist yet,
/// using the system DPI (what a new top-level window opens at).
func pxForNewWindow(_ points: Double) -> Int32 {
    Int32((points * Double(GetDpiForSystem()) / 96.0).rounded())
}

/// Logical points → physical pixels, unrounded (for layout math and D2D).
func pxExact(_ points: Double, for hwnd: HWND) -> Double {
    points * dpiScaleFactor(for: hwnd)
}

/// Physical pixels → logical points, for values handed back to user code
/// (gesture locations, GeometryReader sizes, Canvas sizes).
func pxToPoints(_ pixels: Double, for hwnd: HWND) -> Double {
    pixels / dpiScaleFactor(for: hwnd)
}

/// Measure a text string's size using DirectWrite (preferred) or GDI fallback.
/// DirectWrite provides more accurate sub-pixel measurement than GDI.
public func measureText(_ text: String, hwnd: HWND) -> (width: Int32, height: Int32) {
    // Text renders DPI-scaled, so measure with the scaled default size.
    let dpiScale = Float(dpiScaleFactor(for: hwnd))
    // Try DirectWrite first — more accurate and consistent with D2D rendering
    if let fmt = D2DRenderer.shared.textFormat(fontSize: Float(defaultBodyFontSize) * dpiScale) {
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

    return (width: Int32(Double(size.cx) * Double(dpiScale)), height: Int32(Double(size.cy) * Double(dpiScale)))
}

/// Measure text with a specific font family using DirectWrite.
public func measureText(_ text: String, fontFamily: String, hwnd: HWND) -> (width: Int32, height: Int32) {
    let dpiScale = Float(dpiScaleFactor(for: hwnd))
    if let fmt = D2DRenderer.shared.textFormat(fontFamily: fontFamily, fontSize: Float(defaultBodyFontSize) * dpiScale) {
        let (w, h) = D2DRenderer.shared.measureText(text, format: fmt)
        if w > 0 || h > 0 {
            return (width: Int32(w) + 4, height: Int32(h) + 2)
        }
    }
    return measureText(text, hwnd: hwnd)
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
    let scale = Float(dpiScaleFactor(for: hwnd))

    switch font {
    case .largeTitle:  return (28 * scale, false, false)
    case .title:       return (24 * scale, false, false)
    case .title2:      return (20 * scale, true, false)
    case .title3:      return (18 * scale, false, false)
    case .headline:    return (14 * scale, true, false)
    case .subheadline: return (12 * scale, true, false)
    case .body:        return (Float(defaultBodyFontSize) * scale, false, false)
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
    /// Cross-axis alignment: 0 = leading, 1 = center, 2 = trailing
    let crossAlignment: Int
    /// Each child's natural (intrinsic) size, captured at creation time.
    /// Used to avoid stretching leaf controls to fill the cross-axis.
    let naturalSizes: [(width: Int32, height: Int32)]

    init(direction: StackDirection, spacing: Int32, children: [HWND],
         flexibleIndices: Set<Int>, crossAlignment: Int = 1) {
        self.direction = direction
        self.spacing = spacing
        self.children = children
        self.flexibleIndices = flexibleIndices
        self.crossAlignment = crossAlignment
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

    // Treat both Spacers and expandHeight children as flexible along the main axis
    var flexIndices = info.flexibleIndices
    for (i, child) in info.children.enumerated() {
        if shouldExpandHeight(child) {
            flexIndices.insert(i)
        }
    }

    // Use natural sizes for fixed height calculation
    var fixedHeight: Int32 = 0
    for (i, _) in info.children.enumerated() {
        if !flexIndices.contains(i) {
            fixedHeight += info.naturalSizes[i].height
        }
    }

    let remainingHeight = max(0, totalHeight - fixedHeight - totalSpacing)
    let flexOrder = flexIndices.sorted()
    let flexHeights = distributeFlexibleSpace(
        remainingHeight, caps: flexOrder.map { expandMaxHeight(info.children[$0]) })
    let flexHeightByIndex = Dictionary(uniqueKeysWithValues: zip(flexOrder, flexHeights))

    var y: Int32 = 0
    for (i, child) in info.children.enumerated() {
        let childHeight: Int32
        if let flexHeight = flexHeightByIndex[i] {
            childHeight = flexHeight
        } else {
            childHeight = info.naturalSizes[i].height
        }

        // VStack: children keep their natural width unless they're a container
        // that should expand (stacks, viewhosts, etc.)
        let naturalW = info.naturalSizes[i].width
        let childWidth: Int32
        let childX: Int32

        if shouldExpandWidth(child) && expandMaxWidth(child).map({ $0 < totalWidth }) == true {
            // Bounded expansion: grow to the cap, aligned like a leaf
            childWidth = expandMaxWidth(child)!
            switch info.crossAlignment {
            case 0:  childX = 0
            case 2:  childX = totalWidth - childWidth
            default: childX = (totalWidth - childWidth) / 2
            }
        } else if shouldExpandWidth(child) || naturalW == 0 || info.flexibleIndices.contains(i) {
            // Explicit width expanders and spacers fill the width
            childWidth = totalWidth
            childX = 0
        } else {
            // Leaf controls keep natural width, positioned by alignment
            childWidth = min(naturalW, totalWidth)
            switch info.crossAlignment {
            case 0:  childX = 0                                // leading
            case 2:  childX = totalWidth - childWidth          // trailing
            default: childX = (totalWidth - childWidth) / 2    // center
            }
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

    // Treat both Spacers and expandWidth children as flexible along the main axis
    var flexIndices = info.flexibleIndices
    for (i, child) in info.children.enumerated() {
        if shouldExpandWidth(child) {
            flexIndices.insert(i)
        }
    }

    var fixedWidth: Int32 = 0
    for (i, _) in info.children.enumerated() {
        if !flexIndices.contains(i) {
            fixedWidth += info.naturalSizes[i].width
        }
    }

    let remainingWidth = max(0, totalWidth - fixedWidth - totalSpacing)
    let flexOrder = flexIndices.sorted()
    let flexWidths = distributeFlexibleSpace(
        remainingWidth, caps: flexOrder.map { expandMaxWidth(info.children[$0]) })
    let flexWidthByIndex = Dictionary(uniqueKeysWithValues: zip(flexOrder, flexWidths))

    var x: Int32 = 0
    for (i, child) in info.children.enumerated() {
        let childWidth: Int32
        if let flexWidth = flexWidthByIndex[i] {
            childWidth = flexWidth
        } else {
            childWidth = info.naturalSizes[i].width
        }

        // HStack: children keep their natural height unless they're a container
        let naturalH = info.naturalSizes[i].height
        let childHeight: Int32
        let childY: Int32

        if shouldExpandHeight(child) && expandMaxHeight(child).map({ $0 < totalHeight }) == true {
            // Bounded expansion: grow to the cap, aligned like a leaf
            childHeight = expandMaxHeight(child)!
            switch info.crossAlignment {
            case 0:  childY = 0
            case 2:  childY = totalHeight - childHeight
            default: childY = (totalHeight - childHeight) / 2
            }
        } else if shouldExpandHeight(child) || naturalH == 0 || info.flexibleIndices.contains(i) {
            childHeight = totalHeight
            childY = 0
        } else {
            childHeight = min(naturalH, totalHeight)
            switch info.crossAlignment {
            case 0:  childY = 0                                 // top
            case 2:  childY = totalHeight - childHeight         // bottom
            default: childY = (totalHeight - childHeight) / 2   // center
            }
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
        let naturalW = childRect.right - childRect.left
        let naturalH = childRect.bottom - childRect.top

        // Expand children that have expand flags (e.g. frame(maxWidth: .infinity))
        let childW = shouldExpandWidth(child) ? min(containerW, expandMaxWidth(child) ?? containerW) : naturalW
        let childH = shouldExpandHeight(child) ? min(containerH, expandMaxHeight(child) ?? containerH) : naturalH

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

let expandWidthPropName: UnsafePointer<WCHAR> = {
    "SwiftUIExpandWidth".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

let expandHeightPropName: UnsafePointer<WCHAR> = {
    "SwiftUIExpandHeight".withCString(encodedAs: UTF16.self) { ptr in
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

let dividerPropName: UnsafePointer<WCHAR> = {
    "SwiftUIDivider".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

/// Check if an HWND is a Divider.
func isDividerHwnd(_ hwnd: HWND) -> Bool {
    return GetPropW(hwnd, dividerPropName) != nil
}

func markExpandWidth(_ hwnd: HWND) {
    SetPropW(hwnd, expandWidthPropName, HANDLE(bitPattern: 1))
}

func markExpandHeight(_ hwnd: HWND) {
    SetPropW(hwnd, expandHeightPropName, HANDLE(bitPattern: 1))
}

// MARK: - Bounded expansion
//
// A flexible frame with a finite max (`.frame(minWidth: 40, maxWidth: 100)`)
// expands like `.infinity` but stops at its max. The cap is stored next to
// the expand flag, carried up through single-child wrappers, and applied by
// the parent layout. Stacks propagate the flag without a cap.

private let expandMaxWidthPropName: UnsafePointer<WCHAR> = makePropName("SwiftUI_ExpandMaxW")
private let expandMaxHeightPropName: UnsafePointer<WCHAR> = makePropName("SwiftUI_ExpandMaxH")

private func makePropName(_ name: String) -> UnsafePointer<WCHAR> {
    name.withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}

// Stored as value + 1 so a 0 cap is distinguishable from "no prop".
func setExpandMaxWidth(_ hwnd: HWND, _ value: Int32) {
    SetPropW(hwnd, expandMaxWidthPropName, HANDLE(bitPattern: Int(max(0, value)) + 1))
}

func setExpandMaxHeight(_ hwnd: HWND, _ value: Int32) {
    SetPropW(hwnd, expandMaxHeightPropName, HANDLE(bitPattern: Int(max(0, value)) + 1))
}

/// A frame max as a pixel cap, or nil when it's effectively unbounded
/// (infinite, NaN, or too large for Int32; converting those would trap).
func pixelCap(_ value: Double) -> Int32? {
    guard value.isFinite, value < Double(Int32.max) else { return nil }
    return Int32(max(0, ceil(value)))
}

/// Remove expand flags and caps, e.g. before re-deriving them on rebuild.
func clearExpandFlags(_ hwnd: HWND) {
    RemovePropW(hwnd, expandWidthPropName)
    RemovePropW(hwnd, expandHeightPropName)
    RemovePropW(hwnd, expandMaxWidthPropName)
    RemovePropW(hwnd, expandMaxHeightPropName)
}

/// The max width an expanding view may take, or nil when it's unbounded.
func expandMaxWidth(_ hwnd: HWND) -> Int32? {
    guard let raw = GetPropW(hwnd, expandMaxWidthPropName) else { return nil }
    return Int32(Int(bitPattern: raw) - 1)
}

func expandMaxHeight(_ hwnd: HWND) -> Int32? {
    guard let raw = GetPropW(hwnd, expandMaxHeightPropName) else { return nil }
    return Int32(Int(bitPattern: raw) - 1)
}

/// Copy a single child's expand flags (and caps) onto its wrapper. By
/// default the size the wrapper adds around the child (padding, border) is
/// measured and added to the cap, so call it right after sizing the
/// container to fit the child. Pass `extraWidth`/`extraHeight` when the
/// container's current size isn't child + insets (e.g. a ViewHost that the
/// parent has already stretched).
func propagateExpandFlags(from child: HWND, to container: HWND,
                          extraWidth: Int32? = nil, extraHeight: Int32? = nil) {
    var childRect = RECT(), containerRect = RECT()
    GetWindowRect(child, &childRect)
    GetWindowRect(container, &containerRect)
    if shouldExpandWidth(child) {
        markExpandWidth(container)
        if let cap = expandMaxWidth(child) {
            let extra = extraWidth
                ?? (containerRect.right - containerRect.left) - (childRect.right - childRect.left)
            setExpandMaxWidth(container, cap + max(0, extra))
        }
    }
    if shouldExpandHeight(child) {
        markExpandHeight(container)
        if let cap = expandMaxHeight(child) {
            let extra = extraHeight
                ?? (containerRect.bottom - containerRect.top) - (childRect.bottom - childRect.top)
            setExpandMaxHeight(container, cap + max(0, extra))
        }
    }
}

/// Split `available` among flexible children, giving capped ones at most
/// their cap and sharing what they leave over among the rest.
func distributeFlexibleSpace(_ available: Int32, caps: [Int32?]) -> [Int32] {
    var sizes = [Int32](repeating: 0, count: caps.count)
    var open = Set(caps.indices)
    var remaining = available
    while !open.isEmpty {
        let share = remaining / Int32(open.count)
        let capped = open.filter { caps[$0].map { $0 < share } ?? false }
        if capped.isEmpty {
            for i in open { sizes[i] = share }
            break
        }
        for i in capped {
            sizes[i] = caps[i]!
            remaining -= caps[i]!
            open.remove(i)
        }
    }
    return sizes
}

func shouldExpandWidth(_ hwnd: HWND) -> Bool {
    GetPropW(hwnd, expandWidthPropName) != nil
}

func shouldExpandHeight(_ hwnd: HWND) -> Bool {
    GetPropW(hwnd, expandHeightPropName) != nil
}

/// Erase a wrapper/container HWND using the brush provided by its parent
/// chain, falling back to the system window brush when no custom background
/// is active. This keeps stretched layout wrappers visually transparent.
func eraseWithInheritedBackground(hwnd: HWND, wParam: WPARAM) -> LRESULT {
    let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
    var rect = RECT()
    GetClientRect(hwnd, &rect)

    if let parent = GetParent(hwnd) {
        let brushResult = SendMessageW(parent, UINT(WM_CTLCOLORSTATIC), wParam, LPARAM(Int(bitPattern: hwnd)))
        if let brush = HBRUSH(bitPattern: Int(brushResult)) {
            FillRect(hdc, &rect, brush)
            return 1
        }
    }

    FillRect(hdc, &rect, GetSysColorBrush(COLOR_WINDOW))
    return 1
}

/// The background color inherited from `hwnd`'s parent chain (as 0...1 RGB),
/// for D2D surfaces that must clear to whatever is behind them. Falls back
/// to the system window color when no ancestor supplies a solid brush.
/// A hollow brush (e.g. from a ZStack) has no color, so keep looking above it.
func inheritedBackgroundColor(for hwnd: HWND) -> (r: Float, g: Float, b: Float) {
    var color = GetSysColor(COLOR_WINDOW)
    if let parent = GetParent(hwnd) {
        let hdc = GetDC(hwnd)
        let brushResult = SendMessageW(parent, UINT(WM_CTLCOLORSTATIC),
                                       WPARAM(UInt(bitPattern: hdc)), LPARAM(Int(bitPattern: hwnd)))
        ReleaseDC(hwnd, hdc)
        if brushResult != 0, let brush = HBRUSH(bitPattern: Int(brushResult)) {
            var logBrush = LOGBRUSH()
            GetObjectW(brush, Int32(MemoryLayout<LOGBRUSH>.size), &logBrush)
            if logBrush.lbStyle == UINT(BS_NULL) {
                return inheritedBackgroundColor(for: parent)
            }
            color = logBrush.lbColor
        }
    }
    return (Float(win32_GetRValue(color)) / 255.0,
            Float(win32_GetGValue(color)) / 255.0,
            Float(win32_GetBValue(color)) / 255.0)
}

/// Bumped whenever the background behind existing windows may change in
/// place (reparenting, a custom button's pressed state, ViewHost rebuilds,
/// system colors). Otherwise backgrounds only appear on newly created
/// windows, whose own caches start empty.
private(set) var inheritedBackgroundGeneration = 0

func invalidateInheritedBackgrounds() {
    inheritedBackgroundGeneration &+= 1
}

/// Per-control cache for `inheritedBackgroundColor(for:)`, which walks the
/// whole WM_CTLCOLORSTATIC chain (and restarts above every ZStack) and costs
/// ~0.15–2 ms in deep trees. Keep one on each D2D control's state object
/// so it dies with the window.
struct InheritedBackgroundCache {
    private var generation = -1
    private var cached: (r: Float, g: Float, b: Float) = (1, 1, 1)

    mutating func color(for hwnd: HWND) -> (r: Float, g: Float, b: Float) {
        if generation != inheritedBackgroundGeneration {
            cached = inheritedBackgroundColor(for: hwnd)
            generation = inheritedBackgroundGeneration
        }
        return cached
    }
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

    case UINT(WM_ERASEBKGND):
        return eraseWithInheritedBackground(hwnd: hwnd!, wParam: wParam)

    case UINT(WM_CTLCOLORSTATIC):
        // ZStack children overlap — STATIC controls must have transparent
        // backgrounds so underlying Color/Image views show through.
        // Forward first (ignoring the brush) so an outer .foregroundColor()
        // still sets the text color.
        if let parent = GetParent(hwnd!) {
            _ = SendMessageW(parent, uMsg, wParam, lParam)
        }
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetBkMode(hdc, TRANSPARENT)
        return LRESULT(Int(bitPattern: GetStockObject(HOLLOW_BRUSH)))

    case UINT(WM_CTLCOLORBTN):
        // Buttons keep normal background; forward to parent for BackgroundView.
        if let parent = GetParent(hwnd!) {
            return SendMessageW(parent, uMsg, wParam, lParam)
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)

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
