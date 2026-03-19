/// A scrollable list that renders each child in a row.
///
/// Use with `ForEach` for data-driven content:
/// ```swift
/// List {
///     ForEach(items) { item in
///         Text(item.name)
///     }
/// }
/// ```
public struct List<Content: View>: View {
    public typealias Body = Never

    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Never { fatalError("List is a primitive view") }
}
