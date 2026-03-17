/// A view that binds focus state to a boolean @FocusState.
/// Created by `.focused($isFocused)`.
public struct FocusedView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let focusState: FocusState<Bool>

    public var body: Never { fatalError("FocusedView is a primitive view") }
}

/// A view that binds focus state to an enum @FocusState case.
/// Created by `.focused($field, equals: .someCase)`.
public struct FocusedEqualsView<Content: View, Value: Hashable>: View {
    public typealias Body = Never

    public let content: Content
    public let focusState: FocusState<Value?>
    public let value: Value

    public var body: Never { fatalError("FocusedEqualsView is a primitive view") }
}

extension View {
    /// Binds the focus state of this view to a boolean @FocusState.
    public func focused(_ state: FocusState<Bool>) -> FocusedView<Self> {
        FocusedView(content: self, focusState: state)
    }

    /// Binds the focus state of this view to an enum @FocusState case.
    public func focused<V: Hashable>(_ state: FocusState<V?>, equals value: V) -> FocusedEqualsView<Self, V> {
        FocusedEqualsView(content: self, focusState: state, value: value)
    }
}
