/// SwiftUI's `.onExitCommand(perform:)` — runs an action when the user
/// presses the Escape key (the "cancel"/exit command) while this view or
/// a focused descendant is active.
///
/// - GTK4: registers an Escape shortcut in the window's
///   `KeyboardShortcutRegistry`; the window's key controller dispatches
///   Escape to it (window-scoped, which matches how Escape "cancel"
///   behaves for a single active field).
/// - Win32 / other backends: currently pass through via `body` (parity
///   matrix note) — the modifier compiles and is inert until a backend
///   implements it.
public struct OnExitCommandView<Content: View>: View {
    public let content: Content
    public let action: () -> Void

    public var body: some View { content }
}

extension View {
    /// Adds an action to perform when the user presses the Escape key.
    public func onExitCommand(perform action: @escaping () -> Void) -> OnExitCommandView<Self> {
        OnExitCommandView(content: self, action: action)
    }
}
