import XCTest
@testable import SwiftOpenUI

final class ControlStyleTests: XCTestCase {

    // MARK: - ButtonStyleType

    func testButtonStyleTypeEquatable() {
        XCTAssertEqual(ButtonStyleType.automatic, ButtonStyleType.automatic)
        XCTAssertEqual(ButtonStyleType.plain, ButtonStyleType.plain)
        XCTAssertNotEqual(ButtonStyleType.plain, ButtonStyleType.bordered)
        XCTAssertNotEqual(ButtonStyleType.bordered, ButtonStyleType.borderedProminent)
    }

    func testButtonStyleEnvironmentDefault() {
        let env = EnvironmentValues()
        XCTAssertEqual(env.buttonStyle, .automatic)
    }

    func testButtonStyleEnvironmentSet() {
        var env = EnvironmentValues()
        env.buttonStyle = .borderedProminent
        XCTAssertEqual(env.buttonStyle, .borderedProminent)
    }

    func testButtonStyleModifierWraps() {
        let view = Text("Tap").buttonStyle(.plain)
        XCTAssertEqual(view.style, .plain)
        XCTAssertEqual(view.content.content, "Tap")
    }

    // MARK: - ToggleStyleType

    func testToggleStyleTypeEquatable() {
        XCTAssertEqual(ToggleStyleType.automatic, ToggleStyleType.automatic)
        XCTAssertEqual(ToggleStyleType.checkbox, ToggleStyleType.checkbox)
        XCTAssertNotEqual(ToggleStyleType.checkbox, ToggleStyleType.switch)
    }

    func testToggleStyleEnvironmentDefault() {
        let env = EnvironmentValues()
        XCTAssertEqual(env.toggleStyle, .automatic)
    }

    func testToggleStyleEnvironmentSet() {
        var env = EnvironmentValues()
        env.toggleStyle = .switch
        XCTAssertEqual(env.toggleStyle, .switch)
    }

    func testToggleStyleModifierWraps() {
        let view = Text("On").toggleStyle(.switch)
        XCTAssertEqual(view.style, .switch)
    }

    // MARK: - TextFieldStyleType

    func testTextFieldStyleTypeEquatable() {
        XCTAssertEqual(TextFieldStyleType.automatic, TextFieldStyleType.automatic)
        XCTAssertEqual(TextFieldStyleType.plain, TextFieldStyleType.plain)
        XCTAssertNotEqual(TextFieldStyleType.plain, TextFieldStyleType.roundedBorder)
    }

    func testTextFieldStyleEnvironmentDefault() {
        let env = EnvironmentValues()
        XCTAssertEqual(env.textFieldStyle, .automatic)
    }

    func testTextFieldStyleEnvironmentSet() {
        var env = EnvironmentValues()
        env.textFieldStyle = .roundedBorder
        XCTAssertEqual(env.textFieldStyle, .roundedBorder)
    }

    func testTextFieldStyleModifierWraps() {
        let view = Text("Name").textFieldStyle(.plain)
        XCTAssertEqual(view.style, .plain)
    }

    // MARK: - Style propagation

    func testButtonStylePropagatesThroughEnvironment() {
        var env = EnvironmentValues()
        env.buttonStyle = .bordered
        let modified = env.setting(\.buttonStyle, to: .plain)
        XCTAssertEqual(modified.buttonStyle, .plain)
        // Original unchanged
        XCTAssertEqual(env.buttonStyle, .bordered)
    }

    // MARK: - Chaining

    func testStyleModifiersChain() {
        let view = VStack {
            Text("Hello")
        }
        .buttonStyle(.bordered)
        .toggleStyle(.switch)
        .textFieldStyle(.roundedBorder)

        XCTAssertEqual(view.style, .roundedBorder)
        XCTAssertEqual(view.content.style, .switch)
        XCTAssertEqual(view.content.content.style, .bordered)
    }
}
