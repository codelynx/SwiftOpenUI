/// A grouping view with an optional header and footer, separated by dividers.
public struct Section<Content: View>: View {
    public typealias Body = Never

    public let header: String?
    public let footer: String?
    public let content: Content

    public init(_ header: String? = nil, @ViewBuilder content: () -> Content) {
        self.header = header
        self.footer = nil
        self.content = content()
    }

    public init(header: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.header = header
        self.footer = footer
        self.content = content()
    }

    public var body: Never { fatalError("Section is a primitive view") }
}
