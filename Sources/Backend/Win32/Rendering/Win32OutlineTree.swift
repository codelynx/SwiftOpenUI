import WinSDK
import CWin32
import CWin32Bridge
import SwiftOpenUI
import Foundation

// MARK: - Native Win32 OutlineGroup renderer
//
// On backends without a native tree widget, `OutlineGroup` falls back to
// nested `DisclosureGroup`s through its Swift `body`
// (SwiftOpenUI/Views/OutlineGroup.swift). On Win32 that fallback is
// broken three ways:
//   1. stateless — the label-view `DisclosureGroup` has no expansion
//      binding, so folders can never expand;
//   2. content-sized — the surrounding `ScrollView` sizes to the widest
//      row, so the whole tree floats centered instead of filling width;
//   3. white boxes — each collapsed `DisclosureGroup` paints the raw
//      stack-class `COLOR_WINDOW` brush.
//
// This is the Win32 analogue of the GTK4 `GtkTreeListModel` renderer: a
// self-scrolling control that owns the flattened tree, the expansion
// state, and the vertical layout. Expansion state lives in the retained
// model (not SwiftUI `@State`), so expand/collapse works without tripping
// the Win32 child-state reconciliation gap — and only rows under an
// expanded ancestor are ever realized, so a large diff never eagerly
// materializes every node.

private let outlineIndentPerLevel: Int32 = 22
private let outlineArrowSlot: Int32 = 26
private let outlineRowVPad: Int32 = 4

/// Posted to the tree container by an arrow click to run the toggle +
/// relayout *after* the click's own message handler returns — relayout
/// destroys the clicked arrow's HWND, which is unsafe to do from inside
/// that window's own wndproc.
private let outlineToggleMessage = UINT(WM_APP) + 0x21

/// Content that manages its own scrolling and should therefore be
/// rendered directly by `List` rather than wrapped in a `ScrollView`.
/// Mirrors GTK4's `GTKSelfScrollingContent`.
protocol WinSelfScrollingContent {
    func winSelfScrollingWidget(in context: RenderContext) -> HWND?
}

/// Subclass refdata for a disclosure-arrow container: which node it
/// toggles. Retained while the arrow HWND lives; released on WM_NCDESTROY.
private final class OutlineArrowClick {
    weak var model: Win32OutlineModel?
    let key: String
    init(model: Win32OutlineModel, key: String) {
        self.model = model
        self.key = key
    }
}

/// Click handler for the transparent arrow container. Defers the actual
/// expand/collapse to the container via PostMessage (see
/// `outlineToggleMessage`).
private let outlineArrowClickProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uId, dwRef) in
    switch uMsg {
    case UINT(WM_LBUTTONUP):
        if dwRef != 0 {
            let ctx = Unmanaged<OutlineArrowClick>
                .fromOpaque(UnsafeMutableRawPointer(bitPattern: UInt(dwRef))!)
                .takeUnretainedValue()
            if let model = ctx.model, let container = model.container {
                model.pendingToggleKey = ctx.key
                PostMessageW(container, outlineToggleMessage, 0, 0)
            }
        }
        return 0
    case UINT(WM_NCDESTROY):
        if dwRef != 0 {
            Unmanaged<OutlineArrowClick>
                .fromOpaque(UnsafeMutableRawPointer(bitPattern: UInt(dwRef))!)
                .release()
        }
        RemoveWindowSubclass(hwnd, outlineArrowClickProc, uId)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

/// Makes an HWND pass mouse hit-testing through to its parent, so a click
/// on the chevron glyph reaches the clickable arrow container behind it.
private let outlineHitTransparentProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uId, _) in
    if uMsg == UINT(WM_NCHITTEST) { return LRESULT(HTTRANSPARENT) }
    if uMsg == UINT(WM_NCDESTROY) { RemoveWindowSubclass(hwnd, outlineHitTransparentProc, uId) }
    return DefSubclassProc(hwnd, uMsg, wParam, lParam)
}

/// Retained per-control model: the flattened tree, the expansion set, and
/// live layout bookkeeping. Stored on the scroll container's
/// `GWLP_USERDATA` and released on `WM_NCDESTROY`.
final class Win32OutlineModel {
    let rootKeys: [String]
    private let childKeysByKey: [String: [String]]
    private let depthByKey: [String: Int]
    /// Renders the row body (badge/icon/name — no arrow) for a key into
    /// `parent`. Captures the OutlineGroup's generic `rowContent`.
    private let renderRow: (String, HWND, HINSTANCE) -> HWND?

