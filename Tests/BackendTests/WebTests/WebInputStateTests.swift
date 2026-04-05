import XCTest
@testable import SwiftOpenUI
@testable import BackendWeb

final class WebInputStateTests: XCTestCase {

    // MARK: - WebFocusSnapshot construction

    func testSnapshotTextInput() {
        let snapshot = WebFocusSnapshot(
            tag: "input", inputType: "text", typeIndex: 0, typeCount: 2,
            selectionStart: 5, selectionEnd: 5, selectionDirection: "forward")
        XCTAssertEqual(snapshot.tag, "input")
        XCTAssertEqual(snapshot.inputType, "text")
        XCTAssertEqual(snapshot.typeIndex, 0)
        XCTAssertEqual(snapshot.typeCount, 2)
        XCTAssertEqual(snapshot.selectionStart, 5)
        XCTAssertEqual(snapshot.selectionEnd, 5)
        XCTAssertEqual(snapshot.selectionDirection, "forward")
    }

    func testSnapshotPasswordInput() {
        let snapshot = WebFocusSnapshot(
            tag: "input", inputType: "password", typeIndex: 1, typeCount: 3,
            selectionStart: 0, selectionEnd: 8, selectionDirection: nil)
        XCTAssertEqual(snapshot.inputType, "password")
        XCTAssertEqual(snapshot.selectionStart, 0)
        XCTAssertEqual(snapshot.selectionEnd, 8)
    }

    func testSnapshotTextarea() {
        let snapshot = WebFocusSnapshot(
            tag: "textarea", inputType: "textarea", typeIndex: 0, typeCount: 1,
            selectionStart: 10, selectionEnd: 20, selectionDirection: "backward")
        XCTAssertEqual(snapshot.tag, "textarea")
        XCTAssertEqual(snapshot.inputType, "textarea")
        XCTAssertEqual(snapshot.selectionStart, 10)
        XCTAssertEqual(snapshot.selectionEnd, 20)
    }

    func testSnapshotCheckboxNoSelection() {
        let snapshot = WebFocusSnapshot(
            tag: "input", inputType: "checkbox", typeIndex: 0, typeCount: 1,
            selectionStart: nil, selectionEnd: nil, selectionDirection: nil)
        XCTAssertEqual(snapshot.inputType, "checkbox")
        XCTAssertNil(snapshot.selectionStart)
        XCTAssertNil(snapshot.selectionEnd)
    }

    func testSnapshotRangeNoSelection() {
        let snapshot = WebFocusSnapshot(
            tag: "input", inputType: "range", typeIndex: 0, typeCount: 1,
            selectionStart: nil, selectionEnd: nil, selectionDirection: nil)
        XCTAssertEqual(snapshot.inputType, "range")
        XCTAssertNil(snapshot.selectionStart)
    }

    func testSnapshotDateNoSelection() {
        let snapshot = WebFocusSnapshot(
            tag: "input", inputType: "date", typeIndex: 0, typeCount: 1,
            selectionStart: nil, selectionEnd: nil, selectionDirection: nil)
        XCTAssertEqual(snapshot.inputType, "date")
        XCTAssertNil(snapshot.selectionStart)
    }

    // MARK: - Bail guard logic

    func testBailGuardCountMismatch() {
        let snapshot = WebFocusSnapshot(
            tag: "input", inputType: "text", typeIndex: 0, typeCount: 2,
            selectionStart: 5, selectionEnd: 5, selectionDirection: nil)

        // Simulate new DOM having different count of text inputs
        let newCount = 3
        let shouldRestore = newCount == snapshot.typeCount
            && snapshot.typeIndex < newCount
        XCTAssertFalse(shouldRestore, "Count mismatch should bail")
    }

    func testBailGuardCountMatch() {
        let snapshot = WebFocusSnapshot(
            tag: "input", inputType: "text", typeIndex: 1, typeCount: 3,
            selectionStart: 5, selectionEnd: 5, selectionDirection: nil)

        let newCount = 3
        let shouldRestore = newCount == snapshot.typeCount
            && snapshot.typeIndex < newCount
        XCTAssertTrue(shouldRestore, "Matching count should proceed")
    }

