import XCTest
@testable import SwiftOpenUI
@testable import BackendWeb

final class WebStyleTests: XCTestCase {

    // MARK: - Style environment defaults

    func testButtonStyleDefaultIsAutomatic() {
        let env = EnvironmentValues()
        XCTAssertEqual(env.buttonStyle, .automatic)
    }

    func testToggleStyleDefaultIsAutomatic() {
        let env = EnvironmentValues()
        XCTAssertEqual(env.toggleStyle, .automatic)
    }

    func testTextFieldStyleDefaultIsAutomatic() {
        let env = EnvironmentValues()
        XCTAssertEqual(env.textFieldStyle, .automatic)
    }

    // MARK: - Style environment propagation

    func testButtonStylePropagatesThroughEnvironment() {
        var env = EnvironmentValues()
        env.buttonStyle = .borderedProminent
        XCTAssertEqual(env.buttonStyle, .borderedProminent)
    }

    func testToggleStylePropagatesThroughEnvironment() {
        var env = EnvironmentValues()
        env.toggleStyle = .switch
        XCTAssertEqual(env.toggleStyle, .switch)
    }

    func testTextFieldStylePropagatesThroughEnvironment() {
        var env = EnvironmentValues()
        env.textFieldStyle = .roundedBorder
        XCTAssertEqual(env.textFieldStyle, .roundedBorder)
    }

    // MARK: - Modifier wrapping

    func testButtonStyleModifierWraps() {
        let view = Text("Tap").buttonStyle(.plain)
        XCTAssertEqual(view.style, .plain)
    }

    func testToggleStyleModifierWraps() {
        let view = Text("On").toggleStyle(.switch)
        XCTAssertEqual(view.style, .switch)
    }

    func testTextFieldStyleModifierWraps() {
        let view = Text("Name").textFieldStyle(.roundedBorder)
        XCTAssertEqual(view.style, .roundedBorder)
    }

    // MARK: - Chaining

    func testStyleModifiersChain() {
        let view = VStack { Text("Hello") }
            .buttonStyle(.bordered)
            .toggleStyle(.checkbox)
            .textFieldStyle(.plain)
        XCTAssertEqual(view.style, .plain)
        XCTAssertEqual(view.content.style, .checkbox)
        XCTAssertEqual(view.content.content.style, .bordered)
    }
}
