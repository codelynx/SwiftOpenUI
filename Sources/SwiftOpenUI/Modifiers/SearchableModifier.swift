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

/// Simplified token mode for searchable token families.
public enum SearchTokenMode: Equatable {
    case tokens
    case editableTokens
}

/// Erased token value stored by the searchable primitive.
public struct SearchTokenValue: Equatable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

/// Modifier that adds a search entry above the content.
public struct SearchableView<Content: View>: View, PrimitiveView {
    public typealias Body = Never

    public let content: Content
    public let text: Binding<String>
    public let prompt: String
    public let placement: SearchFieldPlacement
    public let isPresented: Binding<Bool>?
    public let tokens: [SearchTokenValue]
    public let tokenMode: SearchTokenMode?

    public var body: Never { fatalError("SearchableView is a primitive view") }
}

private func makeSearchTokenValue<Token: Identifiable>(
    from token: Token,
    label: (Token) -> Text
) -> SearchTokenValue {
    SearchTokenValue(
        id: String(describing: token.id),
        label: label(token).content
    )
}

extension View {
    /// Adds a search bar above this view.
    public func searchable(text: Binding<String>, prompt: String = "Search") -> SearchableView<Self> {
        SearchableView(
            content: self,
            text: text,
            prompt: prompt,
            placement: .automatic,
            isPresented: nil,
            tokens: [],
            tokenMode: nil
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
            isPresented: nil,
            tokens: [],
            tokenMode: nil
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
            isPresented: isPresented,
            tokens: [],
            tokenMode: nil
        )
    }

    /// Adds a searchable field with selected tokens.
    public func searchable<Token: Identifiable>(
        text: Binding<String>,
        tokens: Binding<[Token]>,
        placement: SearchFieldPlacement = .automatic,
        prompt: String = "Search",
        token: (Token) -> Text
    ) -> SearchableView<Self> {
        SearchableView(
            content: self,
            text: text,
            prompt: prompt,
            placement: placement,
            isPresented: nil,
            tokens: tokens.wrappedValue.map { makeSearchTokenValue(from: $0, label: token) },
            tokenMode: .tokens
        )
    }

    /// Adds a searchable field with editable tokens.
    public func searchable<Token: Identifiable>(
        text: Binding<String>,
        editableTokens: Binding<[Token]>,
        placement: SearchFieldPlacement = .automatic,
        prompt: String = "Search",
        token: (Token) -> Text
    ) -> SearchableView<Self> {
        SearchableView(
            content: self,
            text: text,
            prompt: prompt,
            placement: placement,
            isPresented: nil,
            tokens: editableTokens.wrappedValue.map { makeSearchTokenValue(from: $0, label: token) },
            tokenMode: .editableTokens
        )
    }
}
