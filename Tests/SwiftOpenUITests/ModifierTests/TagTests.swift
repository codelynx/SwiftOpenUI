import XCTest
@testable import SwiftOpenUI

final class TagTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearCurrentTagValue()
    }

    // MARK: - TagView

    func testTagWrapsContent() {
        let view = Text("Hello").tag(42)
        XCTAssertEqual(view.tagValue, 42)
        XCTAssertEqual(view.content.content, "Hello")
    }

    func testTagStringValue() {
        let view = Text("Hello").tag("option-a")
        XCTAssertEqual(view.tagValue, "option-a")
    }

    func testTagEnumValue() {
        enum Tab: Hashable { case home, settings }
        let view = Text("Home").tag(Tab.home)
        XCTAssertEqual(view.tagValue, Tab.home)
    }

    // MARK: - Tag value propagation

    func testSetAndGetTagValue() {
        setCurrentTagValue(42)
        XCTAssertEqual(getCurrentTagValue(), AnyHashable(42))
        clearCurrentTagValue()
    }

    func testClearTagValue() {
        setCurrentTagValue("test")
        clearCurrentTagValue()
        XCTAssertNil(getCurrentTagValue())
    }

    func testTagValueOverwrite() {
        setCurrentTagValue(1)
        setCurrentTagValue(2)
        XCTAssertEqual(getCurrentTagValue(), AnyHashable(2))
        clearCurrentTagValue()
    }

    // MARK: - Chaining

    func testTagWithOtherModifiers() {
        let view = Text("Hello")
            .padding()
            .tag(99)
        XCTAssertEqual(view.tagValue, 99)
    }
}
