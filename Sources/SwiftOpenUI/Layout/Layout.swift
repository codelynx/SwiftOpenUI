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

/// A concrete origin point in a container coordinate space.
public struct ViewPoint: Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = ViewPoint(x: 0, y: 0)
}

/// The resolved size and placement of a child within a container.
public struct LayoutPlacement: Equatable {
    public var origin: ViewPoint
    public var size: ViewSize

    public init(origin: ViewPoint, size: ViewSize) {
        self.origin = origin
        self.size = size
    }
}

/// Shared layout result for a fixed/flexible frame.
public struct FrameLayoutResult: Equatable {
    public var containerSize: ViewSize
    public var childPlacement: LayoutPlacement

    public init(containerSize: ViewSize, childPlacement: LayoutPlacement) {
        self.containerSize = containerSize
        self.childPlacement = childPlacement
    }
}

/// Shared layout result for stack containers.
public struct StackLayoutResult: Equatable {
    public var containerSize: ViewSize
    public var childPlacements: [LayoutPlacement]

    public init(containerSize: ViewSize, childPlacements: [LayoutPlacement]) {
        self.containerSize = containerSize
        self.childPlacements = childPlacements
    }
}

/// Resolve shared SwiftUI-like frame sizing and child alignment.
public func computeFrameLayout(
    childNaturalSize: ViewSize,
    width: Double? = nil,
    height: Double? = nil,
    minWidth: Double? = nil,
    minHeight: Double? = nil,
    maxWidth: Double? = nil,
    maxHeight: Double? = nil,
    alignment: Alignment = .center,
    expandsToFillWidth: Bool = false,
    expandsToFillHeight: Bool = false
) -> FrameLayoutResult {
    var containerWidth = childNaturalSize.width
    var containerHeight = childNaturalSize.height

    if let width { containerWidth = width }
    if let height { containerHeight = height }
    if let minWidth { containerWidth = max(containerWidth, minWidth) }
    if let minHeight { containerHeight = max(containerHeight, minHeight) }
    if let maxWidth, maxWidth != .infinity { containerWidth = min(containerWidth, maxWidth) }
    if let maxHeight, maxHeight != .infinity { containerHeight = min(containerHeight, maxHeight) }

    let childWidth = expandsToFillWidth ? containerWidth : min(childNaturalSize.width, containerWidth)
    let childHeight = expandsToFillHeight ? containerHeight : min(childNaturalSize.height, containerHeight)
    let childSize = ViewSize(width: childWidth, height: childHeight)

    return FrameLayoutResult(
        containerSize: ViewSize(width: containerWidth, height: containerHeight),
        childPlacement: LayoutPlacement(
            origin: frameChildOrigin(
                containerSize: ViewSize(width: containerWidth, height: containerHeight),
                childSize: childSize,
                alignment: alignment
            ),
            size: childSize
        )
    )
}

private func frameChildOrigin(
    containerSize: ViewSize,
    childSize: ViewSize,
    alignment: Alignment
) -> ViewPoint {
    let remainingX = max(0, containerSize.width - childSize.width)
    let remainingY = max(0, containerSize.height - childSize.height)

    switch alignment {
    case .topLeading:
        return ViewPoint(x: 0, y: 0)
    case .top:
        return ViewPoint(x: remainingX / 2, y: 0)
    case .topTrailing:
        return ViewPoint(x: remainingX, y: 0)
    case .leading:
        return ViewPoint(x: 0, y: remainingY / 2)
    case .center:
        return ViewPoint(x: remainingX / 2, y: remainingY / 2)
    case .trailing:
        return ViewPoint(x: remainingX, y: remainingY / 2)
    case .bottomLeading:
        return ViewPoint(x: 0, y: remainingY)
    case .bottom:
        return ViewPoint(x: remainingX / 2, y: remainingY)
    case .bottomTrailing:
        return ViewPoint(x: remainingX, y: remainingY)
    }
}

private func measureSubviewSizes(
    _ subviews: [LayoutSubview],
    context: some LayoutMeasureContext,
    proposal: ProposedViewSize = .unspecified
) -> [ViewSize] {
    subviews.map { subview in
        context.measure(subview, proposal: proposal).size
    }
}

/// Resolve shared SwiftUI-like vertical stack sizing and child placement.
public func computeVStackLayout(
    subviews: [LayoutSubview],
    context: some LayoutMeasureContext,
    spacing: Double = 0,
    alignment: HorizontalAlignment = .center
) -> StackLayoutResult {
    return computeVStackLayout(
        childSizes: measureSubviewSizes(subviews, context: context),
        spacing: spacing,
        alignment: alignment
    )
}

