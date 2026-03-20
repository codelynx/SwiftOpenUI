/// Protocol for views that provide multiple children.
/// Parent containers (VStack, HStack) use this to enumerate children
/// individually rather than treating the view as a single opaque child.
public protocol MultiChildView {
    var children: [any View] { get }
}

/// Marker for transparent child aggregators that may be flattened by
/// ViewBuilder accumulation without changing layout semantics.
public protocol TransparentMultiChildView: MultiChildView {}

/// A flat child-list container used by ViewBuilder incremental accumulation.
public struct ViewList: View, TransparentMultiChildView {
    public typealias Body = Never

    public let children: [any View]

    public init(_ children: [any View]) {
        self.children = children
    }

    public var body: Never { fatalError("ViewList is a primitive view") }
}

/// A view that holds two child views.
public struct TupleView2<V0: View, V1: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0
    public let v1: V1

    public init(_ v0: V0, _ v1: V1) {
        self.v0 = v0
        self.v1 = v1
    }

    public var body: Never { fatalError("TupleView2 is a primitive view") }

    public var children: [any View] { [v0, v1] }
}

/// A view that holds three child views.
public struct TupleView3<V0: View, V1: View, V2: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0; public let v1: V1; public let v2: V2

    public init(_ v0: V0, _ v1: V1, _ v2: V2) {
        self.v0 = v0; self.v1 = v1; self.v2 = v2
    }

    public var body: Never { fatalError("TupleView3 is a primitive view") }

    public var children: [any View] { [v0, v1, v2] }
}

/// A view that holds four child views.
public struct TupleView4<V0: View, V1: View, V2: View, V3: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0; public let v1: V1; public let v2: V2; public let v3: V3

    public init(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3) {
        self.v0 = v0; self.v1 = v1; self.v2 = v2; self.v3 = v3
    }

    public var body: Never { fatalError("TupleView4 is a primitive view") }

    public var children: [any View] { [v0, v1, v2, v3] }
}

/// A view that holds five child views.
public struct TupleView5<V0: View, V1: View, V2: View, V3: View, V4: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0; public let v1: V1; public let v2: V2; public let v3: V3; public let v4: V4

    public init(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4) {
        self.v0 = v0; self.v1 = v1; self.v2 = v2; self.v3 = v3; self.v4 = v4
    }

    public var body: Never { fatalError("TupleView5 is a primitive view") }

    public var children: [any View] { [v0, v1, v2, v3, v4] }
}

/// A view that holds six child views.
public struct TupleView6<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0; public let v1: V1; public let v2: V2; public let v3: V3; public let v4: V4; public let v5: V5

    public init(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5) {
        self.v0 = v0; self.v1 = v1; self.v2 = v2; self.v3 = v3; self.v4 = v4; self.v5 = v5
    }

    public var body: Never { fatalError("TupleView6 is a primitive view") }

    public var children: [any View] { [v0, v1, v2, v3, v4, v5] }
}

/// A view that holds seven child views.
public struct TupleView7<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0; public let v1: V1; public let v2: V2; public let v3: V3; public let v4: V4; public let v5: V5; public let v6: V6

    public init(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6) {
        self.v0 = v0; self.v1 = v1; self.v2 = v2; self.v3 = v3; self.v4 = v4; self.v5 = v5; self.v6 = v6
    }

    public var body: Never { fatalError("TupleView7 is a primitive view") }

    public var children: [any View] { [v0, v1, v2, v3, v4, v5, v6] }
}

/// A view that holds eight child views.
public struct TupleView8<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0; public let v1: V1; public let v2: V2; public let v3: V3; public let v4: V4; public let v5: V5; public let v6: V6; public let v7: V7

    public init(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7) {
        self.v0 = v0; self.v1 = v1; self.v2 = v2; self.v3 = v3; self.v4 = v4; self.v5 = v5; self.v6 = v6; self.v7 = v7
    }

    public var body: Never { fatalError("TupleView8 is a primitive view") }

    public var children: [any View] { [v0, v1, v2, v3, v4, v5, v6, v7] }
}

/// A view that holds nine child views.
public struct TupleView9<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0; public let v1: V1; public let v2: V2; public let v3: V3; public let v4: V4; public let v5: V5; public let v6: V6; public let v7: V7; public let v8: V8

    public init(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8) {
        self.v0 = v0; self.v1 = v1; self.v2 = v2; self.v3 = v3; self.v4 = v4; self.v5 = v5; self.v6 = v6; self.v7 = v7; self.v8 = v8
    }

    public var body: Never { fatalError("TupleView9 is a primitive view") }

    public var children: [any View] { [v0, v1, v2, v3, v4, v5, v6, v7, v8] }
}

