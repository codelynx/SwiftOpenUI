import CGTK
import CGTKBridge
import SwiftOpenUI
import SwiftOpenUISymbols
import Foundation
#if canImport(Observation)
import Observation
#endif

/// Register bundled Material Symbols font with FontConfig for this process
/// only, so Pango / GtkLabel can resolve "Material Symbols Rounded" as a
/// font family. The font file is shipped inside SwiftOpenUISymbols' resource
/// bundle; this call makes it visible to FontConfig without installing it
/// to the user's system font directory. Idempotent — calling it more than
/// once just re-adds the same file.
private func gtkRegisterBundledIconFont() {
    let url = MaterialSymbolsResources.roundedRegularFontURL
    let result = url.path.withCString { gtk_swift_fc_app_font_add_file($0) }
    if result == 0 {
        // Non-fatal: icons will render as empty glyphs / fallback text but
        // nothing else breaks. Flag it so a developer notices.
        print("SwiftOpenUI: failed to register bundled Material Symbols font at \(url.path)")
    }
}

/// Recursively search a widget tree for a navigation-provided window titlebar.
private func findTitlebar(in widget: UnsafeMutablePointer<GtkWidget>) -> UnsafeMutablePointer<GtkWidget>? {
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    if let data = g_object_get_data(gobject, "gtk-swift-window-titlebar") {
        return UnsafeMutableRawPointer(data).assumingMemoryBound(to: GtkWidget.self)
    }

    // Search only the visible child of GtkStack to avoid stale titlebars.
    let typeName = String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
    if typeName == "GtkStack" {
        let stackOp = OpaquePointer(widget)
        if let visibleChild = gtk_stack_get_visible_child(stackOp) {
            return findTitlebar(in: visibleChild)
        }
        return nil
    }

    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        if let found = findTitlebar(in: c) {
            return found
        }
        child = gtk_widget_get_next_sibling(c)
    }
    return nil
}

/// Box for passing an activate closure through C user_data.
private class AppActivateBox {
    let activate: (OpaquePointer) -> Void
    init(_ activate: @escaping (OpaquePointer) -> Void) {
        self.activate = activate
    }
}

/// Protocol for scenes that can render onto a GtkApplication.
protocol GTKWindowRenderable {
    func gtkRender(app: OpaquePointer)
}

/// Root GTK window content should fill the proposed size; leaf alignment is
/// handled by child containers, not by centering the hosted root widget.
func gtkConfigureRootContentToFillWindow(_ contentWidget: UnsafeMutablePointer<GtkWidget>) {
    gtk_widget_set_hexpand(contentWidget, 1)
    gtk_widget_set_vexpand(contentWidget, 1)
    gtk_widget_set_halign(contentWidget, GTK_ALIGN_FILL)
    gtk_widget_set_valign(contentWidget, GTK_ALIGN_FILL)
}

extension WindowGroup: GTKWindowRenderable {
    func gtkResolvedDefaultWindowSize() -> (width: Double, height: Double)? {
        switch windowSizing ?? .automatic {
        case .automatic:
            return (
                defaultWindowWidth ?? defaultAutomaticWindowWidth,
                defaultWindowHeight ?? defaultAutomaticWindowHeight
            )
        case .content:
            guard let width = defaultWindowWidth, let height = defaultWindowHeight else {
                return nil
            }
            return (width, height)
        case .contentFixed:
            guard let width = defaultWindowWidth, let height = defaultWindowHeight else {
                return nil
            }
            return (width, height)
        case .size(let width, let height):
            return (width, height)
        }
    }

