/// A view with a search field that filters content.
///
/// The search text is bound to a `String` value. The view's content
/// can use the search text to filter its displayed data.
///
/// ```swift
/// @State private var searchText = ""
/// List { ... }
///     .searchable(text: $searchText, prompt: "Search...")
/// ```
public struct SearchableView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let text: Binding<String>
    public let prompt: String

    public var body: Never { fatalError("SearchableView is a primitive view") }
}

extension View {
    /// Add a search field to this view.
    public func searchable(text: Binding<String>, prompt: String = "Search...") -> SearchableView<Self> {
        SearchableView(content: self, text: text, prompt: prompt)
    }
}
