/// Protocol for views that provide multiple children.
/// Parent containers (VStack, HStack) use this to enumerate children
/// individually rather than treating the view as a single opaque child.
public protocol MultiChildView {
    var children: [any View] { get }
}

/// Marker for transparent child aggregators that may be flattened by
/// ViewBuilder accumulation without changing layout semantics.
public protocol TransparentMultiChildView: MultiChildView, PrimitiveView {}

/// A flat child-list container used by ViewBuilder incremental accumulation.
public struct ViewList: View, TransparentMultiChildView {
    public typealias Body = Never

    public let children: [any View]

    public init(_ children: [any View]) {
        self.children = children
    }

    public var body: Never { fatalError("ViewList is a primitive view") }
}

/// A view that holds a variadic number of child views.
public struct TupleView<each Content: View>: View, TransparentMultiChildView {
    public typealias Body = Never

    public let value: (repeat each Content)

    public init(_ value: (repeat each Content)) {
        self.value = value
    }

    public init(_ value: repeat each Content) {
        self.value = (repeat each value)
    }

    public var body: Never { fatalError("TupleView is a primitive view") }

    public var children: [any View] {
        var result: [any View] = []
        repeat result.append(each value)
        return result
    }
}
