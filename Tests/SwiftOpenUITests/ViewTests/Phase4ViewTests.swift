import XCTest
@testable import SwiftOpenUI

final class Phase4ViewTests: XCTestCase {

    // MARK: - TabView

    func testTabConstruction() {
        let tab = Tab("Settings") { Text("Content") }
        XCTAssertEqual(tab.title, "Settings")
        XCTAssertEqual(tab.id, "settings")
    }

    func testTabCustomId() {
        let tab = Tab("My Tab", id: "custom-id") { Text("Content") }
        XCTAssertEqual(tab.id, "custom-id")
    }

    func testTabViewConstruction() {
        let tabView = TabView {
            Tab("First") { Text("Page 1") }
            Tab("Second") { Text("Page 2") }
        }
        XCTAssertEqual(tabView.tabs.count, 2)
        XCTAssertEqual(tabView.tabs[0].title, "First")
        XCTAssertEqual(tabView.tabs[1].title, "Second")
        XCTAssertNil(tabView.initialTab)
    }

    func testTabViewInitialTab() {
        let tabView = TabView(initialTab: 1) {
            Tab("A") { Text("A") }
            Tab("B") { Text("B") }
        }
        XCTAssertEqual(tabView.initialTab, 1)
    }

    // MARK: - Grid

    func testGridAutoWrap() {
        let grid = Grid(columns: 3, spacing: 8) {
            Text("A")
            Text("B")
        }
        XCTAssertEqual(grid.columns, 3)
        XCTAssertEqual(grid.hSpacing, 8)
        XCTAssertEqual(grid.vSpacing, 8)
        XCTAssertFalse(grid.useExplicitRows)
    }

    func testGridExplicitRows() {
        let grid = Grid(horizontalSpacing: 4, verticalSpacing: 8) {
            GridRow { Text("A"); Text("B") }
            GridRow { Text("C"); Text("D") }
        }
        XCTAssertEqual(grid.hSpacing, 4)
        XCTAssertEqual(grid.vSpacing, 8)
        XCTAssertTrue(grid.useExplicitRows)
    }

    func testGridExplicitRowsPreserveGridRowBoundaries() {
        let grid = Grid(horizontalSpacing: 4, verticalSpacing: 8) {
            GridRow { Text("A"); Text("B") }
            GridRow { Text("C"); Text("D") }
            Text("Footer")
        }

        let multi = try? XCTUnwrap(grid.content as? MultiChildView)
        let children = multi?.children ?? []
        XCTAssertEqual(children.count, 3)
        // GridRow generic parameter varies with buildPartialBlock; check protocol
        XCTAssertTrue(children[0] is MultiChildView, "First child should be a GridRow")
        XCTAssertTrue(children[1] is MultiChildView, "Second child should be a GridRow")
        XCTAssertTrue(children[2] is Text)
    }

    // MARK: - GridRow

    func testGridRowChildren() {
        let row = GridRow {
            Text("A")
            Text("B")
            Text("C")
        }
        // GridRow conforms to MultiChildView
        XCTAssertFalse(row.children.isEmpty)
    }

    func testGridCellColumns() {
        let view = Text("Wide").gridCellColumns(3)
        XCTAssertEqual(view.gridColumnSpan, 3)
    }

    func testGridCellColumnsMinimum() {
        let view = Text("Narrow").gridCellColumns(0)
        XCTAssertEqual(view.gridColumnSpan, 1) // clamped to 1
    }

    // MARK: - DisclosureGroup

    func testDisclosureGroupDefaults() {
        let group = DisclosureGroup("Advanced") {
            Text("Hidden content")
        }
        XCTAssertEqual(group.title, "Advanced")
        XCTAssertFalse(group.isExpanded)
        XCTAssertNil(group.onExpandedChange)
    }

    func testDisclosureGroupExpanded() {
        let group = DisclosureGroup("Open", isExpanded: true) {
            Text("Visible")
        }
        XCTAssertTrue(group.isExpanded)
    }

    func testDisclosureGroupBinding() {
        let group = DisclosureGroup("Bound", isExpanded: .constant(false)) {
            Text("Content")
        }
        XCTAssertFalse(group.isExpanded)
        XCTAssertNotNil(group.onExpandedChange)
    }

    // MARK: - Form

    func testFormConstruction() {
        let form = Form {
            Text("Field 1")
            Text("Field 2")
        }
        XCTAssertFalse(form.children.isEmpty)
    }

    // MARK: - Section

    func testSectionHeaderOnly() {
        let section = Section("Account") {
            Text("Username")
        }
        XCTAssertEqual(section.header, "Account")
        XCTAssertNil(section.footer)
    }

    func testSectionHeaderAndFooter() {
        let section = Section(header: "Settings", footer: "Changes apply immediately.") {
            Text("Toggle")
        }
        XCTAssertEqual(section.header, "Settings")
        XCTAssertEqual(section.footer, "Changes apply immediately.")
    }

    func testSectionNoHeader() {
        let section = Section {
            Text("Content")
        }
        XCTAssertNil(section.header)
        XCTAssertNil(section.footer)
    }

    // MARK: - TabBuilder conditional content

    func testTabBuilderConditional() {
        let showAdvanced = true
        let tabView = TabView {
            Tab("General") { Text("General") }
            if showAdvanced {
                Tab("Advanced") { Text("Advanced") }
            }
        }
        XCTAssertEqual(tabView.tabs.count, 2)
    }

    func testTabBuilderConditionalFalse() {
        let showAdvanced = false
        let tabView = TabView {
            Tab("General") { Text("General") }
            if showAdvanced {
                Tab("Advanced") { Text("Advanced") }
            }
        }
        XCTAssertEqual(tabView.tabs.count, 1)
        XCTAssertEqual(tabView.tabs[0].title, "General")
    }

    // MARK: - GridRow with ForEach

    func testGridRowChildrenViaMultiChildView() {
        let row = GridRow {
            Text("A")
            Text("B")
        }
        // MultiChildView.children must produce actual child views, not stored properties
        let children = row.children
        XCTAssertEqual(children.count, 2)
        XCTAssertTrue(children[0] is Text)
        XCTAssertTrue(children[1] is Text)
    }

    // MARK: - Form with many children (TupleView4+)

    func testFormManyChildren() {
        let form = Form {
            Text("A")
            Text("B")
            Text("C")
            Text("D")
        }
        // Form's MultiChildView.children should enumerate all 4 children
        // via TupleView4, not hit fatalError
        XCTAssertEqual(form.children.count, 4)
    }

    func testSectionManyChildren() {
        // Section content can have 4+ views via TupleView4
        // This should compile and construct without issues
        let section = Section("Many") {
            Text("A")
            Text("B")
            Text("C")
            Text("D")
            Text("E")
        }
        XCTAssertEqual(section.header, "Many")
    }
}
