/// Placement for toolbar items.
public enum ToolbarItemPlacement {
    /// Leading edge of the toolbar (left on LTR).
    case navigationBarLeading
    /// Trailing edge of the toolbar (right on LTR).
    case navigationBarTrailing
    /// Default placement (trailing).
    case automatic
}

/// A single toolbar item with placement and content.
public struct ToolbarItem<Content: View> {
    public let placement: ToolbarItemPlacement
    public let content: Content

    public init(placement: ToolbarItemPlacement = .automatic,
                @ViewBuilder content: () -> Content) {
        self.placement = placement
        self.content = content()
    }
}

/// A view with toolbar items attached.
public struct ToolbarView<Content: View, Items: View>: View {
    public typealias Body = Never

    public let content: Content
    public let items: Items

    public var body: Never { fatalError("ToolbarView is a primitive view") }
}

extension View {
    /// Add toolbar items to this view's navigation bar.
    public func toolbar<Items: View>(@ViewBuilder items: () -> Items) -> ToolbarView<Self, Items> {
        ToolbarView(content: self, items: items())
    }
}
