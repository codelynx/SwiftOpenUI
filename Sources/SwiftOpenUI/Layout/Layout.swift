/// A size proposal for layout.
public struct ProposedViewSize: Equatable {
    public var width: Double?
    public var height: Double?

    public init(width: Double? = nil, height: Double? = nil) {
        self.width = width
        self.height = height
    }

    public static let zero = ProposedViewSize(width: 0, height: 0)
    public static let infinity = ProposedViewSize(width: .infinity, height: .infinity)
    public static let unspecified = ProposedViewSize()
}

/// A concrete size value.
public struct ViewSize: Equatable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let zero = ViewSize(width: 0, height: 0)
}
