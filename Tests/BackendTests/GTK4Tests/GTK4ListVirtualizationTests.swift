import XCTest
import Foundation
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge

/// `List` must build row widgets only for rows that are on screen once it
/// has more than a handful of rows (issue #47). Rows that are realized
/// later, on scroll, must still see the environment the list was built in,
/// and state they read must still rebuild the list when it changes.
final class GTK4ListVirtualizationTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 {
            _ = gtk_init_check()
        }
    }

    /// GtkListView keeps roughly 200 rows realized around the viewport, so
    /// the number of rows built must stay about the same however long the
    /// list is, and far below the total.
    func testLargeListBuildsRowsIndependentOfLength() throws {
        try requireGTK()
        let built20k = try rowsBuilt(forListOf: 20_000)
        let built100k = try rowsBuilt(forListOf: 100_000)

        XCTAssertGreaterThan(built20k.count, 0, "no rows were built at all")
        XCTAssertLessThan(built20k.count, 1_000, "built \(built20k.count) of 20,000 rows")
        XCTAssertLessThan(built100k.count, 1_000, "built \(built100k.count) of 100,000 rows")
        XCTAssertLessThan(built100k.elapsed, 2.0,
                          "building a 100,000-row List took \(built100k.elapsed)s")
    }

    /// Scrolling deep into a long list builds the rows that come into view,
    /// and the total built stays bounded.
    func testScrollingBuildsRowsOnDemand() throws {
        try requireGTK()
        let counter = RowCounter()
        let widget = widgetFromOpaque(gtkRenderView(
            List {
                ForEach(0..<100_000) { i in counter.rowText(i) }
            }
        ))
        let window = try present(widget)
        defer { gtk_window_destroy(windowPointer(window)) }
        XCTAssertFalse(labelTexts(in: widget).contains("row 50000"))

        // Setting the scrolled window's adjustment doesn't rebind rows in a
        // test window (plain GTK behaves the same), so scroll the list view
        // directly.
        let listView = try XCTUnwrap(findWidget(named: "GtkListView", in: widget))
        gtk_list_view_scroll_to(OpaquePointer(listView), 50_000, GTK_LIST_SCROLL_NONE, nil)

        // Rows rebind on the next layout pass, not synchronously.
        func visibleRows() -> [Int] {
            labelTexts(in: widget).compactMap { text in
                text.hasPrefix("row ") ? Int(text.dropFirst(4)) : nil
            }
        }
        let deadline = Date().addingTimeInterval(3)
        while !visibleRows().contains(where: { $0 > 40_000 }), Date() < deadline {
            _ = g_main_context_iteration(nil, 0)
            usleep(2_000)
        }
        let visible = visibleRows()
        XCTAssertTrue(visible.contains { $0 > 40_000 && $0 < 60_000 },
                      "no rows near the middle after scrolling: \(visible.sorted().prefix(3))")
        XCTAssertLessThan(counter.count, 2_000, "built \(counter.count) rows")
    }

    private func rowsBuilt(forListOf rowCount: Int) throws -> (count: Int, elapsed: TimeInterval) {
        let counter = RowCounter()
        let start = Date()
        let widget = widgetFromOpaque(gtkRenderView(
            List {
                ForEach(0..<rowCount) { i in
                    counter.rowText(i)
                }
            }
        ))
        let window = try present(widget)
        defer { gtk_window_destroy(windowPointer(window)) }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(labelTexts(in: widget).contains("row 0"), "first row not on screen")
        return (counter.count, elapsed)
    }

    func testSmallListKeepsEagerListBox() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(
            List {
                ForEach(0..<5) { i in Text("row \(i)") }
            }
        ))
        XCTAssertNotNil(findWidget(named: "GtkListBox", in: widget),
                        "a 5-row List should stay on the GtkListBox path")
        XCTAssertNil(findWidget(named: "GtkListView", in: widget))
        XCTAssertEqual(labelTexts(in: widget).filter { $0.hasPrefix("row ") }.count, 5)
    }

    // MARK: - Rows built after the body pass

    /// Rows are built when they scroll into view, after the List's body pass
    /// has returned. They must still see environment values set above it.
    func testLazyRowsSeeEnvironmentSetAboveList() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(
            List {
                ForEach(0..<(gtkLazyListRowThreshold + 100)) { i in EnvironmentRow(index: i) }
            }
            .environment(\.listProbe, "inherited")
        ))
        let window = try present(widget)
        defer { gtk_window_destroy(windowPointer(window)) }

        let texts = labelTexts(in: widget)
        XCTAssertTrue(texts.contains("inherited 0"), "row lost the environment: \(texts.prefix(3))")
    }

    /// LazyVStack and OutlineGroup share the deferred render context; they
    /// lost the environment the same way before it.
    func testLazyVStackRowsSeeEnvironment() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(
            LazyVStack(Array(0..<50)) { i in EnvironmentRow(index: i) }
                .environment(\.listProbe, "inherited")
        ))
        let window = try present(widget)
        defer { gtk_window_destroy(windowPointer(window)) }
        XCTAssertTrue(labelTexts(in: widget).contains("inherited 0"))
    }

    func testOutlineGroupInListRowsSeeEnvironment() throws {
        try requireGTK()
        let tree = [OutlineNode(id: 0, children: [OutlineNode(id: 1, children: nil)])]
        let widget = widgetFromOpaque(gtkRenderView(
            List {
                OutlineGroup(tree, id: \.id, children: \.children) { node in
                    EnvironmentRow(index: node.id)
                }
            }
            .environment(\.listProbe, "inherited")
        ))
        let window = try present(widget)
        defer { gtk_window_destroy(windowPointer(window)) }
        XCTAssertTrue(labelTexts(in: widget).contains("inherited 0"))
    }

    /// State read only inside a row closure must still update the row: here
    /// the body reads `model.selected` only when a row is built.
    func testStateReadOnlyByLazyRowsUpdatesThem() throws {
        try requireGTK()
        let model = SelectionModel()
        let widget = widgetFromOpaque(gtkRenderView(SelectionList(model: model)))
        let window = try present(widget)
        defer { gtk_window_destroy(windowPointer(window)) }
        XCTAssertTrue(labelTexts(in: widget).contains("selected 0"))

        model.selected = 1
        var iterations = 0
        while !labelTexts(in: widget).contains("selected 1"), iterations < 500 {
            _ = g_main_context_iteration(nil, 0)
            iterations += 1
        }
        let texts = labelTexts(in: widget)
        XCTAssertTrue(texts.contains("selected 1"), "row did not update: \(texts.prefix(3))")
        XCTAssertTrue(texts.contains("row 0"))
    }

    /// Fixed rows and ForEach rows are flattened into one row each, as in
    /// SwiftUI, and only the visible ones are built.
    func testMixedContentFlattensIntoRows() throws {
        try requireGTK()
        let counter = RowCounter()
        let widget = widgetFromOpaque(gtkRenderView(
            List {
                Text("header")
                ForEach(0..<5_000) { i in counter.rowText(i) }
                Text("footer")
            }
        ))
        XCTAssertNotNil(findWidget(named: "GtkListView", in: widget))
        let window = try present(widget)
        defer { gtk_window_destroy(windowPointer(window)) }

        let texts = labelTexts(in: widget)
        XCTAssertTrue(texts.contains("header"))
        XCTAssertTrue(texts.contains("row 0"))
        XCTAssertLessThan(counter.count, 1_000)
    }

    func testRowBuildersFlattenTransparentContainers() {
        let rows = gtkListRowBuilders(TupleView((
            Text("a"),
            Group { Text("b"); Text("c") },
            ForEach(0..<3) { i in Text("\(i)") }
        )))
        XCTAssertEqual(rows.count, 6)
    }
}

