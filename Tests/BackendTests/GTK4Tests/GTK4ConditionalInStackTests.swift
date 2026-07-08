import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge

/// GTK rendering of conditionals inside stacks (the librano issue-list
/// summary-bar regression): branch children must become DIRECT children
/// of the stack's box, on the stack's axis — not one nested vertical box.
final class GTK4ConditionalInStackTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 { _ = gtk_init_check() }
    }

    func testConditionalBranchChildrenLayOnStackAxis() throws {
        try requireGTK()
        let searching = false
        let widget = widgetFromOpaque(gtkRenderView(
            HStack(spacing: 8) {
                if searching {
                    Text("12 of 30 issues")
                } else {
                    Text("30 issues")
                    Text("•")
                    Text("2025")
                }
            }
        ))
        XCTAssertEqual(directChildCount(of: widget), 3,
                       "branch children must be direct children of the HStack box, not one wrapped vertical box")
        XCTAssertEqual(labelTexts(in: widget), ["30 issues", "•", "2025"])
    }

    func testOptionalNoneContributesNoWidget() throws {
        try requireGTK()
        let flag = false
        let widget = widgetFromOpaque(gtkRenderView(
            HStack {
                Text("x")
                if flag {
                    Text("y")
                }
            }
        ))
        XCTAssertEqual(directChildCount(of: widget), 1,
                       "Optional.none must not render an empty spacing-consuming box")
    }

    func testNestedStackRemainsSingleChild() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(
            HStack {
                VStack {
                    Text("a")
                    Text("b")
                }
                Text("c")
            }
        ))
        XCTAssertEqual(directChildCount(of: widget), 2,
                       "a nested VStack is a real container and must not be spliced")
    }

    func testStackAsConditionalBranchRendersAsOneChild() throws {
        // Round-2 review High finding, widget level: a VStack that IS the
        // conditional's branch must render as one child of the HStack —
        // only transparent aggregates splice.
        try requireGTK()
        let flag = true
        let widget = widgetFromOpaque(gtkRenderView(
            HStack {
                if flag {
                    VStack {
                        Text("a")
                        Text("b")
                    }
                }
                Text("c")
            }
        ))
        XCTAssertEqual(directChildCount(of: widget), 2,
                       "the VStack branch must stay one child, its rows must not join the HStack axis")
        XCTAssertEqual(labelTexts(in: widget), ["a", "b", "c"])
    }
}

// MARK: - Helpers

private func requireGTK(
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    guard gtk_is_initialized() != 0 else {
        throw XCTSkip("GTK could not initialize in this environment.", file: file, line: line)
    }
}

private func directChildCount(of widget: UnsafeMutablePointer<GtkWidget>) -> Int {
    var count = 0
    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        count += 1
        child = gtk_widget_get_next_sibling(c)
    }
    return count
}

private func widgetTypeName(_ widget: UnsafeMutablePointer<GtkWidget>) -> String {
    String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
}

/// Collect all GtkLabel texts under a widget in DFS order.
private func labelTexts(in widget: UnsafeMutablePointer<GtkWidget>) -> [String] {
    var result: [String] = []
    labelTextsWalk(in: widget, result: &result)
    return result
}

private func labelTextsWalk(in widget: UnsafeMutablePointer<GtkWidget>, result: inout [String]) {
    if widgetTypeName(widget) == "GtkLabel" {
        result.append(String(cString: gtk_label_get_text(OpaquePointer(widget))))
    }
    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        labelTextsWalk(in: c, result: &result)
        child = gtk_widget_get_next_sibling(c)
    }
}
