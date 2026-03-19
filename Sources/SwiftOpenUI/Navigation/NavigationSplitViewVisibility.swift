/// Controls which columns of a NavigationSplitView are visible.
public enum NavigationSplitViewVisibility: Sendable {
    /// Platform decides which columns to show.
    case automatic
    /// Show all columns.
    case all
    /// Show two columns (sidebar + detail, or sidebar + content).
    case doubleColumn
    /// Show only the detail column.
    case detailOnly
}
