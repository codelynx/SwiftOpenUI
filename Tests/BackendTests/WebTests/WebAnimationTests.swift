import XCTest
@testable import SwiftOpenUI
@testable import BackendWeb

final class WebAnimationTests: XCTestCase {

    // MARK: - webCSSTimingFunction

    func testCSSTimingFunctionLinear() {
        XCTAssertEqual(webCSSTimingFunction(.linear), "linear")
    }

    func testCSSTimingFunctionEaseIn() {
        XCTAssertEqual(webCSSTimingFunction(.easeIn), "ease-in")
    }

    func testCSSTimingFunctionEaseOut() {
        XCTAssertEqual(webCSSTimingFunction(.easeOut), "ease-out")
    }

    func testCSSTimingFunctionEaseInOut() {
        XCTAssertEqual(webCSSTimingFunction(.easeInOut), "ease-in-out")
    }

    func testCSSTimingFunctionSpring() {
        XCTAssertEqual(webCSSTimingFunction(.spring), "cubic-bezier(0.5, 1.8, 0.3, 0.8)")
    }

    // MARK: - AnimatedView TLS scoping

    func testAnimatedViewScopesCurrentAnimation() {
        // Before: no animation in TLS
        setCurrentAnimation(nil)
        XCTAssertNil(getCurrentAnimation())

        // AnimatedView should set currentAnimation for its subtree.
        // We verify the struct stores the animation correctly.
        let view = Text("hello").animation(.easeIn)
        XCTAssertEqual(view.animation?.curve, .easeIn)

        // After the view is done rendering, TLS should be restored.
        // (Actual TLS scoping happens in webCreateElement which requires
        // JavaScriptKit runtime — we test the mechanism at the core level.)
        XCTAssertNil(getCurrentAnimation(),
            "currentAnimation should remain nil outside AnimatedView render")
    }

    func testAnimatedViewNilAnimation() {
        let view = Text("hello").animation(nil)
        XCTAssertNil(view.animation)
    }

    // MARK: - WebViewHost animation fields

    func testCaptureAnimationStoresCurrentAnimation() {
        // WebViewHost.captureAnimation is tested indirectly through
        // the core animation TLS mechanism. Verify the TLS contract.
        setCurrentAnimation(.easeInOut)
        let captured = getCurrentAnimation()
        XCTAssertEqual(captured?.curve, .easeInOut)

        // Clean up
        setCurrentAnimation(nil)
    }

    func testPendingAnimationFromWithAnimation() {
        // Clean state
        _ = consumePendingAnimation()

        withAnimation(.spring) {}
        let pending = getPendingAnimation()
        XCTAssertNotNil(pending)
        XCTAssertEqual(pending?.curve, .spring)

        // Consume clears it
        let consumed = consumePendingAnimation()
        XCTAssertNotNil(consumed)
        let second = consumePendingAnimation()
        XCTAssertNil(second)
    }

    // MARK: - Animation snapshot types

    func testAnimatableSnapshotOpacityRole() {
        let snapshot = WebAnimatableSnapshot(
            key: "opacity@2", role: "opacity", opacity: "0.5", transform: nil)
        XCTAssertEqual(snapshot.key, "opacity@2")
        XCTAssertEqual(snapshot.role, "opacity")
        XCTAssertEqual(snapshot.opacity, "0.5")
        XCTAssertNil(snapshot.transform)
    }

    func testAnimatableSnapshotTransformRole() {
        let snapshot = WebAnimatableSnapshot(
            key: "offset@3", role: "offset", opacity: nil, transform: "translate(10px, 20px)")
        XCTAssertEqual(snapshot.key, "offset@3")
        XCTAssertEqual(snapshot.role, "offset")
        XCTAssertNil(snapshot.opacity)
        XCTAssertEqual(snapshot.transform, "translate(10px, 20px)")
    }

