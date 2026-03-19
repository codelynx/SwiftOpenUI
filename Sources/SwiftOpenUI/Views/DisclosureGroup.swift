/// A collapsible container that shows/hides its content with a disclosure indicator.
///
/// ```swift
/// @State var expanded = false
/// DisclosureGroup("Details", isExpanded: $expanded) {
///     Text("Hidden content")
/// }
/// ```
public struct DisclosureGroup<Content: View>: View {
    public typealias Body = Never

    public let label: String
    public let isExpanded: Binding<Bool>
    public let content: Content

    public init(_ label: String, isExpanded: Binding<Bool>,
                @ViewBuilder content: () -> Content) {
        self.label = label
        self.isExpanded = isExpanded
        self.content = content()
    }

    public var body: Never { fatalError("DisclosureGroup is a primitive view") }
}
