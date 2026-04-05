import XCTest
@testable import SwiftOpenUI

final class TextModifierTests: XCTestCase {

    // MARK: - TextAlignment enum

    func testTextAlignmentEquatable() {
        XCTAssertEqual(TextAlignment.leading, TextAlignment.leading)
        XCTAssertEqual(TextAlignment.center, TextAlignment.center)
        XCTAssertEqual(TextAlignment.trailing, TextAlignment.trailing)
        XCTAssertNotEqual(TextAlignment.leading, TextAlignment.center)
        XCTAssertNotEqual(TextAlignment.center, TextAlignment.trailing)
    }

    // MARK: - TruncationMode enum

    func testTruncationModeEquatable() {
        XCTAssertEqual(TruncationMode.head, TruncationMode.head)
        XCTAssertEqual(TruncationMode.tail, TruncationMode.tail)
        XCTAssertEqual(TruncationMode.middle, TruncationMode.middle)
        XCTAssertNotEqual(TruncationMode.head, TruncationMode.tail)
        XCTAssertNotEqual(TruncationMode.tail, TruncationMode.middle)
    }

    // MARK: - LineLimitView

    func testLineLimitWrapsContent() {
        let view = Text("Hello").lineLimit(3)
        XCTAssertEqual(view.lineLimit, 3)
        XCTAssertEqual(view.content.content, "Hello")
    }

    func testLineLimitNilMeansUnlimited() {
        let view = Text("Hello").lineLimit(nil)
        XCTAssertNil(view.lineLimit)
    }

    func testLineLimitOne() {
        let view = Text("Hello").lineLimit(1)
        XCTAssertEqual(view.lineLimit, 1)
    }

    // MARK: - TruncationModeView

    func testTruncationModeWrapsContent() {
        let view = Text("Hello").truncationMode(.tail)
        XCTAssertEqual(view.mode, .tail)
        XCTAssertEqual(view.content.content, "Hello")
    }

    func testTruncationModeHead() {
        let view = Text("Hello").truncationMode(.head)
        XCTAssertEqual(view.mode, .head)
    }

    func testTruncationModeMiddle() {
        let view = Text("Hello").truncationMode(.middle)
        XCTAssertEqual(view.mode, .middle)
    }

    // MARK: - LineSpacingView

    func testLineSpacingWrapsContent() {
        let view = Text("Hello").lineSpacing(8.0)
        XCTAssertEqual(view.spacing, 8.0)
        XCTAssertEqual(view.content.content, "Hello")
    }

    func testLineSpacingZero() {
        let view = Text("Hello").lineSpacing(0)
        XCTAssertEqual(view.spacing, 0)
    }

    // MARK: - MultilineTextAlignmentView

    func testMultilineTextAlignmentWrapsContent() {
        let view = Text("Hello").multilineTextAlignment(.center)
        XCTAssertEqual(view.alignment, .center)
        XCTAssertEqual(view.content.content, "Hello")
    }

    func testMultilineTextAlignmentLeading() {
        let view = Text("Hello").multilineTextAlignment(.leading)
        XCTAssertEqual(view.alignment, .leading)
    }

    func testMultilineTextAlignmentTrailing() {
        let view = Text("Hello").multilineTextAlignment(.trailing)
        XCTAssertEqual(view.alignment, .trailing)
    }

    // MARK: - Chaining

    func testModifiersChain() {
        let view = Text("Hello")
            .lineLimit(2)
            .truncationMode(.tail)
            .lineSpacing(4.0)
            .multilineTextAlignment(.center)

        XCTAssertEqual(view.alignment, .center)
        XCTAssertEqual(view.content.spacing, 4.0)
        XCTAssertEqual(view.content.content.mode, .tail)
        XCTAssertEqual(view.content.content.content.lineLimit, 2)
    }
}