/// Resolve shared SwiftUI-like vertical stack sizing and child placement.
public func computeVStackLayout(
    childSizes: [ViewSize],
    spacing: Double = 0,
    alignment: HorizontalAlignment = .center
) -> StackLayoutResult {
    let containerWidth = childSizes.map(\.width).max() ?? 0
    let totalSpacing = max(0, Double(max(0, childSizes.count - 1))) * spacing
    let containerHeight = childSizes.reduce(0) { $0 + $1.height } + totalSpacing

    var y = 0.0
    let placements = childSizes.map { childSize in
        let x: Double
        switch alignment {
        case .leading:
            x = 0
        case .center:
            x = max(0, (containerWidth - childSize.width) / 2)
        case .trailing:
            x = max(0, containerWidth - childSize.width)
        }

        let placement = LayoutPlacement(
            origin: ViewPoint(x: x, y: y),
            size: childSize
        )
        y += childSize.height + spacing
        return placement
    }

    return StackLayoutResult(
        containerSize: ViewSize(width: containerWidth, height: containerHeight),
        childPlacements: placements
    )
}

/// Resolve shared SwiftUI-like horizontal stack sizing and child placement.
public func computeHStackLayout(
    subviews: [LayoutSubview],
    context: some LayoutMeasureContext,
    spacing: Double = 0,
    alignment: VerticalAlignment = .center
) -> StackLayoutResult {
    return computeHStackLayout(
        childSizes: measureSubviewSizes(subviews, context: context),
        spacing: spacing,
        alignment: alignment
    )
}

/// Resolve shared SwiftUI-like horizontal stack sizing and child placement.
public func computeHStackLayout(
    childSizes: [ViewSize],
    spacing: Double = 0,
    alignment: VerticalAlignment = .center
) -> StackLayoutResult {
    let containerHeight = childSizes.map(\.height).max() ?? 0
    let totalSpacing = max(0, Double(max(0, childSizes.count - 1))) * spacing
    let containerWidth = childSizes.reduce(0) { $0 + $1.width } + totalSpacing

    var x = 0.0
    let placements = childSizes.map { childSize in
        let y: Double
        switch alignment {
        case .top:
            y = 0
        case .center:
            y = max(0, (containerHeight - childSize.height) / 2)
        case .bottom:
            y = max(0, containerHeight - childSize.height)
        }

        let placement = LayoutPlacement(
            origin: ViewPoint(x: x, y: y),
            size: childSize
        )
        x += childSize.width + spacing
        return placement
    }

    return StackLayoutResult(
        containerSize: ViewSize(width: containerWidth, height: containerHeight),
        childPlacements: placements
    )
}

/// Resolve shared SwiftUI-like z-stack sizing and child placement.
public func computeZStackLayout(
    subviews: [LayoutSubview],
    context: some LayoutMeasureContext,
    alignment: Alignment = .center
) -> StackLayoutResult {
    return computeZStackLayout(
        childSizes: measureSubviewSizes(subviews, context: context),
        alignment: alignment
    )
}

/// Resolve shared SwiftUI-like z-stack sizing and child placement.
public func computeZStackLayout(
    childSizes: [ViewSize],
    alignment: Alignment = .center
) -> StackLayoutResult {
    let containerSize = ViewSize(
        width: childSizes.map(\.width).max() ?? 0,
        height: childSizes.map(\.height).max() ?? 0
    )

    let placements = childSizes.map { childSize in
        LayoutPlacement(
            origin: frameChildOrigin(
                containerSize: containerSize,
                childSize: childSize,
                alignment: alignment
            ),
            size: childSize
        )
    }

    return StackLayoutResult(
        containerSize: containerSize,
        childPlacements: placements
    )
}

/// Resolve shared SwiftUI-like auto-wrapping grid sizing and child placement.
public func computeGridLayout(
    subviews: [LayoutSubview],
    context: some LayoutMeasureContext,
    columns: Int,
    hSpacing: Double = 0,
    vSpacing: Double = 0
) -> StackLayoutResult {
    return computeGridLayout(
        childSizes: measureSubviewSizes(subviews, context: context),
        columns: columns,
        hSpacing: hSpacing,
        vSpacing: vSpacing
    )
}

/// Resolve shared SwiftUI-like auto-wrapping grid sizing and child placement.
public func computeGridLayout(
    childSizes: [ViewSize],
    columns: Int,
    hSpacing: Double = 0,
    vSpacing: Double = 0
) -> StackLayoutResult {
    guard !childSizes.isEmpty else {
        return StackLayoutResult(containerSize: .zero, childPlacements: [])
    }

    let columnCount = max(1, min(columns, childSizes.count))
    let rowCount = (childSizes.count + columnCount - 1) / columnCount
    var columnWidths = Array(repeating: 0.0, count: columnCount)
    var rowHeights = Array(repeating: 0.0, count: rowCount)

    for (index, childSize) in childSizes.enumerated() {
        let row = index / columnCount
        let column = index % columnCount
        columnWidths[column] = max(columnWidths[column], childSize.width)
        rowHeights[row] = max(rowHeights[row], childSize.height)
    }

    let containerWidth = columnWidths.reduce(0, +) + (Double(columnCount - 1) * hSpacing)
    let containerHeight = rowHeights.reduce(0, +) + (Double(rowCount - 1) * vSpacing)

    let placements = childSizes.enumerated().map { index, childSize in
        let row = index / columnCount
        let column = index % columnCount
        let x = columnWidths.prefix(column).reduce(0, +) + (Double(column) * hSpacing)
        let y = rowHeights.prefix(row).reduce(0, +) + (Double(row) * vSpacing)
        return LayoutPlacement(
            origin: ViewPoint(x: x, y: y),
            size: childSize
        )
    }

    return StackLayoutResult(
        containerSize: ViewSize(width: containerWidth, height: containerHeight),
        childPlacements: placements
    )
}

