/// A type that represents part of the UI.
/// Conforming types declare their body as a composition of other views.
public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}

/// A view that produces no content.
public struct EmptyView: View {
    public typealias Body = Never
    public var body: Never { fatalError("EmptyView has no body") }
    public init() {}
}

extension Never: View {
    public var body: Never { fatalError() }
}
