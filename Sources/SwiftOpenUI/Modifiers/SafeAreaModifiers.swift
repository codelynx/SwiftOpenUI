/// A view that opts out of safe-area reservation on specified edges.
public struct IgnoresSafeAreaView<Content: View>: View, PrimitiveView {
    public typealias Body = Never

    public let content: Content
    public let regions: SafeAreaRegions
    public let edges: Edge.Set

    public var body: Never { fatalError("IgnoresSafeAreaView is a primitive view") }
}

/// A view that reserves edge space for inset content.
public struct SafeAreaInsetView<Content: View, Inset: View>: View, PrimitiveView {
    public typealias Body = Never

    public let content: Content
    public let inset: Inset
    public let edge: SafeAreaInsetEdge
    public let alignment: SafeAreaInsetAlignment
    public let spacing: Int

    public var body: Never { fatalError("SafeAreaInsetView is a primitive view") }
}

/// A view that applies safe-area-aware padding around its content.
public struct SafeAreaPaddingView<Content: View>: View, PrimitiveView {
    public typealias Body = Never

    public let content: Content
    public let edges: Edge.Set
    public let length: Int?

    public var body: Never { fatalError("SafeAreaPaddingView is a primitive view") }
}

extension View {
    /// Ignore safe-area reservation for the specified regions and edges.
    public func ignoresSafeArea(
        _ regions: SafeAreaRegions = .all,
        edges: Edge.Set = .all
    ) -> IgnoresSafeAreaView<Self> {
        IgnoresSafeAreaView(content: self, regions: regions, edges: edges)
    }

    /// Reserve inset content at a vertical edge.
    public func safeAreaInset<V: View>(
        edge: VerticalEdge,
        alignment: HorizontalAlignment = .center,
        spacing: Int? = nil,
        @ViewBuilder content: () -> V
    ) -> SafeAreaInsetView<Self, V> {
        SafeAreaInsetView(
            content: self,
            inset: content(),
            edge: edge == .top ? .top : .bottom,
            alignment: .horizontal(alignment),
            spacing: spacing ?? 0
        )
    }

    /// Reserve inset content at a horizontal edge.
    public func safeAreaInset<V: View>(
        edge: HorizontalEdge,
        alignment: VerticalAlignment = .center,
        spacing: Int? = nil,
        @ViewBuilder content: () -> V
    ) -> SafeAreaInsetView<Self, V> {
        SafeAreaInsetView(
            content: self,
            inset: content(),
            edge: edge == .leading ? .leading : .trailing,
            alignment: .vertical(alignment),
            spacing: spacing ?? 0
        )
    }

    /// Apply synthetic safe-area padding on all edges.
    public func safeAreaPadding() -> SafeAreaPaddingView<Self> {
        SafeAreaPaddingView(content: self, edges: .all, length: nil)
    }

    /// Apply safe-area padding with an explicit length on all edges.
    public func safeAreaPadding(_ length: Int) -> SafeAreaPaddingView<Self> {
        SafeAreaPaddingView(content: self, edges: .all, length: length)
    }

    /// Apply safe-area padding on selected edges with an optional explicit length.
    public func safeAreaPadding(_ edges: Edge.Set, _ length: Int? = nil) -> SafeAreaPaddingView<Self> {
        SafeAreaPaddingView(content: self, edges: edges, length: length)
    }
}
