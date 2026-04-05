import Foundation

// MARK: - View Identity

/// Wraps content with an explicit identity for programmatic access.
public struct IdView<Content: View, ID: Hashable>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let id: ID

    public var body: Never { fatalError() }
}

extension View {
    /// Assigns an explicit identity to this view for use with ScrollViewReader.
    public func id<ID: Hashable>(_ id: ID) -> IdView<Self, ID> {
        IdView(content: self, id: id)
    }
}

// MARK: - ID Registry

/// Runtime registry mapping Hashable IDs to rendered platform objects.
/// Backends register elements during rendering; ScrollViewProxy reads them.
/// Global, not per-host — same limitation as onChange tracking.
private var _idRegistry: [AnyHashable: Any] = [:]

/// Register a rendered element for an ID.
public func registerViewID<ID: Hashable>(_ id: ID, element: Any) {
    _idRegistry[AnyHashable(id)] = element
}

/// Look up a rendered element by ID.
public func lookupViewID<ID: Hashable>(_ id: ID) -> Any? {
    _idRegistry[AnyHashable(id)]
}

/// Clear the ID registry. Available for testing and explicit cleanup.
/// NOT called during host rebuilds — the global registry relies on
/// overwrite-on-re-render + platform liveness guards for stale entries.
public func clearViewIDRegistry() {
    _idRegistry.removeAll()
}

// MARK: - ScrollViewProxy

/// Provides programmatic scrolling to identified child views.
public struct ScrollViewProxy {
    /// Scroll to the view with the given identity.
    public func scrollTo<ID: Hashable>(_ id: ID, anchor: UnitPoint? = nil) {
        scrollToAction?(AnyHashable(id), anchor)
    }

    /// Backend-provided scroll action. Set by ScrollViewReader's renderer.
    public var scrollToAction: ((AnyHashable, UnitPoint?) -> Void)?

    public init() {}
}

/// A point in a unit coordinate space (0-1 range).
public struct UnitPoint: Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double = 0, y: Double = 0) {
        self.x = x
        self.y = y
    }

    public static let zero = UnitPoint(x: 0, y: 0)
    public static let center = UnitPoint(x: 0.5, y: 0.5)
    public static let top = UnitPoint(x: 0.5, y: 0)
    public static let bottom = UnitPoint(x: 0.5, y: 1)
    public static let leading = UnitPoint(x: 0, y: 0.5)
    public static let trailing = UnitPoint(x: 1, y: 0.5)
    public static let topLeading = UnitPoint(x: 0, y: 0)
    public static let topTrailing = UnitPoint(x: 1, y: 0)
    public static let bottomLeading = UnitPoint(x: 0, y: 1)
    public static let bottomTrailing = UnitPoint(x: 1, y: 1)
}

// MARK: - ScrollViewReader

/// A view that provides programmatic scrolling via a ScrollViewProxy.
public struct ScrollViewReader<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: (ScrollViewProxy) -> Content

    public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) {
        self.content = content
    }

    public var body: Never { fatalError() }
}
