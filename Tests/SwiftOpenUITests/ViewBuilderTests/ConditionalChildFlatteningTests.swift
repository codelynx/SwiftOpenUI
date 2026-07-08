import XCTest
@testable import SwiftOpenUI

/// Conditionals contribute their ACTIVE branch's children to the
/// enclosing container (SwiftUI stack-axis semantics). Regression for
/// the librano shared-IssuesListView pilot finding: `HStack { if … }`
/// rendered the conditional as one opaque child, so a multi-statement
/// branch fell into the generic vertical-box fallback and the issue-list
/// summary bar stacked vertically.
final class ConditionalChildFlatteningTests: XCTestCase {

    func testConditionalOnlyContentContributesTrueBranchChildren() {
        let searching = false
        // The summary-bar shape from the shared IssuesListView.
        let stack = HStack {
            if searching {
                Text("12 of 30 issues")
            } else {
                Text("30 issues")
                Text("•")
                Text("2025")
            }
        }
        XCTAssertEqual(stack.children.count, 3,
                       "false branch has 3 children; they must splice onto the stack axis")
    }

    func testConditionalOnlyContentContributesFalseBranchChild() {
        let searching = true
        let stack = HStack {
            if searching {
                Text("12 of 30 issues")
            } else {
                Text("30 issues")
                Text("•")
                Text("2025")
            }
        }
        XCTAssertEqual(stack.children.count, 1)
    }

    func testConditionalAmongSiblingsSplices() {
        let flag = true
        let stack = VStack {
            Text("x")
            if flag {
                Text("a")
                Text("b")
            }
            Text("y")
        }
        XCTAssertEqual(stack.children.count, 4,
                       "builder accumulation must splice the branch children among siblings")
    }

    func testIfWithoutElseFalseContributesNothing() {
        let flag = false
        let stack = HStack {
            Text("x")
            if flag {
                Text("y")
            }
        }
        XCTAssertEqual(stack.children.count, 1,
                       "Optional.none must contribute no children (not an empty box)")
    }

    func testNestedStackIsNotFlattened() {
        let stack = HStack {
            VStack {
                Text("a")
                Text("b")
            }
            Text("c")
        }
        XCTAssertEqual(stack.children.count, 2,
                       "nested stacks are real containers, never spliced into the parent")
    }

    func testStackAsConditionalBranchIsNotSpliced() {
        // Round-2 review High finding: a REAL container as the branch's
        // content must survive intact — only transparent aggregates
        // (TupleView, ViewList, nested conditionals) splice.
        let flag = true
        let stack = HStack {
            if flag {
                VStack {
                    Text("a")
                    Text("b")
                }
            }
            Text("c")
        }
        XCTAssertEqual(stack.children.count, 2,
                       "a VStack branch must stay one child, not splice its rows into the HStack")
        let firstChildType = String(describing: type(of: stack.children[0] as Any))
        XCTAssertTrue(firstChildType.hasPrefix("VStack<"),
                      "the branch child must still BE the VStack, got \(firstChildType)")
    }

    func testNestedConditionalFlattensRecursively() {
        let outer = true
        let inner = true
        let stack = HStack {
            if outer {
                Text("a")
                if inner {
                    Text("b")
                    Text("c")
                }
            } else {
                Text("z")
            }
        }
        XCTAssertEqual(stack.children.count, 3,
                       "a conditional nested in a branch splices transitively")
    }
}
