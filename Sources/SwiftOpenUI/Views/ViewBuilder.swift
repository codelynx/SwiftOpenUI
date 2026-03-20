/// Result builder for composing child views declaratively.
@resultBuilder
public struct ViewBuilder {
    private static func childViews(from view: any View) -> [any View] {
        if let multi = view as? TransparentMultiChildView {
            return multi.children
        }
        return [view]
    }

    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    public static func buildBlock<Content: View>(_ content: Content) -> Content {
        content
    }

    public static func buildBlock<V0: View, V1: View>(_ v0: V0, _ v1: V1) -> TupleView2<V0, V1> {
        TupleView2(v0, v1)
    }

    public static func buildBlock<V0: View, V1: View, V2: View>(_ v0: V0, _ v1: V1, _ v2: V2) -> TupleView3<V0, V1, V2> {
        TupleView3(v0, v1, v2)
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3) -> TupleView4<V0, V1, V2, V3> {
        TupleView4(v0, v1, v2, v3)
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4) -> TupleView5<V0, V1, V2, V3, V4> {
        TupleView5(v0, v1, v2, v3, v4)
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5) -> TupleView6<V0, V1, V2, V3, V4, V5> {
        TupleView6(v0, v1, v2, v3, v4, v5)
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6) -> TupleView7<V0, V1, V2, V3, V4, V5, V6> {
        TupleView7(v0, v1, v2, v3, v4, v5, v6)
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7) -> TupleView8<V0, V1, V2, V3, V4, V5, V6, V7> {
        TupleView8(v0, v1, v2, v3, v4, v5, v6, v7)
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8) -> TupleView9<V0, V1, V2, V3, V4, V5, V6, V7, V8> {
        TupleView9(v0, v1, v2, v3, v4, v5, v6, v7, v8)
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9) -> TupleView10<V0, V1, V2, V3, V4, V5, V6, V7, V8, V9> {
        TupleView10(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9)
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9, _ v10: V10) -> TupleView11<V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10> {
        TupleView11(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10)
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9, _ v10: V10, _ v11: V11) -> TupleView12<V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11> {
        TupleView12(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11)
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9, _ v10: V10, _ v11: V11, _ v12: V12) -> TupleView13<V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12> {
        TupleView13(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12)
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9, _ v10: V10, _ v11: V11, _ v12: V12, _ v13: V13) -> TupleView14<V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13> {
        TupleView14(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13)
    }

    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View, V10: View, V11: View, V12: View, V13: View, V14: View>(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9, _ v10: V10, _ v11: V11, _ v12: V12, _ v13: V13, _ v14: V14) -> TupleView15<V0, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14> {
        TupleView15(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14)
    }

    public static func buildOptional<Content: View>(_ content: Content?) -> Content? {
        content
    }

    public static func buildEither<TrueContent: View, FalseContent: View>(first: TrueContent) -> _ConditionalView<TrueContent, FalseContent> {
        .trueContent(first)
    }

    public static func buildEither<TrueContent: View, FalseContent: View>(second: FalseContent) -> _ConditionalView<TrueContent, FalseContent> {
        .falseContent(second)
    }

    public static func buildPartialBlock<Content: View>(first: Content) -> Content {
        first
    }

    public static func buildPartialBlock<Accumulated: View, Next: View>(
        accumulated: Accumulated,
        next: Next
    ) -> ViewList {
        ViewList(childViews(from: accumulated) + childViews(from: next))
    }
}

/// Represents a conditional view from if/else in a ViewBuilder.
public enum _ConditionalView<TrueContent: View, FalseContent: View>: View {
    case trueContent(TrueContent)
    case falseContent(FalseContent)

    public typealias Body = Never
    public var body: Never { fatalError("_ConditionalView is a primitive view") }
}

extension Optional: View where Wrapped: View {
    public typealias Body = Never
    public var body: Never { fatalError("Optional<View> is a primitive view") }
}
