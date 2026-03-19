/// Scroll axis options.
public struct Axis: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let horizontal = Axis(rawValue: 1)
    public static let vertical = Axis(rawValue: 2)
}

/// A scrollable container.
public struct ScrollView<Content: View>: View {
    public typealias Body = Never

    public let axes: Axis
    public let content: Content

    public init(_ axes: Axis = .vertical, @ViewBuilder content: () -> Content) {
        self.axes = axes
        self.content = content()
    }

    public var body: Never { fatalError("ScrollView is a primitive view") }
}
