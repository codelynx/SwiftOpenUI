/// A lazy vertical stack that only renders visible children.
///
/// Current implementation: renders all children (non-virtualized).
/// Functionally equivalent to VStack inside ScrollView.
public struct LazyVStack<Content: View>: View {
    public typealias Body = Never

    public let alignment: HorizontalAlignment
    public let spacing: Int
    public let content: Content

    public init(alignment: HorizontalAlignment = .center, spacing: Int = 0,
                @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError("LazyVStack is a primitive view") }
}

/// A lazy horizontal stack that only renders visible children.
///
/// Current implementation: renders all children (non-virtualized).
/// Functionally equivalent to HStack inside ScrollView.
public struct LazyHStack<Content: View>: View {
    public typealias Body = Never

    public let alignment: VerticalAlignment
    public let spacing: Int
    public let content: Content

    public init(alignment: VerticalAlignment = .center, spacing: Int = 0,
                @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError("LazyHStack is a primitive view") }
}
