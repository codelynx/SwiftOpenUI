import XCTest
@testable import SwiftOpenUI

final class Phase4EViewTests: XCTestCase {

    // MARK: - LazyVStack

    func testLazyVStackConstruction() {
        let items = ["A", "B", "C"]
        let stack = LazyVStack(items) { item in
            Text(item)
        }
        XCTAssertEqual(stack.items.count, 3)
    }

    func testLazyVStackEmpty() {
        let stack = LazyVStack([String]()) { Text($0) }
        XCTAssertEqual(stack.items.count, 0)
    }

    // MARK: - LazyHStack

    func testLazyHStackConstruction() {
        let items = [1, 2, 3, 4]
        let stack = LazyHStack(items) { Text("\($0)") }
        XCTAssertEqual(stack.items.count, 4)
    }

    // MARK: - GridItem

    func testGridItemDefaults() {
        let item = GridItem()
        if case .flexible = item.size {
            // expected
        } else {
            XCTFail("Expected .flexible default")
        }
    }

    func testGridItemFixed() {
        let item = GridItem(.fixed)
        if case .fixed = item.size {
            // expected
        } else {
            XCTFail("Expected .fixed")
        }
    }

    func testGridItemAdaptive() {
        let item = GridItem(.adaptive(minimum: 80))
        if case .adaptive(let min) = item.size {
            XCTAssertEqual(min, 80)
        } else {
            XCTFail("Expected .adaptive")
        }
    }

    // MARK: - LazyVGrid

    func testLazyVGridFixedColumns() {
        let grid = LazyVGrid(columns: 3, data: ["A", "B", "C"]) { Text($0) }
        XCTAssertEqual(grid.items.count, 3)
        XCTAssertEqual(grid.gridItems.count, 3)
    }

    func testLazyVGridExplicitColumns() {
        let columns = [GridItem(.adaptive(minimum: 100)), GridItem(.fixed)]
        let grid = LazyVGrid(columns: columns, data: [1, 2]) { Text("\($0)") }
        XCTAssertEqual(grid.gridItems.count, 2)
    }

    // MARK: - LazyHGrid

    func testLazyHGridFixedRows() {
        let grid = LazyHGrid(rows: 2, data: ["X", "Y"]) { Text($0) }
        XCTAssertEqual(grid.items.count, 2)
        XCTAssertEqual(grid.gridItems.count, 2)
    }

    func testLazyHGridExplicitRows() {
        let rows = [GridItem(.flexible), GridItem(.flexible), GridItem(.flexible)]
        let grid = LazyHGrid(rows: rows, data: [1, 2, 3]) { Text("\($0)") }
        XCTAssertEqual(grid.gridItems.count, 3)
    }
}
