#if canImport(Foundation)
import Foundation
#endif

// MARK: - FocusedValueKey protocol

/// A key for storing values in the focused-value system.
/// Unlike EnvironmentKey, FocusedValueKey has no default value —
/// values are always optional, returning nil when no provider
/// exists in the active window.
public protocol FocusedValueKey {
	associatedtype Value
}

// MARK: - FocusedValues

/// A collection of focused values scoped to the active window.
/// Access values via subscript with a FocusedValueKey type.
///
/// Current implementation resolves at window granularity:
/// the value returned is from the active (foreground) window,
/// not from the focused control's ancestor chain. True focus-chain
/// semantics are deferred to a future milestone.
public struct FocusedValues {
	/// Read a focused value for the active window.
	public subscript<K: FocusedValueKey>(key: K.Type) -> K.Value? {
		get { FocusedValuesStore.shared.resolve(key) }
		set {
			// Write path used by .focusedValue() modifier to set values.
			// In practice, backends call store.register() directly.
		}
	}
}

// MARK: - Provider registration

/// Unique identifier for a focused-value provider registration.
public struct FocusedValueProviderID: Hashable, Sendable {
	fileprivate let value: UInt64
}

// MARK: - Observer handle

/// Handle for removing a focused-values observer.
public struct FocusedValuesObserverID: Hashable, Sendable {
	fileprivate let value: UInt64
}

// MARK: - FocusedValuesStore

/// Singleton store for active-window-scoped focused values.
///
/// Providers register values keyed by (windowID, keyType).
/// Resolution returns the last-registered provider's value
/// for the active window. Observers are notified on window
/// activation changes and value updates.
public final class FocusedValuesStore {
	public static let shared = FocusedValuesStore()

	fileprivate struct Provider {
		let id: FocusedValueProviderID
		let windowID: Int
		let keyTypeID: ObjectIdentifier
		var value: Any
	}

	private struct Observer {
		let id: FocusedValuesObserverID
		let windowID: Int?  // nil = observe all windows
		let handler: () -> Void
	}

	private var providers: [FocusedValueProviderID: Provider] = [:]
	private var insertionOrder: [FocusedValueProviderID] = []
	private var activeWindowID: Int = 0
	private var nextProviderID: UInt64 = 0
	private var observers: [Observer] = []
	private var nextObserverID: UInt64 = 0
	#if canImport(Foundation)
	private let lock = NSLock()
	#endif

	private init() {}

	// MARK: - Provider lifecycle

	/// Register a focused-value provider for a window.
	/// Returns a provider ID for targeted unregistration.
	@discardableResult
	public func register<K: FocusedValueKey>(
		windowID: Int,
		key: K.Type,
		value: K.Value
	) -> FocusedValueProviderID {
		#if canImport(Foundation)
		lock.lock()
		#endif
		let id = FocusedValueProviderID(value: nextProviderID)
		nextProviderID += 1
		let provider = Provider(
			id: id, windowID: windowID,
			keyTypeID: ObjectIdentifier(K.self), value: value
		)
		providers[id] = provider
		insertionOrder.append(id)
		let shouldNotify = windowID == activeWindowID
		#if canImport(Foundation)
		lock.unlock()
		#endif
		if shouldNotify { notifyObservers(windowID: windowID) }
		return id
	}

	/// Remove a specific provider registration.
	public func unregister(id: FocusedValueProviderID) {
		#if canImport(Foundation)
		lock.lock()
		#endif
		let provider = providers.removeValue(forKey: id)
		insertionOrder.removeAll { $0 == id }
		let shouldNotify = provider.map { $0.windowID == activeWindowID } ?? false
		#if canImport(Foundation)
		lock.unlock()
		#endif
		if shouldNotify { notifyObservers(windowID: activeWindowID) }
	}

	// MARK: - Resolution

	/// Resolve a focused value for the active window.
	/// Returns the value from the last-registered provider
	/// matching the key type in the active window, or nil.
	public func resolve<K: FocusedValueKey>(_ key: K.Type) -> K.Value? {
		#if canImport(Foundation)
		lock.lock()
		defer { lock.unlock() }
		#endif
		let keyTypeID = ObjectIdentifier(K.self)
		// Walk insertion order in reverse to find last-registered match
		for providerID in insertionOrder.reversed() {
			if let provider = providers[providerID],
			   provider.windowID == activeWindowID,
			   provider.keyTypeID == keyTypeID {
				return provider.value as? K.Value
			}
		}
		return nil
	}

