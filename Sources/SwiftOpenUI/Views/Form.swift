/// A container for grouping controls in a settings-like layout.
public struct Form<Content: View>: View, MultiChildView {
    public typealias Body = Never

    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var children: [any View] {
        if let multi = content as? MultiChildView {
            return multi.children
        }
        let mirror = Mirror(reflecting: content)
        if mirror.children.isEmpty {
            return [content]
        }
        return mirror.children.compactMap { $0.value as? any View }
    }

    public var body: Never { fatalError("Form is a primitive view") }
}
