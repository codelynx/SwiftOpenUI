// MARK: - Tag

/// Type-erased accessor for a `TagView`'s value and content. Lets
/// containers like `Picker` walk a heterogeneous content tree and
/// extract `(label, tag)` pairs without knowing the tag's static
/// type `V`.
public protocol AnyTagView {
    /// The tag value, erased to `AnyHashable` so the caller can
    /// compare it against a selection binding of any `Hashable` type.
    var anyTagValue: AnyHashable { get }
    /// The wrapped content view — typically a `Text` for `Picker`
    /// usage, but can be any view.
    var anyTagContent: any View { get }
}

/// Associates an explicit tag value with a view for selection-based
/// controls like Picker and TabView.
public struct TagView<Content: View, V: Hashable>: View, PrimitiveView, AnyTagView {
    public typealias Body = Never
    public let content: Content
    public let tagValue: V

    public var body: Never { fatalError() }

    public var anyTagValue: AnyHashable { AnyHashable(tagValue) }
    public var anyTagContent: any View { content }
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
