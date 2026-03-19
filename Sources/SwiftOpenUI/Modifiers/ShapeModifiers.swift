/// A view with rounded corners applied.
public struct CornerRadiusView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let radius: Double

    public var body: Never { fatalError("CornerRadiusView is a primitive view") }
}

/// A view with a shadow applied.
public struct ShadowView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let color: Color
    public let radius: Double
    public let x: Double
    public let y: Double

    public var body: Never { fatalError("ShadowView is a primitive view") }
}

/// A view with a rotation transform applied.
public struct RotationEffectView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let degrees: Double

    public var body: Never { fatalError("RotationEffectView is a primitive view") }
}

extension View {
    /// Apply rounded corners to this view.
    public func cornerRadius(_ radius: Double) -> CornerRadiusView<Self> {
        CornerRadiusView(content: self, radius: radius)
    }

    /// Apply a shadow to this view.
    public func shadow(color: Color = .black.opacity(0.33), radius: Double = 4,
                       x: Double = 0, y: Double = 2) -> ShadowView<Self> {
        ShadowView(content: self, color: color, radius: radius, x: x, y: y)
    }

    /// Apply a rotation transform to this view.
    public func rotationEffect(degrees: Double) -> RotationEffectView<Self> {
        RotationEffectView(content: self, degrees: degrees)
    }
}
