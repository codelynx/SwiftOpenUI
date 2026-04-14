import Foundation

// MARK: - Shape Protocol

/// A 2D shape that can describe itself as a Path within a rectangle.
public protocol Shape: View {
    func path(in rect: CGRect) -> Path
}

// MARK: - Rounded Corner Style

public enum RoundedCornerStyle: Equatable {
    case circular
    case continuous
}

// MARK: - Circle

public struct Circle: Shape, PrimitiveView {
    public typealias Body = Never
    public init() {}

    public func path(in rect: CGRect) -> Path {
        // Inscribe circle in the smaller dimension, centered
        let side = min(rect.size.width, rect.size.height)
        let cx = rect.origin.x + rect.size.width / 2
        let cy = rect.origin.y + rect.size.height / 2
        let halfSide = side / 2
        let insetX = cx - halfSide
        let insetY = cy - halfSide
        let inset = CGRect(origin: CGPoint(x: insetX, y: insetY),
                           size: CGSize(width: side, height: side))
        return Path(ellipseIn: inset)
    }

    public var body: Never { fatalError() }
}

// MARK: - Rectangle

public struct Rectangle: Shape, PrimitiveView {
    public typealias Body = Never
    public init() {}

    public func path(in rect: CGRect) -> Path {
        Path(rect)
    }

    public var body: Never { fatalError() }
}

// MARK: - RoundedRectangle

public struct RoundedRectangle: Shape, PrimitiveView {
    public typealias Body = Never
    public let cornerRadius: Double
    public let style: RoundedCornerStyle

    public init(cornerRadius: Double, style: RoundedCornerStyle = .circular) {
        self.cornerRadius = cornerRadius
        self.style = style
    }

    public func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: rect, cornerRadius: cornerRadius)
        return p
    }

    public var body: Never { fatalError() }
}

// MARK: - Capsule

public struct Capsule: Shape, PrimitiveView {
    public typealias Body = Never
    public let style: RoundedCornerStyle

    public init(style: RoundedCornerStyle = .circular) {
        self.style = style
    }

    public func path(in rect: CGRect) -> Path {
        let radius = min(rect.size.width, rect.size.height) / 2
        var p = Path()
        p.addRoundedRect(in: rect, cornerRadius: radius)
        return p
    }

    public var body: Never { fatalError() }
}

// MARK: - Ellipse

public struct Ellipse: Shape, PrimitiveView {
    public typealias Body = Never
    public init() {}

    public func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect)
    }

    public var body: Never { fatalError() }
}

// MARK: - Shape Modifiers

/// A shape filled with a color.
public struct FilledShape<S: Shape>: View, PrimitiveView {
    public typealias Body = Never
    public let shape: S
    public let color: Color

    public var body: Never { fatalError() }
}

/// A shape stroked with a color and style.
public struct StrokedShape<S: Shape>: View, PrimitiveView {
    public typealias Body = Never
    public let shape: S
    public let color: Color
    public let style: StrokeStyle

    public var body: Never { fatalError() }
}

extension Shape {
    /// Fill this shape with a color.
    public func fill(_ color: Color) -> FilledShape<Self> {
        FilledShape(shape: self, color: color)
    }

    /// Stroke this shape with a color and line width.
    public func stroke(_ color: Color, lineWidth: Double = 1) -> StrokedShape<Self> {
        StrokedShape(shape: self, color: color, style: StrokeStyle(lineWidth: lineWidth))
    }

    /// Stroke this shape with a color and stroke style.
    public func stroke(_ color: Color, style: StrokeStyle) -> StrokedShape<Self> {
        StrokedShape(shape: self, color: color, style: style)
    }

    /// Stroke the border of this shape with a color and line width. SwiftUI's
    /// strokeBorder draws the stroke entirely inside the shape bounds; this
    /// implementation currently aliases to `stroke`, which centers the stroke
    /// on the path. For thin borders the visual difference is negligible;
    /// insetting-by-lineWidth-/2 can be added later if needed.
    public func strokeBorder(_ color: Color, lineWidth: Double = 1) -> StrokedShape<Self> {
        StrokedShape(shape: self, color: color, style: StrokeStyle(lineWidth: lineWidth))
    }

    /// Stroke the border of this shape with a color and stroke style.
    public func strokeBorder(_ color: Color, style: StrokeStyle) -> StrokedShape<Self> {
        StrokedShape(shape: self, color: color, style: style)
    }
}
