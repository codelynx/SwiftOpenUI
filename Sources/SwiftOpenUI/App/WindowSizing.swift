/// Controls how a window's size is chosen at creation time.
public enum WindowSizing: Sendable {
    /// Backend default behavior.
    case automatic
    /// Use the rendered content's natural size.
    case content
    /// Use the rendered content's natural size and make the window non-resizable.
    case contentFixed
    /// Use an explicit initial size.
    case size(width: Double, height: Double)
}

/// Default initial size for desktop windows that use `.automatic` sizing
/// without an explicit `.defaultWindowSize(...)`.
///
/// Content-sized windows remain opt-in via `.windowSizing(.content)` or
/// `.windowSizing(.contentFixed)`. The automatic default gives macOS-style
/// ports a usable first launch size without requiring every content-heavy app
/// to declare a size just to avoid tiny intrinsic windows.
public let defaultAutomaticWindowWidth: Double = 800
public let defaultAutomaticWindowHeight: Double = 600

/// SwiftUI-compatible window resize policy.
///
/// Current backend support:
/// - GTK4: `.contentSize` disables resizing (via `gtk_window_set_resizable`).
///   Content-driven sizing is not yet implemented — use `.defaultWindowSize()`
///   alongside `.windowResizability(.contentSize)` to set the fixed size.
///   `.contentMinSize` is not yet distinguished from `.automatic`.
/// - Win32: `.contentSize` disables drag-to-resize (removes `WS_THICKFRAME`)
///   but keeps `WS_MAXIMIZEBOX` to match GTK4 behavior.
///   `.contentMinSize` behaves the same as `.automatic`.
public enum WindowResizability: Sendable {
    /// Window is non-resizable. On GTK4, requires `.defaultWindowSize()` to
    /// set the actual size; content-driven sizing is not yet implemented.
    case contentSize
    /// Window can be resized with content as minimum size.
    /// Not yet implemented on GTK4 — currently behaves the same as `.automatic`.
    case contentMinSize
    /// Backend default (resizable).
    case automatic
}

/// Controls whether the native window can be resized by the user.
public enum WindowResizeBehavior: Sendable {
    /// Backend default behavior.
    case automatic
    /// Disable user resizing where supported.
    case fixed
    /// Allow user resizing.
    case resizable
}

extension WindowGroup {
    /// Sets the initial window size.
    public func defaultWindowSize(width: Double, height: Double) -> WindowGroup<Content> {
        WindowGroup(
            title: title,
            content: content,
            defaultWindowWidth: width,
            defaultWindowHeight: height,
            minWindowWidth: minWindowWidth,
            minWindowHeight: minWindowHeight,
            maxWindowWidth: maxWindowWidth,
            maxWindowHeight: maxWindowHeight,
            windowSizing: windowSizing,
            windowResizeBehavior: windowResizeBehavior,
            windowResizability: windowResizability
        )
    }

    /// Sets optional minimum and maximum window size constraints.
    public func windowSizeConstraints(
        minWidth: Double? = nil,
        minHeight: Double? = nil,
        maxWidth: Double? = nil,
        maxHeight: Double? = nil
    ) -> WindowGroup<Content> {
        WindowGroup(
            title: title,
            content: content,
            defaultWindowWidth: defaultWindowWidth,
            defaultWindowHeight: defaultWindowHeight,
            minWindowWidth: minWidth ?? minWindowWidth,
            minWindowHeight: minHeight ?? minWindowHeight,
            maxWindowWidth: maxWidth ?? maxWindowWidth,
            maxWindowHeight: maxHeight ?? maxWindowHeight,
            windowSizing: windowSizing,
            windowResizeBehavior: windowResizeBehavior,
            windowResizability: windowResizability
        )
    }

    /// Controls how the backend chooses the initial window size.
    public func windowSizing(_ sizing: WindowSizing) -> WindowGroup<Content> {
        WindowGroup(
            title: title,
            content: content,
            defaultWindowWidth: defaultWindowWidth,
            defaultWindowHeight: defaultWindowHeight,
            minWindowWidth: minWindowWidth,
            minWindowHeight: minWindowHeight,
            maxWindowWidth: maxWindowWidth,
            maxWindowHeight: maxWindowHeight,
            windowSizing: sizing,
            windowResizeBehavior: windowResizeBehavior,
            windowResizability: windowResizability
        )
    }

    /// Controls whether the native window is user-resizable.
    public func windowResizeBehavior(_ behavior: WindowResizeBehavior) -> WindowGroup<Content> {
        WindowGroup(
            title: title,
            content: content,
            defaultWindowWidth: defaultWindowWidth,
            defaultWindowHeight: defaultWindowHeight,
            minWindowWidth: minWindowWidth,
            minWindowHeight: minWindowHeight,
            maxWindowWidth: maxWindowWidth,
            maxWindowHeight: maxWindowHeight,
            windowSizing: windowSizing,
            windowResizeBehavior: behavior,
            windowResizability: windowResizability
        )
    }

    /// SwiftUI-compatible window resizability control.
    /// `.contentSize` disables resizing. On GTK4, pair with `.defaultWindowSize()`
    /// to set the fixed size (content-driven sizing not yet implemented).
    /// `.contentMinSize` is not yet distinguished from `.automatic` on GTK4.
    public func windowResizability(_ resizability: WindowResizability) -> WindowGroup<Content> {
        WindowGroup(
            title: title,
            content: content,
            defaultWindowWidth: defaultWindowWidth,
            defaultWindowHeight: defaultWindowHeight,
            minWindowWidth: minWindowWidth,
            minWindowHeight: minWindowHeight,
            maxWindowWidth: maxWindowWidth,
            maxWindowHeight: maxWindowHeight,
            windowSizing: windowSizing,
            windowResizeBehavior: windowResizeBehavior,
            windowResizability: resizability
        )
    }
}