    var expanded: Set<String> = []

    // Live runtime state, filled by the builder.
    var container: HWND?
    var content: HWND?
    var hInstance: HINSTANCE?
    var capturedEnv: EnvironmentValues?
    var scrollY: Int32 = 0
    var contentHeight: Int32 = 0
    var contentWidth: Int32 = 0
    /// Set by an arrow click, consumed by the container's toggle message.
    var pendingToggleKey: String?

    init<Data: RandomAccessCollection, Row: View>(
        items: [Data.Element],
        childrenKeyPath: KeyPath<Data.Element, Data?>,
        rowContent: @escaping (Data.Element) -> Row
    ) {
        var nodesByKey: [String: Data.Element] = [:]
        var childKeys: [String: [String]] = [:]
        var depths: [String: Int] = [:]
        var counter = 0

        // Positional depth-first keying ("0", "1", …): unique and stable,
        // and immune to two nodes in different subtrees sharing an id.
        func assign(_ element: Data.Element, _ depth: Int) -> String {
            let key = String(counter)
            counter += 1
            nodesByKey[key] = element
            depths[key] = depth
            if let kids = element[keyPath: childrenKeyPath], !kids.isEmpty {
                childKeys[key] = kids.map { assign($0, depth + 1) }
            }
            return key
        }
        rootKeys = items.map { assign($0, 0) }
        childKeysByKey = childKeys
        depthByKey = depths
        renderRow = { key, parent, hInst in
            guard let element = nodesByKey[key] else { return nil }
            return winRenderView(rowContent(element), in: RenderContext(parent: parent, hInstance: hInst))
        }
    }

    func hasChildren(_ key: String) -> Bool { childKeysByKey[key] != nil }
    func depth(_ key: String) -> Int { depthByKey[key] ?? 0 }
    func render(_ key: String, into parent: HWND, _ hInst: HINSTANCE) -> HWND? {
        renderRow(key, parent, hInst)
    }

    /// Depth-first list of currently-visible keys: root rows always, a
    /// node's children only while that node is expanded.
    func visibleKeys() -> [String] {
        var out: [String] = []
        func walk(_ keys: [String]) {
            for k in keys {
                out.append(k)
                if expanded.contains(k), let ch = childKeysByKey[k] { walk(ch) }
            }
        }
        walk(rootKeys)
        return out
    }

    func toggle(_ key: String) {
        if expanded.contains(key) { expanded.remove(key) } else { expanded.insert(key) }
    }
}

/// Reads the model back off a container HWND's `GWLP_USERDATA`.
private func outlineModel(from hwnd: HWND?) -> Win32OutlineModel? {
    guard let hwnd else { return nil }
    let ud = win32_GetWindowLongPtrW(hwnd, GWLP_USERDATA)
    guard ud != 0 else { return nil }
    return Unmanaged<Win32OutlineModel>
        .fromOpaque(UnsafeMutableRawPointer(bitPattern: Int(ud))!)
        .takeUnretainedValue()
}

