import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge
import Foundation

/// Regression: the generic MultiChildView box (Group, TupleView4-12) must be
/// transparent to layout — if its content asks to fill, the box must itself
/// report `hexpand`/`vexpand`, so an enclosing `.frame(maxWidth:.infinity)`
/// (default `.center` alignment) fills instead of centering the whole block
/// at natural size (the centered issue-list bug: rows fixed, but the list sat
/// in a narrow centered column because `Group` swallowed the expand flags).
final class GTK4GroupFillTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 { _ = gtk_init_check() }
    }

    func testGroupPropagatesExpandingChild() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let widget = widgetFromOpaque(
            gtkRenderView(
                Group {
                    Text("content").frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            )
        )
        XCTAssertNotEqual(
            gtk_widget_get_hexpand(widget), 0,
            "Group box must propagate its expanding child's hexpand"
        )
        XCTAssertNotEqual(
            gtk_widget_get_vexpand(widget), 0,
            "Group box must propagate its expanding child's vexpand"
        )
    }

    func testGroupDoesNotForceExpandForPlainChildren() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let widget = widgetFromOpaque(
            gtkRenderView(Group { Text("plain") })
        )
        XCTAssertEqual(
            gtk_widget_get_hexpand(widget), 0,
            "Group of non-expanding content should not report hexpand"
        )
    }
}
