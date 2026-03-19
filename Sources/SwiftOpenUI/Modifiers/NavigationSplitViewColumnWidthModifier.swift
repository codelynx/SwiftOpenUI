/// Protocol for extracting column width constraints from a view.
public protocol NavigationSplitViewColumnWidthProvider {
    var columnMinWidth: Double? { get }
    var columnIdealWidth: Double? { get }
    var columnMaxWidth: Double? { get }
}

/// A view with column width constraints for NavigationSplitView.
public struct NavigationSplitViewColumnWidthView<Content: View>: View, NavigationSplitViewColumnWidthProvider {
    public typealias Body = Never

    public let content: Content
    public let columnMinWidth: Double?
    public let columnIdealWidth: Double?
    public let columnMaxWidth: Double?

    public var body: Never { fatalError("NavigationSplitViewColumnWidthView is a primitive view") }
}

extension View {
    /// Set preferred column width with min/ideal/max constraints.
    public func navigationSplitViewColumnWidth(
        min: Double? = nil,
        ideal: Double,
        max: Double? = nil
    ) -> NavigationSplitViewColumnWidthView<Self> {
        NavigationSplitViewColumnWidthView(
            content: self,
            columnMinWidth: min,
            columnIdealWidth: ideal,
            columnMaxWidth: max
        )
    }

    /// Set a fixed column width.
    /// Note: on GTK4, GtkPaned remains user-resizable — this sets the
    /// initial position and minimum width but cannot lock the divider.
    public func navigationSplitViewColumnWidth(
        _ width: Double
    ) -> NavigationSplitViewColumnWidthView<Self> {
        NavigationSplitViewColumnWidthView(
            content: self,
            columnMinWidth: width,
            columnIdealWidth: width,
            columnMaxWidth: width
        )
    }
}
