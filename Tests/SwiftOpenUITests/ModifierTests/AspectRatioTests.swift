import XCTest
@testable import SwiftOpenUI
import Foundation

final class AspectRatioTests: XCTestCase {

    // MARK: - ContentMode

    func testContentModeEquatable() {
        XCTAssertEqual(ContentMode.fit, ContentMode.fit)
        XCTAssertEqual(ContentMode.fill, ContentMode.fill)
        XCTAssertNotEqual(ContentMode.fit, ContentMode.fill)
    }

    // MARK: - AspectRatioView

    func testAspectRatioWithExplicitRatio() {
        let view = Text("Hello").aspectRatio(16.0 / 9.0, contentMode: .fit)
        XCTAssertEqual(view.ratio!, 16.0 / 9.0, accuracy: 0.01)
        XCTAssertEqual(view.contentMode, .fit)
    }

    func testAspectRatioNilRatio() {
        let view = Text("Hello").aspectRatio(contentMode: .fill)
        XCTAssertNil(view.ratio)
        XCTAssertEqual(view.contentMode, .fill)
    }

    func testAspectRatioFromCGSize() {
        let view = Text("Hello").aspectRatio(CGSize(width: 4, height: 3), contentMode: .fit)
        XCTAssertEqual(view.ratio!, 4.0 / 3.0, accuracy: 0.01)
    }

    // MARK: - scaledToFit / scaledToFill

    func testScaledToFit() {
        let view = Text("Hello").scaledToFit()
        XCTAssertNil(view.ratio)
        XCTAssertEqual(view.contentMode, .fit)
    }

    func testScaledToFill() {
        let view = Text("Hello").scaledToFill()
        XCTAssertNil(view.ratio)
        XCTAssertEqual(view.contentMode, .fill)
    }

    // MARK: - Chaining

    func testAspectRatioWithFrame() {
        let view = Text("Hello")
            .frame(width: 200, height: 200)
            .aspectRatio(1.0, contentMode: .fit)
        XCTAssertEqual(view.ratio, 1.0)
    }

    func testScaledToFitWithClip() {
        let view = Text("Hello")
            .scaledToFill()
            .clipped()
        // Common pattern: fill + clip
        _ = view
    }
}
