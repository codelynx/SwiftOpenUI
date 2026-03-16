import XCTest
@testable import SwiftOpenUI

final class LayoutTests: XCTestCase {

    // MARK: - Color

    func testColorHex6() {
        let color = Color(hex: "#FF0000")
        XCTAssertEqual(color.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.green, 0.0, accuracy: 0.01)
        XCTAssertEqual(color.blue, 0.0, accuracy: 0.01)
        XCTAssertEqual(color.alpha, 1.0)
    }

    func testColorHex8() {
        let color = Color(hex: "#FF000080")
        XCTAssertEqual(color.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.alpha, 128.0 / 255.0, accuracy: 0.01)
    }

    func testColorRGBFractional() {
        let color = Color(red: 0.5, green: 0.5, blue: 0.5)
        XCTAssertEqual(color.red, 0.5, accuracy: 0.01)
        XCTAssertEqual(color.alpha, 1.0)
    }

    func testColorRGBInteger() {
        let color = Color(red: 128, green: 0, blue: 255)
        XCTAssertEqual(color.red, 128.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(color.blue, 1.0, accuracy: 0.01)
    }

    func testColorOpacity() {
        let color = Color.red.opacity(0.5)
        XCTAssertEqual(color.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.alpha, 0.5, accuracy: 0.01)
    }

    func testColorEquality() {
        XCTAssertEqual(Color.red, Color.red)
        XCTAssertNotEqual(Color.red, Color.blue)
    }

    func testColorHexOutput() {
        let color = Color(red: 1.0, green: 0.0, blue: 0.0)
        XCTAssertEqual(color.hex, "#FF0000")
    }

    func testNamedColors() {
        // Ensure named colors don't crash
        _ = Color.red
        _ = Color.green
        _ = Color.blue
        _ = Color.orange
        _ = Color.purple
        _ = Color.yellow
        _ = Color.cyan
        _ = Color.gray
        _ = Color.white
        _ = Color.black
        _ = Color.clear
        _ = Color.pink
        _ = Color.brown
        _ = Color.mint
        _ = Color.teal
        _ = Color.indigo
    }

    // MARK: - Edge

    func testEdgeSetAll() {
        let all = Edge.Set.all
        XCTAssertTrue(all.contains(.top))
        XCTAssertTrue(all.contains(.bottom))
        XCTAssertTrue(all.contains(.leading))
        XCTAssertTrue(all.contains(.trailing))
    }

    func testEdgeSetHorizontal() {
        let h = Edge.Set.horizontal
        XCTAssertTrue(h.contains(.leading))
        XCTAssertTrue(h.contains(.trailing))
        XCTAssertFalse(h.contains(.top))
    }

    func testEdgeSetVertical() {
        let v = Edge.Set.vertical
        XCTAssertTrue(v.contains(.top))
        XCTAssertTrue(v.contains(.bottom))
        XCTAssertFalse(v.contains(.leading))
    }

    // MARK: - EdgeInsets

    func testEdgeInsetsDefault() {
        let insets = EdgeInsets()
        XCTAssertEqual(insets.top, 0)
        XCTAssertEqual(insets.leading, 0)
        XCTAssertEqual(insets.bottom, 0)
        XCTAssertEqual(insets.trailing, 0)
    }

    func testEdgeInsetsCustom() {
        let insets = EdgeInsets(top: 1, leading: 2, bottom: 3, trailing: 4)
        XCTAssertEqual(insets.top, 1)
        XCTAssertEqual(insets.leading, 2)
        XCTAssertEqual(insets.bottom, 3)
        XCTAssertEqual(insets.trailing, 4)
    }

    // MARK: - Alignment

    func testAlignmentEnumCases() {
        // Ensure all alignment cases exist
        _ = Alignment.topLeading
        _ = Alignment.top
        _ = Alignment.topTrailing
        _ = Alignment.leading
        _ = Alignment.center
        _ = Alignment.trailing
        _ = Alignment.bottomLeading
        _ = Alignment.bottom
        _ = Alignment.bottomTrailing
        _ = HorizontalAlignment.leading
        _ = HorizontalAlignment.center
        _ = HorizontalAlignment.trailing
        _ = VerticalAlignment.top
        _ = VerticalAlignment.center
        _ = VerticalAlignment.bottom
    }

    // MARK: - ProposedViewSize / ViewSize

    func testViewSizeZero() {
        let size = ViewSize.zero
        XCTAssertEqual(size.width, 0)
        XCTAssertEqual(size.height, 0)
    }

    func testProposedViewSizeUnspecified() {
        let size = ProposedViewSize.unspecified
        XCTAssertNil(size.width)
        XCTAssertNil(size.height)
    }
}
