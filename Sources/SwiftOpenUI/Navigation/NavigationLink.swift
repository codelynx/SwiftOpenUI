/// A button that pushes a destination view onto the navigation stack.
public struct NavigationLink<Destination: View>: View {
    public typealias Body = Never

    public let label: String
    public let labelView: AnyView
    public let title: String
    public let destination: () -> Destination
    /// Value to push onto NavigationPath (used with value-based init).
    public let pushValue: AnyHashable?

    /// Create a navigation link with an explicit destination.
    /// - Parameters:
    ///   - label: Button text
    ///   - title: Navigation title for the destination (shown in header bar). Defaults to label.
    ///   - destination: View to push when tapped
    public init(_ label: String, title: String = "", @ViewBuilder destination: @escaping () -> Destination) {
        self.label = label
        self.labelView = AnyView(Text(label))
        self.title = title.isEmpty ? label : title
        self.destination = destination
        self.pushValue = nil
    }

    /// Create a navigation link with a custom label view.
    /// - Parameters:
    ///   - title: Navigation title for the destination. Defaults to the label text when the label is Text.
    ///   - destination: View to push when tapped.
    ///   - label: View rendered as the tap target label.
    public init<Label: View>(
        title: String = "",
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: () -> Label
    ) {
        let builtLabel = label()
        let labelText = navigationLinkLabelText(from: builtLabel)
        self.label = labelText
        self.labelView = AnyView(builtLabel)
        self.title = title.isEmpty ? labelText : title
        self.destination = destination
        self.pushValue = nil
    }

    public var body: Never { fatalError("NavigationLink is a primitive view") }
}

extension NavigationLink where Destination == EmptyView {
    /// Create a value-based navigation link. The value is pushed onto the
    /// NavigationPath and resolved by a `.navigationDestination(for:)` modifier.
    public init<V: Hashable>(_ label: String, value: V) {
        self.label = label
        self.labelView = AnyView(Text(label))
        self.title = label
        self.destination = { EmptyView() }
        self.pushValue = AnyHashable(value)
    }

    /// Create a value-based navigation link with a custom label view.
    /// The value is pushed onto the NavigationPath and resolved by a
    /// `.navigationDestination(for:)` modifier.
    public init<V: Hashable, Label: View>(
        value: V,
        title: String = "",
        @ViewBuilder label: () -> Label
    ) {
        let builtLabel = label()
        let labelText = navigationLinkLabelText(from: builtLabel)
        self.label = labelText
        self.labelView = AnyView(builtLabel)
        self.title = title.isEmpty ? labelText : title
        self.destination = { EmptyView() }
        self.pushValue = AnyHashable(value)
    }
}

private func navigationLinkLabelText<V: View>(from label: V) -> String {
    if let text = label as? Text {
        return text.content
    }
    return ""
}
