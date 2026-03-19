/// A view that opens a URL when tapped.
public struct Link: View {
    public typealias Body = Never

    public let title: String
    public let destination: String

    /// Create a link with a string URL.
    public init(_ title: String, destination: String) {
        self.title = title
        self.destination = destination
    }

    public var body: Never { fatalError("Link is a primitive view") }
}
