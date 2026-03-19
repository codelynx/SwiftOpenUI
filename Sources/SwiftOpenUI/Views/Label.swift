/// A view that displays an icon alongside a text label.
public struct Label: View {
    public typealias Body = Never

    public let title: String
    public let systemImage: String?
    public let imagePath: String?

    /// Create a label with a system icon name.
    public init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
        self.imagePath = nil
    }

    /// Create a label with an image file path.
    public init(_ title: String, image: String) {
        self.title = title
        self.systemImage = nil
        self.imagePath = image
    }

    public var body: Never { fatalError("Label is a primitive view") }
}