// MARK: - Fixtures

private struct ListProbeKey: EnvironmentKey {
    static let defaultValue = "default"
}

extension EnvironmentValues {
    fileprivate var listProbe: String {
        get { self[ListProbeKey.self] }
        set { self[ListProbeKey.self] = newValue }
    }
}

private struct OutlineNode {
    let id: Int
    let children: [OutlineNode]?
}

private struct EnvironmentRow: View {
    @Environment(\.listProbe) var probe
    let index: Int
    var body: some View { Text("\(probe) \(index)") }
}

private final class SelectionModel: SwiftOpenUI.ObservableObject {
    @SwiftOpenUI.Published var selected = 0
}

private struct SelectionList: View {
    @SwiftOpenUI.ObservedObject var model: SelectionModel
    var body: some View {
        List {
            ForEach(0..<(gtkLazyListRowThreshold + 100)) { i in
                Text(i == model.selected ? "selected \(i)" : "row \(i)")
            }
        }
    }
}

// MARK: - Helpers

/// Counts how many rows were actually rendered into widgets.
final class RowCounter {
    var count = 0
    func rowText(_ i: Int) -> CountedRow { CountedRow(index: i, counter: self) }
}

/// A row whose `body` runs only when the row is rendered, so constructing
/// the view (which a multi-statement ViewBuilder does up front for every
/// `ForEach` row) doesn't count.
struct CountedRow: View {
    let index: Int
    let counter: RowCounter
    var body: some View {
        counter.count += 1
        return Text("row \(index)")
    }
}

