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
    func push(title: String, content: @escaping () -> OpaquePointer) {
        let name = "nav-\(nameCounter)"
        nameCounter += 1

        let widget = widgetFromOpaque(content())
        gtk_stack_add_named(stack, widget, name)

        let entry = GTKNavigationEntry(title: title, name: name, widget: widget)
        entries.append(entry)

        // Slide left for push
        gtk_stack_set_transition_type(stack, GTK_STACK_TRANSITION_TYPE_SLIDE_LEFT)
        gtk_stack_set_visible_child_name(stack, name)
        updateHeaderBar()
    }

    /// Push a hashable value, resolving destination via the registry.
    func pushValue(_ value: AnyHashable) {
        guard let resolved = destinationRegistry.resolve(value) else { return }

        let name = "nav-\(nameCounter)"
        nameCounter += 1

        let w = widgetFromOpaque(resolved.widget)
        gtk_stack_add_named(stack, w, name)

        let title = resolved.title.isEmpty ? String(describing: value.base) : resolved.title
        let entry = GTKNavigationEntry(title: title, name: name, widget: w)
        entries.append(entry)

        gtk_stack_set_transition_type(stack, GTK_STACK_TRANSITION_TYPE_SLIDE_LEFT)
        gtk_stack_set_visible_child_name(stack, name)
        updateHeaderBar()
        syncPathAfterPush(value)
    }

    /// Pop the top view from the navigation stack.
    func pop() {
        guard entries.count > 1 else { return }

        let removed = entries.removeLast()
        let previous = entries.last!

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
func gtkExtractTitle<V: View>(from view: V) -> String {
    if let titled = view as? NavigationTitled {
        return titled.navigationTitle
    }
    let mirror = Mirror(reflecting: view)
    for child in mirror.children {
        if let titled = child.value as? NavigationTitled {
            return titled.navigationTitle
        }
    }
    return ""
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

        // Add root as first stack entry
        let rootName = "nav-root"
        gtk_stack_add_named(stackOp, rootWidget, rootName)
        gtk_stack_set_visible_child_name(stackOp, rootName)
        context.entries.append(GTKNavigationEntry(title: title, name: rootName, widget: rootWidget))

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
        let button = gtk_button_new_with_label(label)!

        // Capture context strongly at render time
        guard let context = getCurrentNavigationContext() else {
            // Not inside a NavigationStack — render as plain button
            return opaqueFromWidget(button)
        }

        let dest = self.destination
        let destTitle = self.title

        let box = Unmanaged.passRetained(ClosureBox {
            // Set context for rendering the destination
            setCurrentNavigationContext(context)
            let prevEnv = getCurrentEnvironment()
            var env = prevEnv
            env[NavigateKey.self] = NavigateAction(
                push: { [weak context] value in context?.pushValue(value) },
                pop: { [weak context] in context?.pop() },
                popToRoot: { [weak context] in context?.popToRoot() }
            )
            setCurrentEnvironment(env)
            let destView = dest()
            let extracted = gtkExtractTitle(from: destView)
            let finalTitle = extracted.isEmpty ? destTitle : extracted
            context.push(title: finalTitle) {
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
            context.destinationRegistry.register(for: dataType) { value in
                setCurrentNavigationContext(context)
                let prevEnv = getCurrentEnvironment()
                var env = prevEnv
                env[NavigateKey.self] = NavigateAction(
                    push: { [weak context] value in context?.pushValue(value) },
                    pop: { [weak context] in context?.pop() },
                    popToRoot: { [weak context] in context?.popToRoot() }
                )
                setCurrentEnvironment(env)
                let destView = destinationBuilder(value)
                let title = gtkExtractTitle(from: destView)
                let widget = gtkRenderView(destView)
                setCurrentEnvironment(prevEnv)
                setCurrentNavigationContext(nil)
                return GTKResolvedDestination(widget: widget, title: title)
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
