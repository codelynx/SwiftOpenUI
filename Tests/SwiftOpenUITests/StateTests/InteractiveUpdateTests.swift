import XCTest
@testable import SwiftOpenUI

// MARK: - Mock ViewHost with interactive update support

private class MockInteractiveHost: AnyViewHost, DependencyTrackingHost {
    var lastReadSet: Set<ObjectIdentifier>?
    var lastInputSnapshot: [StorageSnapshot]?
    var rebuildCount = 0
    private var interactiveUpdateDepth = 0
    private var rebuildDeferredDuringInteraction = false
    private var scheduled = false

    func scheduleRebuild() {
        if interactiveUpdateDepth > 0 {
            rebuildDeferredDuringInteraction = true
            return
        }
        guard !scheduled else { return }
        scheduled = true
        // Simulate immediate rebuild (no async dispatch in tests)
        rebuild()
    }

    func suppressNextFocusRestore() {}

    func beginInteractiveUpdate() {
        interactiveUpdateDepth += 1
    }

    func endInteractiveUpdate() {
        guard interactiveUpdateDepth > 0 else { return }
        interactiveUpdateDepth -= 1
        guard interactiveUpdateDepth == 0,
              rebuildDeferredDuringInteraction,
              !scheduled else { return }
        rebuildDeferredDuringInteraction = false
        scheduled = true
        rebuild()
    }

    private func rebuild() {
        scheduled = false
        rebuildCount += 1
    }
}

final class InteractiveUpdateTests: XCTestCase {

    func testScheduleRebuildSuppressedDuringInteraction() {
        let host = MockInteractiveHost()
        host.beginInteractiveUpdate()
        host.scheduleRebuild()
        XCTAssertEqual(host.rebuildCount, 0, "Rebuild should be suppressed during interaction")
    }

    func testDeferredRebuildFiresOnEnd() {
        let host = MockInteractiveHost()
        host.beginInteractiveUpdate()
        host.scheduleRebuild()
        XCTAssertEqual(host.rebuildCount, 0)
        host.endInteractiveUpdate()
        XCTAssertEqual(host.rebuildCount, 1, "Deferred rebuild should fire on end")
    }

    func testNestedInteractiveUpdates() {
        let host = MockInteractiveHost()
        host.beginInteractiveUpdate()
        host.beginInteractiveUpdate()
        host.scheduleRebuild()
        host.endInteractiveUpdate()
        XCTAssertEqual(host.rebuildCount, 0, "Still suppressed — one level remaining")
        host.endInteractiveUpdate()
        XCTAssertEqual(host.rebuildCount, 1, "All levels ended — rebuild fires")
    }

    func testNoDeferredRebuildIfNothingScheduled() {
        let host = MockInteractiveHost()
        host.beginInteractiveUpdate()
        host.endInteractiveUpdate()
        XCTAssertEqual(host.rebuildCount, 0, "No deferred rebuild if nothing was scheduled")
    }

    func testBindingUpdatesFlowDuringInteraction() {
        let host = MockInteractiveHost()
        let storage = StateStorage(42)
        storage.host = host

        host.beginInteractiveUpdate()
        storage.setValue(99)

        // Value should have been updated even though rebuild is suppressed
        XCTAssertEqual(storage.value, 99, "Binding value should update during interaction")
        // @State always rebuilds its declaring host, but the host suppresses
        // the rebuild because interactiveUpdateDepth > 0
        XCTAssertEqual(host.rebuildCount, 0, "Rebuild suppressed during interaction")
    }
}
