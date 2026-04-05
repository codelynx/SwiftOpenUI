import XCTest
@testable import SwiftOpenUI

final class ContextMenuTests: XCTestCase {

    // MARK: - Modifier wrapping

    func testContextMenuWrapsContent() {
        let view = Text("Hello").contextMenu {
            MenuItem("Copy") {}
        }
        XCTAssertEqual(view.content.content, "Hello")
        XCTAssertEqual(view.menuElements.count, 1)
    }

    func testContextMenuMultipleItems() {
        let view = Text("Hello").contextMenu {
            MenuItem("Copy") {}
            MenuDivider()
            MenuItem("Delete") {}
        }
        XCTAssertEqual(view.menuElements.count, 3)
    }

    func testContextMenuWithSubmenu() {
        let view = Text("Hello").contextMenu {
            MenuItem("Copy") {}
            SubMenu("Share") {
                MenuItem("Email") {}
                MenuItem("Message") {}
            }
        }
        XCTAssertEqual(view.menuElements.count, 2)
        if case .submenu(let label, let children) = view.menuElements[1] {
            XCTAssertEqual(label, "Share")
            XCTAssertEqual(children.count, 2)
        } else {
            XCTFail("Expected submenu")
        }
    }

    func testContextMenuItemLabels() {
        let view = Text("Hello").contextMenu {
            MenuItem("Cut") {}
            MenuItem("Copy") {}
            MenuItem("Paste") {}
        }
        if case .item(let label, _) = view.menuElements[0] {
            XCTAssertEqual(label, "Cut")
        } else {
            XCTFail("Expected item")
        }
        if case .item(let label, _) = view.menuElements[2] {
            XCTAssertEqual(label, "Paste")
        } else {
            XCTFail("Expected item")
        }
    }

    func testContextMenuDivider() {
        let view = Text("Hello").contextMenu {
            MenuItem("A") {}
            MenuDivider()
            MenuItem("B") {}
        }
        if case .divider = view.menuElements[1] {
            // OK
        } else {
            XCTFail("Expected divider")
        }
    }

    // MARK: - Chaining

    func testContextMenuChainedWithOtherModifiers() {
        let view = Text("Hello")
            .padding()
            .contextMenu {
                MenuItem("Copy") {}
            }
        XCTAssertEqual(view.menuElements.count, 1)
    }
}
