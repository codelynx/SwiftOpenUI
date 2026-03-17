/// A button that pushes a destination view onto the navigation stack.
public struct NavigationLink<Destination: View>: View {
    public typealias Body = Never

    public let label: String
    public let title: String
    public let destination: () -> Destination

    /// Create a navigation link.
    /// - Parameters:
    ///   - label: Button text
    ///   - title: Navigation title for the destination (shown in header bar). Defaults to label.
    ///   - destination: View to push when tapped
    public init(_ label: String, title: String = "", @ViewBuilder destination: @escaping () -> Destination) {
        self.label = label
        self.title = title.isEmpty ? label : title
        self.destination = destination
    }

    public var body: Never { fatalError("NavigationLink is a primitive view") }
}
