/// A lazy vertical list that only renders visible items.
/// Unlike VStack (which renders all children upfront), LazyVStack
/// creates widgets on demand as items scroll into view.
public struct LazyVStack<Data, Content: View>: View {
    public typealias Body = Never

    public let items: [Data]
    public let contentBuilder: (Data) -> Content

    public var body: Never { fatalError("LazyVStack is a primitive view") }
}

extension LazyVStack where Data: Identifiable {
    public init(_ data: [Data], @ViewBuilder content: @escaping (Data) -> Content) {
        self.items = data
        self.contentBuilder = content
    }
}

extension LazyVStack {
    public init(_ data: [Data], @ViewBuilder content: @escaping (Data) -> Content) {
        self.items = data
        self.contentBuilder = content
    }
}

/// A lazy horizontal list that only renders visible items.
/// Same as LazyVStack but with horizontal orientation.
public struct LazyHStack<Data, Content: View>: View {
    public typealias Body = Never

    public let items: [Data]
    public let contentBuilder: (Data) -> Content

    public var body: Never { fatalError("LazyHStack is a primitive view") }
}

extension LazyHStack where Data: Identifiable {
    public init(_ data: [Data], @ViewBuilder content: @escaping (Data) -> Content) {
        self.items = data
        self.contentBuilder = content
    }
}

extension LazyHStack {
    public init(_ data: [Data], @ViewBuilder content: @escaping (Data) -> Content) {
        self.items = data
        self.contentBuilder = content
    }
}
