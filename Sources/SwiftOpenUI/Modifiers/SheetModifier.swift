/// A modifier that presents a modal sheet when a binding becomes true.
public struct SheetModifierView<Content: View, SheetContent: View>: View {
    public typealias Body = Never

    public let content: Content
    public let isPresented: Binding<Bool>
    public let onDismiss: (() -> Void)?
    public let sheetContent: SheetContent

    public var body: Never { fatalError("SheetModifierView is a primitive view") }
}

/// A modifier that presents a modal sheet when an optional item becomes non-nil.
public struct ItemSheetModifierView<Content: View, Item: Identifiable, SheetContent: View>: View {
    public typealias Body = Never

    public let content: Content
    public let item: Binding<Item?>
    public let onDismiss: (() -> Void)?
    public let sheetContent: (Item) -> SheetContent

    public var body: Never { fatalError("ItemSheetModifierView is a primitive view") }
}

extension View {
    /// Present a modal sheet when `isPresented` becomes true.
    public func sheet<V: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> V
    ) -> SheetModifierView<Self, V> {
        SheetModifierView(
            content: self,
            isPresented: isPresented,
            onDismiss: nil,
            sheetContent: content()
        )
    }

    /// Present a modal sheet when `isPresented` becomes true and run `onDismiss`
    /// after the active presentation cycle ends.
    public func sheet<V: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)?,
        @ViewBuilder content: () -> V
    ) -> SheetModifierView<Self, V> {
        SheetModifierView(
            content: self,
            isPresented: isPresented,
            onDismiss: onDismiss,
            sheetContent: content()
        )
    }

    /// Present a modal sheet when an optional item becomes non-nil.
    public func sheet<Item: Identifiable, V: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> V
    ) -> ItemSheetModifierView<Self, Item, V> {
        ItemSheetModifierView(
            content: self,
            item: item,
            onDismiss: onDismiss,
            sheetContent: content
        )
    }
}
