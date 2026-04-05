/// A modifier that presents a full-screen modal cover when a binding becomes true.
public struct FullScreenCoverView<Content: View, CoverContent: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let isPresented: Binding<Bool>
    public let onDismiss: (() -> Void)?
    public let coverContent: CoverContent

    public var body: Never { fatalError() }
}

extension View {
    /// Presents a full-screen modal cover when `isPresented` becomes true.
    public func fullScreenCover<V: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> V
    ) -> FullScreenCoverView<Self, V> {
        FullScreenCoverView(
            content: self,
            isPresented: isPresented,
            onDismiss: onDismiss,
            coverContent: content()
        )
    }
}