    func gtkRender(app: OpaquePointer) {
        let window = gtk_application_window_new(gtkApplicationPointer(app))!
        let winPtr = windowPointer(window)
        gtk_window_set_title(winPtr, title)

        // Set window ID in environment for keyboard shortcut scoping
        var wgEnv = getCurrentEnvironment()
        wgEnv.windowID = Int(bitPattern: winPtr)
        setCurrentEnvironment(wgEnv)

        let contentWidget = widgetFromOpaque(gtkRenderView(content))
        if let titlebarWidget = findTitlebar(in: contentWidget) {
            gtk_window_set_titlebar(winPtr, titlebarWidget)
        }

        // Apply minimum content size where configured. GTK4 window sizing is
        // largely content-driven, so min constraints are expressed on the root.
        let minReqW = minWindowWidth.map { Int32($0) } ?? -1
        let minReqH = minWindowHeight.map { Int32($0) } ?? -1
        if minReqW >= 0 || minReqH >= 0 {
            gtk_widget_set_size_request(contentWidget, minReqW, minReqH)
        }

        if let defaultSize = gtkResolvedDefaultWindowSize() {
            gtk_window_set_default_size(
                winPtr,
                gint(defaultSize.width),
                gint(defaultSize.height)
            )
        }

        switch windowSizing ?? .automatic {
        case .automatic, .content:
            break
        case .contentFixed:
            gtk_window_set_resizable(winPtr, 0)
        case .size:
            break
        }

        switch windowResizeBehavior ?? .automatic {
        case .automatic:
            break
        case .fixed:
            gtk_window_set_resizable(winPtr, 0)
        case .resizable:
            gtk_window_set_resizable(winPtr, 1)
        }

        // SwiftUI-compatible .windowResizability() — takes precedence
        // over windowResizeBehavior when set.
        switch windowResizability {
        case .contentSize:
            gtk_window_set_resizable(winPtr, 0)
        case .contentMinSize, .automatic:
            break  // resizable (default GTK4 behavior)
        case nil:
            break
        }

        gtkConfigureRootContentToFillWindow(contentWidget)

        gtk_window_set_child(winPtr, contentWidget)
        let winWidget = widgetPointer(winPtr)
        gtkSetupMenuBarIfNeeded(winPtr: winWidget, contentWidget: contentWidget, windowID: Int(bitPattern: winPtr))
        gtkAttachKeyboardShortcutController(to: winWidget)
        gtkAttachWindowActivationHandler(to: winWidget)
        gtk_window_present(winPtr)
    }
}

// MARK: - Keyboard shortcut controller

/// Attaches a GtkEventControllerKey to a window to dispatch keyboard shortcuts.
/// The window pointer is passed as user_data so the handler can scope dispatch.
func gtkAttachKeyboardShortcutController(to window: UnsafeMutablePointer<GtkWidget>) {
    let controller = gtk_event_controller_key_new()!
    let windowUD = gpointer(window)

    g_signal_connect_data(
        gpointer(controller),
        "key-pressed",
        unsafeBitCast(gtkKeyPressedHandler as @convention(c) (OpaquePointer?, guint, guint, guint, gpointer?) -> gboolean, to: GCallback.self),
        windowUD, nil,
        GConnectFlags(rawValue: 0)
    )

    gtk_widget_add_controller(window, controller)
}

/// Handler for GtkEventControllerKey "key-pressed" signal.
/// Signature: (controller, keyval, keycode, state, user_data) -> gboolean
/// user_data carries the window pointer for dispatch scoping.
private let gtkKeyPressedHandler: @convention(c) (OpaquePointer?, guint, guint, guint, gpointer?) -> gboolean = { _, keyval, _, state, userData in
    var modifiers: EventModifiers = []
    // GDK_CONTROL_MASK = 1 << 2 = 4
    if state & 4 != 0 { modifiers.insert(.command) }
    // GDK_SHIFT_MASK = 1 << 0 = 1
    if state & 1 != 0 { modifiers.insert(.shift) }
    // GDK_ALT_MASK = 1 << 3 = 8
    if state & 8 != 0 { modifiers.insert(.option) }
    // GDK_LOCK_MASK = 1 << 1 = 2
    if state & 2 != 0 { modifiers.insert(.capsLock) }

    guard let key = gtkKeyEquivalentFromKeyval(keyval) else {
        return 0
    }

    let windowID = Int(bitPattern: userData)
    let shortcut = KeyboardShortcut(key, modifiers: modifiers)
    return KeyboardShortcutRegistry.shared.dispatch(shortcut, windowID: windowID) ? 1 : 0
}

