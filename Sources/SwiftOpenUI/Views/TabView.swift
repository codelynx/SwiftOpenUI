/// A view that switches between multiple child views using tabs.
///
/// ```swift
/// TabView {
///     Text("Home").tabItem { Text("Home") }
///     Text("Settings").tabItem { Text("Settings") }
/// }
/// ```
public struct TabView<Content: View>: View {
    public typealias Body = Never

    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Never { fatalError("TabView is a primitive view") }
}

/// A view with a tab item label attached.
public struct TabItemView<Content: View, TabLabel: View>: View {
    public typealias Body = Never

    public let content: Content
    public let tabLabel: TabLabel

    public var body: Never { fatalError("TabItemView is a primitive view") }
}

extension View {
    /// Set the tab item label for this view when inside a TabView.
    public func tabItem<Label: View>(@ViewBuilder label: () -> Label) -> TabItemView<Self, Label> {
        TabItemView(content: self, tabLabel: label())
    }
}
