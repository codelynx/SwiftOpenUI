import XCTest
@testable import SwiftOpenUI

final class ViewBuilderTests: XCTestCase {

    // MARK: - ViewBuilder basics

    func testBuildBlockEmpty() {
        @ViewBuilder func build() -> some View { }
        let view = build()
        XCTAssertTrue(view is EmptyView)
    }

    func testBuildBlockSingle() {
        @ViewBuilder func build() -> some View { Text("hello") }
        let view = build()
        XCTAssertTrue(view is Text)
    }

    func testBuildBlockTwo() {
        @ViewBuilder func build() -> some View {
            Text("a")
            Text("b")
        }
        let view = build()
        // With buildPartialBlock, multi-child results are ViewList (or TupleView2)
        XCTAssertTrue(view is MultiChildView)
        let children = (view as! MultiChildView).children
        XCTAssertEqual(children.count, 2)
    }

    func testBuildBlockThree() {
        @ViewBuilder func build() -> some View {
            Text("a")
            Text("b")
            Text("c")
        }
        let view = build()
        XCTAssertTrue(view is MultiChildView)
        let children = (view as! MultiChildView).children
        XCTAssertEqual(children.count, 3)
    }

    func testBuildOptionalPresent() {
        let show = true
        @ViewBuilder func build() -> some View {
            if show { Text("visible") }
        }
        let view = build()
        // Optional<Text> when present
        XCTAssertNotNil(view)
    }

    func testBuildEitherTrue() {
        let flag = true
        @ViewBuilder func build() -> some View {
            if flag {
                Text("true")
            } else {
                Text("false")
            }
        }
        let view = build()
        XCTAssertTrue(view is _ConditionalView<Text, Text>)
    }

    // MARK: - MultiChildView

    func testTupleViewChildren() {
        let tuple = TupleView(Text("a"), Text("b"))
        XCTAssertEqual(tuple.children.count, 2)
    }

    func testGroupFlattensChildren() {
        let group = Group {
            Text("a")
            Text("b")
            Text("c")
        }
        XCTAssertEqual(group.children.count, 3)
    }

    // MARK: - ForEach

    func testForEachRange() {
        let forEach = ForEach(0..<5) { i in Text("\(i)") }
        XCTAssertEqual(forEach.children.count, 5)
    }

    struct Item: Identifiable {
        let id: Int
        let name: String
    }

    func testForEachIdentifiable() {
        let items = [Item(id: 1, name: "a"), Item(id: 2, name: "b")]
        let forEach = ForEach(items) { item in Text(item.name) }
        XCTAssertEqual(forEach.children.count, 2)
    }

    // MARK: - AnyView

    func testAnyViewWraps() {
        let text = Text("hello")
        let any = AnyView(text)
        XCTAssertTrue(any.wrapped is Text)
    }

    // MARK: - Stacks

    func testVStackDefaults() {
        let stack = VStack { Text("child") }
        XCTAssertEqual(stack.children.count, 1)
    }

    func testHStackDefaults() {
        let stack = HStack { Text("child") }
        XCTAssertEqual(stack.children.count, 1)
    }

    func testZStackDefaults() {
        let stack = ZStack { Text("child") }
        XCTAssertEqual(stack.children.count, 1)
    }

    func testVStackMultipleChildren() {
        let stack = VStack {
            Text("a")
            Text("b")
            Text("c")
        }
        XCTAssertEqual(stack.children.count, 3)
    }
}
