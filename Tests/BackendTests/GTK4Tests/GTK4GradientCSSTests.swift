import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge

/// The GTK4 gradient bug was: an INVALID CSS string that GTK silently dropped
/// (nothing rendered), while the parity matrix claimed "Y". A unit test on the
/// angle math alone can't catch that. This loads the generated CSS into a real
/// GtkCssProvider and asserts it *parses* — the guard that was missing.
final class GTK4GradientCSSTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 { _ = gtk_init_check() }
    }

    private final class ErrBox { var hadError = false }

    /// Returns true if loading `css` into a GtkCssProvider raises a parsing-error.
    private func cssHasParseError(_ css: String) -> Bool {
        let provider = gtk_css_provider_new()!
        defer { g_object_unref(gpointer(provider)) }
        let box = ErrBox()
        let boxPtr = Unmanaged.passUnretained(box).toOpaque()
        g_signal_connect_data(
            gpointer(provider), "parsing-error",
            unsafeBitCast({ (_: gpointer?, _: gpointer?, _: gpointer?, ud: gpointer?) in
                guard let ud else { return }
                Unmanaged<ErrBox>.fromOpaque(ud).takeUnretainedValue().hadError = true
            } as @convention(c) (gpointer?, gpointer?, gpointer?, gpointer?) -> Void, to: GCallback.self),
            boxPtr, nil, GConnectFlags(rawValue: 0)
        )
        gtk_css_provider_load_from_string(provider, css)
        return box.hadError
    }

    /// The fixed generator emits valid CSS for every direction.
    func testGeneratedLinearGradientCSSParses() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let dirs: [(UnitPoint, UnitPoint)] = [
            (.leading, .trailing), (.topLeading, .bottomTrailing), (.top, .bottom), (.trailing, .leading),
        ]
        for (s, e) in dirs {
            let g = LinearGradient(colors: [.blue, .red], startPoint: s, endPoint: e)
            let css = "* { background: \(gtkLinearGradientCSS(g)); }"
            XCTAssertFalse(cssHasParseError(css), "generated CSS should parse: \(css)")
        }
    }

    /// Guard proof: the ORIGINAL broken `from X% Y% to X% Y%` syntax IS caught as
    /// invalid — so this test would have failed on the pre-fix code.
    func testOldPointSyntaxIsRejected() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let broken = "* { background: linear-gradient(from 0% 50% to 100% 50%, rgba(0,0,255,1.0) 0%, rgba(255,0,0,1.0) 100%); }"
        XCTAssertTrue(cssHasParseError(broken), "the old from/to syntax must be rejected as invalid CSS")
    }

    /// RadialGradient CSS also parses (Q2: same-class check; not the same bug).
    func testGeneratedRadialGradientCSSParses() throws {
        try XCTSkipUnless(gtk_is_initialized() != 0, "GTK not available (headless)")
        let g = RadialGradient(colors: [.green, .teal], center: .center, startRadius: 0, endRadius: 100)
        let css = "* { background: \(gtkRadialGradientCSS(g)); }"
        XCTAssertFalse(cssHasParseError(css), "generated RadialGradient CSS should parse: \(css)")
    }
}
