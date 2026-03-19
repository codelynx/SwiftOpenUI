/// A two-column navigation layout with sidebar and detail.
///
/// ```swift
/// NavigationSplitView {
///     List { ... }  // sidebar
/// } detail: {
///     Text("Select an item")  // detail
/// }
/// ```
public struct NavigationSplitView<Sidebar: View, Detail: View>: View {
    public typealias Body = Never

    public let sidebar: Sidebar
    public let detail: Detail
    public let sidebarWidth: Int

    public init(sidebarWidth: Int = 250,
                @ViewBuilder sidebar: () -> Sidebar,
                @ViewBuilder detail: () -> Detail) {
        self.sidebarWidth = sidebarWidth
        self.sidebar = sidebar()
        self.detail = detail()
    }

    public var body: Never { fatalError("NavigationSplitView is a primitive view") }
}
