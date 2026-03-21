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
            windowResizeBehavior: windowResizeBehavior
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
            windowResizeBehavior: windowResizeBehavior
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
            windowResizeBehavior: windowResizeBehavior
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
            windowResizeBehavior: behavior
        )
    }
}
