import XCTest
@testable import SwiftOpenUI

final class NavigationSplitViewTests: XCTestCase {

    // MARK: - Two-column

    func testTwoColumnDefault() {
        let split = NavigationSplitView {
            Text("Sidebar")
        } detail: {
            Text("Detail")
        }
        XCTAssertFalse(split.hasContentColumn)
        XCTAssertEqual(split.sidebarWidth, 250)
        XCTAssertNil(split.columnVisibility)
    }

    func testTwoColumnCustomWidth() {
        let split = NavigationSplitView(sidebarWidth: 300) {
            Text("Sidebar")
        } detail: {
            Text("Detail")
        }
        XCTAssertEqual(split.sidebarWidth, 300)
        XCTAssertFalse(split.hasContentColumn)
    }

    func testTwoColumnWithVisibility() {
        let split = NavigationSplitView(columnVisibility: .constant(.all)) {
            Text("Sidebar")
        } detail: {
            Text("Detail")
        }
        XCTAssertNotNil(split.columnVisibility)
        XCTAssertFalse(split.hasContentColumn)
    }

    // MARK: - Three-column

    func testThreeColumn() {
        let split = NavigationSplitView {
            Text("Sidebar")
        } content: {
            Text("Content")
        } detail: {
            Text("Detail")
        }
        XCTAssertTrue(split.hasContentColumn)
        XCTAssertEqual(split.sidebarWidth, 200)
    }

    func testThreeColumnWithVisibility() {
        let split = NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
            Text("Sidebar")
        } content: {
            Text("Content")
        } detail: {
            Text("Detail")
        }
        XCTAssertTrue(split.hasContentColumn)
        XCTAssertNotNil(split.columnVisibility)
    }

    // MARK: - Visibility enum

    func testVisibilityEnum() {
        let cases: [NavigationSplitViewVisibility] = [.automatic, .all, .doubleColumn, .detailOnly]
        XCTAssertEqual(cases.count, 4)
    }

    // MARK: - Column width modifier

    func testColumnWidthIdeal() {
        let view = Text("Sidebar")
            .navigationSplitViewColumnWidth(min: 150, ideal: 250, max: 400)
        XCTAssertEqual(view.columnMinWidth, 150)
        XCTAssertEqual(view.columnIdealWidth, 250)
        XCTAssertEqual(view.columnMaxWidth, 400)
    }

    func testColumnWidthFixed() {
        let view = Text("Sidebar").navigationSplitViewColumnWidth(200)
        XCTAssertEqual(view.columnMinWidth, 200)
        XCTAssertEqual(view.columnIdealWidth, 200)
        XCTAssertEqual(view.columnMaxWidth, 200)
    }

    func testColumnWidthIdealOnly() {
        let view = Text("Content").navigationSplitViewColumnWidth(ideal: 300)
        XCTAssertNil(view.columnMinWidth)
        XCTAssertEqual(view.columnIdealWidth, 300)
        XCTAssertNil(view.columnMaxWidth)
    }

    func testColumnWidthProvider() {
        let view = Text("Test").navigationSplitViewColumnWidth(min: 100, ideal: 200, max: 300)
        let provider = view as NavigationSplitViewColumnWidthProvider
        XCTAssertEqual(provider.columnMinWidth, 100)
        XCTAssertEqual(provider.columnIdealWidth, 200)
        XCTAssertEqual(provider.columnMaxWidth, 300)
    }
}
