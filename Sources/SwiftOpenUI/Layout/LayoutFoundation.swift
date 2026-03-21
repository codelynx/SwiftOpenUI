/// A backend-provided handle representing a child participating in layout.
public struct LayoutSubview: Equatable, Hashable {
    public var index: Int

    public init(index: Int) {
        self.index = index
    }
}

/// The measured result for a child under a particular size proposal.
public struct LayoutMeasurement: Equatable {
    public var size: ViewSize
    public var expandsToFillWidth: Bool
    public var expandsToFillHeight: Bool

    public init(
        size: ViewSize,
        expandsToFillWidth: Bool = false,
        expandsToFillHeight: Bool = false
    ) {
        self.size = size
        self.expandsToFillWidth = expandsToFillWidth
        self.expandsToFillHeight = expandsToFillHeight
    }
}

/// Backend adapter contract for shared layout code to measure child subviews.
public protocol LayoutMeasureContext {
    func measure(_ subview: LayoutSubview, proposal: ProposedViewSize) -> LayoutMeasurement
}
