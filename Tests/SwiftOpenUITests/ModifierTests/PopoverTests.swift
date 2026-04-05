import XCTest
@testable import SwiftOpenUI

final class PopoverTests: XCTestCase {

    // MARK: - Modifier wrapping

    func testPopoverWrapsContent() {
        var presented = false
        let view = Text("Anchor").popover(isPresented: .init(
            get: { presented }, set: { presented = $0 }
        )) {
            Text("Popover content")
        }
        XCTAssertEqual(view.content.content, "Anchor")
        XCTAssertFalse(view.isPresented.wrappedValue)
    }

    func testPopoverStoresBinding() {
        var presented = true
        let view = Text("Anchor").popover(isPresented: .init(
            get: { presented }, set: { presented = $0 }
        )) {
            Text("Content")
        }
        XCTAssertTrue(view.isPresented.wrappedValue)
    }

    func testPopoverBindingCanBeToggled() {
        var presented = false
        let binding = Binding<Bool>(
            get: { presented }, set: { presented = $0 }
        )
        let view = Text("Anchor").popover(isPresented: binding) {
            Text("Content")
        }
        XCTAssertFalse(view.isPresented.wrappedValue)

        presented = true
        XCTAssertTrue(view.isPresented.wrappedValue)
    }

    // MARK: - Chaining

    func testPopoverChainedWithFrame() {
        var presented = false
        let view = Text("Anchor")
            .frame(width: 100, height: 50)
            .popover(isPresented: .init(
                get: { presented }, set: { presented = $0 }
            )) {
                Text("Popover")
            }
        XCTAssertEqual(view.content.width, 100)
    }

    func testPopoverChainedWithPadding() {
        var presented = false
        let view = Text("Anchor")
            .padding()
            .popover(isPresented: .init(
                get: { presented }, set: { presented = $0 }
            )) {
                Text("Popover")
            }
        _ = view // compiles
    }
}
