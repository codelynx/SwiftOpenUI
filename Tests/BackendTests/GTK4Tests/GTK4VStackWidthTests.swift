import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge
import Foundation

/// Bug 2 regression: a VStack must not pin the widest child's *natural* width as
/// a non-negotiable *minimum*. The GtkFixed-based shared path did (GtkFixed
/// measures to contain children), which forced the window open when a child was
/// wide (a long wrapped label). A GtkBox reports the child's negotiable minimum,
/// matching SwiftLinuxUI and SwiftUI proposal semantics.
final class GTK4VStackWidthTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 { _ = gtk_init_check() }
    }

    private func minWidth(_ w: UnsafeMutablePointer<GtkWidget>) -> Int32 {
        var mn: Int32 = 0
        var nt: Int32 = 0
        gtk_swift_widget_measure(w, GTK_ORIENTATION_HORIZONTAL, -1, &mn, &nt)
        return mn
    }

    /// `VStack { Text(long).lineLimit(2) }.frame(maxWidth: .infinity)` — the exact
    /// shape of the issue-list row. Its minimum width must stay small (the label
    /// wraps), not balloon to the label's full natural width.
    func testWideWrappedLabelDoesNotPinHugeMinimumWidth() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let long = String(repeating: "very long headline segment ", count: 40) // ~1080 chars
        let widget = widgetFromOpaque(
            VStack(alignment: .leading) {
                Text(long).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .gtkCreateWidget()
        )
        let mw = minWidth(widget)
        XCTAssertLessThan(
            mw, 600,
            "VStack row pinned a \(mw)px minimum width; a wrappable label should stay negotiable"
        )
    }

    /// Moving to the GtkBox path must preserve horizontal alignment: the VStack's
    /// alignment maps onto each child's halign.
    func testVStackAlignmentMapsToChildHalign() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        func firstChildHalign(_ alignment: HorizontalAlignment) -> GtkAlign {
            let box = widgetFromOpaque(
                VStack(alignment: alignment) { Text("hi") }.gtkCreateWidget()
            )
            guard let child = gtk_widget_get_first_child(box) else { return GTK_ALIGN_FILL }
            return gtk_widget_get_halign(child)
        }
        XCTAssertEqual(firstChildHalign(.leading), GTK_ALIGN_START)
        XCTAssertEqual(firstChildHalign(.center), GTK_ALIGN_CENTER)
        XCTAssertEqual(firstChildHalign(.trailing), GTK_ALIGN_END)
    }
}
