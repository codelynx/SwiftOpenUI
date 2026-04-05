import XCTest
@testable import SwiftOpenUI

final class TextDecorationTests: XCTestCase {

    // MARK: - Bold

    func testBoldWrapsContent() {
        let view = Text("Hello").bold()
        XCTAssertEqual(view.content.content, "Hello")
    }

    // MARK: - Italic

    func testItalicWrapsContent() {
        let view = Text("Hello").italic()
        XCTAssertEqual(view.content.content, "Hello")
    }

    // MARK: - FontWeight

    func testFontWeightWrapsContent() {
        let view = Text("Hello").fontWeight(.heavy)
        XCTAssertEqual(view.weight, .heavy)
        XCTAssertEqual(view.content.content, "Hello")
    }

    func testFontWeightAllValues() {
        let weights: [FontWeight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        for w in weights {
            let view = Text("X").fontWeight(w)
            XCTAssertEqual(view.weight, w)
        }
    }

    // MARK: - Underline

    func testUnderlineDefaultActive() {
        let view = Text("Hello").underline()
        XCTAssertTrue(view.isActive)
    }

    func testUnderlineExplicitFalse() {
        let view = Text("Hello").underline(false)
        XCTAssertFalse(view.isActive)
    }

    // MARK: - Strikethrough

    func testStrikethroughDefaultActive() {
        let view = Text("Hello").strikethrough()
        XCTAssertTrue(view.isActive)
    }

    func testStrikethroughExplicitFalse() {
        let view = Text("Hello").strikethrough(false)
        XCTAssertFalse(view.isActive)
    }

    // MARK: - TextCase

    func testTextCaseUppercase() {
        let view = Text("Hello").textCase(.uppercase)
        XCTAssertEqual(view.textCase, .uppercase)
    }

    func testTextCaseLowercase() {
        let view = Text("Hello").textCase(.lowercase)
        XCTAssertEqual(view.textCase, .lowercase)
    }

    func testTextCaseNilReset() {
        let view = Text("Hello").textCase(nil)
        XCTAssertNil(view.textCase)
    }

    // MARK: - Chaining

    func testChainBoldItalicUnderline() {
        let view = Text("Hello")
            .bold()
            .italic()
            .underline()
        XCTAssertTrue(view.isActive)
    }

    func testChainFontWeightWithStrikethrough() {
        let view = Text("Hello")
            .fontWeight(.semibold)
            .strikethrough()
        XCTAssertTrue(view.isActive)
        XCTAssertEqual(view.content.weight, .semibold)
    }
}
