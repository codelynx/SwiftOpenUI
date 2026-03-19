/// The size component of a GeometryProxy.
public struct GeometrySize {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Provides layout dimensions to a GeometryReader's content builder.
public struct GeometryProxy {
    public let size: GeometrySize

    public init(size: GeometrySize) {
        self.size = size
    }
}

/// A container view that provides its allocated dimensions to its content builder.
/// Content is rendered lazily once dimensions are available.
public struct GeometryReader<Content: View>: View {
    public typealias Body = Never

    public let content: (GeometryProxy) -> Content

    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {
        self.content = content
    }

    public var body: Never { fatalError("GeometryReader is a primitive view") }
}
