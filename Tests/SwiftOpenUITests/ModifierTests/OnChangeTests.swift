import XCTest
@testable import SwiftOpenUI

final class OnChangeTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearOnChangeState()
    }

    // MARK: - Modifier wrapping

    func testOnChangeWrapsContent() {
        var fired = false
        let view = Text("Hello").onChange(of: 1) { _ in fired = true }
        XCTAssertEqual(view.content.content, "Hello")
        XCTAssertEqual(view.value, 1)
        XCTAssertFalse(fired)
    }

    // MARK: - Value tracking

    func testFirstRenderDoesNotFire() {
        var fired = false
        // First render — no previous value stored, should not fire
        onChangeCheckAndFire(value: "hello") { _ in fired = true }
        XCTAssertFalse(fired)
    }

    func testSecondRenderWithSameValueDoesNotFire() {
        var fireCount = 0
        // First render — stores value 42 at key 0
        onChangeCheckAndFire(value: 42) { _ in fireCount += 1 }
        // Second render — reset counter, same value at key 0
        resetOnChangeTracking()
        onChangeCheckAndFire(value: 42) { _ in fireCount += 1 }
        XCTAssertEqual(fireCount, 0)
    }

    func testSecondRenderWithDifferentValueFires() {
        var received: Int?
        // First render
        onChangeCheckAndFire(value: 1) { _ in }
        // Second render, different value
        resetOnChangeTracking()
        onChangeCheckAndFire(value: 2) { received = $0 }
        XCTAssertEqual(received, 2)
    }

    func testMultipleOnChangeTrackIndependently() {
        var firedA = false
        var firedB = false
        // First render — two onChange at keys 0 and 1
        onChangeCheckAndFire(value: "a") { _ in }
        onChangeCheckAndFire(value: "x") { _ in }
        // Second render — change only the first
        resetOnChangeTracking()
        onChangeCheckAndFire(value: "b") { _ in firedA = true }
        onChangeCheckAndFire(value: "x") { _ in firedB = true }
        XCTAssertTrue(firedA, "First onChange should fire — value changed from a to b")
        XCTAssertFalse(firedB, "Second onChange should not fire — value unchanged")
    }

    func testCounterResetsPerRenderPass() {
        let key1 = onChangeCheckAndFire(value: 1) { _ in }
        XCTAssertEqual(key1, 0)
        let key2 = onChangeCheckAndFire(value: 2) { _ in }
        XCTAssertEqual(key2, 1)
        resetOnChangeTracking()
        let key3 = onChangeCheckAndFire(value: 3) { _ in }
        XCTAssertEqual(key3, 0, "Reset should restart counter at 0")
    }

    // MARK: - Equatable comparison

    func testOnChangeUsesEquatable() {
        struct Pair: Equatable {
            let x: Int
            let y: Int
        }
        var received: Pair?
        onChangeCheckAndFire(value: Pair(x: 1, y: 2)) { _ in }
        resetOnChangeTracking()
        onChangeCheckAndFire(value: Pair(x: 1, y: 3)) { received = $0 }
        XCTAssertEqual(received, Pair(x: 1, y: 3))
    }

    // MARK: - Two-arg form

    func testOnChangeTwoArgWrapsContent() {
        let view = Text("Hello").onChange(of: 1) { _, _ in }
        XCTAssertEqual(view.content.content, "Hello")
        XCTAssertEqual(view.value, 1)
    }

    func testOnChangeTwoArgFiresWithOldAndNewValue() {
        var received: (Int, Int)?

        // First render — seeds key 0 with value 10, no fire
        onChangeCheckAndFireTwoArg(value: 10) { _, _ in }
        // Second render — same key, changed value, should fire with (10, 20)
        resetOnChangeTracking()
        onChangeCheckAndFireTwoArg(value: 20) { old, new in
            received = (old, new)
        }

        XCTAssertEqual(received?.0, 10)
        XCTAssertEqual(received?.1, 20)
    }

    func testOnChangeTwoArgDoesNotFireWhenUnchanged() {
        var fired = false

        onChangeCheckAndFireTwoArg(value: "a") { _, _ in }
        resetOnChangeTracking()
        onChangeCheckAndFireTwoArg(value: "a") { _, _ in fired = true }

        XCTAssertFalse(fired)
    }
}
