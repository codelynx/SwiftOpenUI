/// A view that displays a label with an optional icon and title.
///
/// ```swift
/// Label("Settings", systemImage: "gear")
/// ```
public struct Label: View {
    public typealias Body = Never

    public let title: String
    public let systemImage: String?

    /// Create a label with a title and system image name.
    public init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    /// Create a text-only label.
    public init(_ title: String) {
        self.title = title
        self.systemImage = nil
    }

    public var body: Never { fatalError("Label is a primitive view") }
}
