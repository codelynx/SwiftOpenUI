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
        /// A glyph from Google's Material Symbols font, identified by its
        /// Material name (e.g. "search", "folder_open", "create_new_folder").
        /// Rendered by backends that bundle `SwiftOpenUISymbols` via Pango /
        /// DirectWrite / equivalent text shaping with OpenType ligature
        /// substitution.
        case materialSymbol(String)
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

    /// Create an image from a Google Material Symbols name.
    ///
    /// The name is a Material Symbol token like `"search"`, `"folder_open"`,
    /// or `"create_new_folder"` — see https://fonts.google.com/icons for the
    /// catalog. Rendering requires the bundled Material Symbols font shipped
    /// by the `SwiftOpenUISymbols` SwiftPM target, which backends on Linux /
    /// Windows / Web / Android depend on conditionally.
    ///
    /// On macOS this renders as a placeholder — SwiftOpenUI does not bundle
    /// the Material Symbols font on Apple platforms (SwiftUI's native
    /// rendering uses SF Symbols via `Image(systemName:)` instead).
    /// Cross-platform code that needs true portability should prefer
    /// `Image(systemName:)` paired with SwiftOpenUI's SF-to-Material name
    /// compatibility map (see the M-Symbols-3 roadmap in
    /// `docs/architecture/icon-symbols.md`).
    public init(material name: String) {
        self.source = .materialSymbol(name)
    }

    /// Set the scale of the image.
    public func imageScale(_ scale: ImageScale) -> Image {
        var copy = self
        copy.scale = scale
        return copy
    }

    public var body: Never { fatalError("Image is a primitive view") }
}
