/// A single tab page with a title and content.
public struct Tab<Content: View>: View {
    public typealias Body = Never

    public let title: String
    public let id: String
    public let content: Content

    public init(_ title: String, id: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.id = id ?? String(title.lowercased().map { $0 == " " ? "-" : $0 })
        self.content = content()
    }

    public var body: Never { fatalError("Tab is a primitive view") }
}

/// Type-erased tab for storing heterogeneous Tab<Content> in an array.
public struct AnyTab {
    public let title: String
    public let id: String
    public let wrapped: any View

    public init<Content: View>(_ tab: Tab<Content>) {
        self.title = tab.title
        self.id = tab.id
        self.wrapped = tab.content
    }
}

/// A tabbed container that switches between child pages.
public struct TabView: View {
    public typealias Body = Never

    public let tabs: [AnyTab]
    public let initialTab: Int?

    public init(initialTab: Int? = nil, @TabBuilder content: () -> [AnyTab]) {
        self.initialTab = initialTab
        self.tabs = content()
    }

    public var body: Never { fatalError("TabView is a primitive view") }
}

/// Result builder for composing tabs.
@resultBuilder
public struct TabBuilder {
    public static func buildBlock(_ tabs: [AnyTab]...) -> [AnyTab] {
        tabs.flatMap { $0 }
    }

    public static func buildExpression<Content: View>(_ tab: Tab<Content>) -> [AnyTab] {
        [AnyTab(tab)]
    }

    public static func buildOptional(_ tabs: [AnyTab]?) -> [AnyTab] {
        tabs ?? []
    }

    public static func buildEither(first tabs: [AnyTab]) -> [AnyTab] {
        tabs
    }

    public static func buildEither(second tabs: [AnyTab]) -> [AnyTab] {
        tabs
    }

    public static func buildArray(_ tabs: [[AnyTab]]) -> [AnyTab] {
        tabs.flatMap { $0 }
    }
}