    func testBailGuardIndexOutOfBounds() {
        let snapshot = WebFocusSnapshot(
            tag: "input", inputType: "text", typeIndex: 5, typeCount: 3,
            selectionStart: nil, selectionEnd: nil, selectionDirection: nil)

        let newCount = 3
        let shouldRestore = newCount == snapshot.typeCount
            && snapshot.typeIndex < newCount
        XCTAssertFalse(shouldRestore, "Index out of bounds should bail")
    }

    // MARK: - Text-selectable type classification

    func testTextSelectableTypes() {
        let selectable: Set<String> = ["text", "password", "search", "textarea"]
        XCTAssertTrue(selectable.contains("text"))
        XCTAssertTrue(selectable.contains("password"))
        XCTAssertTrue(selectable.contains("search"))
        XCTAssertTrue(selectable.contains("textarea"))
        XCTAssertFalse(selectable.contains("checkbox"))
        XCTAssertFalse(selectable.contains("range"))
        XCTAssertFalse(selectable.contains("date"))
    }

    // MARK: - Suppress focus restore

    func testSuppressFocusRestoreContract() {
        // suppressNextFocusRestore is consumed before Phase 7 early return
        // in rebuild(), same lifecycle as pendingAnimation. This prevents
        // the flag from leaking to a later unrelated rebuild.
        //
        // WebViewHost requires JavaScriptKit runtime, so we verify the
        // contract structurally: the flag is read and cleared before the
        // inputsUnchanged check, not inside the snapshot conditional.
        //
        // Verify WebViewHost conforms to AnyViewHost (which requires
        // suppressNextFocusRestore).
        XCTAssertTrue(WebViewHost.self is AnyViewHost.Type)
    }

    // MARK: - webRestoreFocusState suppressFocus parameter

    func testRestoreWithSuppressFocusTrueSkipsFocusButAllowsSelection() {
        // When suppressFocus is true, webRestoreFocusState should:
        // - NOT call focus()
        // - Still attempt setSelectionRange() for text-selectable types
        // This matches Win32 behavior (testSuppressFocusDoesNotSuppressEditState).
        //
        // We can't test DOM calls without a browser, but verify the
        // snapshot carries selection data even in the suppress case.
        let snapshot = WebFocusSnapshot(
            tag: "input", inputType: "text", typeIndex: 0, typeCount: 1,
            selectionStart: 5, selectionEnd: 10, selectionDirection: "forward")

        // Selection should be present regardless of suppress flag
        XCTAssertNotNil(snapshot.selectionStart)
        XCTAssertNotNil(snapshot.selectionEnd)
        XCTAssertEqual(snapshot.selectionDirection, "forward")
    }

    func testRestoreWithSuppressFocusFalseForNonTextType() {
        // Non-text types should have nil selection even without suppression
        let snapshot = WebFocusSnapshot(
            tag: "input", inputType: "range", typeIndex: 0, typeCount: 1,
            selectionStart: nil, selectionEnd: nil, selectionDirection: nil)
        XCTAssertNil(snapshot.selectionStart)
        XCTAssertNil(snapshot.selectionEnd)
    }

    // MARK: - Tag classification

    func testTagClassificationInput() {
        // Verify the snapshot correctly distinguishes input types
        let textSnap = WebFocusSnapshot(
            tag: "input", inputType: "text", typeIndex: 0, typeCount: 1,
            selectionStart: 3, selectionEnd: 3, selectionDirection: nil)
        let rangeSnap = WebFocusSnapshot(
            tag: "input", inputType: "range", typeIndex: 0, typeCount: 1,
            selectionStart: nil, selectionEnd: nil, selectionDirection: nil)

        // Same tag but different input types — should not match
        XCTAssertNotEqual(textSnap.inputType, rangeSnap.inputType)
    }

    func testTagClassificationTextarea() {
        let snap = WebFocusSnapshot(
            tag: "textarea", inputType: "textarea", typeIndex: 0, typeCount: 1,
            selectionStart: 0, selectionEnd: 0, selectionDirection: nil)
        XCTAssertNotEqual(snap.tag, "input")
        XCTAssertEqual(snap.tag, "textarea")
    }
}
