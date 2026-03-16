/// A type that represents the structure and behavior of an app.
///
/// Platform backends provide the concrete app lifecycle (GTK application,
/// Win32 message loop, etc.).
public protocol App {
    associatedtype Body: Scene
    @SceneBuilder var body: Body { get }

    init()
}

/// A part of an app's user interface with a lifecycle managed by the system.
public protocol Scene {
    associatedtype Body: Scene
    @SceneBuilder var body: Body { get }
}

extension Never: Scene {}

/// A scene that presents a window.
public struct WindowGroup<Content: View>: Scene {
    public typealias Body = Never

    public let title: String
    public let content: Content

    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: Never { fatalError("WindowGroup is a primitive scene") }
}

/// Result builder for composing scenes.
@resultBuilder
public struct SceneBuilder {
    public static func buildBlock<Content: Scene>(_ content: Content) -> Content {
        content
    }
}
