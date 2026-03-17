/// A control that displays an editable text interface.
///
/// TextField binds to a `String` value and updates it as the user types.
/// The `title` string is used as a placeholder when the field is empty.
public struct TextField: View {
    public typealias Body = Never

    public let title: String
    public let text: Binding<String>

    public init(_ title: String, text: Binding<String>) {
        self.title = title
        self.text = text
    }

    public var body: Never { fatalError("TextField is a primitive view") }
}
