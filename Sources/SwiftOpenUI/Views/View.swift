/// A type that represents part of the UI.
/// Conforming types declare their body as a composition of other views.
public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}

/// A marker protocol for views that have no reactive properties (@State, etc.)
/// and can skip Mirror reflection during rendering.
public protocol PrimitiveView: View {}

/// A view that produces no content.
public struct EmptyView: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { fatalError("EmptyView has no body") }
    public init() {}
}

extension Never: View {
    public var body: Never { fatalError() }
}
