import XCTest
@testable import SwiftOpenUI

/// Tests for the `@Bindable` property wrapper that projects bindings
/// from an `@Observable` (or any reference-typed) class's mutable
/// properties.
final class BindableTests: XCTestCase {

    /// A plain class used to exercise `@Bindable` without requiring
    /// the `@Observable` macro — `@Bindable` is constrained only to
    /// `AnyObject`, and the reactivity story belongs to the view
    /// host, not to the wrapper itself.
    final class Model {
        var count: Int
        var title: String

        init(count: Int = 0, title: String = "") {
            self.count = count
            self.title = title
        }
    }

    func testBindableExposesObject() {
        let model = Model(count: 5, title: "alpha")
        let bindable = Bindable(wrappedValue: model)

        XCTAssertTrue(bindable.wrappedValue === model)
        XCTAssertEqual(bindable.wrappedValue.count, 5)
    }

    func testProjectedValueReturnsSelf() {
        let model = Model()
        let bindable = Bindable(wrappedValue: model)
        // projectedValue returns the Bindable itself so `$bindable.x`
        // reaches the dynamic-member subscript.
        XCTAssertTrue(bindable.projectedValue.wrappedValue === model)
    }

    func testDynamicMemberSubscriptBuildsBindingThatReads() {
        let model = Model(count: 7, title: "alpha")
        let bindable = Bindable(wrappedValue: model)

        let countBinding: Binding<Int> = bindable.count
        XCTAssertEqual(countBinding.wrappedValue, 7)
    }

    func testDynamicMemberSubscriptBuildsBindingThatWrites() {
        let model = Model(count: 0, title: "alpha")
        let bindable = Bindable(wrappedValue: model)

        let countBinding: Binding<Int> = bindable.count
        countBinding.wrappedValue = 42

        XCTAssertEqual(model.count, 42, "Write should flow through to the wrapped object")
    }

    func testBindingTracksLatestValueAcrossMutations() {
        let model = Model(count: 1, title: "")
        let bindable = Bindable(wrappedValue: model)

        let binding: Binding<Int> = bindable.count
        model.count = 99
        XCTAssertEqual(binding.wrappedValue, 99, "Binding reads should reflect mutations through the object itself")
    }

    func testMultipleBindingsFromSameObjectAreIndependent() {
        let model = Model(count: 0, title: "start")
        let bindable = Bindable(wrappedValue: model)

        let countBinding: Binding<Int> = bindable.count
        let titleBinding: Binding<String> = bindable.title

        countBinding.wrappedValue = 3
        titleBinding.wrappedValue = "done"

        XCTAssertEqual(model.count, 3)
        XCTAssertEqual(model.title, "done")
    }
}