/// Rebuilds and lays out every currently-visible row. Called on create
/// and on every expand/collapse. Destroys the previous rows first, so
/// collapsed subtrees release their widgets.
private func outlineRelayout(_ model: Win32OutlineModel) {
    guard let container = model.container, let content = model.content,
          let hInst = model.hInstance else { return }

    // Destroy the previous rows. Each arrow's click subclass releases its
    // retained context on WM_NCDESTROY, and collapsed subtrees drop their
    // widgets.
    var oldChild = GetWindow(content, UINT(GW_CHILD))
    while let c = oldChild {
        let next = GetWindow(c, UINT(GW_HWNDNEXT))
        DestroyWindow(c)
        oldChild = next
    }

    // Row bodies render through winRenderView, which reads the current
    // environment (fonts/colors). Restore the environment captured at
    // build time so rows re-rendered during a toggle match the originals.
    let prevEnv = getCurrentEnvironment()
    if let env = model.capturedEnv { setCurrentEnvironment(env) }
    defer { setCurrentEnvironment(prevEnv) }

    var y: Int32 = 0
    var widest: Int32 = 0
    for key in model.visibleKeys() {
        let indent = Int32(model.depth(key)) * outlineIndentPerLevel

        // Row body (badge + icon + name + count).
        let bodyHwnd = model.render(key, into: content, hInst)
        var bodyW: Int32 = 0, bodyH: Int32 = 0
        if let bodyHwnd {
            var r = RECT(); GetWindowRect(bodyHwnd, &r)
            bodyW = r.right - r.left; bodyH = r.bottom - r.top
        }

        // Disclosure chevron — folders only. Rendered through the same
        // Material Symbols pipeline as every other icon (Image(systemName:))
        // and hosted in a transparent, borderless clickable container, so it
        // matches the mac/Linux disclosure look instead of a native push
        // button. The glyph passes clicks through to the container, which
        // toggles expansion.
        var arrowContainer: HWND?
        var glyphHwnd: HWND?
        var glyphW: Int32 = 0, glyphH: Int32 = 0
        if model.hasChildren(key) {
            arrowContainer = CreateWindowExW(
                0, outlineContentClassName, nil,
                DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
                0, 0, outlineArrowSlot, max(bodyH, 1),
                content, nil, hInst, nil
            )
            if let arrowContainer {
                let sf = model.expanded.contains(key) ? "chevron.down" : "chevron.right"
                let glyphCtx = RenderContext(parent: arrowContainer, hInstance: hInst)
                glyphHwnd = winRenderView(Image(systemName: sf).imageScale(.small), in: glyphCtx)
                if let glyphHwnd {
                    var gr = RECT(); GetWindowRect(glyphHwnd, &gr)
                    glyphW = gr.right - gr.left
                    glyphH = gr.bottom - gr.top
                    SetWindowSubclass(glyphHwnd, outlineHitTransparentProc, 71, 0)
                }
                let clickCtx = OutlineArrowClick(model: model, key: key)
                let ptr = Unmanaged.passRetained(clickCtx).toOpaque()
                SetWindowSubclass(arrowContainer, outlineArrowClickProc, 70, DWORD_PTR(UInt(bitPattern: ptr)))
            }
        }

        let rowH = max(bodyH, glyphH)
        if let arrowContainer {
            SetWindowPos(arrowContainer, nil, indent, y, outlineArrowSlot, rowH, UINT(SWP_NOZORDER))
            if let glyphHwnd {
                SetWindowPos(glyphHwnd, nil,
                             max(0, (outlineArrowSlot - glyphW) / 2),
                             max(0, (rowH - glyphH) / 2),
                             glyphW, glyphH, UINT(SWP_NOZORDER))
            }
        }
        let bodyX = indent + outlineArrowSlot
        if let bodyHwnd {
            SetWindowPos(bodyHwnd, nil, bodyX, y + max(0, (rowH - bodyH) / 2),
                         bodyW, bodyH, UINT(SWP_NOZORDER))
        }
        widest = max(widest, bodyX + bodyW)
        y += rowH + outlineRowVPad
    }

    model.contentHeight = y
    model.contentWidth = widest

    var crect = RECT(); GetClientRect(container, &crect)
    let clientW = crect.right - crect.left
    let clientH = crect.bottom - crect.top
    let contentW = max(clientW, widest)
    let maxScroll = max(0, y - clientH)
    if model.scrollY > maxScroll { model.scrollY = maxScroll }

    SetWindowPos(content, nil, 0, -model.scrollY, contentW, max(y, 1), UINT(SWP_NOZORDER))
    outlineUpdateScrollRange(model)
    InvalidateRect(container, nil, true)
}

/// Reposition content on container resize (no re-render — row heights are
/// width-independent). Keeps the content at least the client width so it
/// fills, and clamps the scroll offset to the new viewport.
private func outlineHandleResize(_ model: Win32OutlineModel) {
    guard let container = model.container, let content = model.content else { return }
    var rect = RECT(); GetClientRect(container, &rect)
    let clientW = rect.right - rect.left
    let visibleH = rect.bottom - rect.top
    let contentW = max(clientW, model.contentWidth)
    let maxScroll = max(0, model.contentHeight - visibleH)
    if model.scrollY > maxScroll { model.scrollY = maxScroll }
    SetWindowPos(content, nil, 0, -model.scrollY, contentW, max(model.contentHeight, 1), UINT(SWP_NOZORDER))
    outlineUpdateScrollRange(model)
}

