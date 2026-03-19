/// A password input field that obscures its contents.
public struct SecureField: View {
    public typealias Body = Never

    public let placeholder: String
    public let text: Binding<String>

    /// Create a secure text field with a placeholder and text binding.
    public init(_ placeholder: String = "", text: Binding<String>) {
        self.placeholder = placeholder
        self.text = text
    }

    public var body: Never { fatalError("SecureField is a primitive view") }
}
