import CGTK
import CGTKBridge
import SwiftOpenUI
import Foundation

// MARK: - Helpers

/// Box for passing a widget pointer through a C callback.
private class WidgetRef {
    let widget: UnsafeMutablePointer<GtkWidget>
    init(_ widget: UnsafeMutablePointer<GtkWidget>) { self.widget = widget }
}

// MARK: - Navigation context (GTK-specific)

/// Entry in the navigation stack.
struct GTKNavigationEntry {
    let title: String
    let name: String
    let widget: UnsafeMutablePointer<GtkWidget>
    var toolbarWidgets: [(widget: UnsafeMutablePointer<GtkWidget>, placement: ToolbarItemPlacement)] = []
}

/// Manages the navigation stack state for GTK4.
/// Shared between NavigationStack and NavigationLink via thread-local capture at render time.
class GTKNavigationContext {
    let stack: OpaquePointer          // GtkStack
    let headerBar: OpaquePointer      // GtkHeaderBar
    let backButton: UnsafeMutablePointer<GtkWidget>
    var entries: [GTKNavigationEntry] = []
    var nameCounter = 0

    /// Registry for type-based navigation destinations.
    let destinationRegistry = GTKNavigationDestinationRegistry()

    /// Optional binding to a NavigationPath for programmatic navigation sync.
    var pathBinding: Binding<NavigationPath>?

    /// Guard against re-entrant sync between path and stack.
    private var isSyncing = false

    init(stack: OpaquePointer, headerBar: OpaquePointer, backButton: UnsafeMutablePointer<GtkWidget>) {
        self.stack = stack
        self.headerBar = headerBar
        self.backButton = backButton
    }

    /// Push a new view onto the navigation stack.
    func push(title: String, toolbarItems: [AnyToolbarItem] = [], content: @escaping () -> OpaquePointer) {
        let name = "nav-\(nameCounter)"
        nameCounter += 1

        // Remove current entry's toolbar widgets
        removeCurrentToolbarWidgets()

        let widget = widgetFromOpaque(content())
        gtk_stack_add_named(stack, widget, name)

        var entry = GTKNavigationEntry(title: title, name: name, widget: widget)

        // Install new toolbar items into header bar
        for item in toolbarItems {
            let itemWidget = widgetFromOpaque(gtkRenderAnyView(item.wrapped))
            switch item.placement {
            case .leading:
                gtk_header_bar_pack_start(headerBar, itemWidget)
            case .primaryAction, .trailing:
                gtk_header_bar_pack_end(headerBar, itemWidget)
            }
            g_object_ref(gpointer(itemWidget))
            entry.toolbarWidgets.append((widget: itemWidget, placement: item.placement))
        }

        entries.append(entry)

        // Slide left for push
        gtk_stack_set_transition_type(stack, GTK_STACK_TRANSITION_TYPE_SLIDE_LEFT)
        gtk_stack_set_visible_child_name(stack, name)
        updateHeaderBar()
    }

    /// Push a hashable value, resolving destination via the registry.
    func pushValue(_ value: AnyHashable) {
        guard let resolved = destinationRegistry.resolve(value) else { return }

        let title = resolved.title.isEmpty ? String(describing: value.base) : resolved.title
        push(title: title, toolbarItems: resolved.toolbarItems) {
            resolved.widget
        }
        syncPathAfterPush(value)
    }

