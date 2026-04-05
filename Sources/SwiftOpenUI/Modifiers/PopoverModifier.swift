/// Presents a popover attached to the content view when a binding is true.
public struct PopoverView<Content: View, PopoverContent: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let isPresented: Binding<Bool>
    public let popoverContent: PopoverContent

    public var body: Never { fatalError() }
}

extension View {
    /// Presents a popover when the given binding is true.
    public func popover<V: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> V
    ) -> PopoverView<Self, V> {
        PopoverView(content: self, isPresented: isPresented, popoverContent: content())
    }
}
