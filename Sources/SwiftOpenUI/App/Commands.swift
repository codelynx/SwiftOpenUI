// MARK: - Commands protocol

/// A type that represents a set of app-level menu commands.
///
/// Commands provide menu bar integration on desktop platforms.
/// The `body` property declares command groups and items.
///
/// ```swift
/// struct FileCommands: Commands {
///     @FocusedValue(\.document) var document
///     var body: some Commands {
///         CommandGroup(replacing: .newItem) {
///             CommandMenuItem("Save", shortcut: .init("s")) {
///                 document?.save()
///             }
///             .disabled(document == nil)
///         }
///     }
/// }
/// ```
///
/// > Note: `CommandMenuItem` is used instead of `Button` for command
/// > content. This is a known API difference from Apple's SwiftUI,
/// > which uses `@ViewBuilder` with `Button` views. The difference
/// > exists because introspecting arbitrary view trees to extract
/// > menu metadata is fragile. `MenuElement` is for in-view popup
/// > and context menus; `CommandMenuItem` is for app-level command
/// > menus with disable state and shortcut metadata.
public protocol Commands {
	associatedtype Body: Commands
	@CommandsBuilder var body: Body { get }
}

// MARK: - EmptyCommands

/// A commands type that contains no commands.
public struct EmptyCommands: Commands {
	public typealias Body = Never
	public var body: Never { fatalError() }
	public init() {}
}

extension Never: Commands {}

// MARK: - CommandGroupPlacement

/// Where a command group should appear in the menu bar.
public enum CommandGroupPlacement: Equatable, Hashable {
	/// Replaces the New Item commands (File menu).
	case newItem
	/// Replaces the Save commands (File menu).
	case saveItem
	/// Replaces the Print commands (File menu).
	case printItem
	/// Replaces the Undo/Redo commands (Edit menu).
	case undoRedo
	/// Replaces the Pasteboard commands (Edit menu).
	case pasteboard
	/// Replaces the Toolbar commands (View menu).
	case toolbar
	/// Replaces the Sidebar commands (View menu).
	case sidebar
	/// Replaces the Window Size commands (Window menu).
	case windowSize
	/// Replaces the Help commands (Help menu).
	case help
}

// MARK: - CommandMenuItem

/// A single command menu item with label, action, shortcut, and enable state.
///
/// Used inside `CommandGroup` to declare menu items.
/// Separate from `MenuElement` (which is for in-view popup/context menus).
public struct CommandMenuItem {
	public let label: String
	public let action: () -> Void
	public let shortcut: KeyboardShortcut?
	public private(set) var isDisabled: Bool

	public init(
		_ label: String,
		shortcut: KeyboardShortcut? = nil,
		action: @escaping () -> Void
	) {
		self.label = label
		self.action = action
		self.shortcut = shortcut
		self.isDisabled = false
	}

	/// Returns a copy with disabled state set.
	public func disabled(_ isDisabled: Bool) -> CommandMenuItem {
		var copy = self
		copy.isDisabled = isDisabled
		return copy
	}
}

// MARK: - CommandGroup

/// A group of menu commands at a specific placement in the menu bar.
public struct CommandGroup: Commands {
	public typealias Body = Never

	public let placement: CommandGroupPlacement
	public let items: [CommandMenuItem]

	public init(
		replacing placement: CommandGroupPlacement,
		@CommandMenuBuilder content: () -> [CommandMenuItem]
	) {
		self.placement = placement
		self.items = content()
	}

	public var body: Never { fatalError() }
}

// MARK: - TupleCommands

/// A composite commands type holding two children.
public struct TupleCommands<C0: Commands, C1: Commands>: Commands {
	public typealias Body = Never
	public let commands0: C0
	public let commands1: C1

	public init(_ c0: C0, _ c1: C1) {
		self.commands0 = c0
		self.commands1 = c1
	}

	public var body: Never { fatalError() }
}

// MARK: - CommandsBuilder

/// Result builder for composing Commands types.
@resultBuilder
public struct CommandsBuilder {
	public static func buildBlock<C: Commands>(_ content: C) -> C {
		content
	}

	public static func buildBlock<C0: Commands, C1: Commands>(_ c0: C0, _ c1: C1) -> TupleCommands<C0, C1> {
		TupleCommands(c0, c1)
	}
}

// MARK: - CommandMenuBuilder

/// Result builder for composing CommandMenuItem arrays.
@resultBuilder
public struct CommandMenuBuilder {
	public static func buildBlock(_ items: [CommandMenuItem]...) -> [CommandMenuItem] {
		items.flatMap { $0 }
	}

	public static func buildExpression(_ item: CommandMenuItem) -> [CommandMenuItem] {
		[item]
	}

	public static func buildOptional(_ items: [CommandMenuItem]?) -> [CommandMenuItem] {
		items ?? []
	}

	public static func buildEither(first items: [CommandMenuItem]) -> [CommandMenuItem] {
		items
	}

	public static func buildEither(second items: [CommandMenuItem]) -> [CommandMenuItem] {
		items
	}
}

// MARK: - Command extraction

/// Extract all CommandMenuItems from a Commands tree, grouped by placement.
public func extractCommandGroups<C: Commands>(from commands: C) -> [CommandGroupPlacement: [CommandMenuItem]] {
	var result: [CommandGroupPlacement: [CommandMenuItem]] = [:]
	collectCommandGroups(commands, into: &result)
	return result
}

/// Protocol for extracting command groups from tuple commands.
protocol TupleCommandsProtocol {
	func collectInto(_ result: inout [CommandGroupPlacement: [CommandMenuItem]])
}

extension TupleCommands: TupleCommandsProtocol {
	func collectInto(_ result: inout [CommandGroupPlacement: [CommandMenuItem]]) {
		collectCommandGroups(commands0, into: &result)
		collectCommandGroups(commands1, into: &result)
	}
}

private func collectCommandGroups<C: Commands>(_ commands: C, into result: inout [CommandGroupPlacement: [CommandMenuItem]]) {
	if let group = commands as? CommandGroup {
		result[group.placement, default: []].append(contentsOf: group.items)
	} else if let tuple = commands as? TupleCommandsProtocol {
		tuple.collectInto(&result)
	} else if !(commands is EmptyCommands) {
		// Recurse into body for custom Commands types
		let body = commands.body
		collectCommandGroups(body, into: &result)
	}
}

// MARK: - Scene commands modifier

/// Type-erased commands factory closure.
public typealias AnyCommandsFactory = () -> [CommandGroupPlacement: [CommandMenuItem]]

/// Global storage for the commands factory.
/// Set by `.commands {}` on WindowGroup. Backends read this
/// after window creation to build the native menu bar.
///
/// Single-slot design: one app has one set of commands.
/// Multiple WindowGroups share the same command definitions.
public var globalCommandsFactory: AnyCommandsFactory?

extension WindowGroup {
	/// Attaches app-level menu commands to this window group.
	public func commands<C: Commands>(@CommandsBuilder _ commands: @escaping () -> C) -> WindowGroup {
		globalCommandsFactory = { extractCommandGroups(from: commands()) }
		return self
	}
}
