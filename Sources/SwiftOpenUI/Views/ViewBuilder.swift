/// Result builder for composing child views declaratively.
@resultBuilder
public struct ViewBuilder {
    private static func childViews(from view: any View) -> [any View] {
        if let multi = view as? any TransparentMultiChildView {
            return multi.children
        }
        return [view]
    }

    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<repeat each Content> {
        TupleView(repeat each content)
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
public enum _ConditionalView<TrueContent: View, FalseContent: View>: View, PrimitiveView {
    case trueContent(TrueContent)
    case falseContent(FalseContent)

    public typealias Body = Never
    public var body: Never { fatalError("_ConditionalView is a primitive view") }
}

extension Optional: PrimitiveView where Wrapped: View {}

extension Optional: View where Wrapped: View {
    public typealias Body = Never
    public var body: Never { fatalError("Optional<View> is a primitive view") }
}

// MARK: - Conditional child flattening (SwiftUI stack-axis semantics)

/// The children a conditional-like wrapper contributes to an enclosing
/// container: its ACTIVE branch's children, spliced. Only TRANSPARENT
/// aggregates splice (TupleView, ViewList, nested conditionals) — a real
/// container as the branch content (`if flag { VStack { … } }`) is itself
/// `MultiChildView`, and splicing it would dissolve its layout into the
/// parent (round-2 review High finding).
private func activeBranchChildren(_ view: any View) -> [any View] {
    if let transparent = view as? any TransparentMultiChildView {
        return transparent.children
    }
    return [view]
}

/// A conditional inside a stack contributes its active branch's children
/// to the STACK'S axis (SwiftUI semantics). Without this, backends
/// rendered the conditional as one opaque child, and a multi-statement
/// branch fell into the generic multi-child fallback — a vertical box —
/// so `HStack { if … }` laid out vertically (found by the librano
/// shared-IssuesListView pilot: the issue-list summary bar stacked).
/// Transparent conformance also lets ViewBuilder accumulation splice
/// branch children when a conditional sits among other siblings; the
/// body re-evaluates on every state change, so the active branch is
/// always the one spliced. Bare rendering is unchanged — every backend
/// dispatches to its Renderable conformance before consulting
/// MultiChildView.
extension _ConditionalView: TransparentMultiChildView {
    public var children: [any View] {
        switch self {
        case .trueContent(let view): return activeBranchChildren(view)
        case .falseContent(let view): return activeBranchChildren(view)
        }
    }
}

/// `if` without `else` builds an Optional: `.none` contributes no
/// children at all (SwiftUI parity — previously it rendered an empty
/// box, which still consumed stack spacing).
extension Optional: MultiChildView, TransparentMultiChildView where Wrapped: View {
    public var children: [any View] {
        switch self {
        case .some(let view): return activeBranchChildren(view)
        case .none: return []
        }
    }
}
