/// A multi-line source-code editor with syntax highlighting and a line-number
/// gutter. On the GTK4 backend this is a `GtkSourceView` configured for Swift;
/// other backends may fall back to a plain text editor.
public struct CodeEditor: View {
    public typealias Body = Never

    public let text: Binding<String>

    /// Create a code editor bound to `text`. The initial language is Swift.
    public init(text: Binding<String>) {
        self.text = text
    }

    public var body: Never { fatalError("CodeEditor is a primitive view") }
}
