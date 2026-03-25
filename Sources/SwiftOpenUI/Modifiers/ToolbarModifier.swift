/// Placement for toolbar items.
public enum ToolbarItemPlacement {
    case leading
    case trailing
    case primaryAction
}

/// Flattened toolbar content produced by `ToolbarContentBuilder`.
public struct ToolbarContent {
    public let items: [AnyToolbarItem]

    public init(items: [AnyToolbarItem]) {
        self.items = items
    }
}

/// Result builder for composing one or more toolbar items.
@resultBuilder
public enum ToolbarContentBuilder {
    public static func buildBlock() -> ToolbarContent {
        ToolbarContent(items: [])
    }

    public static func buildBlock(_ components: ToolbarContent...) -> ToolbarContent {
        ToolbarContent(items: components.flatMap(\.items))
    }

    public static func buildExpression<Content: View>(_ expression: ToolbarItem<Content>) -> ToolbarContent {
        ToolbarContent(items: [AnyToolbarItem(expression)])
    }

    public static func buildExpression(_ expression: ToolbarContent) -> ToolbarContent {
        expression
    }

    public static func buildOptional(_ component: ToolbarContent?) -> ToolbarContent {
        component ?? ToolbarContent(items: [])
    }

    public static func buildEither(first component: ToolbarContent) -> ToolbarContent {
        component
    }

    public static func buildEither(second component: ToolbarContent) -> ToolbarContent {
        component
    }

    public static func buildArray(_ components: [ToolbarContent]) -> ToolbarContent {
        ToolbarContent(items: components.flatMap(\.items))
    }

    public static func buildPartialBlock(first: ToolbarContent) -> ToolbarContent {
        first
    }

    public static func buildPartialBlock(
        accumulated: ToolbarContent,
        next: ToolbarContent
    ) -> ToolbarContent {
        ToolbarContent(items: accumulated.items + next.items)
    }
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
    public let toolbarID: String?
    public let toolbarItems: [AnyToolbarItem]

    public var body: Never { fatalError("ToolbarView is a primitive view") }
}

extension View {
    /// Adds one or more toolbar items.
    public func toolbar(
        @ToolbarContentBuilder content: () -> ToolbarContent
    ) -> ToolbarView<Self> {
        let toolbarContent = content()
        return ToolbarView(content: self, toolbarID: nil, toolbarItems: toolbarContent.items)
    }

    /// Adds one or more toolbar items with a stored toolbar identifier.
    public func toolbar(
        id: String,
        @ToolbarContentBuilder content: () -> ToolbarContent
    ) -> ToolbarView<Self> {
        let toolbarContent = content()
        return ToolbarView(content: self, toolbarID: id, toolbarItems: toolbarContent.items)
    }
}
