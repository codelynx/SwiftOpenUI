import WinSDK
import CWin32
import CWin32Bridge
import SwiftOpenUI

// MARK: - Native Win32 Menu
//
// SwiftUI's `Menu` takes views for its items (`Button`, `Divider`, nested
// `Menu`, `Section`, …), but Win32's native popup menu takes strings. At
// render time the content view tree is walked into a small entry model, the
// label view is rendered as the trigger, and a click anywhere on the trigger
// opens a native `TrackPopupMenu` below it. Choosing an item runs that
// `Button`'s action.
//
// Item labels are text only: an item's title is the first `Text` or `Label`
// title found in its label view. Icons in item labels are dropped.

/// One entry of a Win32 popup menu, flattened from `Menu` content views.
enum WinMenuEntry {
    case item(title: String, isDisabled: Bool, action: () -> Void)
    case divider
    case submenu(title: String, isDisabled: Bool, entries: [WinMenuEntry])
}

// MARK: Content-view walker

/// A `Button` seen as a menu item.
private protocol WinMenuButtonSource {
    var winMenuAction: () -> Void { get }
    var winMenuLabel: any View { get }
}

extension Button: WinMenuButtonSource {
    fileprivate var winMenuAction: () -> Void { action }
    fileprivate var winMenuLabel: any View { label }
}

/// A nested `Menu` seen as a submenu.
private protocol WinMenuSubmenuSource {
    var winMenuContent: any View { get }
    var winMenuLabel: any View { get }
}

extension Menu: WinMenuSubmenuSource {
    fileprivate var winMenuContent: any View { content }
    fileprivate var winMenuLabel: any View { label }
}

private protocol WinMenuDisabledSource {
    var winMenuContent: any View { get }
    var winMenuIsDisabled: Bool { get }
}

extension DisabledView: WinMenuDisabledSource {
    fileprivate var winMenuContent: any View { content }
    fileprivate var winMenuIsDisabled: Bool { isDisabled }
}

private protocol WinMenuSectionSource {
    var winMenuContent: any View { get }
    var winMenuHeader: String? { get }
}

extension Section: WinMenuSectionSource {
    fileprivate var winMenuContent: any View { content }
    fileprivate var winMenuHeader: String? {
        if let headerView, let title = winMenuTitle(of: headerView) { return title }
        return header
    }
}

/// Flattens `Menu` content into popup entries, in the order written.
/// Actions are bound to the current (render-time) environment, since they
/// run later from the click handler.
func winMenuEntries(from content: any View) -> [WinMenuEntry] {
    var entries: [WinMenuEntry] = []
    walkMenuContent(content, isDisabled: false, into: &entries)
    return normalizedDividers(entries)
}

private func walkMenuContent(_ view: any View, isDisabled: Bool, into entries: inout [WinMenuEntry]) {
    if let button = view as? WinMenuButtonSource {
        entries.append(.item(
            title: winMenuTitle(of: button.winMenuLabel) ?? "",
            isDisabled: isDisabled,
            action: bindActionToCurrentEnvironment(button.winMenuAction)
        ))
    } else if view is Divider {
        entries.append(.divider)
    } else if let submenu = view as? WinMenuSubmenuSource {
        var children: [WinMenuEntry] = []
        walkMenuContent(submenu.winMenuContent, isDisabled: isDisabled, into: &children)
        entries.append(.submenu(
            title: winMenuTitle(of: submenu.winMenuLabel) ?? "",
            isDisabled: isDisabled,
            entries: normalizedDividers(children)
        ))
    } else if let disabled = view as? WinMenuDisabledSource {
        walkMenuContent(disabled.winMenuContent,
                        isDisabled: isDisabled || disabled.winMenuIsDisabled, into: &entries)
    } else if let section = view as? WinMenuSectionSource {
        // SwiftUI separates sections with dividers and shows the header as
        // an inert title row.
        entries.append(.divider)
        if let header = section.winMenuHeader {
            entries.append(.item(title: header, isDisabled: true, action: {}))
        }
        walkMenuContent(section.winMenuContent, isDisabled: isDisabled, into: &entries)
        entries.append(.divider)
    } else if let multi = view as? MultiChildView {
        // TupleView, Group, ForEach, if/else branches, Optional.
        for child in multi.children {
            walkMenuContent(child, isDisabled: isDisabled, into: &entries)
        }
    } else if let any = view as? AnyView {
        walkMenuContent(any.wrapped, isDisabled: isDisabled, into: &entries)
    } else if let title = leafTitle(of: view) {
        // A bare Text/Label in a menu is an inert row, as in SwiftUI.
        entries.append(.item(title: title, isDisabled: true, action: {}))
    } else if let wrapped = wrappedContent(of: view) {
        // Other modifiers (.keyboardShortcut, .help, …) wrap the item.
        walkMenuContent(wrapped, isDisabled: isDisabled, into: &entries)
    }
}

/// The text a label view shows: a `Text`, a `Label`'s title, or the first
/// of those found inside stacks and modifier wrappers.
func winMenuTitle(of view: any View) -> String? {
    if let title = leafTitle(of: view) { return title }
    if let multi = view as? MultiChildView {
        for child in multi.children {
            if let title = winMenuTitle(of: child) { return title }
        }
        return nil
    }
    if let any = view as? AnyView { return winMenuTitle(of: any.wrapped) }
    if let wrapped = wrappedContent(of: view) { return winMenuTitle(of: wrapped) }
    return nil
}

