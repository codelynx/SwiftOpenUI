import WinSDK
import CWin32
import CWin32Bridge
import SwiftOpenUI
import SwiftOpenUISymbols
import Foundation
#if canImport(Observation)
import Observation
#endif

/// Register the bundled Material Symbols Rounded font with GDI for this
/// process only. Called once during `Win32Backend.run()` so subsequent
/// HFONT creations (`CreateFontW` with `"Material Symbols Rounded"`)
/// find the font family. Process-private registration via
/// `AddFontResourceExW(FR_PRIVATE)` — no system font changes, no admin
/// rights needed, and the registration dies with the process.
///
/// Idempotent: calling again just re-adds the same file, which is a no-op
/// for a font already private-registered to this process.
private var materialSymbolsFontRegistered = false
private func win32RegisterBundledIconFont() {
    guard !materialSymbolsFontRegistered else { return }
    let url = MaterialSymbolsResources.roundedRegularFontURL
    let added = url.path.withCString(encodedAs: UTF16.self) { wstr -> Int32 in
        AddFontResourceExW(wstr, DWORD(FR_PRIVATE), nil)
    }
    if added == 0 {
        // Non-fatal: Material Symbols glyphs will render as missing-font
        // boxes. Flag it so a developer notices.
        debugPrint("SwiftOpenUI: AddFontResourceExW failed for \(url.path)")
    }
    materialSymbolsFontRegistered = true
}

private final class MainWindowState {
    let contentHwnd: HWND
    let style: DWORD
    let minClientWidth: Int32?
    let minClientHeight: Int32?
    let maxClientWidth: Int32?
    let maxClientHeight: Int32?
    /// Whether the root content wants to expand on each axis.
    /// When false, the content is centered at its natural size (SwiftUI behavior).
    let expandsWidth: Bool
    let expandsHeight: Bool
    /// Natural (intrinsic) size of the root content, used for centering.
    let naturalContentW: Int32
    let naturalContentH: Int32

    init(
        contentHwnd: HWND,
        style: DWORD,
        minClientWidth: Int32?,
        minClientHeight: Int32?,
        maxClientWidth: Int32?,
        maxClientHeight: Int32?,
        expandsWidth: Bool = true,
        expandsHeight: Bool = true,
        naturalContentW: Int32 = 0,
        naturalContentH: Int32 = 0
    ) {
        self.contentHwnd = contentHwnd
        self.style = style
        self.minClientWidth = minClientWidth
        self.minClientHeight = minClientHeight
        self.expandsWidth = expandsWidth
        self.expandsHeight = expandsHeight
        self.naturalContentW = naturalContentW
        self.naturalContentH = naturalContentH
        self.maxClientWidth = maxClientWidth
        self.maxClientHeight = maxClientHeight
    }
}

