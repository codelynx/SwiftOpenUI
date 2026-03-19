/// A control that displays an obscured text input for sensitive data like passwords.
///
/// SecureField binds to a `String` value and masks the characters as the user types.
/// The `title` string is used as a placeholder when the field is empty.
public struct SecureField: View {
    public typealias Body = Never

    public let title: String
    public let text: Binding<String>

    public init(_ title: String, text: Binding<String>) {
        self.title = title
        self.text = text
    }

    public var body: Never { fatalError("SecureField is a primitive view") }
}
