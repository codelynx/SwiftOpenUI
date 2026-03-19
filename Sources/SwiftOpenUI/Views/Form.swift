/// A container for grouping controls and data entry, similar to a settings screen.
///
/// Form renders its children with visual grouping. Use Section for labeled groups.
public struct Form<Content: View>: View {
    public typealias Body = Never

    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Never { fatalError("Form is a primitive view") }
}
