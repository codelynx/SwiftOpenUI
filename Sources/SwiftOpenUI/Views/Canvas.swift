import Foundation

/// A drawing canvas for 2D graphics.
///
/// SwiftUI-compatible usage:
/// ```swift
/// Canvas { context, size in
///     context.setColor(r: 1, g: 0, b: 0)
///     context.moveTo(x: 10, y: 10)
///     context.lineTo(x: Double(size.width), y: Double(size.height))
///     context.stroke()
/// }
/// .frame(width: 400, height: 300)
/// ```
///
/// Legacy usage (still supported):
/// ```swift
/// Canvas(width: 400, height: 300) { context, w, h in
///     // w, h are the init-specified size
/// }
/// ```
public struct Canvas: View {
    public typealias Body = Never

    /// Legacy draw handler using (DrawingContext, Int, Int).
    public let drawHandler: (DrawingContext, Int, Int) -> Void

    /// SwiftUI-style draw handler using (DrawingContext, CGSize).
    /// When set, this takes precedence over drawHandler.
    public let sizedDrawHandler: ((DrawingContext, CGSize) -> Void)?

    /// Explicit size from init. When nil, Canvas takes its size from layout.
    public let width: Int
    public let height: Int

    /// Whether this Canvas should receive its size from layout (true)
    /// or use the explicit width/height (false).
    public var usesLayoutSize: Bool { sizedDrawHandler != nil && width == 0 && height == 0 }

    /// SwiftUI-compatible initializer. Canvas receives its size from
    /// the layout system (via `.frame()` or parent-proposed size).
    public init(
        renderer: @escaping (DrawingContext, CGSize) -> Void
    ) {
        self.sizedDrawHandler = renderer
        self.width = 0
        self.height = 0
        // Legacy handler wraps the sized handler (fallback if backend
        // doesn't support layout-sized Canvas yet)
        self.drawHandler = { ctx, w, h in
            renderer(ctx, CGSize(width: CGFloat(w), height: CGFloat(h)))
        }
    }

    /// Legacy initializer with explicit size.
    /// Equivalent to `Canvas { ... }.frame(width:height:)`.
    public init(
        width: Int = 0,
        height: Int = 0,
        draw: @escaping (DrawingContext, Int, Int) -> Void
    ) {
        self.width = width
        self.height = height
        self.drawHandler = draw
        self.sizedDrawHandler = nil
    }

    public var body: Never { fatalError("Canvas is a primitive view") }

    /// Set the canvas content size.
    public func canvasSize(width: Int, height: Int) -> Canvas {
        Canvas(width: width, height: height, draw: self.drawHandler)
    }
}

/// A drawing context wrapping a native 2D graphics context.
/// On GTK4, this wraps a Cairo context. On Win32, a D2DCanvasContext.
/// The API is platform-independent.
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
