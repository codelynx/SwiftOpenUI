/// A two-way reference to a value owned by a parent view's @State.
/// Created via `$stateName` (State's projectedValue).
///
/// Binding lifetime is tied to the parent view's render cycle.
/// The get/set closures capture the parent's StateStorage, so mutations
/// flow through the same lock + scheduling path as direct @State writes.
@propertyWrapper
public struct Binding<Value> {
    public let get: () -> Value
    public let set: (Value) -> Void

    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.get = get
        self.set = set
    }

    public var wrappedValue: Value {
        get { get() }
        nonmutating set { set(newValue) }
    }

    /// Projects self so `$bindingName` returns a `Binding<Value>` (SwiftUI parity).
    public var projectedValue: Binding<Value> { self }

    /// Creates a binding with an immutable value (SwiftUI-compatible).
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { _ in })
    }
}
