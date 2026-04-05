import XCTest
@testable import SwiftOpenUI
@testable import BackendWeb

final class WebClipShapeTests: XCTestCase {

    // MARK: - webClipPathCSS helper

    func testClipPathCircle() {
        let css = webClipPathCSS(Circle())
        XCTAssertEqual(css, "clip-path: circle(50%);")
    }

    func testClipPathEllipse() {
        let css = webClipPathCSS(Ellipse())
        XCTAssertEqual(css, "clip-path: ellipse(50% 50%);")
    }

    func testClipPathRoundedRectangle() {
        let css = webClipPathCSS(RoundedRectangle(cornerRadius: 12))
        XCTAssertEqual(css, "clip-path: inset(0 round 12px);")
    }

    func testClipPathCapsule() {
        let css = webClipPathCSS(Capsule())
        XCTAssertEqual(css, "clip-path: inset(0 round 9999px);")
    }

    func testClipPathRectangleIsNil() {
        let css = webClipPathCSS(SwiftOpenUI.Rectangle())
        XCTAssertNil(css, "Rectangle clip uses overflow: hidden, no clip-path needed")
    }

    // MARK: - Modifier storage

    func testClipShapeStoresShape() {
        let view = Text("Hello").clipShape(Circle())
        XCTAssertEqual(view.content.content, "Hello")
    }

    func testClipShapeWithRoundedRectangle() {
        let view = Text("Hello").clipShape(RoundedRectangle(cornerRadius: 8))
        XCTAssertEqual(view.shape.cornerRadius, 8)
    }

    func testClippedWrapsContent() {
        let view = Text("Hello").clipped()
        XCTAssertEqual(view.content.content, "Hello")
    }

    // MARK: - Chaining

    func testClipShapeWithFrame() {
        let view = Text("Hello")
            .frame(width: 50, height: 50)
            .clipShape(Circle())
        XCTAssertEqual(view.content.width, 50)
    }

    func testClipShapeWithBackgroundAndClip() {
        let view = Text("Hello")
            .background(.red)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        XCTAssertEqual(view.shape.cornerRadius, 10)
    }
}
