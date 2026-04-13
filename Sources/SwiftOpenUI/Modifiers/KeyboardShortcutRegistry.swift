#if canImport(Foundation)
import Foundation
#endif

/// Unique identifier for a keyboard shortcut registration.
/// Used to remove a specific registration without affecting
/// other registrations of the same shortcut.
public struct ShortcutRegistrationID: Hashable, Sendable {
	fileprivate let value: UInt64
}

/// Global registry of active keyboard shortcuts.
///
/// Registrations are instance-scoped (each gets a unique ID) and
/// window-scoped (each is associated with a window identifier).
/// Dispatch resolves only within the requesting window, and
/// unregistration targets a specific registration by ID.
public final class KeyboardShortcutRegistry {
	public static let shared = KeyboardShortcutRegistry()

	private struct Entry {
		let id: ShortcutRegistrationID
		let windowID: Int
		let action: () -> Void
	}

	private var entries: [KeyboardShortcut: [Entry]] = [:]
	private var nextID: UInt64 = 0
	#if canImport(Foundation)
	private let lock = NSLock()
	#endif

	private init() {}

	/// Register a shortcut → action binding scoped to a window.
	/// Returns a registration ID for targeted unregistration.
	@discardableResult
	public func register(_ shortcut: KeyboardShortcut, windowID: Int, action: @escaping () -> Void) -> ShortcutRegistrationID {
		#if canImport(Foundation)
		lock.lock()
		defer { lock.unlock() }
		#endif
		let id = ShortcutRegistrationID(value: nextID)
		nextID += 1
		entries[shortcut, default: []].append(Entry(id: id, windowID: windowID, action: action))
		return id
	}

	/// Remove a specific registration by ID.
	/// Safe to call even if the registration was already removed.
	public func unregister(id: ShortcutRegistrationID) {
		#if canImport(Foundation)
		lock.lock()
		defer { lock.unlock() }
		#endif
		for (shortcut, var list) in entries {
			if let idx = list.firstIndex(where: { $0.id == id }) {
				list.remove(at: idx)
				if list.isEmpty {
					entries.removeValue(forKey: shortcut)
				} else {
					entries[shortcut] = list
				}
				return
			}
		}
	}

	/// Dispatch a key event for a specific window.
	/// Fires the most recently registered action matching the
	/// shortcut within the given window. Returns true if handled.
	public func dispatch(_ shortcut: KeyboardShortcut, windowID: Int) -> Bool {
		#if canImport(Foundation)
		lock.lock()
		let match = entries[shortcut]?.last(where: { $0.windowID == windowID })
		lock.unlock()
		#else
		let match = entries[shortcut]?.last(where: { $0.windowID == windowID })
		#endif
		if let match {
			match.action()
			return true
		}
		return false
	}
}
