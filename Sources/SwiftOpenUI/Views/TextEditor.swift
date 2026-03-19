/// A multi-line text editor.
public struct TextEditor: View {
    public typealias Body = Never

    public let text: Binding<String>

    /// Create a multi-line text editor with a text binding.
    public init(text: Binding<String>) {
        self.text = text
    }

    public var body: Never { fatalError("TextEditor is a primitive view") }
}
