/// A row of cells within a Grid. Each child becomes one cell.
/// Use `.gridCellColumns(n)` on a child to span multiple columns.
public struct GridRow<Content: View>: View, MultiChildView {
    public typealias Body = Never

    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var children: [any View] {
        if let multi = content as? MultiChildView {
            return multi.children
        }
        let mirror = Mirror(reflecting: content)
        if mirror.children.isEmpty {
            return [content]
        }
        return mirror.children.compactMap { $0.value as? any View }
    }

    public var body: Never { fatalError("GridRow is a primitive view") }
}

// MARK: - Grid cell column span

/// Protocol to mark views that carry grid cell span metadata.
public protocol GridCellSpanProvider {
    var gridColumnSpan: Int { get }
}

/// A wrapper that carries column span metadata for Grid layout.
public struct GridCellSpanView<Content: View>: View, GridCellSpanProvider {
    public typealias Body = Never

    public let content: Content
    public let gridColumnSpan: Int

    public var body: Never { fatalError("GridCellSpanView is a primitive view") }
}

extension View {
    /// When inside a GridRow, this cell spans the given number of columns.
    public func gridCellColumns(_ count: Int) -> GridCellSpanView<Self> {
        GridCellSpanView(content: self, gridColumnSpan: max(1, count))
    }
}