    /// Pop the top view from the navigation stack.
    func pop() {
        guard entries.count > 1 else { return }

        removeCurrentToolbarWidgets()
        let removed = entries.removeLast()
        let previous = entries.last!

        // Restore previous entry's toolbar widgets
        for item in previous.toolbarWidgets {
            switch item.placement {
            case .leading:
                gtk_header_bar_pack_start(headerBar, item.widget)
            case .primaryAction, .trailing:
                gtk_header_bar_pack_end(headerBar, item.widget)
            }
        }

        // Slide right for pop
        gtk_stack_set_transition_type(stack, GTK_STACK_TRANSITION_TYPE_SLIDE_RIGHT)
        gtk_stack_set_visible_child_name(stack, previous.name)

        // Defer widget removal until after the slide transition completes,
        // so GTK doesn't destroy a widget mid-animation.
        let stackOp = stack
        let widget = removed.widget
        g_object_ref(gpointer(widget))
        let duration = gtk_stack_get_transition_duration(stackOp)
        g_timeout_add(duration + 50, { userData -> gboolean in
            let w = Unmanaged<WidgetRef>.fromOpaque(userData!).takeRetainedValue()
            if gtk_swift_is_widget(w.widget) != 0,
               let parent = gtk_widget_get_parent(w.widget) {
                let parentOp = OpaquePointer(parent)
                gtk_stack_remove(parentOp, w.widget)
            }
            g_object_unref(gpointer(w.widget))
            return 0 // G_SOURCE_REMOVE
        }, Unmanaged.passRetained(WidgetRef(widget)).toOpaque())

        updateHeaderBar()
        syncPathAfterPop()
    }

    /// Pop to the root view.
    func popToRoot() {
        while entries.count > 1 {
            pop()
        }
    }

    // MARK: - Path binding sync

    /// Suppress path sync (used during initial path consumption).
    func beginSync() { isSyncing = true }
    func endSync() { isSyncing = false }

    /// After a UI-driven push, append the value to the bound path.
    private func syncPathAfterPush(_ value: AnyHashable) {
        guard let pathBinding = pathBinding, !isSyncing else { return }
        isSyncing = true
        var path = pathBinding.wrappedValue
        path.elements.append(value)
        pathBinding.wrappedValue = path
        isSyncing = false
    }

    /// After a UI-driven pop, remove the last element from the bound path.
    private func syncPathAfterPop() {
        guard let pathBinding = pathBinding, !isSyncing else { return }
        isSyncing = true
        var path = pathBinding.wrappedValue
        if !path.isEmpty {
            path.removeLast()
        }
        pathBinding.wrappedValue = path
        isSyncing = false
    }

    /// Remove current entry's toolbar widgets from the header bar.
    private func removeCurrentToolbarWidgets() {
        guard let current = entries.last else { return }
        for item in current.toolbarWidgets {
            gtk_header_bar_remove(headerBar, item.widget)
        }
    }

    private func updateHeaderBar() {
        let title = entries.last?.title ?? ""
        gtk_header_bar_set_title_widget(headerBar, gtk_label_new(title))
        gtk_widget_set_visible(backButton, entries.count > 1 ? 1 : 0)
    }
}

// MARK: - Destination registry

/// Result from resolving a navigation destination.
struct GTKResolvedDestination {
    let widget: OpaquePointer
    let title: String
    let toolbarItems: [AnyToolbarItem]
}

/// Registry of type-to-view factories for path-based navigation.
class GTKNavigationDestinationRegistry {
    private var factories: [ObjectIdentifier: (AnyHashable) -> GTKResolvedDestination] = [:]

    func register<V: Hashable>(for type: V.Type, factory: @escaping (V) -> GTKResolvedDestination) {
        factories[ObjectIdentifier(type)] = { anyValue in
            factory(anyValue.base as! V)
        }
    }

    func resolve(_ value: AnyHashable) -> GTKResolvedDestination? {
        let typeId = ObjectIdentifier(type(of: value.base))
        return factories[typeId]?(value)
    }
}

// MARK: - Thread-local context for render-time access

#if canImport(Glibc) || canImport(Darwin)
private let _navContextKey: pthread_key_t = {
    var key = pthread_key_t()
    pthread_key_create(&key, nil)
    return key
}()

func setCurrentNavigationContext(_ context: GTKNavigationContext?) {
    if let context = context {
        let ptr = Unmanaged.passUnretained(context).toOpaque()
        pthread_setspecific(_navContextKey, ptr)
    } else {
        pthread_setspecific(_navContextKey, nil)
    }
}

func getCurrentNavigationContext() -> GTKNavigationContext? {
    guard let ptr = pthread_getspecific(_navContextKey) else { return nil }
    return Unmanaged<GTKNavigationContext>.fromOpaque(ptr).takeUnretainedValue()
}
#else
private var _currentNavContext: GTKNavigationContext?