/// A view that holds ten child views.
public struct TupleView10<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0; public let v1: V1; public let v2: V2; public let v3: V3; public let v4: V4; public let v5: V5; public let v6: V6; public let v7: V7; public let v8: V8; public let v9: V9

    public init(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9) {
        self.v0 = v0; self.v1 = v1; self.v2 = v2; self.v3 = v3; self.v4 = v4; self.v5 = v5; self.v6 = v6; self.v7 = v7; self.v8 = v8; self.v9 = v9
    }

    public var body: Never { fatalError("TupleView10 is a primitive view") }

    public var children: [any View] { [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9] }
}

/// A view that holds eleven child views.
public struct TupleView11<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0; public let v1: V1; public let v2: V2; public let v3: V3; public let v4: V4; public let v5: V5; public let v6: V6; public let v7: V7; public let v8: V8; public let v9: V9; public let v10: V10

    public init(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9, _ v10: V10) {
        self.v0 = v0; self.v1 = v1; self.v2 = v2; self.v3 = v3; self.v4 = v4; self.v5 = v5; self.v6 = v6; self.v7 = v7; self.v8 = v8; self.v9 = v9; self.v10 = v10
    }

    public var body: Never { fatalError("TupleView11 is a primitive view") }

    public var children: [any View] { [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10] }
}

/// A view that holds twelve child views.
public struct TupleView12<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0; public let v1: V1; public let v2: V2; public let v3: V3; public let v4: V4; public let v5: V5; public let v6: V6; public let v7: V7; public let v8: V8; public let v9: V9; public let v10: V10; public let v11: V11

    public init(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9, _ v10: V10, _ v11: V11) {
        self.v0 = v0; self.v1 = v1; self.v2 = v2; self.v3 = v3; self.v4 = v4; self.v5 = v5; self.v6 = v6; self.v7 = v7; self.v8 = v8; self.v9 = v9; self.v10 = v10; self.v11 = v11
    }

    public var body: Never { fatalError("TupleView12 is a primitive view") }

    public var children: [any View] { [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11] }
}

/// A view that holds thirteen child views.
public struct TupleView13<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0; public let v1: V1; public let v2: V2; public let v3: V3; public let v4: V4; public let v5: V5; public let v6: V6; public let v7: V7; public let v8: V8; public let v9: V9; public let v10: V10; public let v11: V11; public let v12: V12

    public init(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9, _ v10: V10, _ v11: V11, _ v12: V12) {
        self.v0 = v0; self.v1 = v1; self.v2 = v2; self.v3 = v3; self.v4 = v4; self.v5 = v5; self.v6 = v6; self.v7 = v7; self.v8 = v8; self.v9 = v9; self.v10 = v10; self.v11 = v11; self.v12 = v12
    }

    public var body: Never { fatalError("TupleView13 is a primitive view") }

    public var children: [any View] { [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12] }
}

/// A view that holds fourteen child views.
public struct TupleView14<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0; public let v1: V1; public let v2: V2; public let v3: V3; public let v4: V4; public let v5: V5; public let v6: V6; public let v7: V7; public let v8: V8; public let v9: V9; public let v10: V10; public let v11: V11; public let v12: V12; public let v13: V13

    public init(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9, _ v10: V10, _ v11: V11, _ v12: V12, _ v13: V13) {
        self.v0 = v0; self.v1 = v1; self.v2 = v2; self.v3 = v3; self.v4 = v4; self.v5 = v5; self.v6 = v6; self.v7 = v7; self.v8 = v8; self.v9 = v9; self.v10 = v10; self.v11 = v11; self.v12 = v12; self.v13 = v13
    }

    public var body: Never { fatalError("TupleView14 is a primitive view") }

    public var children: [any View] { [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13] }
}

/// A view that holds fifteen child views.
public struct TupleView15<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View>: View, TransparentMultiChildView {
    public typealias Body = Never
    public let v0: V0; public let v1: V1; public let v2: V2; public let v3: V3; public let v4: V4; public let v5: V5; public let v6: V6; public let v7: V7; public let v8: V8; public let v9: V9; public let v10: V10; public let v11: V11; public let v12: V12; public let v13: V13; public let v14: V14

    public init(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9, _ v10: V10, _ v11: V11, _ v12: V12, _ v13: V13, _ v14: V14) {
        self.v0 = v0; self.v1 = v1; self.v2 = v2; self.v3 = v3; self.v4 = v4; self.v5 = v5; self.v6 = v6; self.v7 = v7; self.v8 = v8; self.v9 = v9; self.v10 = v10; self.v11 = v11; self.v12 = v12; self.v13 = v13; self.v14 = v14
    }

    public var body: Never { fatalError("TupleView15 is a primitive view") }

    public var children: [any View] { [v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14] }
}
