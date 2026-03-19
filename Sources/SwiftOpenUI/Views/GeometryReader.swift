/// A proxy for accessing the size and coordinate space of a container.
public struct GeometryProxy {
    /// The size of the container.
    public let size: (width: Double, height: Double)

    public init(size: (width: Double, height: Double)) {
        self.size = size
    }
}

/// A container view that provides its size to its content closure.
///
/// ```swift
/// GeometryReader { geometry in
///     Text("Width: \(Int(geometry.size.width))")
/// }
/// ```
public struct GeometryReader<Content: View>: View {
    public typealias Body = Never

    public let content: (GeometryProxy) -> Content

    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {
        self.content = content
    }

    public var body: Never { fatalError("GeometryReader is a primitive view") }
}