/// Maps a GDK keyval to a KeyEquivalent.
private func gtkKeyEquivalentFromKeyval(_ keyval: guint) -> KeyEquivalent? {
    switch keyval {
    case 0xff0d: return .return       // GDK_KEY_Return
    case 0xff8d: return .return       // GDK_KEY_KP_Enter
    case 0xff1b: return .escape       // GDK_KEY_Escape
    case 0xffff: return .delete       // GDK_KEY_Delete
    case 0xff08: return .delete       // GDK_KEY_BackSpace
    case 0xff09: return .tab          // GDK_KEY_Tab
    case 0xff52: return .upArrow      // GDK_KEY_Up
    case 0xff54: return .downArrow    // GDK_KEY_Down
    case 0xff51: return .leftArrow    // GDK_KEY_Left
    case 0xff53: return .rightArrow   // GDK_KEY_Right
    case 0x0020: return .space        // GDK_KEY_space
    default:
        // For ASCII printable characters, GDK keyvals match Unicode codepoints
        // a-z: 0x61-0x7a, A-Z: 0x41-0x5a (normalize to lowercase)
        let lower: guint
        if keyval >= 0x41 && keyval <= 0x5a {
            lower = keyval + 0x20
        } else {
            lower = keyval
        }
        if lower >= 0x20 && lower <= 0x7e {
            return KeyEquivalent(Character(Unicode.Scalar(lower)!))
        }
        return nil
    }
}

// MARK: - Window activation tracking

/// Connects to "notify::is-active" to track window activation for @FocusedValue.
func gtkAttachWindowActivationHandler(to window: UnsafeMutablePointer<GtkWidget>) {
    let windowUD = gpointer(window)
    g_signal_connect_data(
        gpointer(window),
        "notify::is-active",
        unsafeBitCast(gtkWindowActivationHandler as @convention(c) (gpointer?, gpointer?, gpointer?) -> Void, to: GCallback.self),
        windowUD, nil,
        GConnectFlags(rawValue: 0)
    )
}

/// Handler for GtkWindow "notify::is-active" signal.
/// Signature: (object, pspec, user_data) per GObject notify pattern.
private let gtkWindowActivationHandler: @convention(c) (gpointer?, gpointer?, gpointer?) -> Void = { widget, _, userData in
    guard let widget else { return }
    let widgetPtr = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GtkWidget.self)
    if gtk_swift_window_is_active(widgetPtr) != 0 {
        FocusedValuesStore.shared.setActiveWindow(Int(bitPattern: userData))
    }
}

// MARK: - GTK4 menu bar host

/// Mutable closure box whose identity (heap address) must remain stable for the
/// lifetime of its owning GSimpleAction, because the action's activate signal
/// callback holds an unretained pointer to it as user_data. Replacing the entry
/// in `actionClosures` would free the old box while GObject still points at it,
/// so `updateInPlace` mutates `.closure` instead of rebinding the slot.
private final class MenuActionClosure {
    var closure: () -> Void
    init(_ closure: @escaping () -> Void) { self.closure = closure }
}

/// Manages a GtkPopoverMenuBar on a GTK4 window.
/// Handles command dispatch via GAction, keyboard shortcut registration,
/// and observation-based re-evaluation of Commands.
///
/// Note: GtkPopoverMenuBar renders as a horizontal bar with dropdown menus
/// inside the window. This differs from Win32's native HMENU (integrated
/// into the window frame) but provides equivalent functionality.
final class GTK4MenuBarHost {
    let winPtr: UnsafeMutablePointer<GtkWidget>
    let factory: AnyCommandsFactory
    let windowID: Int
    private var menuBar: UnsafeMutablePointer<GtkWidget>?
    private var actionGroup: OpaquePointer?
    private var actions: [String: OpaquePointer] = [:]  // actionName → GSimpleAction
    private var actionClosures: [String: MenuActionClosure] = [:]  // kept alive for signal handlers
    private var shortcutRegIDs: [ShortcutRegistrationID] = []
    private var focusedValuesObserverID: FocusedValuesObserverID?
    private var containerBox: UnsafeMutablePointer<GtkWidget>?

    init(winPtr: UnsafeMutablePointer<GtkWidget>, factory: @escaping AnyCommandsFactory, windowID: Int) {
        self.winPtr = winPtr
        self.factory = factory
        self.windowID = windowID
    }

