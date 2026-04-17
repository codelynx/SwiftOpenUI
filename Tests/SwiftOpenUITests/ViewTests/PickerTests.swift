import XCTest
@testable import SwiftOpenUI

/// Tests for the SwiftUI-shaped generic Picker initializer that
/// takes a `@ViewBuilder content:` with `.tag(_:)`-annotated children.
/// The existing Int-indexed initializers are exercised elsewhere;
/// these focus on the new content-walking path.
final class PickerTests: XCTestCase {

    private enum Action: Hashable, CaseIterable {
        case snapshot, compare, sync
    }

    // MARK: - Basic extraction from a ForEach

    func testGenericPickerExtractsOptionsFromForEach() {
        var selected = Action.snapshot
        let binding = Binding(
            get: { selected },
            set: { selected = $0 }
        )

        let picker = Picker("Action", selection: binding) {
            ForEach(Action.allCases, id: \.self) { action in
                Text(String(describing: action)).tag(action)
            }
        }

        XCTAssertEqual(picker.options, ["snapshot", "compare", "sync"])
        XCTAssertEqual(picker.selected, 0)
    }

    func testGenericPickerSelectedReflectsCurrentValue() {
        var selected = Action.compare
        let binding = Binding(
            get: { selected },
            set: { selected = $0 }
        )

        let picker = Picker("Action", selection: binding) {
            ForEach(Action.allCases, id: \.self) { action in
                Text(String(describing: action)).tag(action)
            }
        }

        XCTAssertEqual(picker.selected, 1) // .compare is index 1
    }

    func testGenericPickerOnChangedWritesThroughBinding() {
        var selected = Action.snapshot
        let binding = Binding(
            get: { selected },
            set: { selected = $0 }
        )

        let picker = Picker("Action", selection: binding) {
            ForEach(Action.allCases, id: \.self) { action in
                Text(String(describing: action)).tag(action)
            }
        }

        picker.onChanged?(2)
        XCTAssertEqual(selected, .sync)
    }

    // MARK: - Explicit inline options (TupleView)

    func testGenericPickerExtractsOptionsFromInlineContent() {
        var selected = "a"
        let binding = Binding(
            get: { selected },
            set: { selected = $0 }
        )

        let picker = Picker("Choice", selection: binding) {
            Text("Option A").tag("a")
            Text("Option B").tag("b")
            Text("Option C").tag("c")
        }

        XCTAssertEqual(picker.options, ["Option A", "Option B", "Option C"])
        XCTAssertEqual(picker.selected, 0)

        picker.onChanged?(1)
        XCTAssertEqual(selected, "b")
    }

    // MARK: - Defensive behavior

    func testGenericPickerUnknownSelectionFallsBackToZero() {
        var selected = "unknown-value"
        let binding = Binding(
            get: { selected },
            set: { selected = $0 }
        )

        let picker = Picker("Choice", selection: binding) {
            Text("A").tag("a")
            Text("B").tag("b")
        }

        // No tag matches "unknown-value"; guard against out-of-range
        // `selected` by defaulting to 0 rather than crashing.
        XCTAssertEqual(picker.selected, 0)
    }

    // MARK: - pickerStyle + labelsHidden compose

    func testGenericPickerStyleChainSurvivesPickerStyle() {
        var selected = Action.snapshot
        let binding = Binding(
            get: { selected },
            set: { selected = $0 }
        )

        let styled = Picker("Action", selection: binding) {
            ForEach(Action.allCases, id: \.self) { action in
                Text(String(describing: action)).tag(action)
            }
        }
        .pickerStyle(.segmented)

        XCTAssertEqual(styled.style, .segmented)
        XCTAssertEqual(styled.options, ["snapshot", "compare", "sync"])
    }

    func testLabelsHiddenWrapsContent() {
        let hidden = Text("hello").labelsHidden()
        XCTAssertNotNil(hidden as LabelsHiddenView<Text>)
    }
}