private func outlineHandleVScroll(_ model: Win32OutlineModel, wParam: WPARAM) {
    guard let container = model.container, let content = model.content else { return }
    var rect = RECT(); GetClientRect(container, &rect)
    let visibleH = rect.bottom - rect.top
    let clientW = rect.right - rect.left
    let maxScroll = max(0, model.contentHeight - visibleH)

    let action = Int32(win32_LOWORD(DWORD_PTR(wParam)))
    var newPos = model.scrollY
    switch action {
    case SB_LINEUP: newPos -= 20
    case SB_LINEDOWN: newPos += 20
    case SB_PAGEUP: newPos -= visibleH
    case SB_PAGEDOWN: newPos += visibleH
    case SB_THUMBTRACK, SB_THUMBPOSITION:
        // Read the full 32-bit track position; wParam's HIWORD caps at 65535
        // (~2,400 rows), which would wrap the thumb on very tall trees.
        var tsi = SCROLLINFO()
        tsi.cbSize = UINT(MemoryLayout<SCROLLINFO>.size)
        tsi.fMask = UINT(SIF_TRACKPOS)
        newPos = GetScrollInfo(container, INT(SB_VERT), &tsi) ? tsi.nTrackPos
            : Int32(win32_HIWORD(DWORD_PTR(wParam)))
    default: break
    }
    newPos = min(max(newPos, 0), maxScroll)
    guard newPos != model.scrollY else { return }
    model.scrollY = newPos

    let contentW = max(clientW, model.contentWidth)
    SetWindowPos(content, nil, 0, -newPos, contentW, max(model.contentHeight, 1), UINT(SWP_NOZORDER))
    var si = SCROLLINFO()
    si.cbSize = UINT(MemoryLayout<SCROLLINFO>.size)
    si.fMask = UINT(SIF_POS)
    si.nPos = newPos
    SetScrollInfo(container, INT(SB_VERT), &si, true)
}

private func outlineUpdateScrollRange(_ model: Win32OutlineModel) {
    guard let container = model.container else { return }
    var rect = RECT(); GetClientRect(container, &rect)
    let visibleH = rect.bottom - rect.top
    var si = SCROLLINFO()
    si.cbSize = UINT(MemoryLayout<SCROLLINFO>.size)
    si.fMask = UINT(SIF_RANGE | SIF_PAGE | SIF_POS)
    si.nMin = 0
    si.nMax = max(0, model.contentHeight - 1)
    si.nPage = UINT(max(0, visibleH))
    si.nPos = model.scrollY
    SetScrollInfo(container, INT(SB_VERT), &si, true)
}

// MARK: - Window classes