func setCurrentNavigationContext(_ context: GTKNavigationContext?) {
    _currentNavContext = context
}

func getCurrentNavigationContext() -> GTKNavigationContext? {
    _currentNavContext
}
#endif

// MARK: - Title extraction

/// Extract navigation title from a view via NavigationTitled conformance.
/// Walks the view tree recursively so .navigationTitle() works regardless
/// of modifier ordering or nesting depth.
func gtkExtractTitle<V: View>(from view: V) -> String {
    return gtkExtractTitleAny(from: view)
}

private func gtkExtractTitleAny(from view: Any, depth: Int = 0) -> String {
    guard depth < 20 else { return "" }
    if let titled = view as? NavigationTitled {
        return titled.navigationTitle
    }
    let mirror = Mirror(reflecting: view)
    for child in mirror.children {
        if let titled = child.value as? NavigationTitled {
            return titled.navigationTitle
        }
    }
    for child in mirror.children {
        if child.value is any View {
            let result = gtkExtractTitleAny(from: child.value, depth: depth + 1)
            if !result.isEmpty { return result }
        }
    }
    return ""
}

// MARK: - Toolbar extraction

/// Extract toolbar items from a view tree via ToolbarProvider protocol.
/// Walks Mirror children recursively (depth-limited) to find ToolbarProvider
/// regardless of modifier ordering.
func gtkExtractToolbarItems<V: View>(from view: V) -> [AnyToolbarItem] {
    return gtkExtractToolbarItemsAny(from: view)
}

private func gtkExtractToolbarItemsAny(from view: Any, depth: Int = 0) -> [AnyToolbarItem] {
    guard depth < 20 else { return [] }

    if let provider = view as? ToolbarProvider {
        return provider.toolbarItems
    }

    let mirror = Mirror(reflecting: view)
    for child in mirror.children {
        if let provider = child.value as? ToolbarProvider {
            return provider.toolbarItems
        }
    }

    for child in mirror.children {
        if child.value is any View {
            let result = gtkExtractToolbarItemsAny(from: child.value, depth: depth + 1)
            if !result.isEmpty { return result }
        }
    }

    return []
}

/// Extract toolbar configuration from a view tree via ToolbarConfigurationProvider.
func gtkExtractToolbarConfiguration<V: View>(from view: V) -> ToolbarConfiguration? {
    return gtkExtractToolbarConfigurationAny(from: view)
}

private func gtkExtractToolbarConfigurationAny(from view: Any, depth: Int = 0) -> ToolbarConfiguration? {
    guard depth < 20 else { return nil }

    if let provider = view as? ToolbarConfigurationProvider {
        return provider.toolbarConfiguration
    }

    let mirror = Mirror(reflecting: view)
    for child in mirror.children {
        if let provider = child.value as? ToolbarConfigurationProvider {
            return provider.toolbarConfiguration
        }
    }

    for child in mirror.children {
        if child.value is any View {
            if let result = gtkExtractToolbarConfigurationAny(from: child.value, depth: depth + 1) {
                return result
            }
        }
    }

    return nil
}

/// Filter toolbar items based on configuration (remove placements, respect visibility).
func gtkApplyToolbarConfiguration(
    items: [AnyToolbarItem],
    configuration: ToolbarConfiguration?
) -> (items: [AnyToolbarItem], hidden: Bool) {
    guard let config = configuration else { return (items, false) }

    // GTK only renders navigation-bar-style toolbar; only hide for matching targets
    let targetAppliesToGTK = config.visibilityTarget == nil
        || config.visibilityTarget == .automatic
        || config.visibilityTarget == .navigationBar
    let hidden = config.visibility == .hidden && targetAppliesToGTK
    let filtered = items.filter { !config.removedPlacements.contains($0.placement) }
    return (filtered, hidden)
}

// MARK: - GTK rendering extensions

