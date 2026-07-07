import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge

/// A nested stateful child in the shape that caused the librano runaway
/// `.task` loop: a child view whose `@State` guard must survive its
/// PARENT host's rebuild. Before positional child-state reconciliation,
/// every parent rebuild constructed a fresh `StateStorage` (guard reset),
/// so guarded once-only work re-fired on every rebuild.
private struct GuardedChild: View {
    @State private var hasStarted = false
    var body: some View {
        Text(hasStarted ? "started" : "idle")
    }
}

/// Same-typed stateful siblings for the positional-identity hazard test.
private struct TaggedChild: View {
    let tag: String
    @State private var value = 0
    var body: some View {
        Text("\(tag):\(value)")
    }
}

final class GTK4ChildStateReconciliationTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 {
            _ = gtk_init_check()
        }
    }

    /// Regression test for the runaway-`.task` bug: a nested stateful
    /// child's @State must survive a full rebuild of its parent host.
    func testNestedChildStateSurvivesParentRebuild() throws {
        try requireGTK()

        let host = GTKViewHost(buildBody: {
            gtkRenderView(GuardedChild())
        })

        // Initial build — mirrors gtkRenderStatefulView's ritual.
        let previousHost = GTKViewHost.getCurrentRebuilding()
        GTKViewHost.setCurrentRebuilding(host)
        let widget = host.buildBodyWithTracking()
        GTKViewHost.setCurrentRebuilding(previousHost)
        gtk_box_append(boxPointer(host.container), widgetFromOpaque(widget))

        // The parent host cached the child's storage positionally.
        XCTAssertEqual(host.childStateCache.count, 1)
        let storageBefore = try XCTUnwrap(
            host.childStateCache["0:GuardedChild"]?.first as? StateStorage<Bool>)
        XCTAssertFalse(storageBefore.value)
        XCTAssertEqual(labelTexts(in: host.container), ["idle"])

        // Simulate the guarded work's first firing (task sets its flag) …
        storageBefore.setValue(true)

        // … then a full parent rebuild (what reset the guard pre-fix).
        host.rebuild()

        // The freshly constructed child must have the restored value: the
        // guard stays latched, and the rendered output reflects it.
        let storageAfter = try XCTUnwrap(
            host.childStateCache["0:GuardedChild"]?.first as? StateStorage<Bool>)
        XCTAssertTrue(storageAfter.value, "child @State was reset by parent rebuild")
        XCTAssertEqual(labelTexts(in: host.container), ["started"])
    }

    /// Documents the positional-identity limitation (NOT full SwiftUI
    /// structural identity): when same-typed stateful siblings swap render
    /// order, state follows the POSITION, migrating between them. ForEach
    /// ids are not consulted. If this test starts failing because identity
    /// became structural, that's an upgrade — rewrite the expectation.
    func testSameTypedSiblingReorderMigratesStateByPosition() throws {
        try requireGTK()

        var swapped = false
        let host = GTKViewHost(buildBody: {
            let tags = swapped ? ["B", "A"] : ["A", "B"]
            return gtkRenderView(VStack {
                TaggedChild(tag: tags[0])
                TaggedChild(tag: tags[1])
            })
        })

        let previousHost = GTKViewHost.getCurrentRebuilding()
        GTKViewHost.setCurrentRebuilding(host)
        let widget = host.buildBodyWithTracking()
        GTKViewHost.setCurrentRebuilding(previousHost)
        gtk_box_append(boxPointer(host.container), widgetFromOpaque(widget))

        XCTAssertEqual(labelTexts(in: host.container), ["A:0", "B:0"])

        // Give position 0 (currently tagged "A") a distinctive value.
        let position0 = try XCTUnwrap(
            host.childStateCache["0:TaggedChild"]?.first as? StateStorage<Int>)
        position0.setValue(7)

        // Swap the siblings and rebuild the parent.
        swapped = true
        host.rebuild()

        // Positional keying: the value stays at position 0, now tagged "B".
        XCTAssertEqual(
            labelTexts(in: host.container), ["B:7", "A:0"],
            "state is keyed by position + type; a same-typed reorder migrates it")
    }

    /// Mismatched type at the same position must fail open (no restore,
    /// no crash) — the cache skips rather than corrupts.
    func testTypeChangeAtSamePositionSkipsRestore() throws {
        try requireGTK()

        var useGuarded = true
        let host = GTKViewHost(buildBody: {
            useGuarded
                ? gtkRenderView(GuardedChild())
                : gtkRenderView(TaggedChild(tag: "T"))
        })

        let previousHost = GTKViewHost.getCurrentRebuilding()
        GTKViewHost.setCurrentRebuilding(host)
        let widget = host.buildBodyWithTracking()
        GTKViewHost.setCurrentRebuilding(previousHost)
        gtk_box_append(boxPointer(host.container), widgetFromOpaque(widget))

        (host.childStateCache["0:GuardedChild"]?.first as? StateStorage<Bool>)?
            .setValue(true)

        useGuarded = false
        host.rebuild()

        // Different type at position 0 → fresh default state, no crash.
        XCTAssertEqual(labelTexts(in: host.container), ["T:0"])
        XCTAssertNotNil(host.childStateCache["0:TaggedChild"])
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
