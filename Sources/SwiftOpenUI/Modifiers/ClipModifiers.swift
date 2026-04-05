// MARK: - ClipShape

/// Clips the content to the outline of a shape.
public struct ClipShapeView<Content: View, S: Shape>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let shape: S

    public var body: Never { fatalError() }
}

extension View {
    /// Clips this view to the shape you specify.
    public func clipShape<S: Shape>(_ shape: S) -> ClipShapeView<Self, S> {
        ClipShapeView(content: self, shape: shape)
    }
}

// MARK: - Clipped

/// Clips the content to its bounding rectangle.
public struct ClippedView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content

    public var body: Never { fatalError() }
}

extension View {
    /// Clips this view to its bounding rectangular frame.
    public func clipped() -> ClippedView<Self> {
        ClippedView(content: self)
    }
}
