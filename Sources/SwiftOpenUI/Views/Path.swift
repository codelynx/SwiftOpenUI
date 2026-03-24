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

    public init(
        lineWidth: CGFloat = 1,
        lineCap: LineCap = .butt,
        lineJoin: LineJoin = .miter
    ) {
        self.lineWidth = lineWidth
        self.lineCap = lineCap
        self.lineJoin = lineJoin
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
