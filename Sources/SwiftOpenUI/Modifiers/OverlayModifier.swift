/// A view with another view layered on top.
public struct OverlayView<Content: View, Overlay: View>: View {
    public typealias Body = Never

    public let content: Content
    public let overlay: Overlay
    public let alignment: Alignment

    public var body: Never { fatalError("OverlayView is a primitive view") }
}

extension View {
    /// Layer an overlay view on top of this view.
    public func overlay<V: View>(_ overlay: V, alignment: Alignment = .center) -> OverlayView<Self, V> {
        OverlayView(content: self, overlay: overlay, alignment: alignment)
    }

    /// Layer an overlay view on top of this view.
    public func overlay<V: View>(alignment: Alignment = .center, @ViewBuilder _ overlay: () -> V) -> OverlayView<Self, V> {
        OverlayView(content: self, overlay: overlay(), alignment: alignment)
    }
}
