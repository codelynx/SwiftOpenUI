/// Describes a single column (LazyVGrid) or row (LazyHGrid) in a lazy grid.
///
/// Since GtkGridView controls grid layout via min/max column counts
/// (not per-column sizing), `GridItem` primarily conveys the desired
/// column count and adaptive behavior.
public struct GridItem {
    public enum Size {
        /// Fixed column count (array length = column count).
        case fixed
        /// Flexible column count (array length = column count).
        case flexible
        /// Adaptive: as many columns as fit, each cell at least `minimum` pixels wide.
        case adaptive(minimum: Double)
    }

    public let size: Size

    public init(_ size: Size = .flexible) {
        self.size = size
    }
}

/// A lazy vertical grid that only renders visible items.
public struct LazyVGrid<Data, Content: View>: View {
    public typealias Body = Never

    public let items: [Data]
    public let contentBuilder: (Data) -> Content
    public let gridItems: [GridItem]

    public var body: Never { fatalError("LazyVGrid is a primitive view") }
}

extension LazyVGrid {
    /// Create with explicit GridItem columns.
    public init(columns: [GridItem], data: [Data],
                @ViewBuilder content: @escaping (Data) -> Content) {
        self.gridItems = columns
        self.items = data
        self.contentBuilder = content
    }

    /// Create with a fixed column count.
    public init(columns: Int, data: [Data],
                @ViewBuilder content: @escaping (Data) -> Content) {
        self.gridItems = Array(repeating: GridItem(.fixed), count: max(1, columns))
        self.items = data
        self.contentBuilder = content
    }
}

/// A lazy horizontal grid that only renders visible items.
public struct LazyHGrid<Data, Content: View>: View {
    public typealias Body = Never

    public let items: [Data]
    public let contentBuilder: (Data) -> Content
    public let gridItems: [GridItem]

    public var body: Never { fatalError("LazyHGrid is a primitive view") }
}

extension LazyHGrid {
    /// Create with explicit GridItem rows.
    public init(rows: [GridItem], data: [Data],
                @ViewBuilder content: @escaping (Data) -> Content) {
        self.gridItems = rows
        self.items = data
        self.contentBuilder = content
    }

    /// Create with a fixed row count.
    public init(rows: Int, data: [Data],
                @ViewBuilder content: @escaping (Data) -> Content) {
        self.gridItems = Array(repeating: GridItem(.fixed), count: max(1, rows))
        self.items = data
        self.contentBuilder = content
    }
}
