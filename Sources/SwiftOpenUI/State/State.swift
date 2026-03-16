import Foundation

/// Protocol for type-erased access to StateStorage from @State wrappers.
public protocol AnyStateStorageProvider {
    var anyStorage: AnyStateStorage { get }
}

/// Protocol for type-erased StateStorage, allowing ViewHost connection.
public protocol AnyStateStorage: AnyObject {
    var host: AnyViewHost? { get set }
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
public class StateStorage<Value>: AnyStateStorage {
    private let lock = NSLock()
    private var _value: Value
    public weak var host: AnyViewHost?

    public init(_ value: Value) {
        _value = value
    }

    public var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    public func setValue(_ newValue: Value) {
        lock.lock()
        _value = newValue
        lock.unlock()
        host?.scheduleRebuild()
    }
}
