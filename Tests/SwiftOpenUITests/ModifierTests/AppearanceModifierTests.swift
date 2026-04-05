import XCTest
@testable import SwiftOpenUI

final class AppearanceModifierTests: XCTestCase {

    // MARK: - HiddenView

    func testHiddenWrapsContent() {
        let view = Text("Hello").hidden()
        XCTAssertEqual(view.content.content, "Hello")
    }

    // MARK: - BlurView

    func testBlurWrapsContent() {
        let view = Text("Hello").blur(radius: 5)
        XCTAssertEqual(view.content.content, "Hello")
        XCTAssertEqual(view.radius, 5)
    }

    func testBlurDefaultOpaque() {
        let view = Text("Hello").blur(radius: 3)
        XCTAssertFalse(view.opaque)
    }

    func testBlurOpaqueTrue() {
        let view = Text("Hello").blur(radius: 3, opaque: true)
        XCTAssertTrue(view.opaque)
    }

    func testBlurZeroRadius() {
        let view = Text("Hello").blur(radius: 0)
        XCTAssertEqual(view.radius, 0)
    }

    // MARK: - Chaining

    func testHiddenChainedWithOtherModifiers() {
        let view = Text("Hello")
            .padding()
            .hidden()
        _ = view // compiles
    }

    func testBlurChainedWithFrame() {
        let view = Text("Hello")
            .frame(width: 100, height: 100)
            .blur(radius: 10)
        XCTAssertEqual(view.radius, 10)
    }
}
