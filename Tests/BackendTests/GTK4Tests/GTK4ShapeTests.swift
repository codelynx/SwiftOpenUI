import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge

final class GTK4ShapeTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 {
            _ = gtk_init_check()
        }
    }

    // MARK: - Bare shapes render

    func testCircleRendersWidget() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(Circle()))
        XCTAssertNotNil(widget)
        XCTAssertEqual(widgetTypeName(widget), "GtkDrawingArea")
    }

    func testRectangleRendersWidget() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(Rectangle()))
        XCTAssertNotNil(widget)
        XCTAssertEqual(widgetTypeName(widget), "GtkDrawingArea")
    }

    func testRoundedRectangleRendersWidget() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(RoundedRectangle(cornerRadius: 8)))
        XCTAssertNotNil(widget)
        XCTAssertEqual(widgetTypeName(widget), "GtkDrawingArea")
    }

    func testCapsuleRendersWidget() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(Capsule()))
        XCTAssertNotNil(widget)
        XCTAssertEqual(widgetTypeName(widget), "GtkDrawingArea")
    }

    func testEllipseRendersWidget() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(Ellipse()))
        XCTAssertNotNil(widget)
        XCTAssertEqual(widgetTypeName(widget), "GtkDrawingArea")
    }

    // MARK: - FilledShape / StrokedShape

    func testFilledCircleRendersWidget() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(Circle().fill(.red)))
        XCTAssertNotNil(widget)
        XCTAssertEqual(widgetTypeName(widget), "GtkDrawingArea")
    }

    func testStrokedRectangleRendersWidget() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(Rectangle().stroke(.blue, lineWidth: 2)))
        XCTAssertNotNil(widget)
        // Stroke: the drawing area sits in an outset wrapper (issue #45).
        XCTAssertEqual(widgetTypeName(widget), "GtkBox")
        let area = try XCTUnwrap(gtk_widget_get_first_child(widget))
        XCTAssertEqual(widgetTypeName(area), "GtkDrawingArea")
    }

    func testStrokedCircleWithStyleRendersWidget() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(
            Circle().stroke(.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        ))
        XCTAssertNotNil(widget)
        XCTAssertEqual(widgetTypeName(widget), "GtkBox")
        let area = try XCTUnwrap(gtk_widget_get_first_child(widget))
        XCTAssertEqual(widgetTypeName(area), "GtkDrawingArea")
    }

    func testStrokeBorderRendersBareDrawingArea() throws {
        try requireGTK()
        // strokeBorder keeps the line inside the frame, so no outset wrapper.
        let widget = widgetFromOpaque(gtkRenderView(Circle().strokeBorder(.green, lineWidth: 3)))
        XCTAssertEqual(widgetTypeName(widget), "GtkDrawingArea")
    }

    // MARK: - Drawing past the frame (issue #45)

    /// `.stroke()` centers the line on the outline, so half of it is drawn
    /// outside the frame, as in SwiftUI. The drawing area is allocated past
    /// the frame on every side, while layout still sees the frame's size.
    func testStrokeDrawingAreaExtendsPastFrame() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(
            Circle().stroke(.black, lineWidth: 4).frame(width: 40, height: 40)
        ))
        let size = measuredSize(of: widget)
        XCTAssertEqual(size.width, 40, accuracy: 0.01)
        XCTAssertEqual(size.height, 40, accuracy: 0.01)
        gtk_widget_allocate(widget, 40, 40, -1, nil)

        let area = try XCTUnwrap(findWidget(named: "GtkDrawingArea", in: widget))
        let outsetWrapper = try XCTUnwrap(gtk_widget_get_parent(area))
        XCTAssertEqual(gtk_widget_get_width(outsetWrapper), 40)
        // lineWidth 4: half is 2pt, ×√2 for corners, +1px antialiasing → 4.
        XCTAssertEqual(gtk_widget_get_width(area), 48)
        XCTAssertEqual(gtk_widget_get_height(area), 48)
        let origin = try XCTUnwrap(origin(of: area, in: outsetWrapper))
        XCTAssertEqual(origin.x, -4, accuracy: 0.01)
        XCTAssertEqual(origin.y, -4, accuracy: 0.01)

        // Nothing between the frame and the area clips the overhang.
        var current: UnsafeMutablePointer<GtkWidget>? = area
        while let w = current {
            XCTAssertEqual(gtk_widget_get_overflow(w), GTK_OVERFLOW_VISIBLE,
                           "\(widgetTypeName(w)) clips the stroke")
            if w == widget { break }
            current = gtk_widget_get_parent(w)
        }
    }

    func testStrokeIsNotAPointerTarget() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(Circle().stroke(.black, lineWidth: 2)))
        XCTAssertEqual(gtk_widget_get_can_target(widget), gboolean(0))
    }

    func testFixedLayoutContainersDoNotClip() throws {
        try requireGTK()
        // GtkFixed clips by default; SwiftUI containers don't, so an
        // .offset() label must not be cut at its original bounds.
        let widget = widgetFromOpaque(gtkRenderView(
            HStack(spacing: 16) {
                Text("Normal")
                Text("Offset(10,5)").offset(x: 10, y: 5)
            }
            .frame(height: 24)
        ))
        var hidden: [String] = []
        walk(widget) { w in
            if gtk_widget_get_overflow(w) == GTK_OVERFLOW_HIDDEN { hidden.append(widgetTypeName(w)) }
        }
        XCTAssertEqual(hidden, [], "widgets clipping the offset label")
    }

    // MARK: - Shapes expand to fill

    func testBareShapeExpandsHorizontally() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(Circle()))
        XCTAssertNotEqual(gtk_widget_get_hexpand(widget), 0,
                          "Shape should expand horizontally")
    }

    func testBareShapeExpandsVertically() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(Circle()))
        XCTAssertNotEqual(gtk_widget_get_vexpand(widget), 0,
                          "Shape should expand vertically")
    }

    // MARK: - Foreground color propagation

    func testBareShapeWithForegroundColorRendersWidget() throws {
        try requireGTK()
        // Verify that foregroundColor + bare shape doesn't crash.
        // The actual color is applied in the Cairo callback at draw time,
        // which we can't easily inspect without a display, but we verify
        // the render-time propagation doesn't error.
        let widget = widgetFromOpaque(gtkRenderView(
            Circle().foregroundColor(.red)
        ))
        XCTAssertNotNil(widget)
        XCTAssertEqual(widgetTypeName(widget), "GtkDrawingArea")
    }

    // MARK: - Shape with .frame()

    func testShapeWithFrameProducesCorrectSize() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(
            Circle().frame(width: 100, height: 100)
        ))
        let size = measuredSize(of: widget)
        XCTAssertEqual(size.width, 100, accuracy: 1)
        XCTAssertEqual(size.height, 100, accuracy: 1)
    }

    func testFilledShapeWithFrameProducesCorrectSize() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(
            Rectangle().fill(.blue).frame(width: 50, height: 30)
        ))
        let size = measuredSize(of: widget)
        XCTAssertEqual(size.width, 50, accuracy: 1)
        XCTAssertEqual(size.height, 30, accuracy: 1)
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

