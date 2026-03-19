/// A multi-line text editing control.
///
/// TextEditor binds to a `String` value and allows multi-line text input.
public struct TextEditor: View {
    public typealias Body = Never

    public let text: Binding<String>

    public init(text: Binding<String>) {
        self.text = text
    }

    public var body: Never { fatalError("TextEditor is a primitive view") }
}
