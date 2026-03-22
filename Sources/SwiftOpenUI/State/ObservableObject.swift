import Foundation

// MARK: - ObservableObject

/// A class whose published properties trigger view re-renders.
public protocol ObservableObject: AnyObject {}

// MARK: - @Published

/// Protocol for type-erased access to PublishedStorage.
public protocol AnyPublishedProvider {
    var anyPublished: AnyPublishedStorage { get }
}

/// Protocol for type-erased PublishedStorage.
public protocol AnyPublishedStorage: AnyObject {
    /// Add an observer identified by a token. Replaces any existing observer
    /// with the same token, preventing accumulation on re-wiring.
    func setObserver(token: ObjectIdentifier, _ observer: @escaping () -> Void)
}

/// A property wrapper for properties of ObservableObject that trigger re-renders.
@propertyWrapper
public struct Published<Value>: AnyPublishedProvider {
    public let storage: PublishedStorage<Value>

    public init(wrappedValue: Value) {
        storage = PublishedStorage(wrappedValue)
    }

    public var wrappedValue: Value {
        get { storage.value }
        nonmutating set { storage.setValue(newValue) }
    }

    public var anyPublished: AnyPublishedStorage { storage }
}

/// Backing storage for @Published. Thread-safe with token-keyed observer map.
/// Each observer is identified by an ObjectIdentifier (the ObservedObjectStorage
/// instance), so re-wiring replaces the old observer instead of accumulating.
public class PublishedStorage<Value>: AnyPublishedStorage, GenerationTracked {
    private let lock = NSLock()
    private var _value: Value
    private var observers: [ObjectIdentifier: () -> Void] = [:]
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
        let currentObservers = observers.values
        lock.unlock()
        for observer in currentObservers {
            observer()
        }
    }

    public func setObserver(token: ObjectIdentifier, _ observer: @escaping () -> Void) {
        lock.lock()
        observers[token] = observer
        lock.unlock()
    }
}

// MARK: - @ObservedObject

/// A property wrapper that observes an external ObservableObject.
/// When any @Published property on the object changes, the owning
/// ViewHost schedules a re-render.
@propertyWrapper
public struct ObservedObject<ObjectType: ObservableObject>: AnyStateStorageProvider {
    public let storage: ObservedObjectStorage<ObjectType>

    public init(wrappedValue: ObjectType) {
        storage = ObservedObjectStorage(wrappedValue)
    }

    public var wrappedValue: ObjectType {
        storage.object
    }

    public var anyStorage: AnyStateStorage { storage }
}

/// Backing storage for @ObservedObject. Conforms to AnyStateStorage so
/// installState in ViewHost can wire it automatically via Mirror.
public class ObservedObjectStorage<ObjectType: ObservableObject>: AnyStateStorage {
    public let object: ObjectType
    public weak var host: AnyViewHost? {
        didSet { wirePublishedProperties() }
    }

    public init(_ object: ObjectType) {
        self.object = object
    }

    private func wirePublishedProperties() {
        wirePublished(object: object, token: ObjectIdentifier(self), host: host)
    }

    public func restoreValue(from other: AnyStateStorage) {
        // ObservedObject holds a reference — no value to restore
    }
}

// MARK: - @StateObject

/// A property wrapper that creates and owns an ObservableObject with the
/// view's lifecycle. Unlike @ObservedObject (which wraps an externally-provided
/// object), @StateObject creates the object once and keeps it alive across
/// rebuilds — the same pattern as @State but for ObservableObject instances.
@propertyWrapper
public struct StateObject<ObjectType: ObservableObject>: AnyStateStorageProvider {
    public let storage: StateObjectStorage<ObjectType>

    public init(wrappedValue: @autoclosure @escaping () -> ObjectType) {
        storage = StateObjectStorage(factory: wrappedValue)
    }

    public var wrappedValue: ObjectType { storage.object }
    public var anyStorage: AnyStateStorage { storage }
}

/// Backing storage for @StateObject. Creates the object lazily on first
/// access and caches it. Since this is a class (reference type), copying
/// the view struct shares the same storage — the object persists.
public class StateObjectStorage<ObjectType: ObservableObject>: AnyStateStorage {
    private let factory: () -> ObjectType
    private var _object: ObjectType?
    public weak var host: AnyViewHost? {
        didSet { wirePublishedProperties() }
    }

    public init(factory: @escaping () -> ObjectType) {
        self.factory = factory
    }

    public var object: ObjectType {
        if let obj = _object { return obj }
        let obj = factory()
        _object = obj
        return obj
    }

    private func wirePublishedProperties() {
        wirePublished(object: object, token: ObjectIdentifier(self), host: host)
    }

    public func restoreValue(from other: AnyStateStorage) {
        // StateObject owns its object — no value to restore
    }
}

// MARK: - @EnvironmentObject

/// A property wrapper that reads an ObservableObject from the environment.
/// The object must be injected by an ancestor view using `.environmentObject()`.
@propertyWrapper
public struct EnvironmentObject<ObjectType: ObservableObject>: AnyStateStorageProvider {
    public let storage: EnvironmentObjectStorage<ObjectType>

    public init() {
        storage = EnvironmentObjectStorage()
    }

    public var wrappedValue: ObjectType { storage.object }
    public var anyStorage: AnyStateStorage { storage }
}

/// Backing storage for @EnvironmentObject. Resolves the object lazily
/// from the environment on first access.
public class EnvironmentObjectStorage<ObjectType: ObservableObject>: AnyStateStorage {
    private var _object: ObjectType?
    public weak var host: AnyViewHost? {
        didSet { wirePublishedProperties() }
    }

    public init() {}

    public var object: ObjectType {
        if let obj = _object { return obj }
        guard let obj = getEnvironmentObject(ObjectType.self) else {
            fatalError("No ObservableObject of type \(ObjectType.self) found in environment. Use .environmentObject() to inject it.")
        }
        _object = obj
        return obj
    }

    private func wirePublishedProperties() {
        wirePublished(object: object, token: ObjectIdentifier(self), host: host)
    }

    public func restoreValue(from other: AnyStateStorage) {
        // EnvironmentObject is resolved from environment — no value to restore
    }
}

// MARK: - Shared wiring helper

/// Walk an ObservableObject's @Published properties via Mirror and wire
/// observers to the host's scheduleRebuild. Walks the full superclass
/// chain so inherited @Published properties are also observed.
private func wirePublished<T: ObservableObject>(
    object: T, token: ObjectIdentifier, host: AnyViewHost?
) {
    var mirror: Mirror? = Mirror(reflecting: object)
    while let m = mirror {
        for child in m.children {
            if let provider = child.value as? AnyPublishedProvider {
                let storage = provider.anyPublished
                provider.anyPublished.setObserver(token: token) { [weak host] in
                    guard let host = host else { return }
                    // Skip rebuild if host has a read-set and this storage wasn't read
                    if let trackingHost = host as? DependencyTrackingHost,
                       let readSet = trackingHost.lastReadSet,
                       !isDependency(storage as AnyObject, in: readSet) {
                        return
                    }
                    host.scheduleRebuild()
                }
            }
        }
        mirror = m.superclassMirror
    }
}
