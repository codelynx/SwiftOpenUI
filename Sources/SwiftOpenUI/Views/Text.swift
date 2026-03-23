/// A view that displays one or more lines of read-only text.
public struct Text: View, PrimitiveView {
    public typealias Body = Never

    public let content: String

    public init(_ content: String) {
        self.content = content
    }

    public var body: Never { fatalError("Text is a primitive view") }
}
