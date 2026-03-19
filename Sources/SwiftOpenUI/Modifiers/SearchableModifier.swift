/// Modifier that adds a search entry above the content.
public struct SearchableView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let text: Binding<String>
    public let prompt: String

    public var body: Never { fatalError("SearchableView is a primitive view") }
}

extension View {
    /// Adds a search bar above this view.
    public func searchable(text: Binding<String>, prompt: String = "Search") -> SearchableView<Self> {
        SearchableView(content: self, text: text, prompt: prompt)
    }
}
