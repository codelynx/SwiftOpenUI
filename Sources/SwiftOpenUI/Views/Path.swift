import Foundation

/// A SwiftUI-compatible 2D path for use with Canvas drawing.
///
/// ```swift
/// var path = Path()
/// path.move(to: CGPoint(x: 10, y: 10))
/// path.addLine(to: CGPoint(x: 100, y: 100))
/// context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: 2))
/// ```
public struct Path {
    /// The elements that make up this path.
    public private(set) var elements: [PathElement] = []

    public init() {}

    /// Create a path from a rectangle.
    public init(_ rect: CGRect) {
        addRect(rect)
    }

    /// Create a path from an ellipse inscribed in a rectangle.
    public init(ellipseIn rect: CGRect) {
        addEllipse(in: rect)
    }

    // MARK: - Path construction

    public mutating func move(to point: CGPoint) {
        elements.append(.moveTo(point))
    }

    public mutating func addLine(to point: CGPoint) {
        elements.append(.lineTo(point))
    }

    public mutating func addRect(_ rect: CGRect) {
        let x0 = rect.origin.x
        let y0 = rect.origin.y
        let x1 = x0 + rect.size.width
        let y1 = y0 + rect.size.height
        elements.append(.moveTo(CGPoint(x: x0, y: y0)))
        elements.append(.lineTo(CGPoint(x: x1, y: y0)))
        elements.append(.lineTo(CGPoint(x: x1, y: y1)))
        elements.append(.lineTo(CGPoint(x: x0, y: y1)))
        elements.append(.closeSubpath)
    }

    /// Add a rounded rectangle with the given corner radius.
    public mutating func addRoundedRect(in rect: CGRect, cornerRadius: Double) {
        let x = rect.origin.x
        let y = rect.origin.y
        let w = rect.size.width
        let h = rect.size.height
        let r = min(cornerRadius, min(w, h) / 2)

        move(to: CGPoint(x: x + r, y: y))
        addLine(to: CGPoint(x: x + w - r, y: y))
        addArc(center: CGPoint(x: x + w - r, y: y + r), radius: r,
               startAngle: -.pi / 2, endAngle: 0, clockwise: false)
        addLine(to: CGPoint(x: x + w, y: y + h - r))
        addArc(center: CGPoint(x: x + w - r, y: y + h - r), radius: r,
               startAngle: 0, endAngle: .pi / 2, clockwise: false)
        addLine(to: CGPoint(x: x + r, y: y + h))
        addArc(center: CGPoint(x: x + r, y: y + h - r), radius: r,
               startAngle: .pi / 2, endAngle: .pi, clockwise: false)
        addLine(to: CGPoint(x: x, y: y + r))
        addArc(center: CGPoint(x: x + r, y: y + r), radius: r,
               startAngle: .pi, endAngle: -.pi / 2, clockwise: false)
        closeSubpath()
    }

    public mutating func addEllipse(in rect: CGRect) {
        let cx = rect.origin.x + rect.size.width / 2
        let cy = rect.origin.y + rect.size.height / 2
        let rx = rect.size.width / 2
        let ry = rect.size.height / 2
        elements.append(.ellipse(center: CGPoint(x: cx, y: cy), radiusX: rx, radiusY: ry))
    }

    public mutating func addArc(
        center: CGPoint,
        radius: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat,
        clockwise: Bool
    ) {
        elements.append(.arc(
            center: center, radius: radius,
            startAngle: startAngle, endAngle: endAngle,
            clockwise: clockwise
        ))
    }

    public mutating func addCurve(
        to end: CGPoint,
        control1: CGPoint,
        control2: CGPoint
    ) {
        elements.append(.curve(to: end, control1: control1, control2: control2))
    }

    public mutating func closeSubpath() {
        elements.append(.closeSubpath)
    }

    /// True if path has no elements.
    public var isEmpty: Bool { elements.isEmpty }
}

/// Individual operations in a path.
public enum PathElement {
    case moveTo(CGPoint)
    case lineTo(CGPoint)
    case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
    case arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool)
    case ellipse(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat)
    case closeSubpath
}

/// Describes how a path is stroked.
public struct StrokeStyle {
    public var lineWidth: CGFloat
    public var lineCap: LineCap
    public var lineJoin: LineJoin
    /// Dash pattern — alternating "on" and "off" lengths in points.
    /// Empty means solid line. `[8, 4]` draws 8-point dashes separated
    /// by 4-point gaps.
    public var dash: [CGFloat]
    /// Starting offset into the dash pattern, in points.
    public var dashPhase: CGFloat

    public init(
        lineWidth: CGFloat = 1,
        lineCap: LineCap = .butt,
        lineJoin: LineJoin = .miter,
        dash: [CGFloat] = [],
        dashPhase: CGFloat = 0
    ) {
        self.lineWidth = lineWidth
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.dash = dash
        self.dashPhase = dashPhase
    }
}

/// Describes how a shape is filled or stroked in a Canvas.
public enum Shading {
    case color(Color)

    /// Extract RGBA values.
    public var colorComponents: (r: Double, g: Double, b: Double, a: Double) {
        switch self {
        case .color(let c):
            return (r: c.red, g: c.green, b: c.blue, a: c.alpha)
        }
    }
}