private func widgetTypeName(_ widget: UnsafeMutablePointer<GtkWidget>) -> String {
    String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
}

private func measuredSize(of widget: UnsafeMutablePointer<GtkWidget>) -> (width: Double, height: Double) {
    var minW: gint = 0, natW: gint = 0
    var minH: gint = 0, natH: gint = 0
    gtk_widget_measure(widget, GTK_ORIENTATION_HORIZONTAL, -1, &minW, &natW, nil, nil)
    gtk_widget_measure(widget, GTK_ORIENTATION_VERTICAL, -1, &minH, &natH, nil, nil)
    return (Double(natW), Double(natH))
}

private func walk(_ widget: UnsafeMutablePointer<GtkWidget>, _ visit: (UnsafeMutablePointer<GtkWidget>) -> Void) {
    visit(widget)
    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        walk(c, visit)
        child = gtk_widget_get_next_sibling(c)
    }
}

private func findWidget(named name: String, in widget: UnsafeMutablePointer<GtkWidget>) -> UnsafeMutablePointer<GtkWidget>? {
    var found: UnsafeMutablePointer<GtkWidget>?
    walk(widget) { w in
        if found == nil, widgetTypeName(w) == name { found = w }
    }
    return found
}

private func origin(
    of widget: UnsafeMutablePointer<GtkWidget>,
    in ancestor: UnsafeMutablePointer<GtkWidget>
) -> (x: Double, y: Double)? {
    var source = graphene_point_t()
    var result = graphene_point_t()
    guard gtk_widget_compute_point(widget, ancestor, &source, &result) != 0 else { return nil }
    return (Double(result.x), Double(result.y))
}
