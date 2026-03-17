/// A view wrapper that carries a navigation title.
public struct TitledView<Content: View>: View, NavigationTitled {
    public typealias Body = Never

    public let content: Content
    public let navigationTitle: String

    public var body: Never { fatalError("TitledView is a primitive view") }
}

extension View {
    /// Set the navigation title for this view (displayed in the header bar).
    public func navigationTitle(_ title: String) -> TitledView<Self> {
        TitledView(content: self, navigationTitle: title)
    }
}
