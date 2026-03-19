/// A view with rounded corners applied.
public struct CornerRadiusView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let radius: Double

    public var body: Never { fatalError("CornerRadiusView is a primitive view") }
}

extension View {
    /// Clips this view to a rounded rectangle with the given corner radius.
    public func cornerRadius(_ radius: Double) -> CornerRadiusView<Self> {
        CornerRadiusView(content: self, radius: max(0, radius))
    }
}