extension NavigationStack: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        // Create header bar
        let headerBar = gtk_header_bar_new()!
        let headerBarOp = OpaquePointer(headerBar)

        // Create back button (hidden initially)
        let backButton = gtk_button_new_with_label("Back")!
        gtk_widget_set_visible(backButton, 0)
        gtk_header_bar_pack_start(headerBarOp, backButton)

        // Create stack for content
        let stack = gtk_stack_new()!
        let stackOp = OpaquePointer(stack)
        gtk_stack_set_transition_duration(stackOp, 200)
        gtk_widget_set_vexpand(stack, 1)
        gtk_widget_set_hexpand(stack, 1)

        // Create context
        let context = GTKNavigationContext(stack: stackOp, headerBar: headerBarOp, backButton: backButton)
        if let pathBinding = pathBinding {
            context.pathBinding = pathBinding
        }

        // Attach context to stack widget for lifetime management
        let retained = Unmanaged.passRetained(context).toOpaque()
        let gobject = UnsafeMutableRawPointer(stack).assumingMemoryBound(to: GObject.self)
        g_object_set_data_full(gobject, "nav-context", retained, { userData in
            Unmanaged<GTKNavigationContext>.fromOpaque(userData!).release()
        })

        // Connect back button
        let backBox = Unmanaged.passRetained(ClosureBox { [weak context] in
            context?.pop()
        }).toOpaque()
        g_signal_connect_data(
            gpointer(backButton),
            "clicked",
            unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                let box = Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                box.closure()
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            backBox,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<ClosureBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        // Set context for render pass
        setCurrentNavigationContext(context)
        var env = getCurrentEnvironment()
        env[NavigateKey.self] = NavigateAction(
            push: { [weak context] value in context?.pushValue(value) },
            pop: { [weak context] in context?.pop() },
            popToRoot: { [weak context] in context?.popToRoot() }
        )
        let prevEnv = getCurrentEnvironment()
        setCurrentEnvironment(env)
        let title = gtkExtractTitle(from: content)
        let rootWidget = widgetFromOpaque(gtkRenderView(content))
        setCurrentEnvironment(prevEnv)
        setCurrentNavigationContext(nil)

        // Extract and install root toolbar items
        let rawToolbarItems = gtkExtractToolbarItems(from: content)
        let toolbarConfig = gtkExtractToolbarConfiguration(from: content)
        let (toolbarItems, toolbarHidden) = gtkApplyToolbarConfiguration(items: rawToolbarItems, configuration: toolbarConfig)
        var rootEntry = GTKNavigationEntry(title: title, name: "nav-root", widget: rootWidget)
        if !toolbarHidden {
        for item in toolbarItems {
            let itemWidget = widgetFromOpaque(gtkRenderAnyView(item.wrapped))
            switch item.placement {
            case .leading:
                gtk_header_bar_pack_start(headerBarOp, itemWidget)
            case .primaryAction, .trailing:
                gtk_header_bar_pack_end(headerBarOp, itemWidget)
            }
            g_object_ref(gpointer(itemWidget))
            rootEntry.toolbarWidgets.append((widget: itemWidget, placement: item.placement))
        }
        } // end if !toolbarHidden

        // Add root as first stack entry
        gtk_stack_add_named(stackOp, rootWidget, "nav-root")
        gtk_stack_set_visible_child_name(stackOp, "nav-root")
        context.entries.append(rootEntry)

        // Set initial title
        gtk_header_bar_set_title_widget(headerBarOp, gtk_label_new(title))

        // Consume any initial path elements (suppress sync — these are already in the binding)
        if let pathBinding = pathBinding {
            let path = pathBinding.wrappedValue
            if !path.isEmpty {
                context.beginSync()
                setCurrentNavigationContext(context)
                setCurrentEnvironment(env)
                for element in path.elements {
                    context.pushValue(element)
                }
                setCurrentEnvironment(prevEnv)
                setCurrentNavigationContext(nil)
                context.endSync()
            }
        }

        // Expose the header bar to Window via widget data
        g_object_ref(gpointer(headerBar))
        let stackObject = UnsafeMutableRawPointer(stack).assumingMemoryBound(to: GObject.self)
        g_object_set_data_full(stackObject, "gtk-swift-window-titlebar", headerBar, { userData in
            g_object_unref(userData)
        })

        return opaqueFromWidget(stack)
    }
}

