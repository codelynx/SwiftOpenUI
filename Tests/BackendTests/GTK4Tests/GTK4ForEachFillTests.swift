import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge
import Foundation

/// Regression: a `ForEach` must be transparent to layout — if its rows ask to
/// fill width, the box it produces must itself report `hexpand`, so a
/// surrounding `.center` stack lets the rows span the width rather than
/// centering the whole narrow block (the centered issue-list-rows bug).
final class GTK4ForEachFillTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 { _ = gtk_init_check() }
    }

    func testForEachPropagatesExpandingChildren() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let widget = widgetFromOpaque(
            ForEach(Array(0..<3), id: \.self) { _ in
                Text("row").frame(maxWidth: .infinity, alignment: .leading)
            }.gtkCreateWidget()
        )
        XCTAssertNotEqual(
            gtk_widget_get_hexpand(widget), 0,
            "ForEach box must propagate its expanding children's hexpand"
        )
    }

    func testForEachDoesNotForceExpandForPlainRows() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let widget = widgetFromOpaque(
            ForEach(Array(0..<3), id: \.self) { _ in Text("row") }.gtkCreateWidget()
        )
        XCTAssertEqual(
            gtk_widget_get_hexpand(widget), 0,
            "ForEach of non-expanding rows should not report hexpand"
        )
    }
}