	// MARK: - Active window

	/// Set the currently active (foreground) window.
	/// Notifies all observers if the active window changed.
	public func setActiveWindow(_ windowID: Int) {
		#if canImport(Foundation)
		lock.lock()
		#endif
		let changed = activeWindowID != windowID
		activeWindowID = windowID
		#if canImport(Foundation)
		lock.unlock()
		#endif
		if changed { notifyObservers(windowID: nil) }
	}

	/// The currently active window ID.
	public var currentActiveWindowID: Int {
		#if canImport(Foundation)
		lock.lock()
		defer { lock.unlock() }
		#endif
		return activeWindowID
	}

	// MARK: - Observer registration

	/// Add an observer that fires when focused values change.
	/// - windowID: if non-nil, only fires for changes in that window.
	///   If nil, fires on any change (including active window switches).
	/// - Returns: an observer ID for removal.
	@discardableResult
	public func addObserver(windowID: Int? = nil, handler: @escaping () -> Void) -> FocusedValuesObserverID {
		#if canImport(Foundation)
		lock.lock()
		defer { lock.unlock() }
		#endif
		let id = FocusedValuesObserverID(value: nextObserverID)
		nextObserverID += 1
		observers.append(Observer(id: id, windowID: windowID, handler: handler))
		return id
	}

	/// Remove an observer.
	public func removeObserver(id: FocusedValuesObserverID) {
		#if canImport(Foundation)
		lock.lock()
		defer { lock.unlock() }
		#endif
		observers.removeAll { $0.id == id }
	}

	// MARK: - Notification

	/// Notify relevant observers.
	/// - windowID: if nil, notifies all observers (window switch).
	///   If non-nil, notifies observers for that window + global observers.
	private func notifyObservers(windowID: Int?) {
		#if canImport(Foundation)
		lock.lock()
		#endif
		let toNotify: [() -> Void]
		if let windowID {
			toNotify = observers
				.filter { $0.windowID == nil || $0.windowID == windowID }
				.map { $0.handler }
		} else {
			toNotify = observers.map { $0.handler }
		}
		#if canImport(Foundation)
		lock.unlock()
		#endif
		for handler in toNotify {
			handler()
		}
	}
}

// MARK: - @FocusedValue property wrapper

/// Reads a value from the active window's focused-value providers.
/// Returns nil when the active window has no provider for the key.
///
/// Usage:
/// ```swift
/// struct MyCommands: Commands {
///     @FocusedValue(\.myKey) var myValue
/// }
/// ```
@propertyWrapper
public struct FocusedValue<Value> {
	private let resolve: () -> Value?

	public init(_ keyPath: KeyPath<FocusedValues, Value?>) {
		// Capture the keyPath for deferred resolution.
		// We use FocusedValues subscript which delegates to FocusedValuesStore.
		self.resolve = {
			FocusedValues()[keyPath: keyPath]
		}
	}

	public var wrappedValue: Value? {
		resolve()
	}
}

// MARK: - FocusedValueView modifier

/// Registers a focused-value provider for the current window.
/// The provider is active while the view's native widget exists
/// and is unregistered when the widget is destroyed.
public struct FocusedValueView<Content: View, K: FocusedValueKey>: View, PrimitiveView {
	public typealias Body = Never
	public let content: Content
	public let keyType: K.Type
	public let value: K.Value

	public var body: Never { fatalError() }
}

extension View {
	/// Publishes a value to the focused-value system for the current window.
	public func focusedValue<K: FocusedValueKey>(
		_ keyPath: WritableKeyPath<FocusedValues, K.Value?>,
		_ value: K.Value
	) -> FocusedValueView<Self, K> {
		FocusedValueView(content: self, keyType: K.self, value: value)
	}

	/// Publishes a value to the focused-value system for the current window.
	/// Convenience overload that takes the key type directly.
	public func focusedValue<K: FocusedValueKey>(
		_ key: K.Type,
		_ value: K.Value
	) -> FocusedValueView<Self, K> {
		FocusedValueView(content: self, keyType: key, value: value)
	}
}
