/// A two- or three-column navigation layout with sidebar and detail panes.
///
/// Two-column:
/// ```swift
/// NavigationSplitView {
///     List { ... }  // sidebar
/// } detail: {
///     Text("Select an item")  // detail
/// }
/// ```
///
/// Three-column:
/// ```swift
/// NavigationSplitView {
///     List { ... }  // sidebar
/// } content: {
///     List { ... }  // content
/// } detail: {
///     Text("Detail")  // detail
/// }
/// ```
public struct NavigationSplitView<Sidebar: View, Content: View, Detail: View>: View {
    public typealias Body = Never

    public let sidebar: Sidebar
    public let content: Content
    public let detail: Detail
    public let sidebarWidth: Int
    public let columnVisibility: Binding<NavigationSplitViewVisibility>?

    /// True when the content column is present (three-column mode).
    public var hasContentColumn: Bool { Content.self != EmptyView.self }

    public var body: Never { fatalError("NavigationSplitView is a primitive view") }
}

// MARK: - Two-column initializers

extension NavigationSplitView where Content == EmptyView {
    /// Two-column layout with configurable sidebar width.
    public init(sidebarWidth: Int = 250,
                @ViewBuilder sidebar: () -> Sidebar,
                @ViewBuilder detail: () -> Detail) {
        self.sidebarWidth = sidebarWidth
        self.sidebar = sidebar()
        self.content = EmptyView()
        self.detail = detail()
        self.columnVisibility = nil
    }

    /// Two-column layout with column visibility control.
    public init(columnVisibility: Binding<NavigationSplitViewVisibility>,
                @ViewBuilder sidebar: () -> Sidebar,
                @ViewBuilder detail: () -> Detail) {
        self.sidebarWidth = 250
        self.sidebar = sidebar()
        self.content = EmptyView()
        self.detail = detail()
        self.columnVisibility = columnVisibility
    }
}

// MARK: - Three-column initializers

extension NavigationSplitView {
    /// Three-column layout.
    public init(@ViewBuilder sidebar: () -> Sidebar,
                @ViewBuilder content: () -> Content,
                @ViewBuilder detail: () -> Detail) {
        self.sidebarWidth = 200
        self.sidebar = sidebar()
        self.content = content()
        self.detail = detail()
        self.columnVisibility = nil
    }

    /// Three-column layout with column visibility control.
    public init(columnVisibility: Binding<NavigationSplitViewVisibility>,
                @ViewBuilder sidebar: () -> Sidebar,
                @ViewBuilder content: () -> Content,
                @ViewBuilder detail: () -> Detail) {
        self.sidebarWidth = 200
        self.sidebar = sidebar()
        self.content = content()
        self.detail = detail()
        self.columnVisibility = columnVisibility
    }
}
