/// A view that fires an action when tapped.
/// Created by `.onTapGesture { }`.
public struct TapGestureView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let count: Int
    public let action: () -> Void

    public var body: Never { fatalError("TapGestureView is a primitive view") }
}

/// A view that fires an action on long press.
/// Created by `.onLongPressGesture { }`.
public struct LongPressGestureView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let minimumDuration: Double
    public let action: () -> Void

    public var body: Never { fatalError("LongPressGestureView is a primitive view") }
}

/// A value describing the state of a drag gesture.
public struct DragGestureValue {
    /// The location of the drag at the time of the event.
    public let location: (x: Double, y: Double)
    /// The location where the drag started.
    public let startLocation: (x: Double, y: Double)

    public init(location: (x: Double, y: Double), startLocation: (x: Double, y: Double)) {
        self.location = location
        self.startLocation = startLocation
    }
    /// The total translation from the start.
    public var translation: (width: Double, height: Double) {
        (width: location.x - startLocation.x, height: location.y - startLocation.y)
    }
}

/// A view that tracks drag gestures.
/// Created by `.gesture(DragGesture().onChanged { }.onEnded { })`.
/// For convenience, also available via `.onDrag(onChanged:onEnded:)`.
public struct DragGestureView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let onChanged: ((DragGestureValue) -> Void)?
    public let onEnded: ((DragGestureValue) -> Void)?

    public var body: Never { fatalError("DragGestureView is a primitive view") }
}

// MARK: - View extensions

extension View {
    /// Adds a tap gesture to this view.
    public func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> TapGestureView<Self> {
        TapGestureView(content: self, count: count, action: action)
    }

    /// Adds a long-press gesture to this view.
    public func onLongPressGesture(
        minimumDuration: Double = 0.5,
        perform action: @escaping () -> Void
    ) -> LongPressGestureView<Self> {
        LongPressGestureView(content: self, minimumDuration: minimumDuration, action: action)
    }

    /// Adds drag tracking to this view.
    public func onDrag(
        onChanged: ((DragGestureValue) -> Void)? = nil,
        onEnded: ((DragGestureValue) -> Void)? = nil
    ) -> DragGestureView<Self> {
        DragGestureView(content: self, onChanged: onChanged, onEnded: onEnded)
    }
}
