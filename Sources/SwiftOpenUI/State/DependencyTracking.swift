/// Host-level dependency gating and input-equality short-circuiting.
///
/// Phase 6: Records which state sources a ViewHost reads during body evaluation.
/// On subsequent changes, rebuilds are suppressed for unread sources.
///
/// Phase 7: Captures generation counters of read storages. Before the next
/// body evaluation, compares current generations to the snapshot. If all match,
/// no storage was mutated → skip rebuild entirely.

// MARK: - Generation tracking

/// Protocol for storages that track a mutation generation counter.
/// Both StateStorage and PublishedStorage conform.
public protocol GenerationTracked: AnyObject {
    var generation: UInt64 { get }
}

/// Snapshot of a storage's identity and generation at render time.
public struct StorageSnapshot {
    public weak var storage: AnyObject?
    public let generation: UInt64

    public init(storage: AnyObject, generation: UInt64) {
        self.storage = storage
        self.generation = generation
    }
}

/// Check if all storages in the snapshot still have the same generation.
/// Returns true if nothing changed (safe to skip rebuild).
/// Returns false if any storage was mutated, deallocated, or the snapshot
/// is empty (no tracked inputs → can't prove nothing changed, e.g.
/// @Observable or @FocusState driven rebuilds).
public func inputsUnchanged(snapshot: [StorageSnapshot]) -> Bool {
    guard !snapshot.isEmpty else { return false }
    for snap in snapshot {
        guard let storage = snap.storage as? GenerationTracked else {
            return false // Deallocated or not tracked — assume changed
        }
        if storage.generation != snap.generation {
            return false
        }
    }
    return true
}

// MARK: - Tracking context (stack-based)

/// Each tracking session captures both a read-set (Phase 6) and
/// a snapshot array (Phase 7).
private struct TrackingSession {
    var readSet: Set<ObjectIdentifier> = []
    var snapshots: [StorageSnapshot] = []
}

/// Stack of tracking sessions for nested stateful host renders.
private var _trackingStack: [TrackingSession] = []

/// Begin tracking reads. Call before body evaluation.
public func beginDependencyTracking() {
    _trackingStack.append(TrackingSession())
}

/// Record a storage read. Called from StateStorage/PublishedStorage value getters.
/// Captures both the ObjectIdentifier (Phase 6) and generation snapshot (Phase 7).
public func recordDependencyRead(_ storage: AnyObject) {
    guard !_trackingStack.isEmpty else { return }
    let id = ObjectIdentifier(storage)
    let idx = _trackingStack.count - 1
    // Only record each storage once per session
    if !_trackingStack[idx].readSet.contains(id) {
        _trackingStack[idx].readSet.insert(id)
        if let tracked = storage as? GenerationTracked {
            _trackingStack[idx].snapshots.append(
                StorageSnapshot(storage: storage, generation: tracked.generation))
        }
    }
}

/// End tracking and return the captured read-set (Phase 6) and snapshots (Phase 7).
public func endDependencyTracking() -> (readSet: Set<ObjectIdentifier>, snapshots: [StorageSnapshot])? {
    guard !_trackingStack.isEmpty else { return nil }
    let session = _trackingStack.removeLast()
    return (readSet: session.readSet, snapshots: session.snapshots)
}

/// Check if a storage was read during a tracked render (Phase 6).
public func isDependency(_ storage: AnyObject, in readSet: Set<ObjectIdentifier>) -> Bool {
    readSet.contains(ObjectIdentifier(storage))
}

// MARK: - DependencyTrackingHost protocol

/// Protocol for ViewHosts that support dependency-gated rebuilds
/// and input-equality short-circuiting.
public protocol DependencyTrackingHost: AnyViewHost {
    /// The set of storage ObjectIdentifiers read during the last render (Phase 6).
    var lastReadSet: Set<ObjectIdentifier>? { get set }
    /// Generation snapshots of storages read during the last render (Phase 7).
    var lastInputSnapshot: [StorageSnapshot]? { get set }
}
