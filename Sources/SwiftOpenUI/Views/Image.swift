/// Scale for system images.
public enum ImageScale {
    case small
    case medium
    case large

    public var pointSize: Int {
        switch self {
        case .small: return 14
        case .medium: return 20
        case .large: return 24
        }
    }
}

/// A view that displays an image from an icon name or file path.
public struct Image: View {
    public typealias Body = Never

    public enum Source {
        case systemName(String)
        case filePath(String)
    }

    public let source: Source
    public var scale: ImageScale = .medium

    /// Create an image from a system icon name (GTK icon theme names on Linux).
    public init(systemName: String) {
        self.source = .systemName(systemName)
    }

    /// Create an image from a file path.
    public init(filePath: String) {
        self.source = .filePath(filePath)
    }

    /// Set the scale of the image.
    public func imageScale(_ scale: ImageScale) -> Image {
        var copy = self
        copy.scale = scale
        return copy
    }

    public var body: Never { fatalError("Image is a primitive view") }
}
