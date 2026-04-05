/// Attaches a context menu to the content, triggered by right-click
/// or long-press depending on platform.
public struct ContextMenuView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let menuElements: [MenuElement]

    public var body: Never { fatalError() }
}

extension View {
    /// Adds a context menu to this view with the given menu items.
    public func contextMenu(@MenuBuilder menuItems: () -> [MenuElement]) -> ContextMenuView<Self> {
        ContextMenuView(content: self, menuElements: menuItems())
    }
}
