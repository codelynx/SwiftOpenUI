// MARK: - Bold

/// Applies bold font weight to the content.
public struct BoldView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public var body: Never { fatalError() }
}

// MARK: - Italic

/// Applies italic style to the content.
public struct ItalicView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public var body: Never { fatalError() }
}

// MARK: - Font Weight

/// Applies a specific font weight to the content.
public struct FontWeightView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let weight: FontWeight
    public var body: Never { fatalError() }
}

// MARK: - Underline

/// Applies underline decoration to text content.
public struct UnderlineView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let isActive: Bool
    public var body: Never { fatalError() }
}

// MARK: - Strikethrough

/// Applies strikethrough decoration to text content.
public struct StrikethroughView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let isActive: Bool
    public var body: Never { fatalError() }
}

// MARK: - Text Case

/// Transforms text case.
public enum TextCaseType: Equatable {
    case uppercase
    case lowercase
}

/// Applies a text case transformation to the content.
public struct TextCaseView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let textCase: TextCaseType?
    public var body: Never { fatalError() }
}

// MARK: - View Extensions

extension View {
    /// Applies bold font weight.
    public func bold() -> BoldView<Self> {
        BoldView(content: self)
    }

    /// Applies italic style.
    public func italic() -> ItalicView<Self> {
        ItalicView(content: self)
    }

    /// Sets the font weight.
    public func fontWeight(_ weight: FontWeight) -> FontWeightView<Self> {
        FontWeightView(content: self, weight: weight)
    }

    /// Applies underline decoration.
    public func underline(_ isActive: Bool = true) -> UnderlineView<Self> {
        UnderlineView(content: self, isActive: isActive)
    }

    /// Applies strikethrough decoration.
    public func strikethrough(_ isActive: Bool = true) -> StrikethroughView<Self> {
        StrikethroughView(content: self, isActive: isActive)
    }

    /// Transforms text case. Pass `nil` to reset.
    public func textCase(_ textCase: TextCaseType?) -> TextCaseView<Self> {
        TextCaseView(content: self, textCase: textCase)
    }
}
