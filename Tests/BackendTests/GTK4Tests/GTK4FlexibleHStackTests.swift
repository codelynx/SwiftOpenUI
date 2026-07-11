import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge

/// Tests for the GTK4 flexible-HStack equal-division layout
/// (`gtk_custom_layout`-backed). Exercises the pure waterfall and the
/// widget-level width distribution (`gtkHStackAssignWidths`), which is the
/// function shared by the allocate and height-for-width measure callbacks.
///
/// See docs/proposals/gtk4-flexible-hstack-layout.md.
final class GTK4FlexibleHStackTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 {
            _ = gtk_init_check()
        }
    }

    private func requireGTK() throws {
        if gtk_is_initialized() == 0 {
            throw XCTSkip("GTK could not be initialized (no display)")
        }
    }

    private func box(_ view: some View) -> UnsafeMutablePointer<GtkWidget> {
        widgetFromOpaque(gtkRenderView(view))
    }

    // MARK: - Pure waterfall

    func testWaterfallEqualSplit() {
        XCTAssertEqual(gtkHStackWaterfall(remainder: 400, mins: [0, 0]), [200, 200])
        XCTAssertEqual(gtkHStackWaterfall(remainder: 300, mins: [0, 0, 0]), [100, 100, 100])
    }

    func testWaterfallRoundingRemainderToFirst() {
        // 401 / 2 = 200 r1 → first child gets the extra pixel.
        XCTAssertEqual(gtkHStackWaterfall(remainder: 401, mins: [0, 0]), [201, 200])
        // 302 / 3 = 100 r2 → first two get +1.
        XCTAssertEqual(gtkHStackWaterfall(remainder: 302, mins: [0, 0, 0]), [101, 101, 100])
    }

    func testWaterfallClampsChildAboveSliceToMinAndRedivides() {
        // slice would be 200; second child needs 300 → it takes 300, the
        // first re-divides the remaining 100.
        XCTAssertEqual(gtkHStackWaterfall(remainder: 400, mins: [0, 300]), [100, 300])
    }

    func testWaterfallOverConstrainedNeverNegative() {
        // Both minimums exceed any equal slice; each clamps to its min,
        // total overflows (clip) but no width is negative.
        let out = gtkHStackWaterfall(remainder: 100, mins: [200, 200])
        XCTAssertEqual(out, [200, 200])
        XCTAssertFalse(out.contains { $0 < 0 })
    }

    // MARK: - Widget-level distribution

    func testTwoFlexibleGetEqualWidthsDespiteUnequalContent() throws {
        try requireGTK()
        // Two flexible children whose content naturals differ wildly but are
        // shrinkable (ellipsizing, like the drop-zone path). GtkBox would
        // give the long one more; equal-division gives them the same. (Non-
        // shrinkable content correctly keeps its minimum — that's the
        // waterfall's job, covered by the pure tests above.)
        let hstack = HStack(spacing: 0) {
            Text("x").lineLimit(1).frame(maxWidth: .infinity)
            Text("a considerably longer label than the other")
                .lineLimit(1).frame(maxWidth: .infinity)
        }
        let assign = gtkHStackAssignWidths(box: box(hstack), totalWidth: 400, spacing: 0)
        XCTAssertEqual(assign.count, 2)
        XCTAssertLessThanOrEqual(abs(assign[0].width - assign[1].width), 1,
                                 "two flexible children must get equal widths (±1px)")
        XCTAssertEqual(assign[0].width + assign[1].width, 400,
                       "flexible widths must consume the full container")
    }

    func testFixedSiblingTakesNaturalFlexibleSplitRemainder() throws {
        try requireGTK()
        // Fixed label between/around two flexible children: fixed keeps its
        // natural width, the two flexible split the remainder equally.
        let hstack = HStack(spacing: 0) {
            Text("FIXED")
            Text("x").frame(maxWidth: .infinity)
            Text("y").frame(maxWidth: .infinity)
        }
        let assign = gtkHStackAssignWidths(box: box(hstack), totalWidth: 500, spacing: 0)
        XCTAssertEqual(assign.count, 3)
        XCTAssertGreaterThan(assign[0].width, 0, "fixed child keeps a natural width")
        XCTAssertLessThan(assign[0].width, 200, "fixed child is not stretched")
        XCTAssertLessThanOrEqual(abs(assign[1].width - assign[2].width), 1,
                                 "the two flexible children split the remainder equally")
        XCTAssertEqual(assign[0].width + assign[1].width + assign[2].width, 500)
    }

    func testSpacerJoinsTheEqualSplit() throws {
        try requireGTK()
        // A Spacer between two flexible children is maximally flexible in
        // SwiftUI — all three get an equal third (the review's spacer fix).
        let hstack = HStack(spacing: 0) {
            Text("x").frame(maxWidth: .infinity)
            Spacer()
            Text("y").frame(maxWidth: .infinity)
        }
        let assign = gtkHStackAssignWidths(box: box(hstack), totalWidth: 300, spacing: 0)
        XCTAssertEqual(assign.count, 3)
        for a in assign {
            XCTAssertLessThanOrEqual(abs(a.width - 100), 1,
                                     "flexible children incl. Spacer split into equal thirds")
        }
    }
}
