/// A drawing canvas for 2D graphics.
///
/// Usage:
/// ```swift
/// Canvas { context, width, height in
///     context.setColor(r: 1, g: 0, b: 0)
///     context.setLineWidth(3)
///     context.moveTo(x: 10, y: 10)
///     context.lineTo(x: 100, y: 100)
///     context.stroke()
/// }
/// .canvasSize(width: 400, height: 300)
/// ```
public struct Canvas: View {
    public typealias Body = Never

    public let drawHandler: (DrawingContext, Int, Int) -> Void
    public let width: Int
    public let height: Int

    public init(
        width: Int = 0,
        height: Int = 0,
        draw: @escaping (DrawingContext, Int, Int) -> Void
    ) {
        self.width = width
        self.height = height
        self.drawHandler = draw
    }

    public var body: Never { fatalError("Canvas is a primitive view") }

    /// Set the canvas content size.
    public func canvasSize(width: Int, height: Int) -> Canvas {
        Canvas(width: width, height: height, draw: self.drawHandler)
    }
}

/// A drawing context wrapping a native 2D graphics context.
/// On GTK4, this wraps a Cairo context. The API is platform-independent.
public struct DrawingContext {
    public let cr: OpaquePointer

    public init(cr: OpaquePointer) {
        self.cr = cr
    }
}

/// Line cap style for stroke operations.
public enum LineCap {
    case butt, round, square
}

/// Line join style for stroke operations.
public enum LineJoin {
    case miter, round, bevel
}