extension NavigationLink: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let button: UnsafeMutablePointer<GtkWidget>
        if label.isEmpty {
            button = gtk_button_new()!
            let childWidget = widgetFromOpaque(gtkRenderView(labelView))
            let btnPtr = UnsafeMutableRawPointer(button).assumingMemoryBound(to: GtkButton.self)
            gtk_button_set_child(btnPtr, childWidget)
            applyCSSToWidget(button, properties: """
                border: none;
                outline: none;
                padding: 0;
                min-height: 0;
                min-width: 0;
                """)
        } else {
            button = gtk_button_new_with_label(label)!
        }

        // Capture context strongly at render time
        guard let context = getCurrentNavigationContext() else {
            // Not inside a NavigationStack — render as plain button
            return opaqueFromWidget(button)
        }

        let destTitle = self.title

        // Value-based NavigationLink — push value via registry
        if let value = pushValue {
            let box = Unmanaged.passRetained(ClosureBox { [weak context] in
                context?.pushValue(value)
            }).toOpaque()

            g_signal_connect_data(
                gpointer(button),
                "clicked",
                unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                    let box = Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                    box.closure()
                } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
                box,
                { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    Unmanaged<ClosureBox>.fromOpaque(userData!).release()
                },
                GConnectFlags(rawValue: 0)
            )

            return opaqueFromWidget(button)
        }

        // Destination-based NavigationLink
        let dest = self.destination

        // Capture the render-time environment so the deferred click callback
        // restores the correct ancestor environment (not whatever is ambient
        // at dispatch time). See deferred-callback-environment-binding.md.
        let capturedEnv = getCurrentEnvironment()

        let box = Unmanaged.passRetained(ClosureBox {
            // Set context for rendering the destination
            setCurrentNavigationContext(context)
            let prevEnv = getCurrentEnvironment()
            var env = capturedEnv
            env[NavigateKey.self] = NavigateAction(
                push: { [weak context] value in context?.pushValue(value) },
                pop: { [weak context] in context?.pop() },
                popToRoot: { [weak context] in context?.popToRoot() }
            )
            setCurrentEnvironment(env)
            let destView = dest()
            let extracted = gtkExtractTitle(from: destView)
            let finalTitle = extracted.isEmpty ? destTitle : extracted
            let rawItems = gtkExtractToolbarItems(from: destView)
            let destConfig = gtkExtractToolbarConfiguration(from: destView)
            let (toolbarItems, destHidden) = gtkApplyToolbarConfiguration(items: rawItems, configuration: destConfig)
            context.push(title: finalTitle, toolbarItems: destHidden ? [] : toolbarItems) {
                gtkRenderView(destView)
            }
            setCurrentEnvironment(prevEnv)
            setCurrentNavigationContext(nil)
        }).toOpaque()

        g_signal_connect_data(
            gpointer(button),
            "clicked",
            unsafeBitCast({ (_: gpointer?, userData: gpointer?) in
                let box = Unmanaged<ClosureBox>.fromOpaque(userData!).takeUnretainedValue()
                box.closure()
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                Unmanaged<ClosureBox>.fromOpaque(userData!).release()
            },
            GConnectFlags(rawValue: 0)
        )

        return opaqueFromWidget(button)
    }
}

extension NavigationDestinationModifier: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        // Register the destination factory on the current context
        if let context = getCurrentNavigationContext() {
            let destinationBuilder = destination
            // Capture render-time environment for the deferred factory callback.
            let capturedEnv = getCurrentEnvironment()
            context.destinationRegistry.register(for: dataType) { value in
                setCurrentNavigationContext(context)
                let prevEnv = getCurrentEnvironment()
                var env = capturedEnv
                env[NavigateKey.self] = NavigateAction(
                    push: { [weak context] value in context?.pushValue(value) },
                    pop: { [weak context] in context?.pop() },
                    popToRoot: { [weak context] in context?.popToRoot() }
                )
                setCurrentEnvironment(env)
                let destView = destinationBuilder(value)
                let title = gtkExtractTitle(from: destView)
                let rawItems = gtkExtractToolbarItems(from: destView)
                let destConfig = gtkExtractToolbarConfiguration(from: destView)
                let (filteredItems, destHidden) = gtkApplyToolbarConfiguration(items: rawItems, configuration: destConfig)
                let widget = gtkRenderView(destView)
                setCurrentEnvironment(prevEnv)
                setCurrentNavigationContext(nil)
                return GTKResolvedDestination(widget: widget, title: title, toolbarItems: destHidden ? [] : filteredItems)
            }
        }

        // Render the wrapped content
        return gtkRenderView(content)
    }
}

