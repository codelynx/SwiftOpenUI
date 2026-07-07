/// `.monospacedDigit()` — tabular figures. GTK4 renders via Pango
/// font-feature-settings "tnum"; other backends currently pass through
/// (parity matrix note).
public struct MonospacedDigitView<Content: View>: View {
    public let content: Content
    public var body: some View { content }
}

/// `.controlSize(_:)` — accepted for API parity; currently does not affect
/// rendering on any SwiftOpenUI backend (parity matrix note).
public enum ControlSize: Sendable, Equatable { case mini, small, regular, large, extraLarge }

extension View {
    public func monospacedDigit() -> MonospacedDigitView<Self> {
        MonospacedDigitView(content: self)
    }

    public func controlSize(_ size: ControlSize) -> Self {
        self
    }
}
