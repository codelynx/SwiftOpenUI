/// A view that presents a menu of actions when tapped.
///
/// ```swift
/// Menu("Options") {
///     Button("Copy") { ... }
///     Button("Paste") { ... }
///     Divider()
///     Button("Delete") { ... }
/// }
/// ```
public struct Menu<Content: View>: View {
    public typealias Body = Never

    public let label: String
    public let content: Content

    public init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    public var body: Never { fatalError("Menu is a primitive view") }
}