extension TitledView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        gtkRenderView(content)
    }
}

// MARK: - NavigationSplitView GTK extension

/// Extract column width provider from a view tree, walking through modifier
/// wrappers recursively so modifier ordering doesn't matter.
private func gtkExtractColumnWidthProvider<V: View>(from view: V) -> NavigationSplitViewColumnWidthProvider? {
    return gtkExtractColumnWidthProviderAny(from: view)
}

private func gtkExtractColumnWidthProviderAny(from view: Any, depth: Int = 0) -> NavigationSplitViewColumnWidthProvider? {
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
            if let result = gtkExtractColumnWidthProviderAny(from: child.value, depth: depth + 1) {
                return result
            }
        }
    }
    return nil
}

/// Extract column ideal width from a view with .navigationSplitViewColumnWidth applied.
private func gtkExtractColumnWidth<V: View>(from view: V) -> Double? {
    gtkExtractColumnWidthProvider(from: view)?.columnIdealWidth
}

/// Install toolbar items from a view tree into a GtkHeaderBar, attaching
/// it to the given widget via "gtk-swift-window-titlebar" for Window pickup.
private func gtkInstallToolbar<V: View>(from view: V, on widget: UnsafeMutablePointer<GtkWidget>) {
    let rawItems = gtkExtractToolbarItems(from: view)
    let config = gtkExtractToolbarConfiguration(from: view)
    let (toolbarItems, hidden) = gtkApplyToolbarConfiguration(items: rawItems, configuration: config)
    guard !hidden, !toolbarItems.isEmpty else { return }

    let headerBar = gtk_header_bar_new()!
    let headerBarOp = OpaquePointer(headerBar)
    gtk_header_bar_set_title_widget(headerBarOp, gtk_label_new(""))
    for item in toolbarItems {
        let itemWidget = widgetFromOpaque(gtkRenderAnyView(item.wrapped))
        switch item.placement {
        case .leading:
            gtk_header_bar_pack_start(headerBarOp, itemWidget)
        case .primaryAction, .trailing:
            gtk_header_bar_pack_end(headerBarOp, itemWidget)
        }
    }

    g_object_ref(gpointer(headerBar))
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    g_object_set_data_full(gobject, "gtk-swift-window-titlebar", headerBar,
        { userData in g_object_unref(userData) })
}

/// Apply visibility state to NavigationSplitView columns.
private func gtkApplyVisibility(
    _ visibility: NavigationSplitViewVisibility,
    sidebar: UnsafeMutablePointer<GtkWidget>,
    content: UnsafeMutablePointer<GtkWidget>?,
    paned: UnsafeMutablePointer<GtkWidget>
) {
    switch visibility {
    case .automatic, .all:
        gtk_widget_set_visible(sidebar, 1)
        if let content = content { gtk_widget_set_visible(content, 1) }
    case .doubleColumn:
        gtk_widget_set_visible(sidebar, 1)
        if let content = content { gtk_widget_set_visible(content, 0) }
    case .detailOnly:
        gtk_widget_set_visible(sidebar, 0)
        if let content = content { gtk_widget_set_visible(content, 0) }
        gtk_swift_paned_set_position(paned, 0)
    }
}