    /// Build the initial menu bar and start observation.
    func setup(contentWidget: UnsafeMutablePointer<GtkWidget>) {
        // Create a vertical box: menu bar on top, content below
        let vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        containerBox = vbox

        // Move content into the box
        g_object_ref(gpointer(contentWidget))
        gtk_window_set_child(windowPointer(winPtr), nil)
        gtk_box_append(UnsafeMutableRawPointer(vbox).assumingMemoryBound(to: GtkBox.self), contentWidget)
        gtk_widget_set_hexpand(contentWidget, 1)
        gtk_widget_set_vexpand(contentWidget, 1)
        gtk_widget_set_halign(contentWidget, GTK_ALIGN_FILL)
        gtk_widget_set_valign(contentWidget, GTK_ALIGN_FILL)
        gtk_widget_set_hexpand(vbox, 1)
        gtk_widget_set_vexpand(vbox, 1)
        g_object_unref(gpointer(contentWidget))

        // Set the box as window child
        gtk_window_set_child(windowPointer(winPtr), vbox)

        // Register for focused-value changes
        focusedValuesObserverID = FocusedValuesStore.shared.addObserver(windowID: nil) { [weak self] in
            self?.scheduleReevaluation()
        }

        evaluateWithTracking()
    }

    /// Schedule a re-evaluation on the main thread via GLib idle.
    private func scheduleReevaluation() {
        let box = Unmanaged.passRetained(ClosureBox { [weak self] in
            self?.evaluateWithTracking()
        }).toOpaque()
        g_idle_add({ (userData: gpointer?) -> gboolean in
            guard let userData else { return 0 }
            let box = Unmanaged<ClosureBox>.fromOpaque(userData).takeRetainedValue()
            box.closure()
            return 0  // G_SOURCE_REMOVE
        }, box)
    }

