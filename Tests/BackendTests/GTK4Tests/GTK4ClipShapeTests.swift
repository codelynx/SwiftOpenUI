import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge

final class GTK4ClipShapeTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 {
            _ = gtk_init_check()
        }
    }

    // MARK: - ClippedView

    func testClippedWrapsInOverflowHidden() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Hello").clipped()
        ))
        XCTAssertEqual(gtk_widget_get_overflow(widget), GTK_OVERFLOW_HIDDEN)
    }

    func testClippedContentIsAccessible() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Hello").clipped()
        ))
        let label = findFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertNotNil(label, "Clipped content should still be in the tree")
    }

    // MARK: - ClipShapeView with Circle

    func testClipShapeCircleAppliesBorderRadius50() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Hello").clipShape(Circle())
        ))
        XCTAssertEqual(gtk_widget_get_overflow(widget), GTK_OVERFLOW_HIDDEN)
        // The wrapper should have border-radius: 50% via CSS.
        // We can't directly query CSS from GTK in tests, but verify the
        // widget is a wrapper box (not the raw label).
        let typeName = String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
        XCTAssertEqual(typeName, "GtkBox", "ClipShape should wrap in a GtkBox")
    }

    // MARK: - ClipShapeView with RoundedRectangle

    func testClipShapeRoundedRectangleRendersWrapper() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Hello").clipShape(RoundedRectangle(cornerRadius: 12))
        ))
        XCTAssertEqual(gtk_widget_get_overflow(widget), GTK_OVERFLOW_HIDDEN)
    }

    // MARK: - ClipShapeView with Capsule

    func testClipShapeCapsuleRendersWrapper() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Hello").clipShape(Capsule())
        ))
        XCTAssertEqual(gtk_widget_get_overflow(widget), GTK_OVERFLOW_HIDDEN)
    }

    // MARK: - ClipShapeView with Ellipse

    func testClipShapeEllipseRendersWrapper() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Hello").clipShape(Ellipse())
        ))
        XCTAssertEqual(gtk_widget_get_overflow(widget), GTK_OVERFLOW_HIDDEN)
    }

    // MARK: - ClipShapeView with Rectangle

    func testClipShapeRectangleRendersWrapper() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Hello").clipShape(Rectangle())
        ))
        XCTAssertEqual(gtk_widget_get_overflow(widget), GTK_OVERFLOW_HIDDEN)
    }

    // MARK: - Expand flag propagation

    func testClippedPreservesChildExpandFlags() throws {
        try requireGTK()

        // Circle expands by default (hexpand + vexpand)
        let widget = widgetFromOpaque(gtkRenderView(
            Circle().clipped()
        ))
        XCTAssertNotEqual(gtk_widget_get_hexpand(widget), 0,
                          "Clipped wrapper should inherit child hexpand")
        XCTAssertNotEqual(gtk_widget_get_vexpand(widget), 0,
                          "Clipped wrapper should inherit child vexpand")
    }

    func testClipShapePreservesChildExpandFlags() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Circle().clipShape(RoundedRectangle(cornerRadius: 8))
        ))
        XCTAssertNotEqual(gtk_widget_get_hexpand(widget), 0,
                          "ClipShape wrapper should inherit child hexpand")
        XCTAssertNotEqual(gtk_widget_get_vexpand(widget), 0,
                          "ClipShape wrapper should inherit child vexpand")
    }

    func testClippedNonExpandingChildDoesNotExpand() throws {
        try requireGTK()

        // Text does not expand
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Hello").clipped()
        ))
        XCTAssertEqual(gtk_widget_get_hexpand(widget), 0,
                       "Clipped non-expanding child should not expand")
    }

    // MARK: - Chaining

    func testClipShapeWithFrame() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Hello").frame(width: 80, height: 80).clipShape(Circle())
        ))
        XCTAssertEqual(gtk_widget_get_overflow(widget), GTK_OVERFLOW_HIDDEN)
        // Content should still be accessible inside the clip wrapper
        let label = findFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertNotNil(label)
    }

    func testClipShapeWithBackground() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Hello").background(.blue).clipShape(RoundedRectangle(cornerRadius: 8))
        ))
        XCTAssertEqual(gtk_widget_get_overflow(widget), GTK_OVERFLOW_HIDDEN)
    }

    func testClippedWithPadding() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Hello").padding().clipped()
        ))
        XCTAssertEqual(gtk_widget_get_overflow(widget), GTK_OVERFLOW_HIDDEN)
    }
}

// MARK: - Helpers

private func requireGTK(
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    guard gtk_is_initialized() != 0 else {
        throw XCTSkip("GTK could not initialize in this environment.", file: file, line: line)
    }
}

private func findFirstDescendant(ofType typeName: String, in widget: UnsafeMutablePointer<GtkWidget>) -> UnsafeMutablePointer<GtkWidget>? {
    guard gtk_swift_is_widget(widget) != 0 else { return nil }
    let name = String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
    if name == typeName { return widget }
    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        if let found = findFirstDescendant(ofType: typeName, in: c) { return found }
        child = gtk_widget_get_next_sibling(c)
    }
    return nil
}
