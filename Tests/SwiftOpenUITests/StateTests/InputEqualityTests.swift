import XCTest
@testable import SwiftOpenUI

final class InputEqualityTests: XCTestCase {

    // MARK: - Generation counter

    func testGenerationIncrementsOnSetValue() {
        let storage = StateStorage(42)
        XCTAssertEqual(storage.generation, 0)
        storage.setValue(99)
        XCTAssertEqual(storage.generation, 1)
        storage.setValue(100)
        XCTAssertEqual(storage.generation, 2)
    }

    func testPublishedGenerationIncrementsOnSetValue() {
        let storage = PublishedStorage("hello")
        XCTAssertEqual(storage.generation, 0)
        storage.setValue("world")
        XCTAssertEqual(storage.generation, 1)
    }

    func testGenerationDoesNotIncrementOnRead() {
        let storage = StateStorage(42)
        _ = storage.value
        XCTAssertEqual(storage.generation, 0, "Reading should not change generation")
    }

    // MARK: - Snapshot capture

    func testSnapshotCapturedDuringTracking() {
        let storage1 = StateStorage(1)
        let storage2 = PublishedStorage("two")
        storage1.setValue(10) // generation = 1
        storage2.setValue("updated") // generation = 1

        beginDependencyTracking()
        _ = storage1.value
        _ = storage2.value
        let tracking = endDependencyTracking()

        XCTAssertNotNil(tracking)
        XCTAssertEqual(tracking!.snapshots.count, 2)
        // Both should have generation 1
        for snap in tracking!.snapshots {
            XCTAssertEqual(snap.generation, 1)
        }
    }

    // MARK: - inputsUnchanged

    func testInputsUnchangedWhenNoMutation() {
        let storage = StateStorage(42)
        storage.setValue(99) // generation = 1

        beginDependencyTracking()
        _ = storage.value
        let tracking = endDependencyTracking()!

        // No further mutations — inputs should be unchanged
        XCTAssertTrue(inputsUnchanged(snapshot: tracking.snapshots))
    }

    func testInputsChangedAfterMutation() {
        let storage = StateStorage(42)

        beginDependencyTracking()
        _ = storage.value
        let tracking = endDependencyTracking()!

        // Mutate after snapshot was taken
        storage.setValue(99)

        // Inputs should be changed (generation mismatch)
        XCTAssertFalse(inputsUnchanged(snapshot: tracking.snapshots))
    }

    func testInputsChangedWhenSnapshotEmpty() {
        // Empty snapshot means no GenerationTracked inputs were read —
        // e.g. @Observable or @FocusState driven rebuild. Can't prove
        // nothing changed, so must return false (rebuild).
        XCTAssertFalse(inputsUnchanged(snapshot: []))
    }

    func testInputsChangedWhenStorageDeallocated() {
        var tracking: (readSet: Set<ObjectIdentifier>, snapshots: [StorageSnapshot])!

        // Create storage in a scope so it gets deallocated
        do {
            let storage = StateStorage(42)
            beginDependencyTracking()
            _ = storage.value
            tracking = endDependencyTracking()!
        }

        // Storage is deallocated — weak ref is nil → treat as changed (safe default)
        XCTAssertFalse(inputsUnchanged(snapshot: tracking.snapshots))
    }
}
