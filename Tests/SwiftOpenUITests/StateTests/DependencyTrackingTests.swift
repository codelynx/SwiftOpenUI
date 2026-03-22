import XCTest
@testable import SwiftOpenUI

// MARK: - Mock ViewHost

private class MockViewHost: AnyViewHost, DependencyTrackingHost {
    var lastReadSet: Set<ObjectIdentifier>?
    var lastInputSnapshot: [StorageSnapshot]?
    var rebuildCount = 0

    func scheduleRebuild() { rebuildCount += 1 }
    func suppressNextFocusRestore() {}
}

final class DependencyTrackingTests: XCTestCase {

    // MARK: - Tracking context

    func testBeginEndTracking() {
        let obj = NSObject()
        beginDependencyTracking()
        recordDependencyRead(obj)
        let tracking = endDependencyTracking()
        XCTAssertNotNil(tracking)
        XCTAssertTrue(tracking!.readSet.contains(ObjectIdentifier(obj)))
    }

    func testEmptyTrackingReturnsEmptySet() {
        beginDependencyTracking()
        let tracking = endDependencyTracking()
        XCTAssertNotNil(tracking)
        XCTAssertTrue(tracking!.readSet.isEmpty)
    }

    func testNoTrackingReturnsNil() {
        let tracking = endDependencyTracking()
        XCTAssertNil(tracking)
    }

    // MARK: - isDependency

    func testIsDependencyTrue() {
        let obj = NSObject()
        let readSet: Set<ObjectIdentifier> = [ObjectIdentifier(obj)]
        XCTAssertTrue(isDependency(obj, in: readSet))
    }

    func testIsDependencyFalse() {
        let obj = NSObject()
        let other = NSObject()
        let readSet: Set<ObjectIdentifier> = [ObjectIdentifier(other)]
        XCTAssertFalse(isDependency(obj, in: readSet))
    }

    // MARK: - Storage integration

    func testStateStorageRecordsDependency() {
        let storage = StateStorage(42)
        beginDependencyTracking()
        _ = storage.value
        let tracking = endDependencyTracking()
        XCTAssertNotNil(tracking)
        XCTAssertTrue(tracking!.readSet.contains(ObjectIdentifier(storage)))
    }

    func testPublishedStorageRecordsDependency() {
        let storage = PublishedStorage("hello")
        beginDependencyTracking()
        _ = storage.value
        let tracking = endDependencyTracking()
        XCTAssertNotNil(tracking)
        XCTAssertTrue(tracking!.readSet.contains(ObjectIdentifier(storage)))
    }

    // MARK: - @State always rebuilds (no gating)

    func testStateAlwaysRebuildsEvenWhenUnread() {
        let host = MockViewHost()
        let unreadStorage = StateStorage(1)
        unreadStorage.host = host

        beginDependencyTracking()
        let tracking = endDependencyTracking()
        host.lastReadSet = tracking?.readSet

        host.rebuildCount = 0
        unreadStorage.setValue(99)
        XCTAssertEqual(host.rebuildCount, 1, "@State must always rebuild — may pass value via Binding")
    }

    // MARK: - @Published gating

    func testPublishedSkipsRebuildForUnreadStorage() {
        let host = MockViewHost()
        let readPublished = PublishedStorage("read")
        let unreadPublished = PublishedStorage("unread")

        readPublished.setObserver(token: ObjectIdentifier(host)) { [weak host] in
            guard let host = host else { return }
            if let trackingHost = host as? DependencyTrackingHost,
               let readSet = trackingHost.lastReadSet,
               !isDependency(readPublished, in: readSet) {
                return
            }
            host.scheduleRebuild()
        }
        unreadPublished.setObserver(token: ObjectIdentifier(host)) { [weak host] in
            guard let host = host else { return }
            if let trackingHost = host as? DependencyTrackingHost,
               let readSet = trackingHost.lastReadSet,
               !isDependency(unreadPublished, in: readSet) {
                return
            }
            host.scheduleRebuild()
        }

        beginDependencyTracking()
        _ = readPublished.value
        let tracking = endDependencyTracking()
        host.lastReadSet = tracking?.readSet

        host.rebuildCount = 0
        unreadPublished.setValue("changed")
        XCTAssertEqual(host.rebuildCount, 0, "Should skip rebuild for unread @Published")
    }

    func testPublishedRebuildsForReadStorage() {
        let host = MockViewHost()
        let readPublished = PublishedStorage("read")

        readPublished.setObserver(token: ObjectIdentifier(host)) { [weak host] in
            guard let host = host else { return }
            if let trackingHost = host as? DependencyTrackingHost,
               let readSet = trackingHost.lastReadSet,
               !isDependency(readPublished, in: readSet) {
                return
            }
            host.scheduleRebuild()
        }

        beginDependencyTracking()
        _ = readPublished.value
        let tracking = endDependencyTracking()
        host.lastReadSet = tracking?.readSet

        host.rebuildCount = 0
        readPublished.setValue("changed")
        XCTAssertEqual(host.rebuildCount, 1, "Should rebuild for read @Published")
    }

    // MARK: - Nested tracking (stack-based)

    func testNestedTrackingPreservesParentSession() {
        let parentObj = NSObject()
        let childObj = NSObject()

        beginDependencyTracking()
        recordDependencyRead(parentObj)

        beginDependencyTracking()
        recordDependencyRead(childObj)
        let childTracking = endDependencyTracking()

        XCTAssertNotNil(childTracking)
        XCTAssertTrue(childTracking!.readSet.contains(ObjectIdentifier(childObj)))
        XCTAssertFalse(childTracking!.readSet.contains(ObjectIdentifier(parentObj)))

        let parentTracking = endDependencyTracking()
        XCTAssertNotNil(parentTracking)
        XCTAssertTrue(parentTracking!.readSet.contains(ObjectIdentifier(parentObj)))
        XCTAssertFalse(parentTracking!.readSet.contains(ObjectIdentifier(childObj)))
    }
}
