/// A grid layout that arranges children in rows and columns.
///
/// ```swift
/// Grid {
///     GridRow {
///         Text("A1"); Text("A2"); Text("A3")
///     }
///     GridRow {
///         Text("B1"); Text("B2"); Text("B3")
///     }
/// }
/// ```
public struct Grid<Content: View>: View {
    public typealias Body = Never

    public let alignment: Alignment
    public let horizontalSpacing: Int
    public let verticalSpacing: Int
    public let content: Content

    public init(alignment: Alignment = .center,
                horizontalSpacing: Int = 4, verticalSpacing: Int = 4,
                @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content()
    }

    public var body: Never { fatalError("Grid is a primitive view") }
}

/// A single row within a Grid.
public struct GridRow<Content: View>: View, MultiChildView {
    public typealias Body = Never

    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Never { fatalError("GridRow is a primitive view") }

    public var children: [any View] {
        if let multi = content as? MultiChildView {
            return multi.children
        }
        return [content]
    }
}

/// A lazy vertical grid.
///
/// Current implementation: renders all children (non-virtualized).
public struct LazyVGrid<Content: View>: View {
    public typealias Body = Never

    public let columns: [GridItem]
    public let spacing: Int
    public let content: Content

    public init(columns: [GridItem], spacing: Int = 4,
                @ViewBuilder content: () -> Content) {
        self.columns = columns
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError("LazyVGrid is a primitive view") }
}

/// A lazy horizontal grid.
///
/// Current implementation: renders all children (non-virtualized).
public struct LazyHGrid<Content: View>: View {
    public typealias Body = Never

    public let rows: [GridItem]
    public let spacing: Int
    public let content: Content

    public init(rows: [GridItem], spacing: Int = 4,
                @ViewBuilder content: () -> Content) {
        self.rows = rows
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError("LazyHGrid is a primitive view") }
}

/// Describes the size of a grid column or row.
public struct GridItem {
    public enum Size {
        case fixed(Double)
        case flexible(minimum: Double, maximum: Double)
        case adaptive(minimum: Double, maximum: Double)
    }

    public let size: Size
    public let spacing: Double?

    public init(_ size: Size = .flexible(minimum: 10, maximum: .infinity),
                spacing: Double? = nil) {
        self.size = size
        self.spacing = spacing
    }

    /// Convenience for fixed-width columns.
    public static func fixed(_ width: Double) -> GridItem {
        GridItem(.fixed(width))
    }

    /// Convenience for flexible columns.
    public static func flexible(minimum: Double = 10, maximum: Double = .infinity) -> GridItem {
        GridItem(.flexible(minimum: minimum, maximum: maximum))
    }
}