private func adjustedWindowSize(clientWidth: Int32, clientHeight: Int32, style: DWORD) -> (Int32, Int32) {
    var rect = RECT(left: 0, top: 0, right: LONG(clientWidth), bottom: LONG(clientHeight))
    AdjustWindowRectEx(&rect, style, false, 0)
    return (rect.right - rect.left, rect.bottom - rect.top)
}

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

        var style = DWORD(WS_OVERLAPPEDWINDOW)
        switch windowResizeBehavior ?? .automatic {
        case .automatic:
            if case .contentFixed = windowSizing {
                style &= ~DWORD(WS_THICKFRAME | WS_MAXIMIZEBOX)
            }
        case .fixed:
            style &= ~DWORD(WS_THICKFRAME | WS_MAXIMIZEBOX)
        case .resizable:
            break
        }

        // SwiftUI-compatible .windowResizability() — takes precedence
        // over windowResizeBehavior when set.
        // Only remove WS_THICKFRAME (drag-to-resize); keep WS_MAXIMIZEBOX
        // to match GTK4 behavior where gtk_window_set_resizable(0) still
        // allows maximize via the window manager.
        switch windowResizability {
        case .contentSize:
            style &= ~DWORD(WS_THICKFRAME)
        case .contentMinSize, .automatic:
            break
        case nil:
            break
        }

        // Create with default size initially; we'll resize after rendering content
        let titleWide: [WCHAR] = Array(title.utf16) + [0]
        let hwnd = titleWide.withUnsafeBufferPointer { titlePtr in
            className.withUnsafeBufferPointer { classPtr in
                CreateWindowExW(
                    0,
                    classPtr.baseAddress!,
                    titlePtr.baseAddress!,
                    style,
                    Int32(CW_USEDEFAULT), Int32(CW_USEDEFAULT),
                    500, 600,
                    nil,
                    nil,
                    hInstance,
                    nil
                )
            }
        }!

        // Set window ID in environment for keyboard shortcut scoping
        var env = getCurrentEnvironment()
        env.windowID = Int(bitPattern: hwnd)
        setCurrentEnvironment(env)

        // Render the content view tree into the window
        let context = RenderContext(parent: hwnd, hInstance: hInstance)
        if let contentHwnd = winRenderView(content, in: context) {
            let contentRect: RECT = {
                var rect = RECT()
                GetWindowRect(contentHwnd, &rect)
                return rect
            }()
            let naturalContentW = contentRect.right - contentRect.left
            let naturalContentH = contentRect.bottom - contentRect.top

            let desiredClientSize: (Int32, Int32) = {
                switch windowSizing ?? .automatic {
                case .automatic, .content, .contentFixed:
                    return (naturalContentW + 20, naturalContentH + 20)
                case .size(let width, let height):
                    return (Int32(width), Int32(height))
                }
            }()

            let screenW = GetSystemMetrics(SM_CXSCREEN)
            let screenH = GetSystemMetrics(SM_CYSCREEN)
            // When explicit sizing is provided (defaultWindowSize or windowSizing(.size)),
            // don't enforce 300x200 minimum — the developer chose the size.
            let hasExplicitSize = defaultWindowWidth != nil || defaultWindowHeight != nil || {
                if case .size = windowSizing ?? .automatic { return true }
                if case .contentFixed = windowSizing ?? .automatic { return true }
                return false
            }()
            let minClientW = minWindowWidth.map { Int32($0) } ?? (hasExplicitSize ? 1 : 300)
            let minClientH = minWindowHeight.map { Int32($0) } ?? (hasExplicitSize ? 1 : 200)
            let maxClientW = maxWindowWidth.map { Int32($0) } ?? (screenW * 3 / 4)
            let maxClientH = maxWindowHeight.map { Int32($0) } ?? (screenH * 3 / 4)

            let defaultClientW = defaultWindowWidth.map { Int32($0) }
            let defaultClientH = defaultWindowHeight.map { Int32($0) }
            let automaticDefaultClientSize: (Int32?, Int32?) = {
                if case .automatic = windowSizing ?? .automatic {
                    return (Int32(defaultAutomaticWindowWidth), Int32(defaultAutomaticWindowHeight))
                }
                return (nil, nil)
            }()
            let unclampedW = defaultClientW ?? automaticDefaultClientSize.0 ?? desiredClientSize.0
            let unclampedH = defaultClientH ?? automaticDefaultClientSize.1 ?? desiredClientSize.1
            let clientW = max(minClientW, min(unclampedW, maxClientW))
            let clientH = max(minClientH, min(unclampedH, maxClientH))

            let windowSize = adjustedWindowSize(clientWidth: clientW, clientHeight: clientH, style: style)
            SetWindowPos(hwnd, nil,
                         Int32(CW_USEDEFAULT), Int32(CW_USEDEFAULT),
                         windowSize.0,
                         windowSize.1,
                         UINT(SWP_NOMOVE | SWP_NOZORDER))

            // SwiftUI's WindowGroup centers intrinsically-sized root content
            // (e.g. a plain Text) and stretches fill-semantic roots (e.g. a
            // VStack with Spacer). Mirror that by checking expand flags.
            let wantsFillW = shouldExpandWidth(contentHwnd)
            let wantsFillH = shouldExpandHeight(contentHwnd)
            var actualClientRect = RECT()
            GetClientRect(hwnd, &actualClientRect)
            let actualW = Int32(actualClientRect.right - actualClientRect.left)
            let actualH = Int32(actualClientRect.bottom - actualClientRect.top)
            let contentW: Int32 = wantsFillW ? actualW : min(naturalContentW, actualW)
            let contentH: Int32 = wantsFillH ? actualH : min(naturalContentH, actualH)
            let contentX: Int32 = wantsFillW ? 0 : (actualW - contentW) / 2
            let contentY: Int32 = wantsFillH ? 0 : (actualH - contentH) / 2
            SetWindowPos(
                contentHwnd, nil,
                contentX, contentY,
                contentW, contentH,
                UINT(SWP_NOZORDER)
            )
            let state = MainWindowState(
                contentHwnd: contentHwnd,
                style: style,
                minClientWidth: minWindowWidth.map { Int32($0) },
                minClientHeight: minWindowHeight.map { Int32($0) },
                maxClientWidth: maxWindowWidth.map { Int32($0) },
                maxClientHeight: maxWindowHeight.map { Int32($0) },
                expandsWidth: wantsFillW,
                expandsHeight: wantsFillH,
                naturalContentW: naturalContentW,
                naturalContentH: naturalContentH
            )
            let retained = Unmanaged.passRetained(state).toOpaque()
            win32_SetWindowLongPtrW(hwnd, GWLP_USERDATA, LONG_PTR(Int(bitPattern: retained)))
        }

        // Set up menu bar from Commands if declared
        if let commandsFactory = globalCommandsFactory {
            let windowID = Int(bitPattern: hwnd)
            let host = Win32MenuBarHost(hwnd: hwnd, factory: commandsFactory, windowID: windowID)
            host.setup()

            // Store the host on the window so it stays alive and can be cleaned up
            let retained = Unmanaged.passRetained(host).toOpaque()
            _ = menuBarHostPropName.withUnsafeBufferPointer { ptr in
                SetPropW(hwnd, ptr.baseAddress!, HANDLE(retained))
            }
        }

        Win32WindowRegistry.shared.hasMainWindow = true
        ShowWindow(hwnd, SW_SHOWDEFAULT)
        UpdateWindow(hwnd)
    }
}

