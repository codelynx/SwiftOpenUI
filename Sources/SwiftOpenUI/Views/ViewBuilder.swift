/// Result builder for composing child views declaratively.
@resultBuilder
public struct ViewBuilder {
    private static func childViews(from view: any View) -> [any View] {
        if let multi = view as? any TransparentMultiChildView {
            return multi.children
        }
        return [view]
    }

    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<repeat each Content> {
        TupleView(repeat each content)
    }

    public static func buildOptional<Content: View>(_ content: Content?) -> Content? {
        content
    }

    public static func buildEither<TrueContent: View, FalseContent: View>(first: TrueContent) -> _ConditionalView<TrueContent, FalseContent> {
        .trueContent(first)
    }

    public static func buildEither<TrueContent: View, FalseContent: View>(second: FalseContent) -> _ConditionalView<TrueContent, FalseContent> {
        .falseContent(second)
    }

    public static func buildPartialBlock<Content: View>(first: Content) -> Content {
        first
    }

    public static func buildPartialBlock<Accumulated: View, Next: View>(
        accumulated: Accumulated,
        next: Next
    ) -> ViewList {
        ViewList(childViews(from: accumulated) + childViews(from: next))
    }
}

/// Represents a conditional view from if/else in a ViewBuilder.
public enum _ConditionalView<TrueContent: View, FalseContent: View>: View, PrimitiveView {
    case trueContent(TrueContent)
    case falseContent(FalseContent)

    public typealias Body = Never
    public var body: Never { fatalError("_ConditionalView is a primitive view") }
}

extension Optional: PrimitiveView where Wrapped: View {}

extension Optional: View where Wrapped: View {
    public typealias Body = Never
    public var body: Never { fatalError("Optional<View> is a primitive view") }
}
