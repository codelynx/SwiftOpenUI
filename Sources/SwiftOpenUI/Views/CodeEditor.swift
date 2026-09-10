/// One completion candidate offered in the editor's Ctrl+Space popover.
public struct CodeCompletionItem: Sendable {
    /// Text shown in the popover row.
    public let label: String
    /// Text inserted at the caret when the row is chosen.
    public let insertText: String

    public init(label: String, insertText: String) {
        self.label = label
        self.insertText = insertText
    }
}

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

    /// Optional Ctrl+Space completion source. Given the full buffer text and the
    /// 0-based caret (line, column), it returns candidates asynchronously; the
    /// editor shows them in a popover at the caret and inserts the chosen one.
    public let completionProvider: (@Sendable (String, Int, Int) async -> [CodeCompletionItem])?

    /// Create a code editor bound to `text`. The initial language is Swift.
    ///
    /// - Parameters:
    ///   - text: Two-way binding to the full document.
    ///   - selection: Optional binding updated with the current selection.
    ///   - completionProvider: Optional Ctrl+Space completion source.
    public init(
        text: Binding<String>,
        selection: Binding<String>? = nil,
        completionProvider: (@Sendable (String, Int, Int) async -> [CodeCompletionItem])? = nil
    ) {
        self.text = text
        self.selection = selection
        self.completionProvider = completionProvider
    }

    public var body: Never { fatalError("CodeEditor is a primitive view") }
}
