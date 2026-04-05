// MARK: - Tag

/// Associates an explicit tag value with a view for selection-based
/// controls like Picker and TabView.
public struct TagView<Content: View, V: Hashable>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let tagValue: V

    public var body: Never { fatalError() }
}

extension View {
    /// Tags this view with a value for use in selection-based controls.
    public func tag<V: Hashable>(_ tag: V) -> TagView<Self, V> {
        TagView(content: self, tagValue: tag)
    }
}

// MARK: - Tag value propagation

/// Thread-local storage for the current tag value during rendering.
/// Backends read this when rendering selection-based controls.
private var _currentTagValue: AnyHashable?

/// Set the current tag value for the render context.
public func setCurrentTagValue<V: Hashable>(_ value: V) {
    _currentTagValue = AnyHashable(value)
}

/// Get the current tag value.
public func getCurrentTagValue() -> AnyHashable? {
    _currentTagValue
}

/// Clear the current tag value.
public func clearCurrentTagValue() {
    _currentTagValue = nil
}
