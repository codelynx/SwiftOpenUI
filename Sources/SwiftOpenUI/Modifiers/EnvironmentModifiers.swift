/// A view that injects an ObservableObject into the environment for descendant views.
public struct EnvironmentObjectModifierView<Content: View, ObjectType: ObservableObject>: View {
    public typealias Body = Never

    public let content: Content
    public let object: ObjectType

    public var body: Never { fatalError("EnvironmentObjectModifierView is a primitive view") }
}

/// A view that injects an environment value for descendant views.
public struct EnvironmentModifierView<Content: View, V>: View {
    public typealias Body = Never

    public let content: Content
    public let keyPath: WritableKeyPath<EnvironmentValues, V>
    public let value: V

    public var body: Never { fatalError("EnvironmentModifierView is a primitive view") }
}

extension View {
    /// Inject an ObservableObject into the environment for descendant views.
    /// Descendants access it via `@EnvironmentObject var obj: T`.
    public func environmentObject<T: ObservableObject>(_ object: T) -> EnvironmentObjectModifierView<Self, T> {
        EnvironmentObjectModifierView(content: self, object: object)
    }

    /// Set an environment value for descendant views.
    public func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> EnvironmentModifierView<Self, V> {
        EnvironmentModifierView(content: self, keyPath: keyPath, value: value)
    }
}
