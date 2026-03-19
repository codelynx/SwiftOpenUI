/// An expandable/collapsible section with a title and content.
public struct DisclosureGroup<Content: View>: View {
    public typealias Body = Never

    public let title: String
    public let isExpanded: Bool
    public let content: Content
    public let onExpandedChange: ((Bool) -> Void)?

    /// Simple initializer (no state tracking).
    public init(_ title: String, isExpanded: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isExpanded = isExpanded
        self.content = content()
        self.onExpandedChange = nil
    }

    /// Binding initializer for two-way state tracking.
    public init(_ title: String, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isExpanded = isExpanded.wrappedValue
        self.content = content()
        self.onExpandedChange = { newValue in
            if newValue != isExpanded.wrappedValue {
                isExpanded.wrappedValue = newValue
            }
        }
    }

    public var body: Never { fatalError("DisclosureGroup is a primitive view") }
}
