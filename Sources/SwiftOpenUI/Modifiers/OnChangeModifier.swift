/// Fires an action when the observed value changes between renders.
///
/// The action fires during rendering when the current value differs
/// from the value at the previous render. Uses a global counter-keyed
/// dictionary to persist previous values. The counter is reset at the
/// start of each render pass by the ViewHost calling `resetOnChangeTracking()`.
public struct OnChangeView<Content: View, V: Equatable>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let value: V
    public let action: (V) -> Void

    public var body: Never { fatalError() }
}

extension View {
    /// Adds an action to perform when the given value changes.
    public func onChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> OnChangeView<Self, V> {
        OnChangeView(content: self, value: value, action: action)
    }
}

// MARK: - onChange value tracking

/// Thread-local counter to generate unique keys for onChange instances
/// within a single render pass. Reset at the start of each rebuild.
private var _onChangeCounter: Int = 0

/// Thread-local storage for previous onChange values, keyed by render-pass counter.
/// Backends call `onChangeCheckAndFire` during rendering.
private var _onChangePreviousValues: [Int: Any] = [:]

/// Reset the onChange counter at the start of a render pass.
/// Does NOT clear stored values — they persist across rebuilds.
public func resetOnChangeTracking() {
    _onChangeCounter = 0
}

/// Clear all onChange state. Called between tests or when a host is destroyed.
public func clearOnChangeState() {
    _onChangeCounter = 0
    _onChangePreviousValues.removeAll()
}

/// Check if a value changed since last render and fire the action if so.
/// Called by backend renderers for each OnChangeView encountered.
/// Returns the current counter key (for testing).
@discardableResult
public func onChangeCheckAndFire<V: Equatable>(value: V, action: (V) -> Void) -> Int {
    let key = _onChangeCounter
    _onChangeCounter += 1

    if let previous = _onChangePreviousValues[key] as? V {
        if previous != value {
            action(value)
        }
    }
    // Store current value for next render pass
    _onChangePreviousValues[key] = value

    return key
}
