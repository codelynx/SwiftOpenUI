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
        XCTAssertEqual(widgetTypeName(widget), "GtkDrawingArea")
    }

    func testStrokedCircleWithStyleRendersWidget() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(
            Circle().stroke(.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        ))
        XCTAssertNotNil(widget)
        XCTAssertEqual(widgetTypeName(widget), "GtkDrawingArea")
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
