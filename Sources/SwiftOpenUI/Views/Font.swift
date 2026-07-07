/// Font weight for custom fonts.
public enum FontWeight: Equatable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black
}

/// Font design (typeface family).
public enum FontDesign: Equatable {
    case `default`
    case monospaced
    case rounded
    case serif
}

/// Font presets matching SwiftUI's font system.
public enum Font: Equatable {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case subheadline
    case body
    case callout
    case footnote
    case caption
    case caption2
    /// Custom font with explicit size in points, optional weight and design.
    case custom(size: Double, weight: FontWeight, design: FontDesign)

    /// SwiftUI's fluent weight modifier on a font (e.g. `.subheadline.weight(.semibold)`).
    /// Resolves the preset to its point size and returns a weighted custom font.
    public func weight(_ weight: FontWeight) -> Font {
        .custom(size: self.pointSize, weight: weight, design: .default)
    }

    /// Point sizes for presets — mirrors the GTK4 backend's CSS mapping
    /// (Sources/Backend/GTK4: gtk font properties switch).
    public var pointSize: Double {
        switch self {
        case .largeTitle:  return 26
        case .title:       return 22
        case .title2:      return 20
        case .title3:      return 18
        case .headline:    return 14
        case .subheadline: return 12
        case .body:        return 14
        case .callout:     return 12
        case .footnote:    return 10
        case .caption:     return 12
        case .caption2:    return 10
        case .custom(let size, _, _): return size
        }
    }

    /// Create a system font with explicit size, weight, and design.
    public static func system(
        size: Double,
        weight: FontWeight = .regular,
        design: FontDesign = .default
    ) -> Font {
        .custom(size: size, weight: weight, design: design)
    }
}
