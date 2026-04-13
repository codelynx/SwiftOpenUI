/// Represents a key equivalent for keyboard shortcuts.
public struct KeyEquivalent: Equatable, Hashable, ExpressibleByExtendedGraphemeClusterLiteral {
	public let character: Character

	public init(_ character: Character) {
		self.character = character
	}

	public init(extendedGraphemeClusterLiteral value: Character) {
		self.character = value
	}

	// MARK: - Special keys

	public static let `return` = KeyEquivalent("\r")
	public static let escape = KeyEquivalent("\u{1B}")
	public static let delete = KeyEquivalent("\u{7F}")
	public static let deleteForward = KeyEquivalent("\u{F728}")
	public static let tab = KeyEquivalent("\t")
	public static let upArrow = KeyEquivalent("\u{F700}")
	public static let downArrow = KeyEquivalent("\u{F701}")
	public static let leftArrow = KeyEquivalent("\u{F702}")
	public static let rightArrow = KeyEquivalent("\u{F703}")
	public static let space = KeyEquivalent(" ")
}

/// A set of key modifiers for keyboard shortcuts.
public struct EventModifiers: OptionSet, Equatable, Hashable, Sendable {
	public let rawValue: Int

	public init(rawValue: Int) {
		self.rawValue = rawValue
	}

	public static let capsLock = EventModifiers(rawValue: 1 << 0)
	public static let shift    = EventModifiers(rawValue: 1 << 1)
	public static let control  = EventModifiers(rawValue: 1 << 2)
	public static let option   = EventModifiers(rawValue: 1 << 3)
	public static let command  = EventModifiers(rawValue: 1 << 4)

	/// Alias for `.option` (cross-platform convenience).
	public static let alt = EventModifiers.option
}

/// Represents a keyboard shortcut combining a key and modifiers.
public struct KeyboardShortcut: Equatable, Hashable {
	public let key: KeyEquivalent
	public let modifiers: EventModifiers

	public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command) {
		self.key = key
		self.modifiers = modifiers
	}

	/// Default action shortcut (Return key, no modifiers).
	public static let defaultAction = KeyboardShortcut(.return, modifiers: [])

	/// Cancel action shortcut (Escape key, no modifiers).
	public static let cancelAction = KeyboardShortcut(.escape, modifiers: [])
}