/// WndProc for the main application window.
private let mainWindowProc: WNDPROC = { (hwnd, uMsg, wParam, lParam) in
    switch uMsg {
    case UINT(WM_SIZE):
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0 {
            let state = Unmanaged<MainWindowState>.fromOpaque(UnsafeMutableRawPointer(bitPattern: Int(userData))!).takeUnretainedValue()
            var clientRect = RECT()
            GetClientRect(hwnd, &clientRect)
            let clientW = clientRect.right - clientRect.left
            let clientH = clientRect.bottom - clientRect.top

            // Center intrinsic content; fill expanding content.
            let cw = state.expandsWidth ? clientW : min(state.naturalContentW, clientW)
            let ch = state.expandsHeight ? clientH : min(state.naturalContentH, clientH)
            let cx = state.expandsWidth ? Int32(0) : (clientW - cw) / 2
            let cy = state.expandsHeight ? Int32(0) : (clientH - ch) / 2
            SetWindowPos(state.contentHwnd, nil, cx, cy, cw, ch, UINT(SWP_NOZORDER))
        }
        return 0

    case UINT(WM_GETMINMAXINFO):
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0, let info = UnsafeMutablePointer<MINMAXINFO>(bitPattern: Int(lParam)) {
            let state = Unmanaged<MainWindowState>.fromOpaque(UnsafeMutableRawPointer(bitPattern: Int(userData))!).takeUnretainedValue()
            if let minW = state.minClientWidth, let minH = state.minClientHeight {
                let adjusted = adjustedWindowSize(clientWidth: minW, clientHeight: minH, style: state.style)
                info.pointee.ptMinTrackSize.x = LONG(adjusted.0)
                info.pointee.ptMinTrackSize.y = LONG(adjusted.1)
            }
            if let maxW = state.maxClientWidth, let maxH = state.maxClientHeight {
                let adjusted = adjustedWindowSize(clientWidth: maxW, clientHeight: maxH, style: state.style)
                info.pointee.ptMaxTrackSize.x = LONG(adjusted.0)
                info.pointee.ptMaxTrackSize.y = LONG(adjusted.1)
            }
            return 0
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

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
        // Clean up menu bar host if present
        menuBarHostPropName.withUnsafeBufferPointer { ptr in
            if let hostPtr = GetPropW(hwnd!, ptr.baseAddress!) {
                let host = Unmanaged<Win32MenuBarHost>.fromOpaque(UnsafeMutableRawPointer(hostPtr)).takeRetainedValue()
                host.destroy()
                RemovePropW(hwnd!, ptr.baseAddress!)
            }
        }
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0 {
            _ = Unmanaged<MainWindowState>.fromOpaque(UnsafeMutableRawPointer(bitPattern: Int(userData))!).takeRetainedValue()
            win32_SetWindowLongPtrW(hwnd!, GWLP_USERDATA, 0)
        }
        Win32WindowRegistry.shared.hasMainWindow = false
        PostQuitMessage(0)
        return 0

    case UINT(WM_ACTIVATE):
        let activateState = Int32(win32_LOWORD(DWORD_PTR(wParam)))
        if activateState != 0 {  // WA_ACTIVE=1 or WA_CLICKACTIVE=2
            FocusedValuesStore.shared.setActiveWindow(Int(bitPattern: hwnd!))
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

    case UINT(WM_KEYDOWN), UINT(WM_SYSKEYDOWN):
        if win32DispatchKeyboardShortcut(wParam: wParam, hwnd: hwnd!) {
            return 0
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

    default:
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
}

/// Checks if the current key press matches a registered keyboard shortcut.
/// Walks up from the message HWND to find the top-level window for scoping.
func win32DispatchKeyboardShortcut(wParam: WPARAM, hwnd: HWND) -> Bool {
    guard let key = win32KeyEquivalentFromVK(DWORD(wParam)) else { return false }

    var modifiers: EventModifiers = []
    if GetKeyState(Int32(VK_CONTROL)) < 0 { modifiers.insert(.command) }
    if GetKeyState(Int32(VK_SHIFT)) < 0 { modifiers.insert(.shift) }
    if GetKeyState(Int32(VK_MENU)) < 0 { modifiers.insert(.option) }

    // Resolve top-level window for scoping
    var topHwnd = hwnd
    while let parent = GetParent(topHwnd) {
        topHwnd = parent
    }
    let windowID = Int(bitPattern: topHwnd)

    let shortcut = KeyboardShortcut(key, modifiers: modifiers)
    return KeyboardShortcutRegistry.shared.dispatch(shortcut, windowID: windowID)
}

/// Maps a Win32 virtual key code to a KeyEquivalent.
private func win32KeyEquivalentFromVK(_ vk: DWORD) -> KeyEquivalent? {
    switch Int32(vk) {
    case VK_RETURN:  return .return
    case VK_ESCAPE:  return .escape
    case VK_DELETE:  return .delete
    case VK_BACK:    return .delete
    case VK_TAB:     return .tab
    case VK_UP:      return .upArrow
    case VK_DOWN:    return .downArrow
    case VK_LEFT:    return .leftArrow
    case VK_RIGHT:   return .rightArrow
    case VK_SPACE:   return .space
    default:
        // A-Z: VK_A (0x41) through VK_Z (0x5A) → lowercase
        if vk >= 0x41 && vk <= 0x5A {
            return KeyEquivalent(Character(Unicode.Scalar(vk - 0x41 + 0x61)!))
        }
        // 0-9
        if vk >= 0x30 && vk <= 0x39 {
            return KeyEquivalent(Character(Unicode.Scalar(vk)!))
        }
        return nil
    }
}

// MARK: - Win32 menu bar host

/// Property name for storing the menu bar host on a window.
private let menuBarHostPropName: [WCHAR] = Array("SwiftOpenUI-MenuBarHost".utf16) + [0]

/// Manages a native HMENU menu bar on a Win32 window.
/// Handles command dispatch, keyboard shortcut registration,
/// and observation-based re-evaluation of Commands.
final class Win32MenuBarHost {
    let hwnd: HWND
    let factory: AnyCommandsFactory
    let windowID: Int
    private var hMenu: HMENU?
    private var renderedCommands: [RenderedMenuCommand] = []
    private var focusedValuesObserverID: FocusedValuesObserverID?

    struct RenderedMenuCommand {
        let controlID: WORD
        let label: String
        var isDisabled: Bool
        var action: () -> Void
        var shortcutRegID: ShortcutRegistrationID?
    }

    init(hwnd: HWND, factory: @escaping AnyCommandsFactory, windowID: Int) {
        self.hwnd = hwnd
        self.factory = factory
        self.windowID = windowID
    }

    /// Build the initial menu bar and start observation.
    func setup() {
        // Register for focused-value changes (per-window + global)
        focusedValuesObserverID = FocusedValuesStore.shared.addObserver(windowID: nil) { [weak self] in
            guard let self else { return }
            runOnMainThread(hwnd: self.hwnd) { [weak self] in
                self?.evaluateWithTracking()
            }
        }
        evaluateWithTracking()
    }

    /// Evaluate Commands with observation tracking and re-arm on change.
    func evaluateWithTracking() {
        #if canImport(Observation)
        if #available(macOS 14.0, iOS 17.0, *) {
            withObservationTracking {
                let groups = self.factory()
                self.updateMenu(groups)
            } onChange: { [weak self] in
                guard let self else { return }
                // Re-arm: schedule another tracked evaluation
                runOnMainThread(hwnd: self.hwnd) { [weak self] in
                    self?.evaluateWithTracking()
                }
            }
            return
        }
        #endif
        // Fallback without observation
        let groups = factory()
        updateMenu(groups)
    }

    /// Update the native menu bar from evaluated command groups.
    private func updateMenu(_ groups: [CommandGroupPlacement: [CommandMenuItem]]) {
        // Flatten all items (for now, single "File" menu containing all items)
        let allItems = groups.sorted(by: { $0.key.hashValue < $1.key.hashValue })
            .flatMap { $0.value }

        if hMenu == nil {
            // First build — create the menu bar
            buildMenu(allItems)
        } else {
            // Incremental update — check for structural changes
            if allItems.count == renderedCommands.count &&
               zip(allItems, renderedCommands).allSatisfy({ $0.label == $1.label }) {
                // Same structure — update in place
                updateInPlace(allItems)
            } else {
                // Structure changed — full rebuild
                teardownShortcuts()
                if let oldMenu = hMenu {
                    DestroyMenu(oldMenu)
                }
                renderedCommands.removeAll()
                buildMenu(allItems)
            }
        }
    }

    /// Build the HMENU from scratch.
    private func buildMenu(_ items: [CommandMenuItem]) {
        let menuBar = CreateMenu()!
        let fileMenu = CreatePopupMenu()!

        for item in items {
            let controlID = nextControlID()
            var labelText = item.label

            // Append shortcut text to label
            if let shortcut = item.shortcut {
                labelText += "\t" + shortcutDisplayText(shortcut)
            }

            let flags: UINT = item.isDisabled
                ? UINT(MF_STRING | MF_GRAYED)
                : UINT(MF_STRING)
            let labelWide: [WCHAR] = Array(labelText.utf16) + [0]
            _ = labelWide.withUnsafeBufferPointer { ptr in
                AppendMenuW(fileMenu, flags, UINT_PTR(controlID), ptr.baseAddress!)
            }

            // Register command handler
            let action = item.action
            registerCommandHandler(controlID: controlID, action: action)

            // Register keyboard shortcut
            var shortcutRegID: ShortcutRegistrationID?
            if let shortcut = item.shortcut, !item.isDisabled {
                shortcutRegID = KeyboardShortcutRegistry.shared.register(
                    shortcut, windowID: windowID, action: action
                )
            }

            renderedCommands.append(RenderedMenuCommand(
                controlID: controlID,
                label: item.label,
                isDisabled: item.isDisabled,
                action: action,
                shortcutRegID: shortcutRegID
            ))
        }

        let fileLabel: [WCHAR] = Array("File".utf16) + [0]
        _ = fileLabel.withUnsafeBufferPointer { ptr in
            AppendMenuW(menuBar, UINT(MF_POPUP), UINT_PTR(Int(bitPattern: fileMenu)), ptr.baseAddress!)
        }

        hMenu = menuBar
        SetMenu(hwnd, menuBar)
        DrawMenuBar(hwnd)
    }

    /// Update enabled/disabled state and actions in place.
    private func updateInPlace(_ items: [CommandMenuItem]) {
        guard let menuBar = hMenu else { return }

        for (i, item) in items.enumerated() {
            var cmd = renderedCommands[i]
            let stateChanged = cmd.isDisabled != item.isDisabled

            // Always update the action closure
            let action = item.action
            registerCommandHandler(controlID: cmd.controlID, action: action)
            cmd.action = action

            if stateChanged {
                cmd.isDisabled = item.isDisabled
                // Update native menu item
                let enableFlag: UINT = item.isDisabled
                    ? UINT(MF_GRAYED | MF_BYCOMMAND)
                    : UINT(MF_ENABLED | MF_BYCOMMAND)
                EnableMenuItem(menuBar, UINT(cmd.controlID), enableFlag)

                // Update shortcut registration
                if let oldRegID = cmd.shortcutRegID {
                    KeyboardShortcutRegistry.shared.unregister(id: oldRegID)
                    cmd.shortcutRegID = nil
                }
                if let shortcut = item.shortcut, !item.isDisabled {
                    cmd.shortcutRegID = KeyboardShortcutRegistry.shared.register(
                        shortcut, windowID: windowID, action: action
                    )
                }
            } else if let shortcut = item.shortcut, !item.isDisabled {
                // Action may have changed — re-register shortcut with new closure
                if let oldRegID = cmd.shortcutRegID {
                    KeyboardShortcutRegistry.shared.unregister(id: oldRegID)
                }
                cmd.shortcutRegID = KeyboardShortcutRegistry.shared.register(
                    shortcut, windowID: windowID, action: action
                )
            }

            renderedCommands[i] = cmd
        }
        DrawMenuBar(hwnd)
    }

    /// Unregister all shortcuts owned by this menu.
    private func teardownShortcuts() {
        for cmd in renderedCommands {
            if let regID = cmd.shortcutRegID {
                KeyboardShortcutRegistry.shared.unregister(id: regID)
            }
            unregisterCommandHandler(controlID: cmd.controlID)
        }
    }

    /// Full cleanup on window destruction.
    func destroy() {
        teardownShortcuts()
        if let observerID = focusedValuesObserverID {
            FocusedValuesStore.shared.removeObserver(id: observerID)
        }
        if let menu = hMenu {
            SetMenu(hwnd, nil)
            DestroyMenu(menu)
        }
        renderedCommands.removeAll()
    }

    /// Format a shortcut for display in a menu item label.
    private func shortcutDisplayText(_ shortcut: KeyboardShortcut) -> String {
        var parts: [String] = []
        if shortcut.modifiers.contains(.command) { parts.append("Ctrl") }
        if shortcut.modifiers.contains(.shift) { parts.append("Shift") }
        if shortcut.modifiers.contains(.option) { parts.append("Alt") }

        let keyText: String
        switch shortcut.key {
        case .return: keyText = "Enter"
        case .escape: keyText = "Esc"
        case .delete: keyText = "Del"
        case .tab: keyText = "Tab"
        case .space: keyText = "Space"
        case .upArrow: keyText = "Up"
        case .downArrow: keyText = "Down"
        case .leftArrow: keyText = "Left"
        case .rightArrow: keyText = "Right"
        default: keyText = String(shortcut.key.character).uppercased()
        }
        parts.append(keyText)
        return parts.joined(separator: "+")
    }
}

/// Win32 rendering backend for SwiftOpenUI.
public struct Win32Backend: RenderBackend {
    public init() {}

    public func run<A: App>(_ appType: A.Type) {
        let hInstance = GetModuleHandleW(nil)!

        // Enable per-monitor DPI awareness
        win32_SetProcessDpiAwarenessContextPerMonitorV2()

        // Runtime workaround: enable ComCtl32 v6 visual styles via activation context.
        // Required for EM_SETCUEBANNER (TextField placeholder text).
        // Uses undocumented shell32.dll resource 124 — see shim.h for details.
        if !win32_EnableVisualStyles() {
            // Non-fatal: controls render in classic style, placeholders won't show.
            debugPrint("SwiftOpenUI: ComCtl32 v6 visual styles activation failed")
        }

        // Initialize common controls (for modern visual styles)
        win32_InitCommonControlsEx(DWORD(ICC_STANDARD_CLASSES | ICC_WIN95_CLASSES))

        // Register the bundled Material Symbols Rounded font privately
        // with GDI so Image(material:) / Image(systemName:) can render
        // icon glyphs via CreateFontW("Material Symbols Rounded").
        win32RegisterBundledIconFont()

        // Inject openWindow action into the environment so views
        // can programmatically open Window scenes by id.
        var env = getCurrentEnvironment()
        env.openWindow = OpenWindowAction { id in
            Win32WindowRegistry.shared.open(id: id, hInstance: hInstance)
        }
        setCurrentEnvironment(env)

        let instance = A()
        let scene = instance.body
        win32RenderScene(scene, hInstance: hInstance)

        // Hybrid Win32 + Foundation run loop.
        // Swift/Foundation timers (e.g. Timer.scheduledTimer) need the main
        // RunLoop to spin, while Win32 UI needs its message queue dispatched.
        var msg = MSG()
        while true {
            while PeekMessageW(&msg, nil, 0, 0, UINT(PM_REMOVE)) {
                if msg.message == UINT(WM_QUIT) {
                    return
                }
                // Intercept keyboard shortcuts at the message pump level
                // so they fire regardless of which control has focus.
                if msg.message == UINT(WM_KEYDOWN) || msg.message == UINT(WM_SYSKEYDOWN) {
                    if win32DispatchKeyboardShortcut(wParam: msg.wParam, hwnd: msg.hwnd!) {
                        continue // swallow the message
                    }
                }
                TranslateMessage(&msg)
                DispatchMessageW(&msg)
            }

            // Pump Foundation sources (Timer, etc.) on the main RunLoop.
            // Use RunLoop.main explicitly and pump both .default and .common modes
            // so Timer.scheduledTimer callbacks fire reliably on Windows.
            let limit = Date(timeIntervalSinceNow: 0.005)
            _ = RunLoop.main.run(mode: .default, before: limit)
            _ = RunLoop.main.run(mode: .common, before: limit)
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

// MARK: - Window scene (single-instance, identified windows)

extension Window: Win32WindowRenderable {
    func win32Render(hInstance: HINSTANCE) {
        // Register a factory so openWindow(id:) can create or refocus later.
        Win32WindowRegistry.shared.register(id: id) { [self] in
            self.win32CreateWindow(hInstance: hInstance)
        }

        if launchBehavior != .suppressed {
            Win32WindowRegistry.shared.open(id: id, hInstance: hInstance)
        }
    }

    func win32CreateWindow(hInstance: HINSTANCE) {
        // Use a per-id window class name to avoid collisions with the main window.
        let className = "SwiftOpenUIWindow_\(id)"
        let classNameWide: [WCHAR] = Array(className.utf16) + [0]

        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.style = UINT(CS_HREDRAW | CS_VREDRAW)
        wc.lpfnWndProc = windowSceneWndProc
        wc.hInstance = hInstance
        wc.hCursor = LoadCursorW(nil, win32_IDC_ARROW())
        wc.hbrBackground = GetSysColorBrush(COLOR_WINDOW)
        classNameWide.withUnsafeBufferPointer { ptr in
            wc.lpszClassName = ptr.baseAddress!
            RegisterClassExW(&wc)
        }

        let style = DWORD(WS_OVERLAPPEDWINDOW)
        let clientW = defaultWindowWidth.map { Int32($0) } ?? 400
        let clientH = defaultWindowHeight.map { Int32($0) } ?? 300
        let windowSize = adjustedWindowSize(
            clientWidth: clientW, clientHeight: clientH, style: style)

        let titleWide: [WCHAR] = Array(title.utf16) + [0]
        let hwnd = titleWide.withUnsafeBufferPointer { titlePtr in
            classNameWide.withUnsafeBufferPointer { classPtr in
                CreateWindowExW(
                    0,
                    classPtr.baseAddress!,
                    titlePtr.baseAddress!,
                    style,
                    Int32(CW_USEDEFAULT), Int32(CW_USEDEFAULT),
                    windowSize.0, windowSize.1,
                    nil, nil, hInstance, nil
                )
            }
        }!

        // Set window ID in environment for keyboard shortcut scoping
        var sceneEnv = getCurrentEnvironment()
        sceneEnv.windowID = Int(bitPattern: hwnd)
        setCurrentEnvironment(sceneEnv)

        // Render the content view tree
        let context = RenderContext(parent: hwnd, hInstance: hInstance)
        if let contentHwnd = winRenderView(content, in: context) {
            var clientRect = RECT()
            GetClientRect(hwnd, &clientRect)
            SetWindowPos(
                contentHwnd, nil,
                0, 0,
                clientRect.right - clientRect.left,
                clientRect.bottom - clientRect.top,
                UINT(SWP_NOZORDER)
            )

            let state = MainWindowState(
                contentHwnd: contentHwnd,
                style: style,
                minClientWidth: minWindowWidth.map { Int32($0) },
                minClientHeight: minWindowHeight.map { Int32($0) },
                maxClientWidth: nil,
                maxClientHeight: nil
            )
            let retained = Unmanaged.passRetained(state).toOpaque()
            win32_SetWindowLongPtrW(hwnd, GWLP_USERDATA, LONG_PTR(Int(bitPattern: retained)))
        }

        // Set up menu bar from Commands if declared (shared app-wide)
        if let commandsFactory = globalCommandsFactory {
            let winID = Int(bitPattern: hwnd)
            let host = Win32MenuBarHost(hwnd: hwnd, factory: commandsFactory, windowID: winID)
            host.setup()
            let retained = Unmanaged.passRetained(host).toOpaque()
            _ = menuBarHostPropName.withUnsafeBufferPointer { ptr in
                SetPropW(hwnd, ptr.baseAddress!, HANDLE(retained))
            }
        }

        // Store the window id in a property so WM_DESTROY can clear it
        let windowId = id
        Win32WindowRegistry.shared.setLiveWindow(id: windowId, hwnd: hwnd)

        ShowWindow(hwnd, SW_SHOWDEFAULT)
        UpdateWindow(hwnd)
    }
}

/// WndProc for Window scene windows (not the main WindowGroup window).
/// On WM_DESTROY, clears the registry entry but does NOT PostQuitMessage —
/// only the main window's destruction should quit the app.
private let windowSceneWndProc: WNDPROC = { (hwnd, uMsg, wParam, lParam) in
    switch uMsg {
    case UINT(WM_SIZE):
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0 {
            let state = Unmanaged<MainWindowState>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: Int(userData))!
            ).takeUnretainedValue()
            var clientRect = RECT()
            GetClientRect(hwnd, &clientRect)
            SetWindowPos(state.contentHwnd, nil, 0, 0,
                        clientRect.right - clientRect.left,
                        clientRect.bottom - clientRect.top,
                        UINT(SWP_NOZORDER))
        }
        return 0

    case UINT(WM_GETMINMAXINFO):
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0, let info = UnsafeMutablePointer<MINMAXINFO>(bitPattern: Int(lParam)) {
            let state = Unmanaged<MainWindowState>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: Int(userData))!
            ).takeUnretainedValue()
            if let minW = state.minClientWidth, let minH = state.minClientHeight {
                let adjusted = adjustedWindowSize(
                    clientWidth: minW, clientHeight: minH, style: state.style)
                info.pointee.ptMinTrackSize.x = LONG(adjusted.0)
                info.pointee.ptMinTrackSize.y = LONG(adjusted.1)
            }
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

    case UINT(WM_CTLCOLORSTATIC), UINT(WM_CTLCOLORBTN):
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetBkMode(hdc, TRANSPARENT)
        return LRESULT(Int(bitPattern: GetSysColorBrush(COLOR_WINDOW)))

    case UINT(WM_COMMAND):
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
        // Clean up menu bar host if present
        menuBarHostPropName.withUnsafeBufferPointer { ptr in
            if let hostPtr = GetPropW(hwnd!, ptr.baseAddress!) {
                let menuHost = Unmanaged<Win32MenuBarHost>.fromOpaque(UnsafeMutableRawPointer(hostPtr)).takeRetainedValue()
                menuHost.destroy()
                RemovePropW(hwnd!, ptr.baseAddress!)
            }
        }
        // Release MainWindowState
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0 {
            _ = Unmanaged<MainWindowState>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: Int(userData))!
            ).takeRetainedValue()
            win32_SetWindowLongPtrW(hwnd!, GWLP_USERDATA, 0)
        }
        // Clear registry entry for this window
        Win32WindowRegistry.shared.clearLiveWindow(for: hwnd!)
        // If no windows remain (no live Window scenes and no main WindowGroup),
        // quit the application so the process doesn't spin headless.
        if Win32WindowRegistry.shared.hasNoLiveWindows {
            PostQuitMessage(0)
        }
        return 0

    case UINT(WM_ACTIVATE):
        let activateState = Int32(win32_LOWORD(DWORD_PTR(wParam)))
        if activateState != 0 {  // WA_ACTIVE=1 or WA_CLICKACTIVE=2
            FocusedValuesStore.shared.setActiveWindow(Int(bitPattern: hwnd!))
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

    case UINT(WM_KEYDOWN), UINT(WM_SYSKEYDOWN):
        if win32DispatchKeyboardShortcut(wParam: wParam, hwnd: hwnd!) {
            return 0
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

    default:
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
}

// MARK: - TupleScene support

extension TupleScene: Win32WindowRenderable {
    func win32Render(hInstance: HINSTANCE) {
        win32RenderScene(scene0, hInstance: hInstance)
        win32RenderScene(scene1, hInstance: hInstance)
    }
}

// MARK: - Win32 Window Registry

/// Registry for single-instance Window scenes. Tracks factories and live
/// HWND handles to enforce the one-window-per-id contract.
class Win32WindowRegistry {
    static let shared = Win32WindowRegistry()

    private var factories: [String: () -> Void] = [:]
    private var liveWindows: [String: HWND] = [:]

    func register(id: String, factory: @escaping () -> Void) {
        factories[id] = factory
    }

    func setLiveWindow(id: String, hwnd: HWND) {
        liveWindows[id] = hwnd
    }

    func clearLiveWindow(id: String) {
        liveWindows.removeValue(forKey: id)
    }

    /// Clear the live window entry matching the given HWND (called from WM_DESTROY).
    func clearLiveWindow(for hwnd: HWND) {
        for (id, h) in liveWindows where h == hwnd {
            liveWindows.removeValue(forKey: id)
            return
        }
    }

    /// Track whether a WindowGroup main window is alive.
    var hasMainWindow: Bool = false

    /// True when no windows remain at all — no Window scenes and no main
    /// WindowGroup. Used to decide whether closing the last Window should
    /// quit the app.
    var hasNoLiveWindows: Bool {
        liveWindows.isEmpty && !hasMainWindow
    }

    /// Open or refocus the window with the given id.
    func open(id: String, hInstance: HINSTANCE) {
        if let existing = liveWindows[id] {
            // Refocus existing window
            ShowWindow(existing, SW_RESTORE)
            SetForegroundWindow(existing)
            return
        }
        factories[id]?()
    }
}
