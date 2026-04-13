/// Environment key for a pending keyboard shortcut.
struct KeyboardShortcutKey: EnvironmentKey {
	static let defaultValue: KeyboardShortcut? = nil
}

/// Environment key for the current window/scene identity.
/// Backends set this before rendering window content.
/// Used by keyboard shortcuts and focused values for window scoping.
struct WindowIDKey: EnvironmentKey {
	static let defaultValue: Int = 0
}

extension EnvironmentValues {
	public var keyboardShortcut: KeyboardShortcut? {
		get { self[KeyboardShortcutKey.self] }
		set { self[KeyboardShortcutKey.self] = newValue }
	}

	/// Opaque window/scene identifier.
	/// Set by backends before rendering window content.
	/// Used for keyboard shortcut scoping and focused value resolution.
	public var windowID: Int {
		get { self[WindowIDKey.self] }
		set { self[WindowIDKey.self] = newValue }
	}
}

/// Attaches a keyboard shortcut to the wrapped content.
/// When the content is a Button, the shortcut is registered
/// at the window level and triggers the button's action.
public struct KeyboardShortcutView<Content: View>: View, PrimitiveView {
	public typealias Body = Never
	public let content: Content
	public let shortcut: KeyboardShortcut

	public var body: Never { fatalError() }
}

extension View {
	/// Adds a keyboard shortcut to this view.
	public func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> KeyboardShortcutView<Self> {
		KeyboardShortcutView(content: self, shortcut: KeyboardShortcut(key, modifiers: modifiers))
	}

	/// Adds a keyboard shortcut to this view.
	public func keyboardShortcut(_ shortcut: KeyboardShortcut) -> KeyboardShortcutView<Self> {
		KeyboardShortcutView(content: self, shortcut: shortcut)
	}
}
