/// Unit tests for compareLeaves() — validates gap checks, alignment checks,
/// and tolerance classification using synthetic snapshots.
///
/// These run on any platform (no backend required).

import XCTest
import LayoutParityShared

final class CompareLeafTests: XCTestCase {

    // MARK: - Helpers

    private func makeSnapshot(
        scenario: String = "test",
        rootWidth: Double = 400,
        rootHeight: Double = 600,
        root: LayoutNode
    ) -> LayoutSnapshot {
        LayoutSnapshot(
            scenario: scenario,
            rootWidth: rootWidth,
            rootHeight: rootHeight,
            root: root,
            platform: "test",
            capturedAt: "2026-01-01T00:00:00Z"
        )
    }

    private func textLeaf(_ tag: String, x: Double, y: Double, w: Double, h: Double) -> LayoutNode {
        LayoutNode(tag: "text:\(tag)", viewType: "CGDrawingLayer", x: x, y: y, width: w, height: h)
    }

    private func colorLeaf(x: Double, y: Double, w: Double, h: Double) -> LayoutNode {
        LayoutNode(tag: "color", viewType: "Color", x: x, y: y, width: w, height: h)
    }

    // MARK: - Zero Spacing Gap Check

    func testZeroSpacingGapDetectsInsertedSpacing() {
        // Reference: three texts stacked with zero spacing
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 10, height: 48,
            children: [
                textLeaf("A", x: 0, y: 0, w: 10, h: 16),
                textLeaf("B", x: 0, y: 16, w: 10, h: 16),
                textLeaf("C", x: 0, y: 32, w: 10, h: 16),
            ]
        ))

        // Actual: backend accidentally inserts 8pt default spacing
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 10, height: 64,
            children: [
                textLeaf("A", x: 0, y: 0, w: 10, h: 16),
                textLeaf("B", x: 0, y: 24, w: 10, h: 16),  // 8pt gap instead of 0
                textLeaf("C", x: 0, y: 48, w: 10, h: 16),  // 8pt gap instead of 0
            ]
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        XCTAssertFalse(result.passed, "Should fail: 8pt spacing injected where 0pt expected")

        let gapDiffs = result.structuralDiffs.filter { $0.path.hasPrefix("gap[") }
        XCTAssertGreaterThanOrEqual(gapDiffs.count, 1, "Should detect gap difference")
    }

    // MARK: - Overlap Detection

    func testOverlapDetectedAsStructuralFailure() {
        // Reference: two texts with 8pt gap (no overlap)
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 10, height: 40,
            children: [
                textLeaf("A", x: 0, y: 0, w: 10, h: 16),
                textLeaf("B", x: 0, y: 24, w: 10, h: 16),  // 8pt gap
            ]
        ))

        // Actual: backend overlaps B into A by 4pt
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 10, height: 28,
            children: [
                textLeaf("A", x: 0, y: 0, w: 10, h: 16),
                textLeaf("B", x: 0, y: 12, w: 10, h: 16),  // -4pt gap (overlap)
            ]
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        XCTAssertFalse(result.passed, "Should fail: overlap where gap expected")

        let gapDiffs = result.structuralDiffs.filter { $0.path.hasPrefix("gap[") }
        XCTAssertGreaterThanOrEqual(gapDiffs.count, 1, "Should detect gap→overlap regression")
    }

    // MARK: - Single-Leaf Alignment

    func testSingleLeafAlignmentTopLeading() {
        // Reference: leaf at top-leading of a 200x200 container
        let ref = makeSnapshot(
            rootWidth: 400, rootHeight: 600,
            root: LayoutNode(
                tag: "root", viewType: "root", x: 0, y: 0, width: 200, height: 200,
                children: [textLeaf("TL", x: 0, y: 0, w: 15, h: 16)]
            )
        )

        // Actual: backend centers the leaf instead (alignment bug)
        let act = makeSnapshot(
            rootWidth: 400, rootHeight: 600,
            root: LayoutNode(
                tag: "root", viewType: "root", x: 0, y: 0, width: 200, height: 200,
                children: [textLeaf("TL", x: 92, y: 92, w: 16, h: 16)]
            )
        )

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        XCTAssertFalse(result.passed, "Should fail: centered instead of top-leading")

        let alignDiffs = result.structuralDiffs.filter { $0.path == "alignment" }
        XCTAssertGreaterThanOrEqual(alignDiffs.count, 1, "Should detect alignment drift")
    }

    func testSingleLeafAlignmentCorrectPasses() {
        // Both sides: leaf at top-leading
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 200, height: 200,
            children: [textLeaf("TL", x: 0, y: 0, w: 15, h: 16)]
        ))
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 200, height: 200,
            children: [textLeaf("TL", x: 1, y: 0, w: 16, h: 16)]
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        XCTAssertTrue(result.passed, "Should pass: alignment matches within tolerance")
    }

    func testSingleLeafDifferentRootSizesCenteredPasses() {
        // When root sizes differ, center-point fraction must match.
        // ref: center = (92+8)/200 = 0.50, act: center = (192+8)/400 = 0.50
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 200, height: 200,
            children: [textLeaf("C", x: 92, y: 92, w: 16, h: 16)]
        ))
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 400, height: 400,
            children: [textLeaf("C", x: 192, y: 192, w: 16, h: 16)]
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        XCTAssertTrue(result.passed,
            "Should pass: both centered at same fraction. Diffs: \(result.structuralDiffs)")
    }

    func testSingleLeafDifferentRootSizesMisalignedFails() {
        // ref: top-leading (frac 0.0), act: centered (frac ~0.46) — should fail
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 200, height: 200,
            children: [textLeaf("TL", x: 0, y: 0, w: 16, h: 16)]
        ))
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 400, height: 400,
            children: [textLeaf("TL", x: 192, y: 192, w: 16, h: 16)]
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        XCTAssertFalse(result.passed,
            "Should fail: top-leading vs centered alignment")
    }

    // MARK: - Text Size vs Position Classification

    func testTextSizeDiffIsTextMetric() {
        // Same position, different text width (font metrics)
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 50, height: 16,
            children: [textLeaf("Hello", x: 0, y: 0, w: 35, h: 16)]
        ))
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 50, height: 16,
            children: [textLeaf("Hello", x: 0, y: 0, w: 50, h: 16)]
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        // Width diff of 15pt > 10pt textSize tolerance → textMetric diff
        let textDiffs = result.textMetricDiffs
        XCTAssertGreaterThanOrEqual(textDiffs.count, 1, "Text width diff should be textMetric")
        // But no structural failures
        XCTAssertTrue(result.passed, "Text size diff should not cause structural failure")
    }

    func testStructuralColorPositionDiffFails() {
        // Color leaf at wrong position — structural
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 200, height: 200,
            children: [colorLeaf(x: 0, y: 0, w: 200, h: 200)]
        ))
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 200, height: 200,
            children: [colorLeaf(x: 10, y: 10, w: 200, h: 200)]
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        XCTAssertFalse(result.passed, "Color position diff should be structural failure")
        XCTAssertTrue(result.structuralDiffs.allSatisfy { $0.category == .structural })
    }

    // MARK: - Horizontal Gap Check

    // MARK: - Same-Row Vertical Gap False Positive

    func testSameRowTextHeightVarianceNoFalseVerticalGap() {
        // HStack with two texts at same y. Font height differs across platforms.
        // Should NOT produce a vertical gap failure — they're on the same row.
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 100, height: 16,
            children: [
                textLeaf("Left", x: 0, y: 0, w: 30, h: 16),
                textLeaf("Right", x: 38, y: 0, w: 30, h: 16),
            ]
        ))
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 100, height: 20,
            children: [
                textLeaf("Left", x: 0, y: 0, w: 32, h: 20),   // taller font
                textLeaf("Right", x: 40, y: 0, w: 32, h: 20),  // taller font
            ]
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        let verticalGapDiffs = result.structuralDiffs.filter {
            $0.path.hasPrefix("gap[") && $0.message.contains("vertical")
        }
        XCTAssertEqual(verticalGapDiffs.count, 0,
            "Same-row texts with different font height should not produce vertical gap failure")
    }

    // MARK: - Centered Single-Leaf Width Variance

    func testCenteredSingleLeafTextWidthDiffPasses() {
        // Centered text in a 200x200 frame. Text width differs (font metrics)
        // but the text remains correctly centered. Center fraction should match.
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 200, height: 200,
            children: [textLeaf("C", x: 92, y: 92, w: 16, h: 16)]
            // center = (92+8)/200 = 0.50
        ))
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 200, height: 200,
            children: [textLeaf("C", x: 84.5, y: 92, w: 31, h: 16)]
            // center = (84.5+15.5)/200 = 0.50  (wider text, still centered)
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        let alignDiffs = result.structuralDiffs.filter { $0.path == "alignment" }
        XCTAssertEqual(alignDiffs.count, 0,
            "Centered text with different width should not produce alignment failure. Got: \(alignDiffs)")
    }

    // MARK: - Horizontal Gap Check

    func testHorizontalGapDetected() {
        // Reference: two texts side by side with 8pt gap
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 100, height: 16,
            children: [
                textLeaf("Left", x: 0, y: 0, w: 30, h: 16),
                textLeaf("Right", x: 38, y: 0, w: 30, h: 16),  // 8pt gap
            ]
        ))

        // Actual: 20pt gap instead of 8pt
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 100, height: 16,
            children: [
                textLeaf("Left", x: 0, y: 0, w: 30, h: 16),
                textLeaf("Right", x: 50, y: 0, w: 30, h: 16),  // 20pt gap
            ]
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        let gapDiffs = result.structuralDiffs.filter { $0.path.hasPrefix("gap[") }
        XCTAssertGreaterThanOrEqual(gapDiffs.count, 1, "Should detect horizontal gap difference")
    }

    // MARK: - Tight text-position reclassification

    /// A trailing-aligned text that grows in width may legitimately shift its
    /// leading x by the width delta while keeping the trailing edge fixed.
    /// That must be reported as a non-structural text-metric diff.
    /// Two leaves are used so content-bbox normalization preserves the
    /// x offset of the trailing leaf (a single-leaf case is collapsed to 0).
    func testTrailingAnchoredTextGrowingReclassifiesAsTextMetric() {
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 200, height: 40,
            children: [
                textLeaf("Anchor", x: 0, y: 0, w: 20, h: 16),
                textLeaf("End", x: 112.5, y: 24, w: 87.5, h: 16),
            ]
        ))
        // Trailing edge of "End" stays anchored at 200 (112.5+87.5 == 98+102).
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 200, height: 40,
            children: [
                textLeaf("Anchor", x: 0, y: 0, w: 20, h: 16),
                textLeaf("End", x: 98, y: 24, w: 102, h: 16),
            ]
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        let xStructural = result.structuralDiffs.contains {
            $0.message.contains("x:") && $0.path.contains("End")
        }
        XCTAssertFalse(xStructural,
                       "Anchored-edge text x drift must be text-metric, not structural.")
    }

    /// A text leaf whose magnitude of x-drift equals its width-drift but in
    /// a direction that moves the trailing edge must remain structural —
    /// the old |dx - dw| heuristic wrongly reclassified these as text-metric.
    func testSameWidthDeltaWrongDirectionStaysStructural() {
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 250, height: 40,
            children: [
                textLeaf("Anchor", x: 0, y: 0, w: 20, h: 16),
                textLeaf("End", x: 112.5, y: 24, w: 87.5, h: 16),  // trailing=200
            ]
        ))
        // Trailing edge drifted from 200 to 229 — a real 29pt placement bug.
        // |dx|=14.5 matches |dw|=14.5, but they move in the SAME direction,
        // so the trailing edge is not anchored.
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 250, height: 40,
            children: [
                textLeaf("Anchor", x: 0, y: 0, w: 20, h: 16),
                textLeaf("End", x: 127, y: 24, w: 102, h: 16),  // trailing=229
            ]
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        let xStructural = result.structuralDiffs.contains {
            $0.message.contains("x:") && $0.path.contains("End")
        }
        XCTAssertTrue(xStructural,
                      "Same |dx|==|dw| magnitudes in the wrong direction must stay structural.")
    }

    // MARK: - Tight gap reclassification

    /// A tiny 1pt font delta cannot explain an 8pt gap insertion. The old
    /// absolute textSize threshold masked this — the proportional rule must
    /// keep it structural.
    func testSmallFontDeltaWithLargeGapStaysStructural() {
        // Ref: two texts stacked tightly with no gap, 16pt tall.
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 30, height: 34,
            children: [
                textLeaf("A", x: 0, y: 0, w: 30, h: 16),
                textLeaf("B", x: 0, y: 16, w: 30, h: 16),
            ]
        ))
        // Act: labels are 17pt (1pt font diff) AND an 8pt gap sneaks in.
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 30, height: 42,
            children: [
                textLeaf("A", x: 0, y: 0, w: 30, h: 17),
                textLeaf("B", x: 0, y: 25, w: 30, h: 17),  // gap=8
            ]
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        let gapStructural = result.structuralDiffs.contains { $0.path.hasPrefix("gap[") }
        XCTAssertTrue(gapStructural,
                      "A font delta cannot justify a gap drift that exceeds it.")
    }

    /// Gap drift that's covered by the accumulated text-height delta is a
    /// legitimate text-metric effect (macOS 16pt labels vs Linux 18pt labels:
    /// each taller label pushes subsequent siblings down, which shows up as
    /// gap shrinkage in flex-packed columns).
    func testGapDriftWithinFontDeltaReclassifiesAsTextMetric() {
        // Ref: 16pt labels, 24pt gap.
        let ref = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 30, height: 56,
            children: [
                textLeaf("A", x: 0, y: 0, w: 30, h: 16),
                textLeaf("B", x: 0, y: 40, w: 30, h: 16),
            ]
        ))
        // Act: 18pt labels (2pt taller each = 4pt combined); gap drops to 22pt
        // (2pt drift is within the 4pt cumulative text-height delta).
        let act = makeSnapshot(root: LayoutNode(
            tag: "root", viewType: "root", x: 0, y: 0, width: 30, height: 58,
            children: [
                textLeaf("A", x: 0, y: 0, w: 30, h: 18),
                textLeaf("B", x: 0, y: 40, w: 30, h: 18),
            ]
        ))

        let result = compareLeaves(reference: ref, actual: act, tolerances: ParityTolerances())
        let gapStructural = result.structuralDiffs.contains { $0.path.hasPrefix("gap[") }
        XCTAssertFalse(gapStructural,
                       "Gap drift within cumulative text-height delta must be text-metric.")
    }
}
