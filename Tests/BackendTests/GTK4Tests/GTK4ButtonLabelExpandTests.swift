import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge
import Foundation

/// Regression guard for the scattered-list bug: a `Button` wrapping a
/// `maxWidth:.infinity` label must propagate horizontal expansion so a parent
/// VStack routes it through the fill layout instead of the fixed/centered path.
final class GTK4ButtonLabelExpandTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 { _ = gtk_init_check() }
    }

    /// `Button { Text(...).frame(maxWidth: .infinity) }` — the custom-label
    /// child asks to expand, so the button must report hexpand != 0.
    func testCustomLabelButtonWithMaxWidthInfinityExpands() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let widget = widgetFromOpaque(
            Button(action: {}) {
                Text("row").frame(maxWidth: .infinity, alignment: .leading)
            }.gtkCreateWidget()
        )
        XCTAssertNotEqual(
            gtk_widget_get_hexpand(widget), 0,
            "Button wrapping a maxWidth:.infinity label must propagate hexpand"
        )
    }

    /// `Button("Retry")` — a plain text label never asks to expand, so the
    /// button stays shrink-to-fit. This is the no-regression side: the fix
    /// only touches the custom-label branch.
    func testTextLabelButtonDoesNotExpand() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let widget = widgetFromOpaque(Button("Retry", action: {}).gtkCreateWidget())
        XCTAssertEqual(
            gtk_widget_get_hexpand(widget), 0,
            "plain text-label Button must remain shrink-to-fit (no regression)"
        )
    }
}
