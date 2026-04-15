/// A view that carries a short help/tooltip text. Renderers attach
/// the text to the underlying widget's native tooltip mechanism.
public struct HelpView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let text: String

    public var body: Never { fatalError("HelpView is a primitive view") }
}

extension View {
    /// Attach a tooltip/help string that the platform shows on hover.
    ///
    /// Maps to the native mechanism on each backend:
    /// - GTK4: `gtk_widget_set_tooltip_text`
    /// - Web: the element's `title` attribute
    /// - Win32: the tooltip control
    /// - Android: no-op for now (would use accessibility content description)
    ///
    /// Matches SwiftUI's `.help(_:)` on macOS/iOS. Empty strings are
    /// forwarded verbatim so the caller can clear a prior help value.
    public func help(_ text: String) -> HelpView<Self> {
        HelpView(content: self, text: text)
    }
}
