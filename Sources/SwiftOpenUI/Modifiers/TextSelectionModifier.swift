/// SwiftUI's `.textSelection(_:)` — whether the user can select and copy
/// the text in this view.
///
/// - GTK4: `.enabled` maps to `gtk_label_set_selectable` on the wrapped
///   `Text`'s `GtkLabel`.
/// - Win32 / other backends: currently pass through via `body` (parity
///   matrix note) — the modifier compiles and is inert until a backend
///   implements it.
public enum TextSelectability: Sendable, Equatable {
    case enabled
    case disabled
}

/// Wrapper produced by `.textSelection(_:)`. Renders its content
/// unchanged except where a backend provides selectable-text support.
///
/// Reconcile-safe: the value is represented in the GTK4 descriptor tree
/// (kind `.widgetProperty`), so a *changed* selectability is not silently
/// reused — it forces a full rebuild whose create path re-applies it.
public struct TextSelectionView<Content: View>: View {
    public let content: Content
    public let selectability: TextSelectability

    public var body: some View { content }
}

extension View {
    /// Controls whether people can select the text in this view.
    public func textSelection(_ selectability: TextSelectability) -> TextSelectionView<Self> {
        TextSelectionView(content: self, selectability: selectability)
    }
}
