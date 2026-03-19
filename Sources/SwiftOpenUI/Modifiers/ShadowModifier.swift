/// A view with a shadow effect applied.
public struct ShadowView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let color: Color
    public let radius: Double
    public let x: Double
    public let y: Double

    public var body: Never { fatalError("ShadowView is a primitive view") }
}

extension View {
    /// Adds a shadow to this view.
    public func shadow(
        color: Color = Color(red: 0, green: 0, blue: 0, opacity: 0.33),
        radius: Double = 4,
        x: Double = 0,
        y: Double = 2
    ) -> ShadowView<Self> {
        ShadowView(content: self, color: color, radius: max(0, radius), x: x, y: y)
    }
}
