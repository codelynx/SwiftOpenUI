/// Minimal SwiftUI-shaped hierarchical styles and materials.
///
/// SwiftUI's ShapeStyle protocol machinery is large; these are concrete
/// types with color approximations, enough for `.foregroundStyle(.secondary)`
/// and `.background(.regularMaterial, in: shape)` call sites to compile and
/// render acceptably. Backed by flat colors (no blur/vibrancy) — recorded in
/// the parity matrix as approximations.
public struct HierarchicalShapeStyle: Sendable, Equatable {
    public enum Level: Sendable, Equatable { case primary, secondary, tertiary, quaternary }
    public let level: Level

    public static let primary = HierarchicalShapeStyle(level: .primary)
    public static let secondary = HierarchicalShapeStyle(level: .secondary)
    public static let tertiary = HierarchicalShapeStyle(level: .tertiary)
    public static let quaternary = HierarchicalShapeStyle(level: .quaternary)

    /// Flat-color approximation of the hierarchical style.
    public var approximatedColor: Color {
        switch level {
        case .primary:    return Color(red: 0.0, green: 0.0, blue: 0.0)
        case .secondary:  return Color(red: 0.45, green: 0.45, blue: 0.47)
        case .tertiary:   return Color(red: 0.60, green: 0.60, blue: 0.62)
        case .quaternary: return Color(red: 0.92, green: 0.92, blue: 0.94)
        }
    }
}

public struct Material: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case regular, thin, thick }
    public let kind: Kind

    public static let regularMaterial = Material(kind: .regular)
    public static let thinMaterial = Material(kind: .thin)
    public static let thickMaterial = Material(kind: .thick)

    /// Flat-color approximation (no translucency/blur).
    public var approximatedColor: Color {
        switch kind {
        case .regular: return Color(red: 0.97, green: 0.97, blue: 0.98)
        case .thin:    return Color(red: 0.98, green: 0.98, blue: 0.99)
        case .thick:   return Color(red: 0.94, green: 0.94, blue: 0.95)
        }
    }
}

extension View {
    /// `.background(.regularMaterial, in: shape)` — approximated as a flat
    /// shape fill behind the content.
    public func background<S: Shape>(_ material: Material, in shape: S) -> BackgroundView<Self, FilledShape<S>> {
        background(shape.fill(material.approximatedColor))
    }

    /// `.background(.quaternary, in: shape)` — approximated as a flat
    /// shape fill behind the content.
    public func background<S: Shape>(_ style: HierarchicalShapeStyle, in shape: S) -> BackgroundView<Self, FilledShape<S>> {
        background(shape.fill(style.approximatedColor))
    }
}
