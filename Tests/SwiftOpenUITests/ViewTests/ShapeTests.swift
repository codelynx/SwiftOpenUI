import XCTest
@testable import SwiftOpenUI
import Foundation

final class ShapeTests: XCTestCase {

    let unitRect = CGRect(x: 0, y: 0, width: 100, height: 100)

    // MARK: - Circle

    func testCirclePathIsNotEmpty() {
        let path = Circle().path(in: unitRect)
        XCTAssertFalse(path.isEmpty)
    }

    func testCircleInscribesInSmallerDimension() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let path = Circle().path(in: rect)
        // Should produce an ellipse element centered in the rect
        // with equal radiusX and radiusY = 50 (half of shorter side)
        XCTAssertFalse(path.isEmpty)
        if case .ellipse(let center, let rx, let ry) = path.elements.first {
            XCTAssertEqual(rx, 50, accuracy: 0.01)
            XCTAssertEqual(ry, 50, accuracy: 0.01)
            XCTAssertEqual(center.x, 100, accuracy: 0.01)
            XCTAssertEqual(center.y, 50, accuracy: 0.01)
        } else {
            XCTFail("Expected ellipse element")
        }
    }

    // MARK: - Rectangle

    func testRectanglePathIsNotEmpty() {
        let path = Rectangle().path(in: unitRect)
        XCTAssertFalse(path.isEmpty)
    }

    func testRectanglePathMatchesRect() {
        let rect = CGRect(x: 10, y: 20, width: 50, height: 30)
        let path = Rectangle().path(in: rect)
        // First element should be moveTo(10, 20)
        if case .moveTo(let pt) = path.elements.first {
            XCTAssertEqual(pt.x, 10, accuracy: 0.01)
            XCTAssertEqual(pt.y, 20, accuracy: 0.01)
        } else {
            XCTFail("Expected moveTo")
        }
        // Should have closeSubpath
        XCTAssertTrue(path.elements.contains(where: {
            if case .closeSubpath = $0 { return true }
            return false
        }))
    }

    // MARK: - RoundedRectangle

    func testRoundedRectangleStoresCornerRadius() {
        let shape = RoundedRectangle(cornerRadius: 12)
        XCTAssertEqual(shape.cornerRadius, 12)
        XCTAssertEqual(shape.style, .circular)
    }

    func testRoundedRectangleContinuousStyle() {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        XCTAssertEqual(shape.style, .continuous)
    }

    func testRoundedRectanglePathIsNotEmpty() {
        let path = RoundedRectangle(cornerRadius: 10).path(in: unitRect)
        XCTAssertFalse(path.isEmpty)
    }

    func testRoundedRectangleCornerRadiusClamped() {
        // cornerRadius larger than half the short side should be clamped
        let rect = CGRect(x: 0, y: 0, width: 20, height: 10)
        let path = RoundedRectangle(cornerRadius: 100).path(in: rect)
        // Should still produce a valid path (clamped to 5)
        XCTAssertFalse(path.isEmpty)
    }

    // MARK: - Capsule

    func testCapsuleDefaultStyle() {
        let shape = Capsule()
        XCTAssertEqual(shape.style, .circular)
    }

    func testCapsulePathIsNotEmpty() {
        let path = Capsule().path(in: unitRect)
        XCTAssertFalse(path.isEmpty)
    }

    func testCapsuleUsesHalfShortSide() {
        // In a 100x40 rect, capsule cornerRadius should be 20
        let rect = CGRect(x: 0, y: 0, width: 100, height: 40)
        let path = Capsule().path(in: rect)
        XCTAssertFalse(path.isEmpty)
        // Path should contain arcs (from the rounded corners)
        let hasArcs = path.elements.contains(where: {
            if case .arc = $0 { return true }
            return false
        })
        XCTAssertTrue(hasArcs, "Capsule path should contain arc elements")
    }

    // MARK: - Ellipse

    func testEllipsePathIsNotEmpty() {
        let path = Ellipse().path(in: unitRect)
        XCTAssertFalse(path.isEmpty)
    }

    func testEllipsePathMatchesRect() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let path = Ellipse().path(in: rect)
        if case .ellipse(let center, let rx, let ry) = path.elements.first {
            XCTAssertEqual(center.x, 100, accuracy: 0.01)
            XCTAssertEqual(center.y, 50, accuracy: 0.01)
            XCTAssertEqual(rx, 100, accuracy: 0.01)
            XCTAssertEqual(ry, 50, accuracy: 0.01)
        } else {
            XCTFail("Expected ellipse element")
        }
    }

    // MARK: - FilledShape

    func testFillReturnsFilledShape() {
        let filled = Circle().fill(.red)
        XCTAssertEqual(filled.color.red, 1.0)
        XCTAssertEqual(filled.color.green, 0.0)
        XCTAssertEqual(filled.color.blue, 0.0)
    }

    func testFilledShapePreservesShape() {
        let filled = RoundedRectangle(cornerRadius: 8).fill(.blue)
        XCTAssertEqual(filled.shape.cornerRadius, 8)
    }

    // MARK: - StrokedShape

    func testStrokeReturnsStrokedShape() {
        let stroked = Circle().stroke(.green, lineWidth: 3)
        XCTAssertGreaterThan(stroked.color.green, 0)
        XCTAssertEqual(stroked.style.lineWidth, 3)
    }

    func testStrokeWithStyleReturnsStrokedShape() {
        let style = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .bevel)
        let stroked = Rectangle().stroke(.red, style: style)
        XCTAssertEqual(stroked.style.lineWidth, 2)
        XCTAssertEqual(stroked.style.lineCap, .round)
        XCTAssertEqual(stroked.style.lineJoin, .bevel)
    }

    func testStrokedShapePreservesShape() {
        let stroked = Capsule().stroke(.black, lineWidth: 1)
        XCTAssertEqual(stroked.shape.style, .circular)
    }

    // MARK: - Path.addRoundedRect

    func testAddRoundedRectProducesElements() {
        var path = Path()
        path.addRoundedRect(in: unitRect, cornerRadius: 10)
        XCTAssertFalse(path.isEmpty)
        // Should have moveTo, lines, arcs, and closeSubpath
        let hasClose = path.elements.contains(where: {
            if case .closeSubpath = $0 { return true }
            return false
        })
        XCTAssertTrue(hasClose)
        let arcCount = path.elements.filter {
            if case .arc = $0 { return true }
            return false
        }.count
        XCTAssertEqual(arcCount, 4, "Rounded rect should have 4 corner arcs")
    }

    // MARK: - RoundedCornerStyle

    func testRoundedCornerStyleEquatable() {
        XCTAssertEqual(RoundedCornerStyle.circular, RoundedCornerStyle.circular)
        XCTAssertEqual(RoundedCornerStyle.continuous, RoundedCornerStyle.continuous)
        XCTAssertNotEqual(RoundedCornerStyle.circular, RoundedCornerStyle.continuous)
    }
}
