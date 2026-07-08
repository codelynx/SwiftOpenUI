import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge
import Foundation

/// Regression: pure-layout frame wrappers must NOT swallow pointer events
/// (SwiftUI parity — empty frame regions don't hit-test), but pruning them
/// with `can_target = false` removes the ENTIRE subtree from picking,
/// children included — which made `Button.frame(maxWidth:.infinity)` a
/// pointer-dead button (round-4 review finding). These tests exercise
/// `gtk_widget_pick` on allocated widgets — real picking behavior, not
/// flags (the original flag-reading tests passed while the button was
/// dead, because a child's own `can_target` doesn't govern picking when
/// an ancestor prunes).
final class GTK4FrameHitTransparencyTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 { _ = gtk_init_check() }
    }

    /// The round-4 regression: a Button inside an infinity-frame wrapper
    /// must actually be reachable by picking, not just carry a targetable
    /// flag.
    func testPickReachesButtonInsideInfinityFrame() throws {
        try requireGTK()
        let wrapper = widgetFromOpaque(gtkRenderView(
            Button("go") {}.frame(maxWidth: .infinity, alignment: .trailing)
        ))
        let window = try hostInRealizedWindow(wrapper, width: 300, height: 40)
        defer { closeWindow(window) }

        let button = try XCTUnwrap(
            findDescendant(of: wrapper, typeName: "GtkButton"),
            "no GtkButton rendered under the frame wrapper")
        let center = try centerPoint(of: button, in: wrapper)

        let picked = gtk_widget_pick(wrapper, center.x, center.y, GTK_PICK_DEFAULT)
        let pickedUnwrapped = try XCTUnwrap(
            picked, "pick returned nothing at the button's center — button is pointer-dead")
        XCTAssertTrue(
            isSelfOrDescendant(pickedUnwrapped, of: button),
            "pick at the button's center must land in the button subtree, got \(widgetTypeName(pickedUnwrapped))")
    }

    /// The original 159745a behavior, now verified through picking: a
    /// non-interactive infinity frame prunes its WHOLE subtree — the empty
    /// region AND the content (a bare label receives no input, so pruning
    /// it with the wrapper is the intended safe-case behavior).
    func testNonInteractiveFrameSubtreePrunedFromPicking() throws {
        try requireGTK()
        let wrapper = widgetFromOpaque(gtkRenderView(
            Text("chevron").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        ))
        let window = try hostInRealizedWindow(wrapper, width: 300, height: 40)
        defer { closeWindow(window) }

        // (Functional-pick controls live in the sibling tests — a label
        // inside a pruned wrapper is unpickable BY DESIGN here: the whole
        // non-interactive subtree is transparent, which is the intended
        // safe-case behavior.)
        let label = try XCTUnwrap(
            findDescendant(of: wrapper, typeName: "GtkLabel"), "no label rendered")
        let labelCenter = try centerPoint(of: label, in: window)
        let pickedAtLabel = gtk_widget_pick(window, labelCenter.x, labelCenter.y, GTK_PICK_DEFAULT)
        if let pickedAtLabel {
            XCTAssertFalse(
                isSelfOrDescendant(pickedAtLabel, of: wrapper),
                "non-interactive wrapper content should be pruned with it, got \(widgetTypeName(pickedAtLabel))")
        }

        // Empty trailing region (leading-aligned content, 300 wide):
        // nothing in the wrapper subtree may claim the pointer there.
        let picked = gtk_widget_pick(window, 295, 20, GTK_PICK_DEFAULT)
        if let picked {
            XCTAssertFalse(
                isSelfOrDescendant(picked, of: wrapper),
                "the empty region of a non-interactive frame wrapper must not hit-test, got \(widgetTypeName(picked))")
        }
    }

    /// Gesture content: the tap-modified widget must be reachable by
    /// picking across the frame's full allocation (the documented
    /// gesture-area-equals-full-frame deviation).
    func testPickReachesTapGestureContent() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(
            Text("row").frame(maxWidth: .infinity).onTapGesture {}
        ))
        let window = try hostInRealizedWindow(widget, width: 300, height: 40)
        defer { closeWindow(window) }

        // Pick at the gesture widget's actual center (its height is the
        // label's natural height, not the window's — a hardcoded point
        // can miss it entirely).
        let center = try centerPoint(of: widget, in: window)
        let picked = gtk_widget_pick(window, center.x, center.y, GTK_PICK_DEFAULT)
        let pickedUnwrapped = try XCTUnwrap(picked, "gesture-bearing content must be pickable")
        XCTAssertTrue(
            isSelfOrDescendant(pickedUnwrapped, of: widget),
            "pick over gesture content must land in its subtree, got \(widgetTypeName(pickedUnwrapped))")
    }

    /// Round-5 marker-gap regression: a context menu is a pointer
    /// affordance attached by the framework (right-click gesture), with no
    /// focusable widget in the subtree — it must survive the frame
    /// wrapper's interactive scan and stay pickable.
    func testPickReachesContextMenuContentInsideInfinityFrame() throws {
        try requireGTK()
        let wrapper = widgetFromOpaque(gtkRenderView(
            Text("row")
                .contextMenu {
                    MenuItem("Copy") {}
                }
                .frame(maxWidth: .infinity, alignment: .leading)
        ))
        let window = try hostInRealizedWindow(wrapper, width: 300, height: 40)
        defer { closeWindow(window) }

        let label = try XCTUnwrap(
            findDescendant(of: wrapper, typeName: "GtkLabel"), "no label rendered")
        let center = try centerPoint(of: label, in: window)
        let picked = gtk_widget_pick(window, center.x, center.y, GTK_PICK_DEFAULT)
        let pickedUnwrapped = try XCTUnwrap(
            picked, "context-menu content is pointer-dead inside the frame")
        XCTAssertTrue(
            isSelfOrDescendant(pickedUnwrapped, of: wrapper),
            "pick over context-menu content must land in its subtree, got \(widgetTypeName(pickedUnwrapped))")
    }

    /// Round-5 marker-gap regression: a drop destination (GtkDropTarget,
    /// nothing focusable) inside an infinity frame must stay pickable —
    /// a pruned drop target silently ignores drags.
    func testPickReachesDropDestinationInsideInfinityFrame() throws {
        try requireGTK()
        let wrapper = widgetFromOpaque(gtkRenderView(
            Text("drop here")
                .dropDestination(for: URL.self) { _, _ in true }
                .frame(maxWidth: .infinity, alignment: .leading)
        ))
        let window = try hostInRealizedWindow(wrapper, width: 300, height: 40)
        defer { closeWindow(window) }

        let label = try XCTUnwrap(
            findDescendant(of: wrapper, typeName: "GtkLabel"), "no label rendered")
        let center = try centerPoint(of: label, in: window)
        let picked = gtk_widget_pick(window, center.x, center.y, GTK_PICK_DEFAULT)
        let pickedUnwrapped = try XCTUnwrap(
            picked, "drop-destination content is pointer-dead inside the frame")
        XCTAssertTrue(
            isSelfOrDescendant(pickedUnwrapped, of: wrapper),
            "pick over drop-destination content must land in its subtree, got \(widgetTypeName(pickedUnwrapped))")
    }

    /// Flag-level invariant kept from the original tests: a purely
    /// decorative infinity frame is still marked non-targetable (the
    /// conditional mark did not silently stop pruning the safe cases).
    func testNonInteractiveWrapperStillMarkedTransparent() throws {
        try requireGTK()
        let widget = widgetFromOpaque(gtkRenderView(
            Text("chevron").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        ))
        XCTAssertEqual(gtk_widget_get_can_target(widget), gboolean(0),
                       "non-interactive layout wrapper must not be a pointer target")
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

/// Host `content` in a presented GtkWindow and pump the main loop until the
/// content is allocated — gtk_widget_pick needs realized, allocated widgets
/// (on unrooted widgets every pick returns NULL, which is how the original
/// flag-based tests passed while the button was pointer-dead). Returns the
/// window widget; callers must `closeWindow` it.
private func hostInRealizedWindow(
    _ content: UnsafeMutablePointer<GtkWidget>,
    width: Int32, height: Int32,
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
    return window
}

private func closeWindow(_ window: UnsafeMutablePointer<GtkWidget>) {
    gtk_window_destroy(windowPointer(window))
    // Let the destroy settle so the next test starts clean.
    for _ in 0..<10 { _ = g_main_context_iteration(nil, 0) }
}

private func widgetTypeName(_ widget: UnsafeMutablePointer<GtkWidget>) -> String {
    String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
}

private func findDescendant(
    of widget: UnsafeMutablePointer<GtkWidget>, typeName: String
) -> UnsafeMutablePointer<GtkWidget>? {
    if widgetTypeName(widget) == typeName { return widget }
    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        if let found = findDescendant(of: c, typeName: typeName) { return found }
        child = gtk_widget_get_next_sibling(c)
    }
    return nil
}

/// Center of `child` expressed in `root`'s coordinate space.
private func centerPoint(
    of child: UnsafeMutablePointer<GtkWidget>,
    in root: UnsafeMutablePointer<GtkWidget>,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> (x: Double, y: Double) {
    var source = graphene_point_t()
    graphene_point_init(
        &source,
        Float(gtk_widget_get_width(child)) / 2,
        Float(gtk_widget_get_height(child)) / 2)
    var target = graphene_point_t()
    guard gtk_widget_compute_point(child, root, &source, &target) != 0 else {
        throw XCTSkip("could not compute child position (widget not allocated)", file: file, line: line)
    }
    return (Double(target.x), Double(target.y))
}

private func isSelfOrDescendant(
    _ widget: UnsafeMutablePointer<GtkWidget>,
    of ancestor: UnsafeMutablePointer<GtkWidget>
) -> Bool {
    var current: UnsafeMutablePointer<GtkWidget>? = widget
    while let c = current {
        if c == ancestor { return true }
        current = gtk_widget_get_parent(c)
    }
    return false
}
