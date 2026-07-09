/// An element within a Menu (item, divider, or submenu).
public enum MenuElement {
    case item(label: String, action: () -> Void)
    case divider
    case submenu(label: String, children: [MenuElement])
}

/// A single menu item with a label and action.
public struct MenuItem {
    public let label: String
    public let action: () -> Void

    public init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }
}

/// A menu divider/separator.
public struct MenuDivider {
    public init() {}
}

/// A submenu with nested menu elements.
public struct SubMenu {
    public let label: String
    public let children: [MenuElement]

    public init(_ label: String, @MenuBuilder content: () -> [MenuElement]) {
        self.label = label
        self.children = content()
    }
}

/// A control that presents a menu of actions, matching SwiftUI's `Menu`.
///
/// The trigger and the items are both views:
/// ```swift
/// Menu {
///     Button("Use Source") { … }
///     Button("Keep Both") { … }
/// } label: {
///     ActionBadge(…)
/// }
/// ```
/// The `Menu(_ title:) { … }` convenience uses a `Text` label.
///
/// - GTK4: `GtkMenuButton` whose child is the rendered label and whose
///   popover holds the rendered items; an item tap fires its action, then
///   the popover is dismissed (act-then-dismiss).
/// - Win32: minimal — renders the label trigger only; the view-shaped
///   popup is deferred (Win32's native menu takes string items, not views).
/// - Web: minimal — renders the label trigger and the items into a
///   dropdown (full parity deferred).
///
/// (Right-click/context menus use `.contextMenu { MenuItem(…) }` and the
/// `MenuElement` model above — a separate mechanism from this control.)
public struct Menu<Label: View, Content: View>: View, PrimitiveView {
    public typealias Body = Never

    public let content: Content
    public let label: Label

    public init(@ViewBuilder content: () -> Content,
                @ViewBuilder label: () -> Label) {
        self.content = content()
        self.label = label()
    }

    public var body: Never { fatalError("Menu is a primitive view") }
}

extension Menu where Label == Text {
    /// Creates a menu with a text label.
    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.init(content: content, label: { Text(title) })
    }
}

/// Result builder for composing menu elements.
@resultBuilder
public struct MenuBuilder {
    public static func buildBlock(_ elements: [MenuElement]...) -> [MenuElement] {
        elements.flatMap { $0 }
    }

    public static func buildExpression(_ item: MenuItem) -> [MenuElement] {
        [.item(label: item.label, action: item.action)]
    }

    public static func buildExpression(_ divider: MenuDivider) -> [MenuElement] {
        [.divider]
    }

    public static func buildExpression(_ submenu: SubMenu) -> [MenuElement] {
        [.submenu(label: submenu.label, children: submenu.children)]
    }

    public static func buildOptional(_ elements: [MenuElement]?) -> [MenuElement] {
        elements ?? []
    }

    public static func buildEither(first elements: [MenuElement]) -> [MenuElement] {
        elements
    }

    public static func buildEither(second elements: [MenuElement]) -> [MenuElement] {
        elements
    }
}
