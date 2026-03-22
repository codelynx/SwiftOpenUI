/// Host-level dependency gating for state-driven rebuilds.
///
/// Records which state sources (PublishedStorage) a ViewHost reads during
/// body evaluation. On subsequent @Published changes, rebuilds are suppressed
/// for hosts whose read-set does not include the changed source.
///
/// @State always rebuilds its declaring host (no gating) because the declaring
/// host is the only one notified and may pass the value to children via Binding.
///
/// This reduces cross-source over-invalidation but does not avoid whole-host
/// rebuilds when multiple used sources belong to the same host.

// MARK: - Tracking context (stack-based)

/// Stack of read-sets for nested tracking sessions.
/// Parent body evaluation may synchronously render nested stateful children,
/// each with their own begin/end tracking. A stack ensures the parent's
/// session is restored after the child's completes.
private var _trackingStack: [Set<ObjectIdentifier>] = []

/// Begin tracking reads. Call before body evaluation.
/// Pushes a new empty read-set onto the stack.
public func beginDependencyTracking() {
    _trackingStack.append(Set())
}

/// Record a storage read. Called from StateStorage/PublishedStorage value getters.
/// Records into the topmost (innermost) tracking session. No-op when stack is empty.
public func recordDependencyRead(_ storage: AnyObject) {
    guard !_trackingStack.isEmpty else { return }
    _trackingStack[_trackingStack.count - 1].insert(ObjectIdentifier(storage))
}

/// End tracking and return the captured read-set.
/// Pops the topmost session from the stack, restoring the parent's session.
/// Returns nil if the stack was empty (no tracking active).
public func endDependencyTracking() -> Set<ObjectIdentifier>? {
    guard !_trackingStack.isEmpty else { return nil }
    return _trackingStack.removeLast()
}

/// Check if a storage was read during a tracked render.
public func isDependency(_ storage: AnyObject, in readSet: Set<ObjectIdentifier>) -> Bool {
    readSet.contains(ObjectIdentifier(storage))
}

// MARK: - DependencyTrackingHost protocol

/// Protocol for ViewHosts that support dependency-gated rebuilds.
/// Backends conform their ViewHost to this protocol and store the
/// read-set captured at the end of each render pass.
public protocol DependencyTrackingHost: AnyViewHost {
    /// The set of storage ObjectIdentifiers read during the last render.
    /// Nil means no tracking data — always rebuild (safe default).
    var lastReadSet: Set<ObjectIdentifier>? { get set }
}
