/// A type-erased view. Use AnyView to wrap a view whose exact type
/// varies at runtime (e.g., from a conditional).
public struct AnyView: View {
    public typealias Body = Never

    public let wrapped: any View

    public init<V: View>(_ view: V) {
        self.wrapped = view
    }

    public var body: Never { fatalError("AnyView is a primitive view") }
}
