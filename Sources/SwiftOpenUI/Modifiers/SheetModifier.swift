/// A modifier that presents a modal sheet when a binding becomes true.
public struct SheetModifierView<Content: View, SheetContent: View>: View {
    public typealias Body = Never

    public let content: Content
    public let isPresented: Binding<Bool>
    public let sheetContent: SheetContent

    public var body: Never { fatalError("SheetModifierView is a primitive view") }
}

extension View {
    /// Present a modal sheet when `isPresented` becomes true.
    public func sheet<V: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> V
    ) -> SheetModifierView<Self, V> {
        SheetModifierView(content: self, isPresented: isPresented, sheetContent: content())
    }
}
