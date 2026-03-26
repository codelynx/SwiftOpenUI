/// A container that displays the first child view whose measured size fits
/// within the available space, falling back to the last child if none fit.
public struct ViewThatFits: View, PrimitiveView {
    public typealias Body = Never

    public let children: [AnyView]

    public init(@ViewThatFitsBuilder content: () -> [AnyView]) {
        self.children = content()
    }

    public var body: Never { fatalError("ViewThatFits is a primitive view") }
}

/// Result builder that lowers heterogeneous ViewThatFits children into AnyView.
@resultBuilder
public enum ViewThatFitsBuilder {
    public static func buildBlock(_ components: [AnyView]...) -> [AnyView] {
        components.flatMap { $0 }
    }

    public static func buildExpression<Content: View>(_ expression: Content) -> [AnyView] {
        [AnyView(expression)]
    }

    public static func buildExpression(_ expression: AnyView) -> [AnyView] {
        [expression]
    }

    public static func buildOptional(_ component: [AnyView]?) -> [AnyView] {
        component ?? []
    }

    public static func buildEither(first component: [AnyView]) -> [AnyView] {
        component
    }

    public static func buildEither(second component: [AnyView]) -> [AnyView] {
        component
    }

    public static func buildArray(_ components: [[AnyView]]) -> [AnyView] {
        components.flatMap { $0 }
    }
}