private func requireGTK(file: StaticString = #filePath, line: UInt = #line) throws {
    guard gtk_is_initialized() != 0 else {
        throw XCTSkip("GTK could not initialize in this environment.", file: file, line: line)
    }
}

/// Show `content` in a real window and spin the main loop until it is laid
/// out, which is when a GtkListView binds the rows that fit (same approach
/// as GTK4FrameHitTransparencyTests). Returns the window; destroy it after.
private func present(
    _ content: UnsafeMutablePointer<GtkWidget>,
    width: Int32 = 400,
    height: Int32 = 300,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> UnsafeMutablePointer<GtkWidget> {
    let window = gtk_window_new()!
    gtk_window_set_default_size(windowPointer(window), width, height)
    gtk_window_set_child(windowPointer(window), content)
    gtk_window_present(windowPointer(window))
    var iterations = 0
    while gtk_widget_get_width(content) == 0, iterations < 1000 {
        _ = g_main_context_iteration(nil, 0)
        iterations += 1
    }
    guard gtk_widget_get_width(content) > 0 else {
        gtk_window_destroy(windowPointer(window))
        throw XCTSkip("window never allocated (no compositor?)", file: file, line: line)
    }
    // A few more iterations so the list view binds its visible rows.
    for _ in 0..<50 { _ = g_main_context_iteration(nil, 0) }
    return window
}

private func walk(_ widget: UnsafeMutablePointer<GtkWidget>, _ visit: (UnsafeMutablePointer<GtkWidget>) -> Void) {
    visit(widget)
    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        walk(c, visit)
        child = gtk_widget_get_next_sibling(c)
    }
}

private func widgetTypeName(_ widget: UnsafeMutablePointer<GtkWidget>) -> String {
    String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
}

private func findWidget(named name: String, in widget: UnsafeMutablePointer<GtkWidget>) -> UnsafeMutablePointer<GtkWidget>? {
    var found: UnsafeMutablePointer<GtkWidget>?
    walk(widget) { w in
        if found == nil, widgetTypeName(w) == name { found = w }
    }
    return found
}

private func labelTexts(in widget: UnsafeMutablePointer<GtkWidget>) -> [String] {
    var texts: [String] = []
    walk(widget) { w in
        if gtk_swift_is_label(w) != 0, let text = gtk_label_get_text(OpaquePointer(w)) {
            texts.append(String(cString: text))
        }
    }
    return texts
}
