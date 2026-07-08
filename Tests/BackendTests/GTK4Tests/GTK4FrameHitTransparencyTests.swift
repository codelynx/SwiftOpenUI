import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge
import Foundation

/// Regression: pure-layout frame wrappers must NOT be pointer targets
/// (SwiftUI parity — empty frame regions don't hit-test), otherwise a
/// `.frame(maxWidth:.infinity)` overlay layer swallows clicks/scroll/zoom
/// gestures meant for widgets beneath it (the dead paging-chevron /
/// unreachable scroll-view-controllers bug). Gesture modifiers re-enable
/// targeting on their own widget.
final class GTK4FrameHitTransparencyTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 { _ = gtk_init_check() }
    }

    func testInfinityFrameWrapperIsHitTransparent() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let widget = widgetFromOpaque(gtkRenderView(
            Text("chevron").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        ))
        XCTAssertEqual(gtk_widget_get_can_target(widget), gboolean(0),
                       "infinity-frame layout wrapper must not be a pointer target")
    }

    func testFrameChildRemainsTargetable() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let wrapper = widgetFromOpaque(gtkRenderView(
            Button("go") {}.frame(maxWidth: .infinity, alignment: .trailing)
        ))
        // find the GtkButton descendant — it must still be targetable
        var child = gtk_widget_get_first_child(wrapper)
        var foundTargetableDescendant = false
        while let c = child {
            if gtk_widget_get_can_target(c) != 0 { foundTargetableDescendant = true; break }
            child = gtk_widget_get_first_child(c) ?? gtk_widget_get_next_sibling(c)
        }
        XCTAssertTrue(foundTargetableDescendant,
                      "the frame's interactive child must remain a pointer target")
    }

    func testTapGestureReenablesTargeting() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let widget = widgetFromOpaque(gtkRenderView(
            Text("row").frame(maxWidth: .infinity).onTapGesture {}
        ))
        XCTAssertNotEqual(gtk_widget_get_can_target(widget), gboolean(0),
                          "a gesture-bearing widget must be a pointer target")
    }
}
