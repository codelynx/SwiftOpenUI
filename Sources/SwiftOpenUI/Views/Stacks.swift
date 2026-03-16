/// A view that arranges its children vertically.
public struct VStack<Content: View>: View, MultiChildView {
    public typealias Body = Never

    public let alignment: HorizontalAlignment
    public let spacing: Int
    public let content: Content

    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError("VStack is a primitive view") }

    public var children: [any View] {
        if let multi = content as? MultiChildView {
            return multi.children
        }
        return [content]
    }
}

/// A view that arranges its children horizontally.
public struct HStack<Content: View>: View, MultiChildView {
    public typealias Body = Never

    public let alignment: VerticalAlignment
    public let spacing: Int
    public let content: Content

    public init(
        alignment: VerticalAlignment = .center,
        spacing: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError("HStack is a primitive view") }

    public var children: [any View] {
        if let multi = content as? MultiChildView {
            return multi.children
        }
        return [content]
    }
}

/// A view that overlays its children on top of each other.
public struct ZStack<Content: View>: View, MultiChildView {
    public typealias Body = Never

    public let alignment: Alignment
    public let content: Content

    public init(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }

    public var body: Never { fatalError("ZStack is a primitive view") }

    public var children: [any View] {
        if let multi = content as? MultiChildView {
            return multi.children
        }
        return [content]
    }
}
