import Foundation

/// Protocol for the reactive view container that manages rebuild scheduling.
/// Platform backends provide concrete implementations (GTK ViewHost, Win32 ViewHost, etc.).
public protocol AnyViewHost: AnyObject {
    /// Schedule a coalesced rebuild of the hosted view subtree.
    func scheduleRebuild()

    /// Suppress the next automatic focus restoration during rebuild.
    func suppressNextFocusRestore()
}

/// Connect all @State / @ObservedObject / @StateObject / @EnvironmentObject
/// storages found on a view (via Mirror) to the given ViewHost.
public func installState<V>(_ view: V, host: AnyViewHost) {
    let mirror = Mirror(reflecting: view)
    for child in mirror.children {
        if let provider = child.value as? AnyStateStorageProvider {
            provider.anyStorage.host = host
        }
    }
}

/// Check if a view has any reactive properties (@State or @ObservedObject) via reflection.
public func hasReactiveProperties<V>(_ view: V) -> Bool {
    let mirror = Mirror(reflecting: view)
    return mirror.children.contains { $0.value is AnyStateStorageProvider }
}