private let outlineContainerClassName: UnsafePointer<WCHAR> = {
    "SwiftUIOutlineTree".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

private let outlineContentClassName: UnsafePointer<WCHAR> = {
    "SwiftUIOutlineContent".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

private var outlineClassesRegistered = false

private func registerOutlineClassesIfNeeded(hInstance: HINSTANCE) {
    guard !outlineClassesRegistered else { return }
    outlineClassesRegistered = true

    var container = WNDCLASSEXW()
    container.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
    container.style = UINT(CS_HREDRAW | CS_VREDRAW)
    container.lpfnWndProc = outlineContainerProc
    container.hInstance = hInstance
    container.hbrBackground = nil // erased via WM_ERASEBKGND (inherited)
    container.lpszClassName = outlineContainerClassName
    RegisterClassExW(&container)

    var content = WNDCLASSEXW()
    content.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
    content.style = UINT(CS_HREDRAW | CS_VREDRAW)
    content.lpfnWndProc = outlineContentProc
    content.hInstance = hInstance
    content.hbrBackground = nil
    content.lpszClassName = outlineContentClassName
    RegisterClassExW(&content)
}

private let outlineContainerProc: WNDPROC = { (hwnd, uMsg, wParam, lParam) in
    switch uMsg {
    case UINT(WM_SIZE):
        if let model = outlineModel(from: hwnd) { outlineHandleResize(model) }
        return 0

    case UINT(WM_VSCROLL):
        if let model = outlineModel(from: hwnd) { outlineHandleVScroll(model, wParam: wParam) }
        return 0

    case UINT(WM_MOUSEWHEEL):
        let delta = Int16(bitPattern: UInt16(win32_HIWORD(DWORD_PTR(wParam))))
        let action: WPARAM = delta > 0 ? WPARAM(SB_LINEUP) : WPARAM(SB_LINEDOWN)
        let steps = max(1, abs(Int32(delta)) / 120)
        for _ in 0 ..< steps { SendMessageW(hwnd, UINT(WM_VSCROLL), action, 0) }
        return 0

    case outlineToggleMessage:
        // Deferred expand/collapse from an arrow click (see
        // outlineArrowClickProc). Runs here, out of the arrow's own wndproc,
        // so relayout can safely destroy that arrow.
        if let model = outlineModel(from: hwnd), let key = model.pendingToggleKey {
            model.pendingToggleKey = nil
            model.toggle(key)
            outlineRelayout(model)
        }
        return 0

    case UINT(WM_COMMAND):
        // Forward any control notifications (e.g. from an expanded row's
        // own interactive widgets) to the root's dispatchCommand.
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            SendMessageW(childHwnd, uMsg, wParam, lParam)
        }
        return SendMessageW(findRootWindow(from: hwnd!), uMsg, wParam, lParam)

    case UINT(WM_ERASEBKGND):
        return eraseWithInheritedBackground(hwnd: hwnd!, wParam: wParam)

    case UINT(WM_CTLCOLORSTATIC), UINT(WM_CTLCOLORBTN):
        if let parent = GetParent(hwnd!) { return SendMessageW(parent, uMsg, wParam, lParam) }
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetBkMode(hdc, TRANSPARENT)
        return LRESULT(Int(bitPattern: GetSysColorBrush(COLOR_WINDOW)))

    case UINT(WM_NCDESTROY):
        let ud = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if ud != 0 {
            Unmanaged<Win32OutlineModel>
                .fromOpaque(UnsafeMutableRawPointer(bitPattern: Int(ud))!)
                .release()
            win32_SetWindowLongPtrW(hwnd!, GWLP_USERDATA, 0)
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

    default:
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
}

private let outlineContentProc: WNDPROC = { (hwnd, uMsg, wParam, lParam) in
    switch uMsg {
    case UINT(WM_COMMAND):
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            SendMessageW(childHwnd, uMsg, wParam, lParam)
        }
        return SendMessageW(findRootWindow(from: hwnd!), uMsg, wParam, lParam)

    case UINT(WM_ERASEBKGND):
        return eraseWithInheritedBackground(hwnd: hwnd!, wParam: wParam)

    case UINT(WM_CTLCOLORSTATIC), UINT(WM_CTLCOLORBTN):
        if let parent = GetParent(hwnd!) { return SendMessageW(parent, uMsg, wParam, lParam) }
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetBkMode(hdc, TRANSPARENT)
        return LRESULT(Int(bitPattern: GetSysColorBrush(COLOR_WINDOW)))

    default:
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
}

// MARK: - Builder

private func winMakeOutlineTree(_ model: Win32OutlineModel, in context: RenderContext) -> HWND? {
    registerOutlineClassesIfNeeded(hInstance: context.hInstance)

    guard let container = CreateWindowExW(
        0, outlineContainerClassName, nil,
        DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN | WS_VSCROLL),
        0, 0, 0, 0,
        context.parent, nil, context.hInstance, nil
    ) else { return nil }

    guard let content = CreateWindowExW(
        0, outlineContentClassName, nil,
        DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
        0, 0, 0, 0,
        container, nil, context.hInstance, nil
    ) else { DestroyWindow(container); return nil } // don't return a half-built container

    model.container = container
    model.content = content
    model.hInstance = context.hInstance
    model.capturedEnv = getCurrentEnvironment()

    let ptr = Unmanaged.passRetained(model).toOpaque()
    win32_SetWindowLongPtrW(container, GWLP_USERDATA, LONG_PTR(Int(bitPattern: ptr)))

    // Fill the space between header and status bar (the List's slot).
    markExpandWidth(container)
    markExpandHeight(container)

    outlineRelayout(model)
    return container
}

// MARK: - OutlineGroup conformances

extension OutlineGroup: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        let model = Win32OutlineModel(
            items: items,
            childrenKeyPath: childrenKeyPath,
            rowContent: rowContent
        )
        return winMakeOutlineTree(model, in: context)
    }
}

extension OutlineGroup: WinSelfScrollingContent {
    func winSelfScrollingWidget(in context: RenderContext) -> HWND? {
        winCreateWidget(in: context)
    }
}
