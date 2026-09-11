/// An imperative handle to a live `CodeEditor` widget, for pushing text into it
/// from outside the SwiftUI-style data flow.
///
/// The GTK `CodeEditor` is an opaque, reused widget (so typing never flickers or
/// resets the caret), which means a plain change to the `text` binding is *not*
/// mirrored back into the widget. That is the right default for a document the
/// user is editing, but a host that loads a file needs to replace the whole
/// buffer. Passing a controller gives it that ability: ``setText(_:)`` writes
/// the buffer directly, and the widget's own change signal then flows the new
/// text back out through the `text` binding.
///
/// `@unchecked Sendable`: the backend stores a UI-thread-only apply closure into
/// it on widget creation; ``setText(_:)`` must be called on the UI (GTK main)
/// thread, exactly like the rest of the Linux UI.
public final class CodeEditorController: @unchecked Sendable {
    /// Set by the backend when the editor widget is created. Pushes `text` into
    /// the live buffer on the UI thread. `nil` until the widget exists.
    public var _applyText: ((String) -> Void)?

    public init() {}

    /// Replace the editor's entire contents with `text`. No-op before the widget
    /// is created. Call on the UI (GTK main) thread.
    public func setText(_ text: String) {
        _applyText?(text)
    }
}

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

    /// Optional imperative handle for pushing text into the live widget (e.g.
    /// loading a file). See ``CodeEditorController``.
    public let controller: CodeEditorController?

    /// Create a code editor bound to `text`. The initial language is Swift.
    ///
    /// - Parameters:
    ///   - text: Two-way binding to the full document.
    ///   - selection: Optional binding updated with the current selection.
    ///   - controller: Optional handle for imperative text replacement (loads).
    ///   - completionProvider: Optional Ctrl+Space completion source.
    public init(
        text: Binding<String>,
        selection: Binding<String>? = nil,
        controller: CodeEditorController? = nil,
        completionProvider: (@Sendable (String, Int, Int) async -> [CodeCompletionItem])? = nil
    ) {
        self.text = text
        self.selection = selection
        self.controller = controller
        self.completionProvider = completionProvider
    }

    public var body: Never { fatalError("CodeEditor is a primitive view") }
}
