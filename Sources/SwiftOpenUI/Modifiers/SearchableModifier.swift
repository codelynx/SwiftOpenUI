/// Placement options for searchable fields.
public enum SearchFieldPlacement: Equatable {
    case automatic
    case toolbar
    case sidebar
    case navigationBarDrawer(displayMode: NavigationBarDrawerDisplayMode = .automatic)
}

/// Display behavior for navigation bar drawer search placement.
public enum NavigationBarDrawerDisplayMode: Equatable {
    case automatic
    case always
}

/// Modifier that adds a search entry above the content.
public struct SearchableView<Content: View>: View, PrimitiveView {
    public typealias Body = Never

    public let content: Content
    public let text: Binding<String>
    public let prompt: String
    public let placement: SearchFieldPlacement
    public let isPresented: Binding<Bool>?

    public var body: Never { fatalError("SearchableView is a primitive view") }
}

extension View {
    /// Adds a search bar above this view.
    public func searchable(text: Binding<String>, prompt: String = "Search") -> SearchableView<Self> {
        SearchableView(
            content: self,
            text: text,
            prompt: prompt,
            placement: .automatic,
            isPresented: nil
        )
    }

    /// Adds a search bar with explicit placement.
    public func searchable(
        text: Binding<String>,
        placement: SearchFieldPlacement = .automatic,
        prompt: String = "Search"
    ) -> SearchableView<Self> {
        SearchableView(
            content: self,
            text: text,
            prompt: prompt,
            placement: placement,
            isPresented: nil
        )
    }

    /// Adds a searchable field whose presentation is controlled by a binding.
    public func searchable(
        text: Binding<String>,
        isPresented: Binding<Bool>,
        placement: SearchFieldPlacement = .automatic,
        prompt: String = "Search"
    ) -> SearchableView<Self> {
        SearchableView(
            content: self,
            text: text,
            prompt: prompt,
            placement: placement,
            isPresented: isPresented
        )
    }
}
