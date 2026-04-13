/// A scene that presents a single unique window identified by a string.
///
/// Unlike `WindowGroup`, which can create multiple window instances,
/// `Window` represents a single window that is opened and closed by id.
public struct Window<Content: View>: Scene {
    public typealias Body = Never

    public let title: String
    public let id: String
    public let content: Content
    public let defaultWindowWidth: Double?
    public let defaultWindowHeight: Double?
    public let minWindowWidth: Double?
    public let minWindowHeight: Double?
    public let launchBehavior: WindowLaunchBehavior

    public init(_ title: String, id: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.id = id
        self.content = content()
        self.defaultWindowWidth = nil
        self.defaultWindowHeight = nil
        self.minWindowWidth = nil
        self.minWindowHeight = nil
        self.launchBehavior = .automatic
    }

    init(
        title: String,
        id: String,
        content: Content,
        defaultWindowWidth: Double?,
        defaultWindowHeight: Double?,
        minWindowWidth: Double?,
        minWindowHeight: Double?,
        launchBehavior: WindowLaunchBehavior
    ) {
        self.title = title
        self.id = id
        self.content = content
        self.defaultWindowWidth = defaultWindowWidth
        self.defaultWindowHeight = defaultWindowHeight
        self.minWindowWidth = minWindowWidth
        self.minWindowHeight = minWindowHeight
        self.launchBehavior = launchBehavior
    }

    public var body: Never { fatalError("Window is a primitive scene") }

    public func defaultWindowSize(width: Double, height: Double) -> Window<Content> {
        Window(
            title: title, id: id, content: content,
            defaultWindowWidth: width, defaultWindowHeight: height,
            minWindowWidth: minWindowWidth, minWindowHeight: minWindowHeight,
            launchBehavior: launchBehavior
        )
    }

    public func defaultLaunchBehavior(_ behavior: WindowLaunchBehavior) -> Window<Content> {
        Window(
            title: title, id: id, content: content,
            defaultWindowWidth: defaultWindowWidth, defaultWindowHeight: defaultWindowHeight,
            minWindowWidth: minWindowWidth, minWindowHeight: minWindowHeight,
            launchBehavior: behavior
        )
    }
}

/// Controls whether a window is shown at application launch.
public enum WindowLaunchBehavior: Sendable {
    /// Backend default — typically shown at launch.
    case automatic
    /// Window is not shown at launch; opened programmatically via `openWindow`.
    case suppressed
}