    /// Evaluate Commands with observation tracking and re-arm on change.
    func evaluateWithTracking() {
        #if canImport(Observation)
        if #available(macOS 14.0, iOS 17.0, *) {
            withObservationTracking {
                let groups = self.factory()
                self.updateMenu(groups)
            } onChange: { [weak self] in
                self?.scheduleReevaluation()
            }
            return
        }
        #endif
        let groups = factory()
        updateMenu(groups)
    }

    /// Update the native menu bar from evaluated command groups.
    private func updateMenu(_ groups: [CommandGroupPlacement: [CommandMenuItem]]) {
        let allItems = groups.sorted(by: { $0.key.hashValue < $1.key.hashValue })
            .flatMap { $0.value }

        if menuBar == nil {
            buildMenu(allItems)
        } else {
            // Check structural match
            let existingLabels = Array(actions.keys.sorted())
            let newLabels = allItems.map { "cmd_\($0.label.lowercased().replacingOccurrences(of: " ", with: "_"))" }
            if existingLabels == newLabels.sorted() && allItems.count == actions.count {
                updateInPlace(allItems)
            } else {
                teardown(widgetsValid: true)
                buildMenu(allItems)
            }
        }
    }

    /// Build GMenu + GtkPopoverMenuBar from scratch.
    private func buildMenu(_ items: [CommandMenuItem]) {
        let group = g_simple_action_group_new()!
        actionGroup = OpaquePointer(group)

        // GtkPopoverMenuBar expects the top-level GMenu to contain submenus,
        // not action items directly — otherwise it emits "Don't know how to
        // handle this item" warnings. Mirror Win32's pattern: wrap all items
        // in a single "File" submenu.
        let menuModel = gtk_swift_menu_new()!
        let fileMenu = gtk_swift_menu_new()!

        for item in items {
            let actionName = "cmd_\(item.label.lowercased().replacingOccurrences(of: " ", with: "_"))"
            let action = g_simple_action_new(actionName, nil)!

            // Set enabled state
            gtk_swift_action_set_enabled(gpointer(action), item.isDisabled ? 0 : 1)

            // Connect activate signal. The closure box identity must remain
            // stable across updateInPlace, because GObject stores user_data as
            // a raw pointer (passUnretained). See MenuActionClosure docstring.
            let closureBox = MenuActionClosure(item.action)
            actionClosures[actionName] = closureBox
            let ud = Unmanaged.passUnretained(closureBox).toOpaque()
            g_signal_connect_data(
                gpointer(action), "activate",
                unsafeBitCast({ (_: gpointer?, _: gpointer?, userData: gpointer?) in
                    guard let userData else { return }
                    Unmanaged<MenuActionClosure>.fromOpaque(userData).takeUnretainedValue().closure()
                } as @convention(c) (gpointer?, gpointer?, gpointer?) -> Void, to: GCallback.self),
                ud, nil,
                GConnectFlags(rawValue: 0)
            )

            gtk_swift_action_map_add_action(gpointer(group), gpointer(action))
            actions[actionName] = action

            // Build label with shortcut hint
            var label = item.label
            if let shortcut = item.shortcut {
                label += "  (\(shortcutHintText(shortcut)))"
            }
            gtk_swift_menu_append(fileMenu, label, "menu.\(actionName)")

            // Register keyboard shortcut
            if let shortcut = item.shortcut, !item.isDisabled {
                let regID = KeyboardShortcutRegistry.shared.register(
                    shortcut, windowID: windowID, action: item.action
                )
                shortcutRegIDs.append(regID)
            }
        }

        gtk_swift_menu_append_submenu(menuModel, "File", fileMenu)

        // Create the popover menu bar
        let bar = gtk_swift_popover_menu_bar_new_from_model(menuModel)!
        menuBar = bar

        // Insert action group on the bar
        gtk_swift_widget_insert_action_group(bar, "menu", gpointer(group))

        // Prepend menu bar to the container box
        if let box = containerBox {
            let boxPtr = UnsafeMutableRawPointer(box).assumingMemoryBound(to: GtkBox.self)
            gtk_box_prepend(boxPtr, bar)
        }
    }

    /// Update enabled state and action closures in place.
    private func updateInPlace(_ items: [CommandMenuItem]) {
        // Unregister old shortcuts
        for regID in shortcutRegIDs {
            KeyboardShortcutRegistry.shared.unregister(id: regID)
        }
        shortcutRegIDs.removeAll()

        for item in items {
            let actionName = "cmd_\(item.label.lowercased().replacingOccurrences(of: " ", with: "_"))"

            // Update enabled state
            if let action = actions[actionName] {
                gtk_swift_action_set_enabled(gpointer(action), item.isDisabled ? 0 : 1)
            }

            // Update action closure IN PLACE — the GSimpleAction activate
            // signal holds an unretained pointer to this box as user_data,
            // so we must not replace the box (would dangle the pointer).
            actionClosures[actionName]?.closure = item.action

            // Re-register shortcut with new closure
            if let shortcut = item.shortcut, !item.isDisabled {
                let regID = KeyboardShortcutRegistry.shared.register(
                    shortcut, windowID: windowID, action: item.action
                )
                shortcutRegIDs.append(regID)
            }
        }
    }

    /// Clean up all resources.
    ///
    /// `widgetsValid` must be false when called from the window-destroy
    /// path: GTK has already torn down the containerBox/menuBar widget
    /// tree by the time our g_object_set_data_full destroy notifier
    /// fires, so calling gtk_box_remove on them triggers a GTK_IS_BOX
    /// assertion failure. During a live menu rebuild the widgets are
    /// still valid and the caller must pass true so the old menu bar
    /// is actually unparented before a new one is appended.
    private func teardown(widgetsValid: Bool) {
        // Unregister shortcuts
        for regID in shortcutRegIDs {
            KeyboardShortcutRegistry.shared.unregister(id: regID)
        }
        shortcutRegIDs.removeAll()

        // Remove menu bar widget — only when the widget tree is still live.
        if widgetsValid, let bar = menuBar, let box = containerBox {
            let boxPtr = UnsafeMutableRawPointer(box).assumingMemoryBound(to: GtkBox.self)
            gtk_box_remove(boxPtr, bar)
        }
        menuBar = nil

        // Clear actions
        actions.removeAll()
        actionClosures.removeAll()
        actionGroup = nil
    }

    /// Full cleanup on window destruction. The widget tree is already
    /// gone at this point — only release non-widget resources.
    func destroy() {
        teardown(widgetsValid: false)
        if let observerID = focusedValuesObserverID {
            FocusedValuesStore.shared.removeObserver(id: observerID)
        }
    }

    /// Format shortcut for display in menu label.
    private func shortcutHintText(_ shortcut: KeyboardShortcut) -> String {
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
        default: keyText = String(shortcut.key.character).uppercased()
        }
        parts.append(keyText)
        return parts.joined(separator: "+")
    }
}

