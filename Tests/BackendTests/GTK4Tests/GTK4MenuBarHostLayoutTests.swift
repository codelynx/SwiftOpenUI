#if os(Linux)
import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge

/// Pins the `GTK4MenuBarHost.setup(contentWidget:)` post-conditions for
/// content-widget expansion. The menu wrapper sits between the GTK
/// window and the app's root content; if its setup logic ever stops
/// forwarding `hexpand` / `vexpand` / `halign = FILL` / `valign = FILL`
/// to the wrapped content, Synca's main window goes back to displaying
/// content in a left-biased, top-aligned natural-width region — the
/// exact symptom captured in `docs/gtk-layout-debugging-notes-2026-04-15.md`
/// (Symptom 2, contributor #4).
///
/// The parity-snapshot framework can't catch this regression because
/// scenarios are rendered into a bare window without going through the
/// `App` + `Commands {}` wrapper chain. This test instantiates the
/// menu host directly and asserts the post-setup widget flags.
///
/// Linux-only: macOS and Windows native menus live outside the window's
/// content widget, so there's no analog wrapper to test.
final class GTK4MenuBarHostLayoutTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 {
            _ = gtk_init_check()
        }
    }

    /// After `setup(contentWidget:)` runs, the content widget should
    /// have the four propagation flags the umbrella fix
    /// (SwiftOpenUI `a1a961f`) set explicitly:
    ///   - `hexpand = 1`  — claim extra horizontal space from the parent
    ///   - `vexpand = 1`  — claim extra vertical space
    ///   - `halign = FILL`  — actually use claimed horizontal space
    ///   - `valign = FILL`  — actually use claimed vertical space
    ///
    /// Without all four, GTK can let the wrapper grow while the inner
    /// content remains pinned at its natural width on the leading edge
    /// — the visual symptom of "page content in a left-biased internal
    /// container".
    func testMenuBarHostSetupForcesContentToFillWrapper() throws {
        try requireGTK()

        // Minimal placeholder window — `GTK4MenuBarHost` needs a real
        // GtkWindow pointer so it can swap the window's child to the
        // menu vbox. `gtk_window_new` is enough; we never present it.
        let winPtr = gtk_window_new()!
        defer { gtk_window_destroy(windowPointer(winPtr)) }

        // A content widget with deliberately *un-set* expansion flags
        // so the assertions below can prove the menu host SET them
        // (rather than just preserved an inherited default).
        let contentWidget = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_widget_set_hexpand(contentWidget, 0)
        gtk_widget_set_vexpand(contentWidget, 0)
        gtk_widget_set_halign(contentWidget, GTK_ALIGN_START)
        gtk_widget_set_valign(contentWidget, GTK_ALIGN_START)
        gtk_window_set_child(windowPointer(winPtr), contentWidget)

        // Empty commands factory — we're not testing menu population
        // here, only the wrapper layout flags. The host happily sets
        // up with no command groups.
        let factory: AnyCommandsFactory = { [:] }
        let host = GTK4MenuBarHost(winPtr: winPtr, factory: factory, windowID: 0)
        host.setup(contentWidget: contentWidget)

        XCTAssertEqual(
            gtk_widget_get_hexpand(contentWidget), 1,
            "Menu wrapper must set hexpand=1 on content so it claims extra horizontal space"
        )
        XCTAssertEqual(
            gtk_widget_get_vexpand(contentWidget), 1,
            "Menu wrapper must set vexpand=1 on content"
        )
        XCTAssertEqual(
            gtk_widget_get_halign(contentWidget), GTK_ALIGN_FILL,
            "Menu wrapper must set halign=FILL on content; without it, content stays at natural width on the leading edge despite hexpand=1"
        )
        XCTAssertEqual(
            gtk_widget_get_valign(contentWidget), GTK_ALIGN_FILL,
            "Menu wrapper must set valign=FILL on content"
        )
    }

    func testRootWindowContentAlwaysFillsWindow() throws {
        try requireGTK()

        let contentWidget = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_widget_set_hexpand(contentWidget, 0)
        gtk_widget_set_vexpand(contentWidget, 0)
        gtk_widget_set_halign(contentWidget, GTK_ALIGN_CENTER)
        gtk_widget_set_valign(contentWidget, GTK_ALIGN_CENTER)

        gtkConfigureRootContentToFillWindow(contentWidget)

        XCTAssertEqual(gtk_widget_get_hexpand(contentWidget), 1)
        XCTAssertEqual(gtk_widget_get_vexpand(contentWidget), 1)
        XCTAssertEqual(gtk_widget_get_halign(contentWidget), GTK_ALIGN_FILL)
        XCTAssertEqual(gtk_widget_get_valign(contentWidget), GTK_ALIGN_FILL)
    }

    func testAutomaticWindowGroupUsesDesktopDefaultSize() {
        let scene = WindowGroup("Automatic") {
            Text("Hello")
        }

        let resolved = scene.gtkResolvedDefaultWindowSize()

        XCTAssertEqual(resolved?.width, defaultAutomaticWindowWidth)
        XCTAssertEqual(resolved?.height, defaultAutomaticWindowHeight)
    }

    func testContentSizedWindowGroupDoesNotUseAutomaticDefault() {
        let scene = WindowGroup("Content") {
            Text("Hello")
        }
        .windowSizing(.content)

        XCTAssertNil(
            scene.gtkResolvedDefaultWindowSize(),
            ".content sizing should stay content-driven unless the app declares a defaultWindowSize."
        )
    }

    func testExplicitWindowGroupSizeOverridesAutomaticDefault() {
        let scene = WindowGroup("Explicit") {
            Text("Hello")
        }
        .defaultWindowSize(width: 320, height: 240)

        let resolved = scene.gtkResolvedDefaultWindowSize()

        XCTAssertEqual(resolved?.width, 320)
        XCTAssertEqual(resolved?.height, 240)
    }
}

private func requireGTK(
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    guard gtk_is_initialized() != 0 else {
        throw XCTSkip("GTK could not initialize in this environment.", file: file, line: line)
    }
}
#endif