/// Resolve shared SwiftUI-like explicit-row grid sizing and child placement
/// using homogeneous columns with optional column spans.
public func computeExplicitGridLayout(
    rows: [[(subview: LayoutSubview, columnSpan: Int)]],
    context: some LayoutMeasureContext,
    hSpacing: Double = 0,
    vSpacing: Double = 0
) -> StackLayoutResult {
    let measuredRows = rows.map { row in
        let sizes = measureSubviewSizes(row.map(\.subview), context: context)
        return zip(row, sizes).map { cell, size in
            (
                size: size,
                columnSpan: cell.columnSpan
            )
        }
    }
    return computeExplicitGridLayout(
        rows: measuredRows,
        hSpacing: hSpacing,
        vSpacing: vSpacing
    )
}

/// Resolve shared SwiftUI-like explicit-row grid sizing and child placement
/// using homogeneous columns with optional column spans.
public func computeExplicitGridLayout(
    rows: [[(size: ViewSize, columnSpan: Int)]],
    hSpacing: Double = 0,
    vSpacing: Double = 0
) -> StackLayoutResult {
    guard !rows.isEmpty else {
        return StackLayoutResult(containerSize: .zero, childPlacements: [])
    }

    let normalizedRows = rows.map { row in
        row.map { (size: $0.size, columnSpan: max(1, $0.columnSpan)) }
    }
    let columnCount = max(
        1,
        normalizedRows.map { row in row.reduce(0) { $0 + $1.columnSpan } }.max() ?? 1
    )
    let baseColumnWidth = normalizedRows
        .flatMap { row in
            row.map { cell in
                let span = max(1, cell.columnSpan)
                return (cell.size.width - (Double(span - 1) * hSpacing)) / Double(span)
            }
        }
        .max() ?? 0

    let rowHeights = normalizedRows.map { row in
        row.map { $0.size.height }.max() ?? 0
    }
    let containerWidth = (Double(columnCount) * baseColumnWidth) + (Double(columnCount - 1) * hSpacing)
    let containerHeight = rowHeights.reduce(0, +) + (Double(max(0, rowHeights.count - 1)) * vSpacing)

    var placements: [LayoutPlacement] = []
    var y = 0.0
    for (rowIndex, row) in normalizedRows.enumerated() {
        var column = 0
        for cell in row {
            let x = (Double(column) * baseColumnWidth) + (Double(column) * hSpacing)
            let width = (Double(cell.columnSpan) * baseColumnWidth) + (Double(cell.columnSpan - 1) * hSpacing)
            placements.append(
                LayoutPlacement(
                    origin: ViewPoint(x: x, y: y),
                    size: ViewSize(width: width, height: rowHeights[rowIndex])
                )
            )
            column += cell.columnSpan
        }
        y += rowHeights[rowIndex] + vSpacing
    }

    return StackLayoutResult(
        containerSize: ViewSize(width: containerWidth, height: containerHeight),
        childPlacements: placements
    )
}

/// Shared layout result for lazy grid configuration.
public struct LazyGridConfiguration: Equatable {
    public var minColumns: Int
    public var maxColumns: Int
    public var adaptiveMinimum: Int

    public init(minColumns: Int, maxColumns: Int, adaptiveMinimum: Int) {
        self.minColumns = minColumns
        self.maxColumns = maxColumns
        self.adaptiveMinimum = adaptiveMinimum
    }
}

/// Shared policy for interpreting GridItem metadata in lazy grids.
public func computeLazyGridConfiguration(
    gridItems: [GridItem]
) -> LazyGridConfiguration {
    guard !gridItems.isEmpty else {
        return LazyGridConfiguration(minColumns: 1, maxColumns: 7, adaptiveMinimum: 0)
    }

    let adaptiveMinimum = gridItems.reduce(0) { current, item in
        switch item.size {
        case .adaptive(let minimum) where minimum > 0:
            return Int(minimum)
        default:
            return current
        }
    }

    if adaptiveMinimum > 0 {
        return LazyGridConfiguration(
            minColumns: 1,
            maxColumns: 100,
            adaptiveMinimum: adaptiveMinimum
        )
    }

    return LazyGridConfiguration(
        minColumns: gridItems.count,
        maxColumns: gridItems.count,
        adaptiveMinimum: 0
    )
}