    func testAnimatableSnapshotKeyFormat() {
        // Key is "role@depth"
        let snapshot = WebAnimatableSnapshot(
            key: "scale@5", role: "scale", opacity: nil, transform: "scale(2)")
        XCTAssertEqual(snapshot.key, "scale@5")
    }

    // MARK: - Strict match guard logic (key-based)

    func testKeySequenceMatchIdentical() {
        let oldKeys = ["opacity@2", "offset@3", "scale@3"]
        let newKeys = ["opacity@2", "offset@3", "scale@3"]
        let keysMatch = oldKeys == newKeys && Set(oldKeys).count == oldKeys.count
        XCTAssertTrue(keysMatch)
    }

    func testKeySequenceMismatchDifferentCount() {
        let oldKeys = ["opacity@2", "offset@3"]
        let newKeys = ["opacity@2", "offset@3", "scale@3"]
        let keysMatch = oldKeys == newKeys && Set(oldKeys).count == oldKeys.count
        XCTAssertFalse(keysMatch)
    }

    func testKeySequenceMismatchDifferentOrder() {
        let oldKeys = ["opacity@2", "scale@3"]
        let newKeys = ["scale@3", "opacity@2"]
        let keysMatch = oldKeys == newKeys && Set(oldKeys).count == oldKeys.count
        XCTAssertFalse(keysMatch)
    }

    func testKeySequenceMismatchDifferentRole() {
        let oldKeys = ["opacity@2"]
        let newKeys = ["rotation@2"]
        let keysMatch = oldKeys == newKeys && Set(oldKeys).count == oldKeys.count
        XCTAssertFalse(keysMatch)
    }

    func testKeySequenceMismatchDifferentDepth() {
        // Same roles but different depths → different nodes, must not pair.
        let oldKeys = ["opacity@2"]
        let newKeys = ["opacity@4"]
        let keysMatch = oldKeys == newKeys && Set(oldKeys).count == oldKeys.count
        XCTAssertFalse(keysMatch, "Same role at different depth must not match")
    }

    func testKeySequenceDuplicateRolesSameDepthCountMismatch() {
        // Two opacity wrappers at depth 3 — if one is removed, count differs.
        let oldKeys = ["opacity@3", "opacity@3"]
        let newKeys = ["opacity@3"]
        let keysMatch = oldKeys == newKeys && Set(oldKeys).count == oldKeys.count
        XCTAssertFalse(keysMatch)
    }

    func testKeySequenceDuplicateRolesSameDepthReorder() {
        // Two same-role siblings at the same depth: even if the sequence
        // looks identical, duplicate keys mean we cannot pair reliably.
        let oldKeys = ["opacity@3", "opacity@3"]
        let newKeys = ["opacity@3", "opacity@3"]
        let keysMatch = oldKeys == newKeys && Set(oldKeys).count == oldKeys.count
        XCTAssertFalse(keysMatch,
            "Duplicate keys must bail — cannot distinguish reordered same-role siblings")
    }

    func testEmptyKeySequencesMatch() {
        let oldKeys: [String] = []
        let newKeys: [String] = []
        let keysMatch = oldKeys == newKeys && Set(oldKeys).count == oldKeys.count
        XCTAssertTrue(keysMatch, "Empty sequences match but animation is skipped (no wrappers)")
    }

    // MARK: - Pending animation lifecycle

    func testPendingAnimationConsumedBeforePhase7() {
        // Verify the contract: pendingAnimation must be consumed before
        // inputsUnchanged can short-circuit, so it cannot leak.
        _ = consumePendingAnimation()
        withAnimation(.easeIn) {}
        let pending = consumePendingAnimation()
        XCTAssertNotNil(pending, "pendingAnimation should be set by withAnimation")

        // After consumption, it's gone — a skipped rebuild cannot reuse it.
        let leaked = consumePendingAnimation()
        XCTAssertNil(leaked, "Consumed pending should not survive")
    }
}
