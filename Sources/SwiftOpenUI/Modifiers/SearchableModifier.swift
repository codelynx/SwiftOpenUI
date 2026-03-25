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

/// Simplified suggestion mode for searchable suggestion families.
public enum SearchSuggestionMode: Equatable {
    case suggestions
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

/// Erased suggestion value stored by the searchable primitive.
public struct SearchSuggestionValue: Equatable {
    public let id: String
    public let label: String
    public let completion: String?

    public init(id: String, label: String, completion: String? = nil) {
        self.id = id
        self.label = label
        self.completion = completion
    }
}

/// Result builder that lowers lightweight suggestion content into erased rows.
@resultBuilder
public enum SearchSuggestionBuilder {
    public static func buildBlock(_ components: [SearchSuggestionValue]...) -> [SearchSuggestionValue] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: Text) -> [SearchSuggestionValue] {
        [SearchSuggestionValue(id: expression.content, label: expression.content)]
    }

    public static func buildExpression(_ expression: SearchSuggestionValue) -> [SearchSuggestionValue] {
        [expression]
    }

    public static func buildOptional(_ component: [SearchSuggestionValue]?) -> [SearchSuggestionValue] {
        component ?? []
    }

    public static func buildEither(first component: [SearchSuggestionValue]) -> [SearchSuggestionValue] {
        component
    }

    public static func buildEither(second component: [SearchSuggestionValue]) -> [SearchSuggestionValue] {
        component
    }

    public static func buildArray(_ components: [[SearchSuggestionValue]]) -> [SearchSuggestionValue] {
        components.flatMap { $0 }
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
    public let suggestions: [SearchSuggestionValue]
    public let suggestionMode: SearchSuggestionMode?

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
            tokenMode: nil,
            suggestions: [],
            suggestionMode: nil
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
            tokenMode: nil,
            suggestions: [],
            suggestionMode: nil
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
            tokenMode: nil,
            suggestions: [],
            suggestionMode: nil
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
            tokenMode: .tokens,
            suggestions: [],
            suggestionMode: nil
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
            tokenMode: .editableTokens,
            suggestions: [],
            suggestionMode: nil
        )
    }
}

extension SearchableView {
    /// Adds search suggestions below the searchable field.
    public func searchSuggestions(
        @SearchSuggestionBuilder _ content: () -> [SearchSuggestionValue]
    ) -> SearchableView<Content> {
        SearchableView(
            content: self.content,
            text: self.text,
            prompt: self.prompt,
            placement: self.placement,
            isPresented: self.isPresented,
            tokens: self.tokens,
            tokenMode: self.tokenMode,
            suggestions: content(),
            suggestionMode: .suggestions
        )
    }
}

extension Text {
    /// Marks this suggestion row with an explicit completion string.
    public func searchCompletion(_ completion: String) -> SearchSuggestionValue {
        SearchSuggestionValue(
            id: "\(content)|\(completion)",
            label: content,
            completion: completion
        )
    }
}
