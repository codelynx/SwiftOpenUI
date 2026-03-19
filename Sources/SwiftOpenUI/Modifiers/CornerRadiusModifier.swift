/// A view with rounded corners applied.
public struct CornerRadiusView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let radius: Double

    public var body: Never { fatalError("CornerRadiusView is a primitive view") }
}

extension View {
    /// Rounds the corners of this view. Note: on GTK4 this applies CSS
    /// border-radius which styles the background but does not clip descendant content.
    public func cornerRadius(_ radius: Double) -> CornerRadiusView<Self> {
        CornerRadiusView(content: self, radius: max(0, radius))
    }
}
