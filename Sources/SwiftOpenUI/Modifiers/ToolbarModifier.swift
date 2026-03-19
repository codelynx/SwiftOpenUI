/// Placement for toolbar items.
public enum ToolbarItemPlacement {
    case leading
    case trailing
    case primaryAction
}

/// A single toolbar item with placement and content.
public struct ToolbarItem<Content: View>: View {
    public typealias Body = Never

    public let placement: ToolbarItemPlacement
    public let content: Content

    public init(placement: ToolbarItemPlacement = .primaryAction,
                @ViewBuilder content: () -> Content) {
        self.placement = placement
        self.content = content()
    }

    public var body: Never { fatalError("ToolbarItem is a primitive view") }
}

/// Type-erased toolbar item.
public struct AnyToolbarItem {
    public let placement: ToolbarItemPlacement
    public let wrapped: any View

    public init<Content: View>(_ item: ToolbarItem<Content>) {
        self.placement = item.placement
        self.wrapped = item.content
    }
}

/// Protocol for views that carry toolbar items (for NavigationStack extraction).
public protocol ToolbarProvider {
    var toolbarItems: [AnyToolbarItem] { get }
}

/// A view that carries toolbar items alongside its content.
public struct ToolbarView<Content: View>: View, ToolbarProvider {
    public typealias Body = Never

    public let content: Content
    public let toolbarItems: [AnyToolbarItem]

    public var body: Never { fatalError("ToolbarView is a primitive view") }
}

extension View {
    /// Adds a single toolbar item.
    public func toolbar<V: View>(
        @ViewBuilder content: () -> ToolbarItem<V>
    ) -> ToolbarView<Self> {
        let item = content()
        return ToolbarView(content: self, toolbarItems: [AnyToolbarItem(item)])
    }
}
