/// A view that recognizes tap gestures on its content.
public struct TapGestureView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let count: Int
    public let action: () -> Void

    public var body: Never { fatalError("TapGestureView is a primitive view") }
}

/// A view that recognizes long-press gestures on its content.
public struct LongPressGestureView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let minimumDuration: Double
    public let action: () -> Void

    public var body: Never { fatalError("LongPressGestureView is a primitive view") }
}

/// Value describing a drag gesture's current state.
public struct DragGestureValue {
    /// The location where the drag started.
    public let startLocation: (x: Double, y: Double)
    /// The current location of the drag.
    public let location: (x: Double, y: Double)
    /// The total translation from the start.
    public let translation: (width: Double, height: Double)

    /// Convenience: translation width (matches SwiftUI CGSize.width).
    public var width: Double { translation.width }
    /// Convenience: translation height (matches SwiftUI CGSize.height).
    public var height: Double { translation.height }

    public init(startLocation: (x: Double, y: Double), location: (x: Double, y: Double), translation: (width: Double, height: Double)) {
        self.startLocation = startLocation
        self.location = location
        self.translation = translation
    }
}

/// A view that recognizes drag gestures on its content.
public struct DragGestureView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let minimumDistance: Double
    public let onChanged: ((DragGestureValue) -> Void)?
    public let onEnded: ((DragGestureValue) -> Void)?

    public var body: Never { fatalError("DragGestureView is a primitive view") }
}

extension View {
    /// Attach a tap gesture recognizer to this view.
    public func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> TapGestureView<Self> {
        TapGestureView(content: self, count: count, action: action)
    }

    /// Attach a long-press gesture recognizer to this view.
    public func onLongPressGesture(minimumDuration: Double = 0.5, perform action: @escaping () -> Void) -> LongPressGestureView<Self> {
        LongPressGestureView(content: self, minimumDuration: minimumDuration, action: action)
    }

    /// Attach a drag gesture recognizer to this view.
    public func onDrag(
        minimumDistance: Double = 10,
        onChanged: ((DragGestureValue) -> Void)? = nil,
        onEnded: ((DragGestureValue) -> Void)? = nil
    ) -> DragGestureView<Self> {
        DragGestureView(content: self, minimumDistance: minimumDistance, onChanged: onChanged, onEnded: onEnded)
    }

    /// Trailing-closure convenience: attach a drag gesture with an onChanged handler.
    public func onDrag(
        minimumDistance: Double = 10,
        _ handler: @escaping (DragGestureValue) -> Void
    ) -> DragGestureView<Self> {
        DragGestureView(content: self, minimumDistance: minimumDistance, onChanged: handler, onEnded: nil)
    }
}
