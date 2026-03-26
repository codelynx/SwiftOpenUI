/// A view that propagates disabled state to descendant controls.
public struct DisabledView<Content: View>: View, PrimitiveView {
    public typealias Body = Never

    public let content: Content
    public let isDisabled: Bool

    public var body: Never { fatalError("DisabledView is a primitive view") }
}

extension View {
    /// Adds a condition that controls whether users can interact with this view.
    ///
    /// Descendant controls are disabled when any ancestor disabled wrapper
    /// resolves `isEnabled` to `false`.
    public func disabled(_ disabled: Bool) -> DisabledView<Self> {
        DisabledView(content: self, isDisabled: disabled)
    }
}
