import XCTest
@testable import SwiftOpenUI
@testable import BackendWeb

final class WebShapeTests: XCTestCase {

    // MARK: - Shape views

    func testCirclePathIsNotEmpty() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = Circle().path(in: rect)
        XCTAssertFalse(path.isEmpty)
    }

    func testRectanglePathIsNotEmpty() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = SwiftOpenUI.Rectangle().path(in: rect)
        XCTAssertFalse(path.isEmpty)
    }

    func testRoundedRectangleStoresCornerRadius() {
        let shape = RoundedRectangle(cornerRadius: 12)
        XCTAssertEqual(shape.cornerRadius, 12)
    }

    func testCapsulePathIsNotEmpty() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 50)
        let path = Capsule().path(in: rect)
        XCTAssertFalse(path.isEmpty)
    }

    func testEllipsePathIsNotEmpty() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let path = Ellipse().path(in: rect)
        XCTAssertFalse(path.isEmpty)
    }

    // MARK: - FilledShape

    func testFillReturnsFilledShape() {
        let filled = Circle().fill(.red)
        XCTAssertEqual(filled.color.red, 1.0)
        XCTAssertEqual(filled.color.green, 0.0)
    }

    func testFilledShapePreservesShape() {
        let filled = RoundedRectangle(cornerRadius: 8).fill(.blue)
        XCTAssertEqual(filled.shape.cornerRadius, 8)
    }

    // MARK: - StrokedShape

    func testStrokeReturnsStrokedShape() {
        let stroked = Circle().stroke(.red, lineWidth: 3)
        XCTAssertEqual(stroked.style.lineWidth, 3)
        XCTAssertEqual(stroked.color.red, 1.0)
    }

    func testStrokeWithStylePreservesStyle() {
        let style = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .bevel)
        let stroked = SwiftOpenUI.Rectangle().stroke(.blue, style: style)
        XCTAssertEqual(stroked.style.lineWidth, 2)
        XCTAssertEqual(stroked.style.lineCap, .round)
        XCTAssertEqual(stroked.style.lineJoin, .bevel)
    }

    // MARK: - Modifier chaining

    func testShapeWithFrameAndFill() {
        // Verify chaining compiles and stores correct values
        let view = Circle().fill(.green).frame(width: 50, height: 50)
        XCTAssertEqual(view.width, 50)
        XCTAssertEqual(view.height, 50)
    }

    // MARK: - RoundedCornerStyle

    func testRoundedCornerStyleEquatable() {
        XCTAssertEqual(RoundedCornerStyle.circular, RoundedCornerStyle.circular)
        XCTAssertNotEqual(RoundedCornerStyle.circular, RoundedCornerStyle.continuous)
    }
}
