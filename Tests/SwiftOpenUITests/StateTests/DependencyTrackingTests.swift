import XCTest
@testable import SwiftOpenUI

// MARK: - Mock ViewHost

private class MockViewHost: AnyViewHost, DependencyTrackingHost {
    var lastReadSet: Set<ObjectIdentifier>?
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
        let readSet = endDependencyTracking()
        XCTAssertNotNil(readSet)
        XCTAssertTrue(readSet!.contains(ObjectIdentifier(obj)))
    }

    func testEmptyTrackingReturnsEmptySet() {
        beginDependencyTracking()
        let readSet = endDependencyTracking()
        XCTAssertNotNil(readSet)
        XCTAssertTrue(readSet!.isEmpty)
    }

    func testNoTrackingReturnsNil() {
        let readSet = endDependencyTracking()
        XCTAssertNil(readSet)
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
        let readSet = endDependencyTracking()
        XCTAssertNotNil(readSet)
        XCTAssertTrue(readSet!.contains(ObjectIdentifier(storage)))
    }

    func testPublishedStorageRecordsDependency() {
        let storage = PublishedStorage("hello")
        beginDependencyTracking()
        _ = storage.value
        let readSet = endDependencyTracking()
        XCTAssertNotNil(readSet)
        XCTAssertTrue(readSet!.contains(ObjectIdentifier(storage)))
    }

    // MARK: - @State always rebuilds (no gating)

    func testStateAlwaysRebuildsEvenWhenUnread() {
        let host = MockViewHost()
        let unreadStorage = StateStorage(1)
        unreadStorage.host = host

        // Simulate a render that reads nothing
        beginDependencyTracking()
        host.lastReadSet = endDependencyTracking()

        // @State always rebuilds its declaring host, regardless of read-set
        host.rebuildCount = 0
        unreadStorage.setValue(99)
        XCTAssertEqual(host.rebuildCount, 1, "@State must always rebuild — may pass value via Binding")
    }

    // MARK: - @Published gating

    func testPublishedSkipsRebuildForUnreadStorage() {
        let host = MockViewHost()
        let readPublished = PublishedStorage("read")
        let unreadPublished = PublishedStorage("unread")

        // Wire observers (simulating wirePublished behavior)
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

        // Simulate a render that only reads readPublished
        beginDependencyTracking()
        _ = readPublished.value
        host.lastReadSet = endDependencyTracking()

        // Change the unread published — should be skipped
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

        // Simulate a render that reads readPublished
        beginDependencyTracking()
        _ = readPublished.value
        host.lastReadSet = endDependencyTracking()

        // Change the read published — should rebuild
        host.rebuildCount = 0
        readPublished.setValue("changed")
        XCTAssertEqual(host.rebuildCount, 1, "Should rebuild for read @Published")
    }

    // MARK: - Nested tracking (stack-based)

    func testNestedTrackingPreservesParentSession() {
        let parentObj = NSObject()
        let childObj = NSObject()

        // Parent begins tracking
        beginDependencyTracking()
        recordDependencyRead(parentObj)

        // Child begins nested tracking (simulating nested stateful view render)
        beginDependencyTracking()
        recordDependencyRead(childObj)
        let childReadSet = endDependencyTracking()

        // Child should have its own read-set
        XCTAssertNotNil(childReadSet)
        XCTAssertTrue(childReadSet!.contains(ObjectIdentifier(childObj)))
        XCTAssertFalse(childReadSet!.contains(ObjectIdentifier(parentObj)))

        // Parent session should be restored with its reads intact
        let parentReadSet = endDependencyTracking()
        XCTAssertNotNil(parentReadSet)
        XCTAssertTrue(parentReadSet!.contains(ObjectIdentifier(parentObj)))
        XCTAssertFalse(parentReadSet!.contains(ObjectIdentifier(childObj)))
    }
}