/// Attach a menu bar host to a window if Commands are declared.
func gtkSetupMenuBarIfNeeded(
    winPtr: UnsafeMutablePointer<GtkWidget>,
    contentWidget: UnsafeMutablePointer<GtkWidget>,
    windowID: Int
) {
    guard let commandsFactory = globalCommandsFactory else { return }
    let host = GTK4MenuBarHost(winPtr: winPtr, factory: commandsFactory, windowID: windowID)
    host.setup(contentWidget: contentWidget)

    // Store the host on the window for lifecycle management
    let retained = Unmanaged.passRetained(host).toOpaque()
    let gobject = UnsafeMutableRawPointer(winPtr).assumingMemoryBound(to: GObject.self)
    g_object_set_data_full(gobject, "gtk-swift-menu-bar-host", retained) { userData in
        guard let userData else { return }
        let host = Unmanaged<GTK4MenuBarHost>.fromOpaque(userData).takeRetainedValue()
        host.destroy()
    }
}

/// GTK4 rendering backend for SwiftOpenUI.
public struct GTK4Backend: RenderBackend {
    public init() {}

    public func run<A: App>(_ appType: A.Type) {
        // Load bundled icon fonts into FontConfig before GTK/Pango builds
        // its default font map. Safe to call multiple times but cheapest
        // to do exactly once per process, and must happen before any widget
        // asks Pango to resolve the "Material Symbols Rounded" family.
        gtkRegisterBundledIconFont()

        let gtkApp = gtk_application_new(nil, G_APPLICATION_DEFAULT_FLAGS)!
        let appPtr = OpaquePointer(gtkApp)

        let factory: (OpaquePointer) -> Void = { appPtr in
            // Inject openWindow action into the environment so views
            // can programmatically open Window scenes by id.
            var env = getCurrentEnvironment()
            env.openWindow = OpenWindowAction { id in
                GTK4WindowRegistry.shared.open(id: id)
            }
            setCurrentEnvironment(env)

            let instance = A()
            gtkRenderScene(instance.body, app: appPtr)
        }

        let box = Unmanaged.passRetained(AppActivateBox(factory)).toOpaque()
        g_signal_connect_data(
            gpointer(appPtr),
            "activate",
            unsafeBitCast({ (app: gpointer?, userData: gpointer?) in
                let box = Unmanaged<AppActivateBox>.fromOpaque(userData!).takeUnretainedValue()
                box.activate(OpaquePointer(app!))
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<AppActivateBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        // Pump Foundation RunLoop sources (Timer, etc.) periodically.
        // GTK4's g_application_run blocks in GMainLoop, so Foundation
        // timers (e.g. Timer.scheduledTimer) never fire unless we
        // explicitly spin RunLoop.main from a GLib timeout source.
        g_timeout_add(5, { _ -> gboolean in
            let limit = Date(timeIntervalSinceNow: 0.001)
            _ = RunLoop.main.run(mode: .default, before: limit)
            return 1 // G_SOURCE_CONTINUE
        }, nil)

        let status = g_application_run(applicationPointer(appPtr), 0, nil)
        g_object_unref(gpointer(appPtr))

        if status != 0 {
            print("GTK application exited with status \(status)")
        }
    }
}

/// GTK4 rendering for Window scenes (single-instance, identified windows).
extension Window: GTKWindowRenderable {
    func gtkRender(app: OpaquePointer) {
        // Register a factory for all Window scenes so openWindow(id:) works
        // regardless of launch behavior.
        GTK4WindowRegistry.shared.register(id: id) { [self] in
            self.gtkCreateWindow(app: app)
        }

        // For non-suppressed windows, use the registry's open(id:) to
        // create or refocus. This prevents duplicates when the GtkApplication
        // "activate" signal fires more than once (e.g., app re-activation).
        if launchBehavior != .suppressed {
            GTK4WindowRegistry.shared.open(id: id)
        }
    }

    func gtkCreateWindow(app: OpaquePointer) {
        let window = gtk_application_window_new(gtkApplicationPointer(app))!
        let winPtr = windowPointer(window)
        gtk_window_set_title(winPtr, title)

        // Set window ID in environment for keyboard shortcut scoping
        var wsEnv = getCurrentEnvironment()
        wsEnv.windowID = Int(bitPattern: winPtr)
        setCurrentEnvironment(wsEnv)

        let contentWidget = widgetFromOpaque(gtkRenderView(content))

        if let w = defaultWindowWidth, let h = defaultWindowHeight {
            gtk_window_set_default_size(winPtr, gint(w), gint(h))
        }

        let minReqW = minWindowWidth.map { Int32($0) } ?? -1
        let minReqH = minWindowHeight.map { Int32($0) } ?? -1
        if minReqW >= 0 || minReqH >= 0 {
            gtk_widget_set_size_request(contentWidget, minReqW, minReqH)
        }

        gtkConfigureRootContentToFillWindow(contentWidget)

        gtk_window_set_child(winPtr, contentWidget)
        let winWidget = widgetPointer(winPtr)
        gtkSetupMenuBarIfNeeded(winPtr: winWidget, contentWidget: contentWidget, windowID: Int(bitPattern: winPtr))
        gtkAttachKeyboardShortcutController(to: winWidget)
        gtkAttachWindowActivationHandler(to: winWidget)
        gtk_window_present(winPtr)

        // Track the live window so repeated openWindow(id:) refocuses
        // instead of creating duplicates. Hook the destroy signal to
        // clear the pointer when the window is closed, preventing
        // use-after-free on subsequent open(id:) calls.
        let windowId = id
        GTK4WindowRegistry.shared.setLiveWindow(id: windowId, window: winPtr)

        let box = ClosureBox {
            GTK4WindowRegistry.shared.clearLiveWindow(id: windowId)
        }
        let ud = Unmanaged.passRetained(box).toOpaque()
        g_signal_connect_data(
            gpointer(winPtr), "destroy",
            unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                guard let userData else { return }
                Unmanaged<ClosureBox>.fromOpaque(userData).takeUnretainedValue().closure()
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            ud,
            { (data: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                if let data { Unmanaged<ClosureBox>.fromOpaque(data).release() }
            },
            GConnectFlags(rawValue: 0)
        )
    }
}

/// GTK4 rendering for TupleScene — renders both child scenes.
extension TupleScene: GTKWindowRenderable {
    func gtkRender(app: OpaquePointer) {
        gtkRenderScene(scene0, app: app)
        gtkRenderScene(scene1, app: app)
    }
}

/// Registry for single-instance Window scenes. Tracks factories and live
/// window pointers to enforce the one-window-per-id contract.
class GTK4WindowRegistry {
    static let shared = GTK4WindowRegistry()
    private var factories: [String: () -> Void] = [:]
    private var liveWindows: [String: UnsafeMutablePointer<GtkWindow>] = [:]

    func register(id: String, factory: @escaping () -> Void) {
        factories[id] = factory
    }

    /// Record a live GTK window for the given id.
    func setLiveWindow(id: String, window: UnsafeMutablePointer<GtkWindow>) {
        liveWindows[id] = window
    }

    /// Clear the live window pointer (called from the destroy signal handler).
    func clearLiveWindow(id: String) {
        liveWindows.removeValue(forKey: id)
    }

    /// Open or refocus the window with the given id.
    /// If a live window exists, it is presented (refocused).
    /// Otherwise, the factory creates a new one.
    func open(id: String) {
        if let existing = liveWindows[id] {
            gtk_window_present(existing)
            return
        }
        // Window was closed or never created — invoke the factory.
        factories[id]?()
    }
}

/// Recursively render a Scene. Terminal scenes (WindowGroup, Window) render
/// directly; composite scenes recurse through their body.
private func gtkRenderScene<S: Scene>(_ scene: S, app: OpaquePointer) {
    if let renderable = scene as? GTKWindowRenderable {
        renderable.gtkRender(app: app)
        return
    }
    // Composite scene — recurse through body
    if S.Body.self != Never.self {
        gtkRenderScene(scene.body, app: app)
    }
}
