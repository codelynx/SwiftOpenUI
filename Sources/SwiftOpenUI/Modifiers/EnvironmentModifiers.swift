/// A view that injects an ObservableObject into the environment for descendant views.
public struct EnvironmentObjectModifierView<Content: View, ObjectType: ObservableObject>: View {
    public typealias Body = Never

    public let content: Content
    public let object: ObjectType

    public var body: Never { fatalError("EnvironmentObjectModifierView is a primitive view") }
}

/// A view that injects an arbitrary reference-typed object (typically
/// an `@Observable` class) into the environment for descendant views.
/// Parallel to `EnvironmentObjectModifierView`, but without the
/// `ObservableObject` constraint, so descendants can read via
/// `@Environment(T.self)` matching SwiftUI's Observation-era API.
public struct EnvironmentObservableModifierView<Content: View, ObjectType: AnyObject>: View {
    public typealias Body = Never

    public let content: Content
    public let object: ObjectType

    public var body: Never { fatalError("EnvironmentObservableModifierView is a primitive view") }
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

    /// Inject a reference-typed object (typically `@Observable`) into
    /// the environment for descendant views. Descendants access it via
    /// `@Environment(T.self) var obj: T`, matching SwiftUI's
    /// Observation-era API. Use this instead of `environmentObject(_:)`
    /// for `@Observable` classes.
    public func environment<T: AnyObject>(_ object: T) -> EnvironmentObservableModifierView<Self, T> {
        EnvironmentObservableModifierView(content: self, object: object)
    }
}
