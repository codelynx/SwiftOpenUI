import Foundation

/// Protocol for type-erased access to StateStorage from @State wrappers.
public protocol AnyStateStorageProvider {
    var anyStorage: AnyStateStorage { get }
}

/// Protocol for type-erased StateStorage, allowing ViewHost connection.
public protocol AnyStateStorage: AnyObject {
    var host: AnyViewHost? { get set }
    /// Copy the stored value from another storage of the same concrete type.
    func restoreValue(from other: AnyStateStorage)
}

/// A property wrapper that stores mutable state for a view.
/// When the value changes, the owning ViewHost schedules a re-render.
///
/// `@State` is a struct wrapping a `StateStorage` class. Copying a view
/// shares the same storage identity (same as SwiftUI). This is intentional:
/// the view struct is recreated on each re-render, but the storage persists.
@propertyWrapper
public struct State<Value>: AnyStateStorageProvider {
    public let storage: StateStorage<Value>

    public init(wrappedValue: Value) {
        storage = StateStorage(wrappedValue)
    }

    public var wrappedValue: Value {
        get { storage.value }
        nonmutating set { storage.setValue(newValue) }
    }

    public var projectedValue: Binding<Value> {
        Binding(get: { self.storage.value }, set: { self.storage.setValue($0) })
    }

    public var anyStorage: AnyStateStorage { storage }
}

/// The backing storage for @State. Thread-safe value access with
/// coalesced re-render scheduling via the owning ViewHost.
public class StateStorage<Value>: AnyStateStorage, GenerationTracked {
    private let lock = NSLock()
    var _value: Value  // internal for restoreValue cross-storage access
    public weak var host: AnyViewHost?
    public private(set) var generation: UInt64 = 0

    public init(_ value: Value) {
        _value = value
    }

    public var value: Value {
        lock.lock()
        defer { lock.unlock() }
        recordDependencyRead(self)
        return _value
    }

    public func setValue(_ newValue: Value) {
        lock.lock()
        _value = newValue
        generation += 1
        lock.unlock()
        // @State always rebuilds its declaring host — no dependency gating.
        // The declaring host is the only host notified, and it may pass
        // the value to children via Binding. Skipping its rebuild would
        // leave bound children stale.
        host?.scheduleRebuild()
    }

    public func restoreValue(from other: AnyStateStorage) {
        if let typed = other as? StateStorage<Value> {
            // Direct access without lock — called only during render pass (single-threaded)
            _value = typed._value
        }
    }
}
