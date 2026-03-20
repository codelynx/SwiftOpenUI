/// A transparent grouping container that flattens its children
/// into the parent container without introducing an extra wrapper.
/// Use Group to work around the ViewBuilder child limit.
public struct Group<Content: View>: View, TransparentMultiChildView {
    public typealias Body = Never

    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Never { fatalError("Group is a primitive view") }

    public var children: [any View] {
        if let multi = content as? MultiChildView {
            return multi.children
        }
        return [content]
    }
}
