import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge
import Foundation

final class GTK4ImageDecodedTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 { _ = gtk_init_check() }
    }

    /// Image(decoded:) renders a GtkPicture from an in-memory pixel buffer
    /// without crashing (exercises the GdkMemoryTexture path + shim).
    func testImageDecodedRendersPicture() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        // 2x2 BGRA, opaque: blue, green / red, yellow
        let pixels = Data([
            0, 0, 255, 255,   0, 255, 0, 255,
            255, 0, 0, 255,   0, 255, 255, 255,
        ])
        let widget = widgetFromOpaque(
            Image(decoded: pixels, width: 2, height: 2, format: .bgra8).gtkCreateWidget()
        )
        let cssName = String(cString: gtk_widget_get_css_name(widget))
        XCTAssertEqual(cssName, "picture", "Image(decoded:) should produce a GtkPicture")
    }

    /// rgba8 path also renders (different GdkMemoryFormat branch).
    func testImageDecodedRGBARenders() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let pixels = Data([255, 0, 0, 255,  0, 255, 0, 255])  // 2x1 RGBA: red, green
        let widget = widgetFromOpaque(
            Image(decoded: pixels, width: 2, height: 1, format: .rgba8).resizable().gtkCreateWidget()
        )
        XCTAssertEqual(String(cString: gtk_widget_get_css_name(widget)), "picture")
    }

    /// A too-small buffer / bad dimensions renders an empty box, not a crash.
    func testImageDecodedInvalidBufferRendersEmpty() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        // Claims 4x4 (needs 64 bytes) but supplies 4.
        let short = Data([1, 2, 3, 4])
        let widget = widgetFromOpaque(
            Image(decoded: short, width: 4, height: 4, format: .rgba8).gtkCreateWidget()
        )
        XCTAssertEqual(String(cString: gtk_widget_get_css_name(widget)), "box",
                       "invalid Image(decoded:) buffer should render an empty box, not crash")
    }
}
