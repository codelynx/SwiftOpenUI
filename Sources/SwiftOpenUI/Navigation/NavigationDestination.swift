/// Modifier that registers a navigation destination factory for path-based navigation.
public struct NavigationDestinationModifier<Content: View, D: Hashable, Destination: View>: View {
    public typealias Body = Never

    public let content: Content
    public let dataType: D.Type
    public let destination: (D) -> Destination

    public var body: Never { fatalError("NavigationDestinationModifier is a primitive view") }
}

extension View {
    /// Register a destination view factory for NavigationPath-based navigation.
    ///
    /// ```swift
    /// NavigationStack(path: $path) {
    ///     List { ... }
    /// }
    /// .navigationDestination(for: String.self) { value in
    ///     Text("Detail: \(value)")
    /// }
    /// ```
    public func navigationDestination<D: Hashable, Destination: View>(
        for data: D.Type,
        @ViewBuilder destination: @escaping (D) -> Destination
    ) -> NavigationDestinationModifier<Self, D, Destination> {
        NavigationDestinationModifier(content: self, dataType: data, destination: destination)
    }
}
