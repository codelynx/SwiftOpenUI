import Foundation

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

/// Byte layout of an in-memory pixel buffer passed to `Image(decoded:)`.
/// 8 bits per channel, straight (non-premultiplied) alpha, row-major, tightly
/// packed at `width * 4` bytes per row.
public enum ImagePixelFormat: Sendable {
    /// R, G, B, A byte order (common for decoded PNG/RGBA sources).
    case rgba8
    /// B, G, R, A byte order — matches PDFium `FPDFBitmap` and Cairo `ARGB32`
    /// on little-endian hosts, so page renders can be handed over without a swizzle.
    case bgra8
}

/// A view that displays an image from an icon name, file path, or in-memory pixels.
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
        /// An already-decoded, in-memory pixel buffer (no file, no network).
        /// The primary use is displaying frames rendered at runtime — PDF pages,
        /// procedurally generated bitmaps, decoded thumbnails — that never touch
        /// disk. `pixels` is `width * height * 4` bytes in `format`'s layout.
        case decoded(pixels: Data, width: Int, height: Int, format: ImagePixelFormat)
    }

    public let source: Source
    public var scale: ImageScale = .medium

    /// When `true`, the image stretches to fill any frame applied to it via
    /// `.frame(width:height:)`. When `false` (the default), the image renders
    /// at its natural size and any surrounding frame merely positions it.
    /// Matches SwiftUI's `.resizable()` semantics.
    public var isResizable: Bool = false

    /// Create an image from a system icon name (GTK icon theme names on Linux).
    public init(systemName: String) {
        self.source = .systemName(systemName)
    }

    /// Create an image from a file path.
    public init(filePath: String) {
        self.source = .filePath(filePath)
    }

    /// Create an image from a file in the app bundle's `Resources/`
    /// directory.
    ///
    /// Resource discovery uses `AppBundle.main`, which in development mode
    /// (`swift run`) walks up from the executable to find the package root's
    /// `Resources/` directory, and in packaged `.app` bundles uses the
    /// platform-native resources location.
    ///
    /// The file name may either include its extension directly
    /// (`Image(resource: "logo.png")`) or pass it via `withExtension:`
    /// (`Image(resource: "logo", withExtension: "png")`). If the resource is
    /// not found, the `name` is kept as the file path so the renderer can
    /// report the missing file consistently with other `filePath` loads.
    public init(resource name: String, withExtension ext: String? = nil) {
        if let bundle = AppBundle.main,
           let resolvedPath = bundle.path(forResource: name, ofType: ext) {
            self.source = .filePath(resolvedPath)
        } else {
            self.source = .filePath(name)
        }
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

    /// Create an image from an already-decoded, in-memory pixel buffer.
    ///
    /// `pixels` must be exactly `width * height * 4` bytes, row-major and tightly
    /// packed (`width * 4` bytes per row), in `format`'s channel order. This is the
    /// in-memory counterpart to `Image(filePath:)`: nothing is read from disk, so
    /// it suits runtime-rendered content (PDF pages, generated bitmaps).
    ///
    /// Pair with `.resizable()` to have the image fill a surrounding `.frame`.
    public init(decoded pixels: Data, width: Int, height: Int, format: ImagePixelFormat = .rgba8) {
        self.source = .decoded(pixels: pixels, width: width, height: height, format: format)
    }

    /// Set the scale of the image.
    public func imageScale(_ scale: ImageScale) -> Image {
        var copy = self
        copy.scale = scale
        return copy
    }

    /// Allow the image to scale to fit any frame applied to it.
    ///
    /// Without `.resizable()`, an image renders at its natural size regardless
    /// of any surrounding `.frame(width:height:)` — the frame positions the
    /// image but does not scale its pixels. After `.resizable()`, the image
    /// stretches to fill its frame. Matches SwiftUI's behavior.
    public func resizable() -> Image {
        var copy = self
        copy.isResizable = true
        return copy
    }

    public var body: Never { fatalError("Image is a primitive view") }
}
