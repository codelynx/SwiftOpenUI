/// Sentinel value for HStack/VStack spacing meaning "use the system
/// default spacing" (~8pt). Backends translate this to their platform
/// convention. Callers passing an explicit non-negative value get that
/// exact spacing; callers omitting the argument get the default.
public let stackDefaultSpacing: Int = -1

/// Resolve an HStack/VStack spacing argument to the effective pixel
/// gap a backend should apply. Negative values are treated as the
/// system default (~8pt); non-negative values pass through unchanged.
public func resolveStackSpacing(_ spacing: Int) -> Int {
    spacing < 0 ? 8 : spacing
}

/// A view that arranges its children vertically.
public struct VStack<Content: View>: View, MultiChildView, PrimitiveView {
    public typealias Body = Never

    public let alignment: HorizontalAlignment
    public let spacing: Int
    public let content: Content

    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Int = stackDefaultSpacing,
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
public struct HStack<Content: View>: View, MultiChildView, PrimitiveView {
    public typealias Body = Never

    public let alignment: VerticalAlignment
    public let spacing: Int
    public let content: Content

    public init(
        alignment: VerticalAlignment = .center,
        spacing: Int = stackDefaultSpacing,
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
public struct ZStack<Content: View>: View, MultiChildView, PrimitiveView {
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
