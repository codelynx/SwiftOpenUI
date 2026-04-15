/// Projects `Binding<T>` values from an `@Observable` class's
/// mutable properties, matching SwiftUI's `@Bindable` property
/// wrapper introduced alongside the Observation framework.
///
/// Typical usage — a view owns an `@Observable` via
/// `@Environment(SomeClass.self)` and needs bindings for controls
/// like `TextField`:
///
/// ```swift
/// struct ContentView: View {
///     @Environment(AppState.self) var appState
///     var body: some View {
///         @Bindable var appState = appState
///         TextField("Name", text: $appState.name)
///     }
/// }
/// ```
///
/// The wrapper itself carries the object reference; `$`-prefix
/// accesses (`$appState.name`) hit the `@dynamicMemberLookup`
/// subscript, which builds a `Binding<T>` whose get/set close over
/// the underlying `ReferenceWritableKeyPath`.
///
/// Reactivity comes from the same path as a plain `@Environment`
/// read — the binding's `get` reads the property inside
/// `withObservationTracking`, so the surrounding view rebuilds on
/// mutation through the existing view-host plumbing.
@propertyWrapper
@dynamicMemberLookup
public struct Bindable<Value: AnyObject> {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    /// `$bindable` returns the `Bindable` itself so that
    /// `$bindable.property` triggers the dynamic-member subscript.
    public var projectedValue: Bindable<Value> { self }

    /// Project a `Binding<T>` to a mutable property of the wrapped
    /// object. Reads and writes both go through the object's own
    /// storage via the keypath, so they participate in the normal
    /// Observation / rebuild cycle.
    public subscript<T>(
        dynamicMember keyPath: ReferenceWritableKeyPath<Value, T>
    ) -> Binding<T> {
        let object = wrappedValue
        return Binding(
            get: { object[keyPath: keyPath] },
            set: { object[keyPath: keyPath] = $0 }
        )
    }
}
