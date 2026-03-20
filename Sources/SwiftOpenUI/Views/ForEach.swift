/// A view that creates views from a collection of identified data.
public struct ForEach<Data, ID: Hashable, Content: View>: View, TransparentMultiChildView {
    public typealias Body = Never

    public let data: [Data]
    public let id: KeyPath<Data, ID>
    public let content: (Data) -> Content

    public var body: Never { fatalError("ForEach is a primitive view") }

    public var children: [any View] {
        data.map { content($0) }
    }
}

// MARK: - Identifiable data

extension ForEach where Data: Identifiable, ID == Data.ID {
    public init(_ data: [Data], @ViewBuilder content: @escaping (Data) -> Content) {
        self.data = data
        self.id = \.id
        self.content = content
    }
}

// MARK: - Custom key path

extension ForEach {
    public init(_ data: [Data], id: KeyPath<Data, ID>, @ViewBuilder content: @escaping (Data) -> Content) {
        self.data = data
        self.id = id
        self.content = content
    }
}

// MARK: - Range-based

extension ForEach where Data == Int, ID == Int {
    public init(_ range: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) {
        self.data = Array(range)
        self.id = \.self
        self.content = content
    }

    /// Range-based ForEach with explicit id key path (matches SwiftUI API).
    public init(_ range: Range<Int>, id: KeyPath<Int, Int>, @ViewBuilder content: @escaping (Int) -> Content) {
        self.data = Array(range)
        self.id = id
        self.content = content
    }
}
