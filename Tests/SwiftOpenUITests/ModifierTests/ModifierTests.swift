import XCTest
@testable import SwiftOpenUI

final class ModifierTests: XCTestCase {

    // MARK: - ViewModifier preserves content

    struct RedBackground: ViewModifier {
        func body(content: Content) -> some View {
            // In a real modifier, content.wrapped holds the original view
            content
        }
    }

    func testViewModifierPreservesWrappedContent() {
        let text = Text("hello")
        let modified = text.modifier(RedBackground())
        // ModifiedContent should pass AnyView(text) through to the modifier
        let modifierContent = RedBackground().body(
            content: _ViewModifierContent<RedBackground>(AnyView(text))
        )
        XCTAssertTrue(modifierContent is _ViewModifierContent<RedBackground>)
        // The wrapped view inside _ViewModifierContent should be our Text
        let content = _ViewModifierContent<RedBackground>(AnyView(text))
        XCTAssertTrue(content.wrapped.wrapped is Text)
    }

    // MARK: - Padding

    func testPaddingUniform() {
        let padded = Text("hello").padding(16)
        XCTAssertEqual(padded.top, 16)
        XCTAssertEqual(padded.bottom, 16)
        XCTAssertEqual(padded.leading, 16)
        XCTAssertEqual(padded.trailing, 16)
    }

    func testPaddingEdges() {
        let padded = Text("hello").padding(.horizontal, 10)
        XCTAssertEqual(padded.leading, 10)
        XCTAssertEqual(padded.trailing, 10)
        XCTAssertEqual(padded.top, 0)
        XCTAssertEqual(padded.bottom, 0)
    }

    func testPaddingPerEdge() {
        let padded = Text("hello").padding(top: 1, bottom: 2, leading: 3, trailing: 4)
        XCTAssertEqual(padded.top, 1)
        XCTAssertEqual(padded.bottom, 2)
        XCTAssertEqual(padded.leading, 3)
        XCTAssertEqual(padded.trailing, 4)
    }

    // MARK: - Frame

    func testFrameFixed() {
        let framed = Text("hello").frame(width: 100, height: 50)
        XCTAssertEqual(framed.width, 100)
        XCTAssertEqual(framed.height, 50)
    }

    func testFrameFlexible() {
        let framed = Text("hello").frame(minWidth: 10, maxWidth: 200)
        XCTAssertEqual(framed.minWidth, 10)
        XCTAssertEqual(framed.maxWidth, 200)
    }

    // MARK: - Style modifiers

    func testForegroundColor() {
        let styled = Text("hello").foregroundColor(.red)
        XCTAssertEqual(styled.color, .red)
    }

    func testForegroundStyleAlias() {
        let styled = Text("hello").foregroundStyle(.blue)
        XCTAssertEqual(styled.color, .blue)
    }

    func testBackgroundColor() {
        let styled = Text("hello").background(.green)
        XCTAssertEqual(styled.color, .green)
    }

    func testFontModifier() {
        let styled = Text("hello").font(.title)
        XCTAssertTrue(styled is FontModifiedView<Text>)
    }

    func testBorderModifier() {
        let styled = Text("hello").border(.red, width: 2)
        XCTAssertEqual(styled.color, .red)
        XCTAssertEqual(styled.width, 2)
    }

    // MARK: - Environment modifiers

    class TestModel: SwiftOpenUI.ObservableObject {
        @SwiftOpenUI.Published var value = "test"
    }

    func testEnvironmentObjectModifier() {
        let model = TestModel()
        let view = Text("hello").environmentObject(model)
        XCTAssertTrue(view is EnvironmentObjectModifierView<Text, TestModel>)
        XCTAssertTrue(view.object === model)
    }

    func testEnvironmentModifier() {
        let view = Text("hello").environment(\.colorScheme, .dark)
        XCTAssertTrue(view is EnvironmentModifierView<Text, ColorScheme>)
    }
}
