/// A grouping view with an optional header and footer, separated by dividers.
public struct Section<Content: View>: View {
    public typealias Body = Never

    public let header: String?
    public let footer: String?
    public let content: Content
    /// View-typed header (SwiftUI's `Section { } header: { }` form).
    /// Takes precedence over the string `header` when set.
    public let headerView: AnyView?

    public init(_ header: String? = nil, @ViewBuilder content: () -> Content) {
        self.header = header
        self.footer = nil
        self.content = content()
        self.headerView = nil
    }

    /// SwiftUI's trailing-header form: `Section { rows } header: { view }`.
    public init<H: View>(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> H) {
        self.header = nil
        self.footer = nil
        self.content = content()
        self.headerView = AnyView(header())
    }

    public init(header: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.header = header
        self.footer = footer
        self.content = content()
        self.headerView = nil
    }

    public var body: Never { fatalError("Section is a primitive view") }
}
