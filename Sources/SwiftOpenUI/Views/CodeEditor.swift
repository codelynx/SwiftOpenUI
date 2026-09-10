/// A multi-line source-code editor with syntax highlighting and a line-number
/// gutter. On the GTK4 backend this is a `GtkSourceView` configured for Swift;
/// other backends may fall back to a plain text editor.
public struct CodeEditor: View {
    public typealias Body = Never

    public let text: Binding<String>

    /// Optional one-way mirror of the editor's current selection (empty when
    /// nothing is selected). Updated as the caret/selection moves — lets a host
    /// evaluate just the selected lines.
    public let selection: Binding<String>?

    /// Create a code editor bound to `text`. The initial language is Swift.
    ///
    /// - Parameters:
    ///   - text: Two-way binding to the full document.
    ///   - selection: Optional binding updated with the current selection.
    public init(text: Binding<String>, selection: Binding<String>? = nil) {
        self.text = text
        self.selection = selection
    }

    public var body: Never { fatalError("CodeEditor is a primitive view") }
}
