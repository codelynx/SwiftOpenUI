/// A view with padding applied around its content.
public struct PaddedView<Content: View>: View, PrimitiveView {
    public typealias Body = Never

    public let content: Content
    public let top: Int
    public let bottom: Int
    public let leading: Int
    public let trailing: Int

    public var body: Never { fatalError("PaddedView is a primitive view") }
}

extension View {
    /// Apply uniform padding on all sides.
    public func padding(_ amount: Int = 8) -> PaddedView<Self> {
        PaddedView(content: self, top: amount, bottom: amount, leading: amount, trailing: amount)
    }

    /// Apply padding with specific values per edge.
    public func padding(top: Int = 0, bottom: Int = 0, leading: Int = 0, trailing: Int = 0) -> PaddedView<Self> {
        PaddedView(content: self, top: top, bottom: bottom, leading: leading, trailing: trailing)
    }

    /// SwiftUI-compatible edge-set padding.
    public func padding(_ edges: Edge.Set, _ amount: Int = 8) -> PaddedView<Self> {
        PaddedView(
            content: self,
            top: edges.contains(.top) ? amount : 0,
            bottom: edges.contains(.bottom) ? amount : 0,
            leading: edges.contains(.leading) ? amount : 0,
            trailing: edges.contains(.trailing) ? amount : 0
        )
    }
}
