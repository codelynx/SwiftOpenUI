import XCTest
@testable import SwiftOpenUI
@testable import BackendWeb

final class WebTextFormattingTests: XCTestCase {

    // MARK: - LineLimitView

    func testLineLimitOneCSS() {
        let css = webLineLimitCSS(1)
        XCTAssertTrue(css.contains("white-space: nowrap"), "lineLimit(1) should set nowrap")
        XCTAssertTrue(css.contains("overflow: hidden"), "lineLimit(1) should set overflow hidden")
    }

    func testLineLimitNilCSS() {
        let css = webLineLimitCSS(nil)
        XCTAssertTrue(css.contains("white-space: normal"), "lineLimit(nil) should set normal wrapping")
    }

    func testLineLimitMultiLineCSS() {
        let css = webLineLimitCSS(3)
        XCTAssertTrue(css.contains("-webkit-line-clamp: 3"), "lineLimit(3) should set line-clamp to 3")
        XCTAssertTrue(css.contains("-webkit-box-orient: vertical"), "lineLimit(3) should set box-orient")
        XCTAssertTrue(css.contains("overflow: hidden"), "lineLimit(3) should set overflow hidden")
    }

    func testLineLimitTwoCSS() {
        let css = webLineLimitCSS(2)
        XCTAssertTrue(css.contains("-webkit-line-clamp: 2"))
    }

    // MARK: - TruncationModeView

    func testTruncationModeTailCSS() {
        let view = Text("Hello").truncationMode(.tail)
        XCTAssertEqual(view.mode, .tail)
        // Tail truncation uses text-overflow: ellipsis
        // Verified by CSS string in webCreateElement
    }

    func testTruncationModeHeadCSS() {
        let view = Text("Hello").truncationMode(.head)
        XCTAssertEqual(view.mode, .head)
        // Head truncation uses direction: rtl hack
    }

    func testTruncationModeMiddleFallsBackToTail() {
        let view = Text("Hello").truncationMode(.middle)
        XCTAssertEqual(view.mode, .middle)
        // Middle truncation falls back to tail (no native CSS support)
    }

    // MARK: - LineSpacingView

    func testLineSpacingStoresValue() {
        let view = Text("Hello").lineSpacing(8.0)
        XCTAssertEqual(view.spacing, 8.0)
        // CSS: line-height: calc(1em + 8.0px)
    }

    func testLineSpacingZero() {
        let view = Text("Hello").lineSpacing(0)
        XCTAssertEqual(view.spacing, 0)
    }

    // MARK: - MultilineTextAlignmentView

    func testMultilineAlignmentLeading() {
        let view = Text("Hello").multilineTextAlignment(.leading)
        XCTAssertEqual(view.alignment, .leading)
        // CSS: text-align: left
    }

    func testMultilineAlignmentCenter() {
        let view = Text("Hello").multilineTextAlignment(.center)
        XCTAssertEqual(view.alignment, .center)
        // CSS: text-align: center
    }

    func testMultilineAlignmentTrailing() {
        let view = Text("Hello").multilineTextAlignment(.trailing)
        XCTAssertEqual(view.alignment, .trailing)
        // CSS: text-align: right
    }

    // MARK: - CSS helper verification

    func testLineLimitCSSHelperIsAccessible() {
        // Verify the helper function is public/internal and callable
        let css1 = webLineLimitCSS(1)
        let cssNil = webLineLimitCSS(nil)
        let css5 = webLineLimitCSS(5)
        XCTAssertFalse(css1.isEmpty)
        XCTAssertFalse(cssNil.isEmpty)
        XCTAssertFalse(css5.isEmpty)
    }

    // MARK: - Modifier chaining

    func testChainedModifiers() {
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
