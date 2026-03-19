/// A view that opens a URL when tapped.
///
/// ```swift
/// Link("Visit Apple", destination: "https://apple.com")
/// ```
public struct Link: View {
    public typealias Body = Never

    public let label: String
    public let destination: String

    public init(_ label: String, destination: String) {
        self.label = label
        self.destination = destination
    }

    public var body: Never { fatalError("Link is a primitive view") }
}
