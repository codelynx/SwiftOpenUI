/// An angle measurement for rotation.
public struct Angle {
    public let degrees: Double

    public init(degrees: Double) { self.degrees = degrees }

    public static func degrees(_ degrees: Double) -> Angle { Angle(degrees: degrees) }
    public static func radians(_ radians: Double) -> Angle { Angle(degrees: radians * 180.0 / .pi) }
    public static let zero = Angle(degrees: 0)
}

/// A view with a rotation transform applied.
public struct RotationView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let angle: Double

    public var body: Never { fatalError("RotationView is a primitive view") }
}

extension View {
    /// Rotates this view by the given angle in degrees.
    public func rotationEffect(_ angle: Double) -> RotationView<Self> {
        RotationView(content: self, angle: angle)
    }

    /// Rotates this view by the given Angle.
    public func rotationEffect(_ angle: Angle) -> RotationView<Self> {
        RotationView(content: self, angle: angle.degrees)
    }
}
