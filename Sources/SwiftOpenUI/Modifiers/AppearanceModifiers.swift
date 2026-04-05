// MARK: - Hidden

/// Hides the content from display.
public struct HiddenView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content

    public var body: Never { fatalError() }
}

extension View {
    /// Hides this view unconditionally.
    public func hidden() -> HiddenView<Self> {
        HiddenView(content: self)
    }
}

// MARK: - Blur

/// Applies a Gaussian blur to the content.
public struct BlurView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let radius: Double
    public let opaque: Bool

    public var body: Never { fatalError() }
}

extension View {
    /// Applies a Gaussian blur to this view.
    public func blur(radius: Double, opaque: Bool = false) -> BlurView<Self> {
        BlurView(content: self, radius: radius, opaque: opaque)
    }
}
