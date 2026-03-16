/// A modifier that you apply to a view, producing a different version
/// of the original value.
public protocol ViewModifier {
    associatedtype Body: View
    @ViewBuilder func body(content: Content) -> Body

    /// The type representing the content view being modified.
    typealias Content = _ViewModifierContent<Self>
}

/// Wraps the original view being modified, so custom modifiers can
/// compose around it via `content` in their `body(content:)`.
public struct _ViewModifierContent<Modifier: ViewModifier>: View {
    public typealias Body = Never

    /// The wrapped original view, type-erased.
    public let wrapped: AnyView

    public init(_ wrapped: AnyView) {
        self.wrapped = wrapped
    }

    public var body: Never { fatalError("_ViewModifierContent is a primitive view") }
}

/// A view produced by applying a modifier to a source view.
public struct ModifiedContent<Content: View, Modifier: ViewModifier>: View {
    public let content: Content
    public let modifier: Modifier

    public init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
    }

    public var body: some View {
        modifier.body(content: _ViewModifierContent<Modifier>(AnyView(content)))
    }
}

extension View {
    /// Apply a ViewModifier to this view.
    public func modifier<T: ViewModifier>(_ modifier: T) -> ModifiedContent<Self, T> {
        ModifiedContent(content: self, modifier: modifier)
    }
}
