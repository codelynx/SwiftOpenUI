/// An expandable/collapsible section with a title and content.
public struct DisclosureGroup<Content: View>: View {
    public typealias Body = Never

    public let title: String
    public let isExpanded: Bool
    public let content: Content
    /// Optional custom label view, used when the label is a View rather than a String.
    public let labelView: (any View)?
    public let onExpandedChange: ((Bool) -> Void)?

    /// Simple initializer (no state tracking).
    public init(_ title: String, isExpanded: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isExpanded = isExpanded
        self.content = content()
        self.labelView = nil
        self.onExpandedChange = nil
    }

    /// Binding initializer for two-way state tracking.
    public init(_ title: String, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isExpanded = isExpanded.wrappedValue
        self.content = content()
        self.labelView = nil
        self.onExpandedChange = { newValue in
            if newValue != isExpanded.wrappedValue {
                isExpanded.wrappedValue = newValue
            }
        }
    }

    /// Label-view initializer matching SwiftUI's DisclosureGroup(content:label:).
    public init(
        isExpanded: Bool = false,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> some View
    ) {
        self.title = ""
        self.isExpanded = isExpanded
        self.content = content()
        self.labelView = label()
        self.onExpandedChange = nil
    }

    public var body: Never { fatalError("DisclosureGroup is a primitive view") }
}
