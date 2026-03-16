import XCTest
@testable import SwiftOpenUI

final class StateTests: XCTestCase {

    // MARK: - @State

    func testStateInitialValue() {
        let state = State<Int>(wrappedValue: 42)
        XCTAssertEqual(state.wrappedValue, 42)
    }

    func testStateSetValue() {
        let state = State<Int>(wrappedValue: 0)
        state.wrappedValue = 99
        XCTAssertEqual(state.wrappedValue, 99)
    }

    func testStateProjectedValueReturnsBinding() {
        let state = State<String>(wrappedValue: "hello")
        let binding = state.projectedValue
        XCTAssertEqual(binding.wrappedValue, "hello")
        binding.wrappedValue = "world"
        XCTAssertEqual(state.wrappedValue, "world")
    }

    func testStateStorageSharedAcrossCopies() {
        let state = State<Int>(wrappedValue: 10)
        let copy = state
        state.wrappedValue = 20
        XCTAssertEqual(copy.wrappedValue, 20, "Copies should share storage")
    }

    // MARK: - @Binding

    func testBindingGetSet() {
        var value = 5
        let binding = Binding<Int>(get: { value }, set: { value = $0 })
        XCTAssertEqual(binding.wrappedValue, 5)
        binding.wrappedValue = 10
        XCTAssertEqual(value, 10)
    }

    func testBindingConstant() {
        let binding = Binding<String>.constant("fixed")
        XCTAssertEqual(binding.wrappedValue, "fixed")
        binding.wrappedValue = "changed"
        XCTAssertEqual(binding.wrappedValue, "fixed", "Constant binding should not change")
    }

    func testBindingProjectedValue() {
        let binding = Binding<Int>(get: { 1 }, set: { _ in })
        let projected = binding.projectedValue
        XCTAssertEqual(projected.wrappedValue, 1)
    }

    // MARK: - @Published / ObservableObject

    class Counter: SwiftOpenUI.ObservableObject {
        @SwiftOpenUI.Published var count = 0
    }

    func testPublishedInitialValue() {
        let counter = Counter()
        XCTAssertEqual(counter.count, 0)
    }

    func testPublishedSetValue() {
        let counter = Counter()
        counter.count = 42
        XCTAssertEqual(counter.count, 42)
    }

    func testPublishedNotifiesObservers() {
        let counter = Counter()
        let expectation = XCTestExpectation(description: "Observer notified")
        let token = ObjectIdentifier(self)
        let published = Mirror(reflecting: counter).children.first { $0.value is AnyPublishedProvider }
        let provider = published!.value as! AnyPublishedProvider
        provider.anyPublished.setObserver(token: token) {
            expectation.fulfill()
        }
        counter.count = 1
        wait(for: [expectation], timeout: 1.0)
    }

    func testPublishedReplacesObserverWithSameToken() {
        let counter = Counter()
        let token = ObjectIdentifier(self)
        var callCount = 0

        let published = Mirror(reflecting: counter).children.first { $0.value is AnyPublishedProvider }
        let provider = published!.value as! AnyPublishedProvider

        // First observer
        provider.anyPublished.setObserver(token: token) { callCount += 100 }
        // Replace with second observer using same token
        provider.anyPublished.setObserver(token: token) { callCount += 1 }

        counter.count = 1
        XCTAssertEqual(callCount, 1, "Only the latest observer should fire")
    }

    // MARK: - Superclass @Published wiring

    class BaseModel: SwiftOpenUI.ObservableObject {
        @SwiftOpenUI.Published var baseProp = "base"
    }

    class DerivedModel: BaseModel {
        @SwiftOpenUI.Published var derivedProp = "derived"
    }

    func testWirePublishedWalksSuperclass() {
        let model = DerivedModel()
        var notifications = 0

        class MockHost: AnyViewHost {
            var onRebuild: (() -> Void)?
            func scheduleRebuild() { onRebuild?() }
            func suppressNextFocusRestore() {}
        }

        let host = MockHost()
        host.onRebuild = { notifications += 1 }

        let observed = ObservedObject<DerivedModel>(wrappedValue: model)
        observed.storage.host = host

        model.derivedProp = "changed"
        XCTAssertEqual(notifications, 1, "Derived @Published should trigger rebuild")

        model.baseProp = "changed"
        XCTAssertEqual(notifications, 2, "Inherited @Published should also trigger rebuild")
    }

    // MARK: - @StateObject

    func testStateObjectLazyCreation() {
        var created = false
        let stateObj = StateObject<Counter>(wrappedValue: {
            created = true
            return Counter()
        }())
        XCTAssertFalse(created == false && stateObj.wrappedValue.count == 0 ? false : true)
        // Access forces creation
        _ = stateObj.wrappedValue
        XCTAssertEqual(stateObj.wrappedValue.count, 0)
    }

    func testStateObjectReturnsSameInstance() {
        let stateObj = StateObject<Counter>(wrappedValue: Counter())
        let first = stateObj.wrappedValue
        let second = stateObj.wrappedValue
        XCTAssertTrue(first === second)
    }

    // MARK: - @FocusState

    func testFocusStateBoolDefault() {
        let focus = FocusState<Bool>()
        XCTAssertEqual(focus.wrappedValue, false)
    }

    func testFocusStateOptionalDefault() {
        enum Field { case name, email }
        let focus = FocusState<Field?>()
        XCTAssertNil(focus.storage.value as Any?)
    }
}