extension NavigationSplitView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        if hasContentColumn {
            return gtkCreateThreeColumnWidget()
        } else {
            return gtkCreateTwoColumnWidget()
        }
    }

    private func gtkCreateTwoColumnWidget() -> OpaquePointer {
        let paned = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL)!

        let sidebarW = gtkExtractColumnWidth(from: sidebar) ?? Double(sidebarWidth)

        let sidebarWidget = widgetFromOpaque(gtkRenderView(sidebar))
        let detailWidget = widgetFromOpaque(gtkRenderView(detail))

        // Apply min width from column width modifier (walks modifier chain)
        if let provider = gtkExtractColumnWidthProvider(from: sidebar),
           let minW = provider.columnMinWidth {
            gtk_widget_set_size_request(sidebarWidget, gint(minW), -1)
        }

        gtkInstallToolbar(from: detail, on: paned)

        gtk_swift_paned_set_start_child(paned, sidebarWidget)
        gtk_swift_paned_set_end_child(paned, detailWidget)
        gtk_swift_paned_set_position(paned, gint(sidebarW))
        gtk_swift_paned_set_shrink_start_child(paned, 0)
        gtk_swift_paned_set_shrink_end_child(paned, 0)

        gtk_widget_set_hexpand(paned, 1)
        gtk_widget_set_vexpand(paned, 1)

        if let visibility = columnVisibility {
            gtkApplyVisibility(visibility.wrappedValue,
                               sidebar: sidebarWidget, content: nil, paned: paned)
        }

        return opaqueFromWidget(paned)
    }

    private func gtkCreateThreeColumnWidget() -> OpaquePointer {
        // Outer paned: [innerPaned | detail]
        let outerPaned = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL)!
        // Inner paned: [sidebar | content]
        let innerPaned = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL)!

        let sidebarWidget = widgetFromOpaque(gtkRenderView(sidebar))
        let contentWidget = widgetFromOpaque(gtkRenderView(content))
        let detailWidget = widgetFromOpaque(gtkRenderView(detail))

        let sidebarW = gtkExtractColumnWidth(from: sidebar) ?? Double(sidebarWidth)
        let contentW = gtkExtractColumnWidth(from: content) ?? 250.0

        // Apply min widths from column width modifiers (walks modifier chain)
        if let provider = gtkExtractColumnWidthProvider(from: sidebar),
           let minW = provider.columnMinWidth {
            gtk_widget_set_size_request(sidebarWidget, gint(minW), -1)
        }
        if let provider = gtkExtractColumnWidthProvider(from: content),
           let minW = provider.columnMinWidth {
            gtk_widget_set_size_request(contentWidget, gint(minW), -1)
        }

        // Inner paned: sidebar + content
        gtk_swift_paned_set_start_child(innerPaned, sidebarWidget)
        gtk_swift_paned_set_end_child(innerPaned, contentWidget)
        gtk_swift_paned_set_position(innerPaned, gint(sidebarW))
        gtk_swift_paned_set_shrink_start_child(innerPaned, 0)
        gtk_swift_paned_set_shrink_end_child(innerPaned, 0)

        // Outer paned: inner + detail
        gtk_swift_paned_set_start_child(outerPaned, innerPaned)
        gtk_swift_paned_set_end_child(outerPaned, detailWidget)
        gtk_swift_paned_set_position(outerPaned, gint(sidebarW + contentW))
        gtk_swift_paned_set_shrink_start_child(outerPaned, 0)
        gtk_swift_paned_set_shrink_end_child(outerPaned, 0)

        gtkInstallToolbar(from: detail, on: outerPaned)

        gtk_widget_set_hexpand(outerPaned, 1)
        gtk_widget_set_vexpand(outerPaned, 1)
        gtk_widget_set_hexpand(innerPaned, 1)
        gtk_widget_set_vexpand(innerPaned, 1)

        if let visibility = columnVisibility {
            gtkApplyVisibility(visibility.wrappedValue,
                               sidebar: sidebarWidget, content: contentWidget,
                               paned: outerPaned)
        }

        return opaqueFromWidget(outerPaned)
    }
}

extension NavigationSplitViewColumnWidthView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        if let minW = columnMinWidth {
            gtk_widget_set_size_request(widget, gint(minW), -1)
        }
        return opaqueFromWidget(widget)
    }
}
