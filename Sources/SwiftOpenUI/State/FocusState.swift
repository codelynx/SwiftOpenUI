import Foundation

/// Storage for focus state, shared across view copies.
/// Implements AnyStateStorage so ViewHost wires up rebuild scheduling.
///
/// Platform backends extend this class to add native focus management
/// (e.g., GTK widget focus, Win32 SetFocus).
open class FocusStateStorage<Value: Hashable>: AnyStateStorage {
    private let lock = NSLock()
    private var _value: Value?
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

        // Notify the platform backend of the focus change
        platformFocusChanged(newValue)

        // Only rebuild when programmatic (e.g., button sets focusedField).
        // Platform focus events should NOT trigger rebuilds —
        // rebuilding destroys and recreates widgets, losing focus.
        if programmatic {
            if newValue == nil {
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

    /// Override in platform backends to handle native focus changes.
    open func platformFocusChanged(_ newValue: Value?) {}
}

/// A property wrapper that tracks keyboard focus state, matching SwiftUI's @FocusState.
///
/// Use with `.focused($focusField, equals: .someCase)` to bind focus state to an enum.
/// Use with `.focused($isFocused)` for simple boolean focus tracking.
@propertyWrapper
public struct FocusState<Value: Hashable>: AnyStateStorageProvider {
    let storage: FocusStateStorage<Value>

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
