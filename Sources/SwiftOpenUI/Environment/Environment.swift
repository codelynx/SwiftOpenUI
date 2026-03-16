import Foundation

/// A key for an environment value.
public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

/// A collection of environment values propagated down the view tree.
public struct EnvironmentValues {
    private var storage: [ObjectIdentifier: Any] = [:]
    private var objects: [ObjectIdentifier: AnyObject] = [:]

    public init() {}

    public subscript<K: EnvironmentKey>(_ key: K.Type) -> K.Value {
        get { storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }

    /// Create a copy with a value set for a key path.
    public func setting<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, to value: V) -> EnvironmentValues {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }

    /// Store an ObservableObject by type.
    public mutating func setObject<T: ObservableObject>(_ object: T) {
        objects[ObjectIdentifier(T.self)] = object
    }

    /// Retrieve an ObservableObject by type.
    public func getObject<T: ObservableObject>(_ type: T.Type) -> T? {
        objects[ObjectIdentifier(type)] as? T
    }
}

// MARK: - Thread-local environment for render pass

#if canImport(Glibc) || canImport(Darwin)
private let _envKey: pthread_key_t = {
    var key = pthread_key_t()
    pthread_key_create(&key, nil)
    return key
}()

/// Set the current environment values for the render pass.
public func setCurrentEnvironment(_ env: EnvironmentValues?) {
    if let env = env {
        let box = Unmanaged.passRetained(EnvironmentBox(env)).toOpaque()
        if let prev = pthread_getspecific(_envKey) {
            Unmanaged<EnvironmentBox>.fromOpaque(prev).release()
        }
        pthread_setspecific(_envKey, box)
    } else {
        if let prev = pthread_getspecific(_envKey) {
            Unmanaged<EnvironmentBox>.fromOpaque(prev).release()
        }
        pthread_setspecific(_envKey, nil)
    }
}

/// Get the current environment values (render-time only).
public func getCurrentEnvironment() -> EnvironmentValues {
    guard let ptr = pthread_getspecific(_envKey) else { return EnvironmentValues() }
    return Unmanaged<EnvironmentBox>.fromOpaque(ptr).takeUnretainedValue().values
}
#elseif canImport(WinSDK)
import WinSDK

private let _tlsIndex: DWORD = TlsAlloc()

public func setCurrentEnvironment(_ env: EnvironmentValues?) {
    if let env = env {
        let box = Unmanaged.passRetained(EnvironmentBox(env)).toOpaque()
        if let prev = TlsGetValue(_tlsIndex) {
            Unmanaged<EnvironmentBox>.fromOpaque(prev).release()
        }
        TlsSetValue(_tlsIndex, box)
    } else {
        if let prev = TlsGetValue(_tlsIndex) {
            Unmanaged<EnvironmentBox>.fromOpaque(prev).release()
        }
        TlsSetValue(_tlsIndex, nil)
    }
}

public func getCurrentEnvironment() -> EnvironmentValues {
    guard let ptr = TlsGetValue(_tlsIndex) else { return EnvironmentValues() }
    return Unmanaged<EnvironmentBox>.fromOpaque(ptr).takeUnretainedValue().values
}
#endif

/// Box for storing EnvironmentValues in thread-local storage.
private class EnvironmentBox {
    let values: EnvironmentValues
    init(_ values: EnvironmentValues) { self.values = values }
}

// MARK: - @Environment property wrapper

/// Reads a value from the current environment at render time.
@propertyWrapper
public struct Environment<Value> {
    private let keyPath: KeyPath<EnvironmentValues, Value>

    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value {
        getCurrentEnvironment()[keyPath: keyPath]
    }
}

// MARK: - Environment object lookup

/// Retrieve an ObservableObject from the current thread-local environment by type.
public func getEnvironmentObject<T: ObservableObject>(_ type: T.Type) -> T? {
    getCurrentEnvironment().getObject(type)
}

// MARK: - Built-in keys

/// SwiftUI-compatible color scheme enum.
public enum ColorScheme: String, Equatable {
    case light
    case dark
}

/// Color scheme key.
public struct ColorSchemeKey: EnvironmentKey {
    public static let defaultValue: ColorScheme = .light
}

extension EnvironmentValues {
    public var colorScheme: ColorScheme {
        get { self[ColorSchemeKey.self] }
        set { self[ColorSchemeKey.self] = newValue }
    }
}

/// A callable action that dismisses the current sheet or dialog.
public struct DismissAction {
    let handler: () -> Void

    public init(handler: @escaping () -> Void = {}) {
        self.handler = handler
    }

    /// Dismiss the enclosing presentation (sheet, alert, etc.).
    public func callAsFunction() {
        handler()
    }
}

/// Environment key for the dismiss action.
public struct DismissKey: EnvironmentKey {
    public static let defaultValue: DismissAction = DismissAction()
}

extension EnvironmentValues {
    public var dismiss: DismissAction {
        get { self[DismissKey.self] }
        set { self[DismissKey.self] = newValue }
    }
}
