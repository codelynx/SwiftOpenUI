/// A flexible space that expands along the major axis of its containing stack.
public struct Spacer: View, PrimitiveView {
    public typealias Body = Never

    public let minLength: Int?

    public init(minLength: Int? = nil) {
        self.minLength = minLength
    }

    public var body: Never { fatalError("Spacer is a primitive view") }
}

/// A visual element that can be used to separate content.
public struct Divider: View, PrimitiveView {
    public typealias Body = Never
    public init() {}
    public var body: Never { fatalError("Divider is a primitive view") }
}
