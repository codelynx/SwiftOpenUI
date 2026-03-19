import Foundation

/// Storage for focus state, shared across view copies.
/// Implements AnyStateStorage so ViewHost wires up rebuild scheduling.
///
/// Platform backends extend this class to add native focus management
/// (e.g., GTK widget focus, Win32 SetFocus).
open class FocusStateStorage<Value: Hashable>: AnyStateStorage {
    private let lock = NSLock()
    var _value: Value?  // internal for restoreValue cross-storage access
    public let defaultValue: Value
    public weak var host: AnyViewHost?

    public var value: Value? {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    public init(_ initial: Value?, default defaultValue: Value) {
        self._value = initial
        self.defaultValue = defaultValue
    }

    /// Whether the change originated from a programmatic set (not a platform focus event).
    private var _programmatic = false

    public func setValue(_ newValue: Value?) {
        lock.lock()
        let changed = _value != newValue
        _value = newValue
        let programmatic = _programmatic
        lock.unlock()

        guard changed else { return }

        // Only drive native focus for programmatic changes.
        // UI-driven focus events (GTK enter/leave) should not loop back.
        if programmatic {
            platformFocusChanged(newValue)
        }

        // Only rebuild when programmatic (e.g., button sets focusedField).
        // Platform focus events should NOT trigger rebuilds —
        // rebuilding destroys and recreates widgets, losing focus.
        if programmatic {
            // Suppress focus restore when clearing to default (nil or false).
            // For @FocusState<Field?>, newValue is .some(nil) not .none,
            // so also check against the default value.
            if newValue == nil || newValue == .some(defaultValue) {
                host?.suppressNextFocusRestore()
            }
            host?.scheduleRebuild()
        }
    }

    /// Set value programmatically (from user code), triggering a rebuild.
    public func setProgrammatic(_ newValue: Value?) {
        lock.lock()
        _programmatic = true
        lock.unlock()
        setValue(newValue)
        lock.lock()
        _programmatic = false
        lock.unlock()
    }

    /// Keyed callbacks set by platform backends to handle native focus changes.
    /// Multiple views can register under different keys (e.g., one per HWND/widget).
    /// This supports FocusedEqualsView where N fields share one storage.
    private var platformFocusCallbacks: [AnyHashable: (Value?) -> Void] = [:]

    /// Single-callback convenience used by GTK4 backend.
    /// Delegates to the keyed callback system under a fixed key.
    public var onProgrammaticFocusChange: ((Value?) -> Void)? {
        get { platformFocusCallbacks[AnyHashable("_single")] }
        set {
            if let cb = newValue {
                platformFocusCallbacks[AnyHashable("_single")] = cb
            } else {
                platformFocusCallbacks.removeValue(forKey: AnyHashable("_single"))
            }
        }
    }

    /// Register a focus callback under a unique key. Replaces any existing
    /// callback for the same key. Use the HWND pointer or ObjectIdentifier as key.
    public func addPlatformFocusCallback(key: AnyHashable, _ callback: @escaping (Value?) -> Void) {
        platformFocusCallbacks[key] = callback
    }

    /// Remove a focus callback by key (e.g., when the HWND is destroyed).
    public func removePlatformFocusCallback(key: AnyHashable) {
        platformFocusCallbacks.removeValue(forKey: key)
    }

    /// Override in platform backends to handle native focus changes.
    open func platformFocusChanged(_ newValue: Value?) {
        for callback in platformFocusCallbacks.values {
            callback(newValue)
        }
    }

    public func restoreValue(from other: AnyStateStorage) {
        if let typed = other as? FocusStateStorage<Value> {
            // Direct access without lock — called only during render pass (single-threaded)
            _value = typed._value
        }
    }
}

/// A property wrapper that tracks keyboard focus state, matching SwiftUI's @FocusState.
///
/// Use with `.focused($focusField, equals: .someCase)` to bind focus state to an enum.
/// Use with `.focused($isFocused)` for simple boolean focus tracking.
@propertyWrapper
public struct FocusState<Value: Hashable>: AnyStateStorageProvider {
    public let storage: FocusStateStorage<Value>

    public init() where Value == Bool {
        self.storage = FocusStateStorage(false, default: false)
    }

    public init<V>() where Value == V? {
        self.storage = FocusStateStorage(nil, default: nil)
    }

    /// Internal init for sharing storage in modifiers.
    init(storage: FocusStateStorage<Value>) {
        self.storage = storage
    }

    public var wrappedValue: Value {
        get { storage.value ?? storage.defaultValue }
        nonmutating set { storage.setProgrammatic(newValue) }
    }

    public var projectedValue: FocusState<Value> { self }

    public var anyStorage: AnyStateStorage { storage }
}
