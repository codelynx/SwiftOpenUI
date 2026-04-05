import XCTest
@testable import SwiftOpenUI

final class OnSubmitTests: XCTestCase {

    // MARK: - OnSubmitView

    func testOnSubmitWrapsContent() {
        var submitted = false
        let view = Text("Hello").onSubmit { submitted = true }
        XCTAssertEqual(view.content.content, "Hello")
        XCTAssertEqual(view.triggers, .text)
        XCTAssertFalse(submitted)
    }

    func testOnSubmitSearchTrigger() {
        let view = Text("Hello").onSubmit(of: .search) {}
        XCTAssertEqual(view.triggers, .search)
    }

    // MARK: - SubmitAction

    func testSubmitActionCallable() {
        var called = false
        let action = SubmitAction { called = true }
        action()
        XCTAssertTrue(called)
    }

    // MARK: - Environment

    func testSubmitActionEnvironmentDefault() {
        let env = EnvironmentValues()
        XCTAssertNil(env.submitAction)
    }

    func testSubmitActionEnvironmentSet() {
        var env = EnvironmentValues()
        var called = false
        env.submitAction = SubmitAction { called = true }
        env.submitAction?()
        XCTAssertTrue(called)
    }

    // MARK: - Chaining

    func testOnSubmitChainedWithTextField() {
        var submitted = false
        let binding = Binding<String>(get: { "" }, set: { _ in })
        let view = TextField("Name", text: binding)
            .onSubmit { submitted = true }
        XCTAssertEqual(view.triggers, .text)
        XCTAssertFalse(submitted)
    }
}
