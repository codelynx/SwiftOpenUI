/// A view with a foreground color applied.
public struct ForegroundColorView<Content: View>: View, PrimitiveView {
    public typealias Body = Never

    public let content: Content
    public let color: Color

    public var body: Never { fatalError("ForegroundColorView is a primitive view") }
}

/// A view with a background applied.
public struct BackgroundView<Content: View, Background: View>: View, PrimitiveView {
    public typealias Body = Never

    public let content: Content
    public let background: Background
    public let alignment: Alignment

    public var body: Never { fatalError("BackgroundView is a primitive view") }
}

extension BackgroundView where Background == Color {
    public var color: Color { background }
}

/// A view with a font applied.
public struct FontModifiedView<Content: View>: View, PrimitiveView {
    public typealias Body = Never

    public let content: Content
    public let font: Font

    public var body: Never { fatalError("FontModifiedView is a primitive view") }
}

/// A view with a border applied.
public struct BorderView<Content: View>: View, PrimitiveView {
    public typealias Body = Never

    public let content: Content
    public let color: Color
    public let width: Int

    public var body: Never { fatalError("BorderView is a primitive view") }
}

extension View {
    /// Apply a foreground color to this view.
    public func foregroundColor(_ color: Color) -> ForegroundColorView<Self> {
        ForegroundColorView(content: self, color: color)
    }

    /// SwiftUI-compatible alias for foregroundColor.
    public func foregroundStyle(_ color: Color) -> ForegroundColorView<Self> {
        foregroundColor(color)
    }

    /// Apply a background color to this view.
    public func background(_ color: Color) -> BackgroundView<Self, Color> {
        BackgroundView(content: self, background: color, alignment: .center)
    }

    /// Layer a background view behind this view.
    public func background<V: View>(_ background: V, alignment: Alignment = .center) -> BackgroundView<Self, V> {
        BackgroundView(content: self, background: background, alignment: alignment)
    }

    /// Build a background view behind this view.
    public func background<V: View>(alignment: Alignment = .center, @ViewBuilder _ background: () -> V) -> BackgroundView<Self, V> {
        BackgroundView(content: self, background: background(), alignment: alignment)
    }

    /// Apply a font to this view.
    public func font(_ font: Font) -> FontModifiedView<Self> {
        FontModifiedView(content: self, font: font)
    }

    /// Apply a border to this view.
    public func border(_ color: Color, width: Int = 1) -> BorderView<Self> {
        BorderView(content: self, color: color, width: width)
    }
}