private func leafTitle(of view: any View) -> String? {
    if let text = view as? Text { return text.content }
    if let label = view as? Label { return label.title }
    return nil
}

/// A modifier view's wrapped `content`, found by reflection.
private func wrappedContent(of view: any View) -> (any View)? {
    Mirror(reflecting: view).children.first { $0.label == "content" }?.value as? any View
}

/// Drops leading, trailing and repeated dividers (sections produce them
/// back to back).
private func normalizedDividers(_ entries: [WinMenuEntry]) -> [WinMenuEntry] {
    var result: [WinMenuEntry] = []
    for entry in entries {
        if case .divider = entry {
            if result.isEmpty { continue }
            if case .divider = result.last! { continue }
        }
        result.append(entry)
    }
    if let last = result.last, case .divider = last { result.removeLast() }
    return result
}

// MARK: Popup

/// Fills `hmenu` with `entries`; returns the action for each command id.
func winBuildPopupMenu(_ hmenu: HMENU, entries: [WinMenuEntry],
                       nextID: inout UINT, actions: inout [UINT: () -> Void]) {
    for entry in entries {
        switch entry {
        case .item(let title, let isDisabled, let action):
            let id = nextID
            nextID += 1
            actions[id] = action
            let flags = UINT(MF_STRING) | (isDisabled ? UINT(MF_GRAYED) : 0)
            _ = title.withCString(encodedAs: UTF16.self) { AppendMenuW(hmenu, flags, UINT_PTR(id), $0) }
        case .divider:
            AppendMenuW(hmenu, UINT(MF_SEPARATOR), 0, nil)
        case .submenu(let title, let isDisabled, let children):
            guard let sub = CreatePopupMenu() else { continue }
            winBuildPopupMenu(sub, entries: children, nextID: &nextID, actions: &actions)
            let flags = UINT(MF_POPUP) | (isDisabled ? UINT(MF_GRAYED) : 0)
            _ = title.withCString(encodedAs: UTF16.self) {
                AppendMenuW(hmenu, flags, UINT_PTR(Int(bitPattern: sub)), $0)
            }
        }
    }
}

/// Click state shared by every HWND of one trigger.
private final class MenuTriggerHandler {
    let entries: [WinMenuEntry]
    let trigger: HWND
    /// Set on button-down inside the trigger, so a stray button-up (e.g.
    /// the release that dismissed the previous popup) doesn't reopen it.
    var armed = false

    init(entries: [WinMenuEntry], trigger: HWND) {
        self.entries = entries
        self.trigger = trigger
    }

    func showPopup() {
        guard !entries.isEmpty, let hmenu = CreatePopupMenu() else { return }
        defer { DestroyMenu(hmenu) }
        var nextID: UINT = 1
        var actions: [UINT: () -> Void] = [:]
        winBuildPopupMenu(hmenu, entries: entries, nextID: &nextID, actions: &actions)

        // Below the trigger, left-aligned, like SwiftUI's menu button.
        var r = RECT()
        GetWindowRect(trigger, &r)
        let chosen = win32_TrackPopupMenuReturnCmd(
            hmenu, UINT(TPM_LEFTALIGN | TPM_TOPALIGN | TPM_NONOTIFY),
            r.left, r.bottom, trigger
        )
        // TPM_RETURNCMD: the action runs here rather than via WM_COMMAND,
        // after the menu has closed.
        if chosen > 0 { actions[UINT(chosen)]?() }
    }
}

private let menuTriggerSubclassID: UINT_PTR = 80

private let menuTriggerProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    guard dwRefData != 0 else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }
    let handler = Unmanaged<MenuTriggerHandler>
        .fromOpaque(UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!)
        .takeUnretainedValue()

    switch uMsg {
    case UINT(WM_LBUTTONDOWN), UINT(WM_LBUTTONDBLCLK):
        handler.armed = true
        return 0
    case UINT(WM_LBUTTONUP):
        guard handler.armed else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }
        handler.armed = false
        handler.showPopup()
        return 0
    case UINT(WM_NCHITTEST):
        // Static text answers HTTRANSPARENT, which would send the click to
        // whatever is behind the trigger; claim it instead.
        return LRESULT(HTCLIENT)
    case UINT(WM_NCDESTROY):
        Unmanaged<MenuTriggerHandler>
            .fromOpaque(UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!)
            .release()
        RemoveWindowSubclass(hwnd, menuTriggerProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

/// Subclasses `hwnd` and every descendant, so a click anywhere on the
/// label opens the menu. Each HWND holds its own retain on the handler.
private func installMenuTrigger(on hwnd: HWND, handler: MenuTriggerHandler) {
    let ptr = Unmanaged.passRetained(handler).toOpaque()
    SetWindowSubclass(hwnd, menuTriggerProc, menuTriggerSubclassID, DWORD_PTR(UInt(bitPattern: ptr)))
    var child = GetWindow(hwnd, UINT(GW_CHILD))
    while let c = child {
        installMenuTrigger(on: c, handler: handler)
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
}

extension Menu: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let trigger = winRenderView(label, in: context) else { return nil }
        let handler = MenuTriggerHandler(entries: winMenuEntries(from: content), trigger: trigger)
        installMenuTrigger(on: trigger, handler: handler)
        return trigger
    }
}
