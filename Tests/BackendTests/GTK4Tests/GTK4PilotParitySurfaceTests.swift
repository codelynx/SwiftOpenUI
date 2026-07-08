import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge

/// Focused tests for the parity surface added for the librano shared
/// IssuesListView pilot (commit "feat(parity): view/modifier parity for
/// the shared IssuesListView pilot"): view-typed Section headers, titled
/// ProgressView, .task/.listStyle/.monospacedDigit acceptance, and the
/// ShapeStyles approximations. Reviewer condition for merging the pilot
/// branch to develop.
final class GTK4PilotParitySurfaceTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 {
            _ = gtk_init_check()
        }
    }

    func testSectionViewTypedHeaderRendersHeaderAndRows() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            List {
                Section {
                    Text("row-1")
                    Text("row-2")
                } header: {
                    Text("HDR")
                }
            }
        ))

        let texts = labelTexts(in: widget)
        XCTAssertTrue(texts.contains("HDR"), "view-typed header missing: \(texts)")
        XCTAssertTrue(texts.contains("row-1"), "section rows missing: \(texts)")
        XCTAssertTrue(texts.contains("row-2"), "section rows missing: \(texts)")
    }

    func testSectionStringHeaderStillRenders() throws {
        try requireGTK()

        // The view-typed initializer must not regress the string form.
        let widget = widgetFromOpaque(gtkRenderView(
            List {
                Section("Year 2024") {
                    Text("issue")
                }
            }
        ))

        let texts = labelTexts(in: widget)
        XCTAssertTrue(texts.contains { $0.contains("Year 2024") }, "string header missing: \(texts)")
        XCTAssertTrue(texts.contains("issue"))
    }

    func testTitledProgressViewShowsTitle() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(ProgressView("Loading issues...")))
        let texts = labelTexts(in: widget)
        XCTAssertTrue(
            texts.contains("Loading issues..."),
            "titled ProgressView must render its title label: \(texts)")
    }

    func testMonospacedDigitPreservesContent() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(Text("42/197").monospacedDigit()))
        XCTAssertEqual(labelTexts(in: widget), ["42/197"])
    }

    func testListStyleAcceptedWithoutAlteringContent() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            List {
                Text("styled-row")
            }
            .listStyle(.plain)
        ))
        XCTAssertTrue(labelTexts(in: widget).contains("styled-row"))
    }

    func testHierarchicalStyleAndMaterialRender() throws {
        try requireGTK()

        // The pilot's exact call shapes: .foregroundStyle(.secondary) on
        // text, material-in-shape background. Rendering must produce a
        // real widget tree with the content intact (flat-color
        // approximations, per the parity matrix).
        let widget = widgetFromOpaque(gtkRenderView(
            Text("subtle")
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        ))
        XCTAssertTrue(labelTexts(in: widget).contains("subtle"))

        let quaternary = widgetFromOpaque(gtkRenderView(
            Text("field")
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        ))
        XCTAssertTrue(labelTexts(in: quaternary).contains("field"))
    }

    func testTaskModifierRendersContentWithoutFiringSynchronously() throws {
        try requireGTK()

        // .task work must not run during widget construction (it fires on
        // map). Rendering unmapped must leave the flag untouched and the
        // content intact.
        nonisolated(unsafe) var fired = false
        let widget = widgetFromOpaque(gtkRenderView(
            Text("content").task { fired = true }
        ))
        XCTAssertTrue(labelTexts(in: widget).contains("content"))
        XCTAssertFalse(fired, ".task must not fire synchronously at render time")
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
