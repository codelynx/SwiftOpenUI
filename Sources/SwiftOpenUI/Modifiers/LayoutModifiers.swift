import Foundation

// MARK: - Position

/// Places the content at an absolute position within its parent.
public struct PositionView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let x: Double
    public let y: Double

    public var body: Never { fatalError() }
}

extension View {
    /// Positions the center of this view at the specified coordinates.
    public func position(x: Double = 0, y: Double = 0) -> PositionView<Self> {
        PositionView(content: self, x: x, y: y)
    }

    /// Positions the center of this view at the specified point.
    public func position(_ position: CGPoint) -> PositionView<Self> {
        PositionView(content: self, x: position.x, y: position.y)
    }
}

// MARK: - Layout Priority

/// Assigns a layout priority to influence how space is distributed
/// among siblings in a stack.
public struct LayoutPriorityView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let priority: Double

    public var body: Never { fatalError() }
}

extension View {
    /// Sets the priority by which a parent layout should apportion space
    /// to this child. Views with higher priority get space first.
    public func layoutPriority(_ value: Double) -> LayoutPriorityView<Self> {
        LayoutPriorityView(content: self, priority: value)
    }
}

// MARK: - Fixed Size

/// Prevents the view from being compressed below its ideal size.
public struct FixedSizeView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let horizontal: Bool
    public let vertical: Bool

    public var body: Never { fatalError() }
}

extension View {
    /// Fixes this view at its ideal size in the specified axes.
    public func fixedSize(horizontal: Bool = true, vertical: Bool = true) -> FixedSizeView<Self> {
        FixedSizeView(content: self, horizontal: horizontal, vertical: vertical)
    }

    /// Fixes this view at its ideal size in both axes.
    public func fixedSize() -> FixedSizeView<Self> {
        FixedSizeView(content: self, horizontal: true, vertical: true)
    }
}
