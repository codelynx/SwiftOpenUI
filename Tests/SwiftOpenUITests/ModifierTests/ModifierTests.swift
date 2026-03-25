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
        _ = text.modifier(RedBackground())
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
        XCTAssertEqual(styled.alignment, .center)
    }

    func testBackgroundViewOverload() {
        let styled = Text("hello").background(Text("bg"), alignment: .bottomTrailing)
        XCTAssertEqual(styled.background.content, "bg")
        XCTAssertEqual(styled.alignment, .bottomTrailing)
    }

    func testBackgroundBuilderOverload() {
        let styled = Text("hello").background(alignment: .topLeading) {
            Text("bg")
        }
        XCTAssertEqual(styled.background.content, "bg")
        XCTAssertEqual(styled.alignment, .topLeading)
    }

    func testFontModifier() {
        let styled = Text("hello").font(.title)
        XCTAssertNotNil(styled as FontModifiedView<Text>)
    }

    func testBorderModifier() {
        let styled = Text("hello").border(.red, width: 2)
        XCTAssertEqual(styled.color, .red)
        XCTAssertEqual(styled.width, 2)
    }

    func testOverlayDirectViewOverload() {
        let styled = Text("hello").overlay(Text("badge"), alignment: .topTrailing)
        XCTAssertEqual(styled.overlay.content, "badge")
        XCTAssertEqual(styled.alignment, .topTrailing)
    }

    // MARK: - Safe area modifiers

    func testIgnoresSafeAreaStoresRegionsAndEdges() {
        let view = Text("hello").ignoresSafeArea([.container], edges: .horizontal)
        XCTAssertTrue(view.regions.contains(.container))
        XCTAssertFalse(view.regions.contains(.keyboard))
        XCTAssertTrue(view.edges.contains(.leading))
        XCTAssertTrue(view.edges.contains(.trailing))
        XCTAssertFalse(view.edges.contains(.top))
    }

    func testSafeAreaInsetVerticalStoresValues() {
        let view = Text("hello").safeAreaInset(edge: .top, alignment: .leading, spacing: 12) {
            Text("inset")
        }

        XCTAssertEqual(view.edge, .top)
        XCTAssertEqual(view.spacing, 12)
        XCTAssertEqual(view.inset.content, "inset")
        if case let .horizontal(alignment) = view.alignment {
            XCTAssertEqual(alignment, .leading)
        } else {
            XCTFail("Expected horizontal alignment")
        }
    }

    func testSafeAreaInsetHorizontalStoresValues() {
        let view = Text("hello").safeAreaInset(edge: .trailing, alignment: .bottom) {
            Text("inset")
        }

        XCTAssertEqual(view.edge, .trailing)
        XCTAssertEqual(view.spacing, 0)
        XCTAssertEqual(view.inset.content, "inset")
        if case let .vertical(alignment) = view.alignment {
            XCTAssertEqual(alignment, .bottom)
        } else {
            XCTFail("Expected vertical alignment")
        }
    }

    func testSafeAreaPaddingDefaultStoresAllEdgesAndNilLength() {
        let view = Text("hello").safeAreaPadding()
        XCTAssertTrue(view.edges.contains(.top))
        XCTAssertTrue(view.edges.contains(.bottom))
        XCTAssertTrue(view.edges.contains(.leading))
        XCTAssertTrue(view.edges.contains(.trailing))
        XCTAssertNil(view.length)
    }

    func testSafeAreaPaddingExplicitLengthStoresAllEdges() {
        let view = Text("hello").safeAreaPadding(20)
        XCTAssertTrue(view.edges.contains(.top))
        XCTAssertTrue(view.edges.contains(.bottom))
        XCTAssertTrue(view.edges.contains(.leading))
        XCTAssertTrue(view.edges.contains(.trailing))
        XCTAssertEqual(view.length, 20)
    }

    func testSafeAreaPaddingSelectedEdgesStoresValues() {
        let view = Text("hello").safeAreaPadding(.horizontal, 12)
        XCTAssertFalse(view.edges.contains(.top))
        XCTAssertFalse(view.edges.contains(.bottom))
        XCTAssertTrue(view.edges.contains(.leading))
        XCTAssertTrue(view.edges.contains(.trailing))
        XCTAssertEqual(view.length, 12)
    }

    func testSafeAreaPaddingSelectedEdgesAllowsSyntheticLength() {
        let view = Text("hello").safeAreaPadding(.vertical)
        XCTAssertTrue(view.edges.contains(.top))
        XCTAssertTrue(view.edges.contains(.bottom))
        XCTAssertFalse(view.edges.contains(.leading))
        XCTAssertFalse(view.edges.contains(.trailing))
        XCTAssertNil(view.length)
    }

    // MARK: - Environment modifiers

    class TestModel: SwiftOpenUI.ObservableObject {
        @SwiftOpenUI.Published var value = "test"
    }

    func testEnvironmentObjectModifier() {
        let model = TestModel()
        let view = Text("hello").environmentObject(model)
        XCTAssertNotNil(view as EnvironmentObjectModifierView<Text, TestModel>)
        XCTAssertTrue(view.object === model)
    }

    func testEnvironmentModifier() {
        let view = Text("hello").environment(\.colorScheme, .dark)
        XCTAssertNotNil(view as EnvironmentModifierView<Text, ColorScheme>)
    }
}
