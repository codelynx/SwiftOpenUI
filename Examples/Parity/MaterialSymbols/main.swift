// Parity: MaterialSymbols (M-Symbols-1 minimum viable proof)
//
// Proves that the bundled Material Symbols font shipped by the
// SwiftOpenUISymbols target loads into FontConfig process-locally and that
// Pango can render a glyph when a GtkLabel asks for the "Material Symbols
// Rounded" family name. Deliberately uses raw CGTK rather than SwiftOpenUI's
// Text API — SwiftOpenUI doesn't yet have a .font(.custom(...)) surface
// (that's M-Symbols-2 work). This example exists to validate the
// packaging / font-loading plumbing, not to demonstrate idiomatic usage.
//
// On non-Linux platforms this target is empty — M-Symbols-1 scope is
// GTK4-only; Win32/Web/Android adopt the SwiftOpenUISymbols target in
// follow-up milestones.

#if canImport(CGTK) && canImport(SwiftOpenUISymbols)
import CGTK
import CGTKBridge
import SwiftOpenUISymbols
import Foundation

// Register the bundled font with FontConfig *before* gtk_application_new so
// Pango's default font map picks it up when the application initializes.
let fontURL = MaterialSymbolsResources.roundedRegularFontURL
let added = fontURL.path.withCString { gtk_swift_fc_app_font_add_file($0) }
if added == 0 {
    FileHandle.standardError.write(Data("[ParityMaterialSymbols] ERROR: failed to register font at \(fontURL.path)\n".utf8))
    exit(1)
}

let app = gtk_application_new(nil, G_APPLICATION_DEFAULT_FLAGS)!

// The Material Symbols font uses OpenType ligatures: the plain text "home"
// gets substituted to the home-icon glyph during Pango shaping when the
// "Material Symbols Rounded" family is selected. We put three icon names
// in one line so the reader can see the substitution working on several
// glyphs at once.
let demoMarkup = """
<span font_family="\(MaterialSymbolsResources.roundedRegularFamilyName)" font_size="96000">home   search   folder_open</span>
"""

let activateHandler: @convention(c) (gpointer?, gpointer?) -> Void = { _, _ in
    guard let defaultApp = g_application_get_default() else { return }
    let applicationOpaque = gpointer(defaultApp)
    let gtkApp = UnsafeMutableRawPointer(applicationOpaque)
        .assumingMemoryBound(to: GtkApplication.self)

    let win = gtk_application_window_new(gtkApp)!
    let winPtr = windowPointer(win)
    gtk_window_set_title(winPtr, "ParityMaterialSymbols")
    gtk_window_set_default_size(winPtr, 640, 200)

    let label = gtk_label_new(nil)!
    gtk_swift_label_set_markup(label, demoMarkup)
    gtk_widget_set_halign(label, GTK_ALIGN_CENTER)
    gtk_widget_set_valign(label, GTK_ALIGN_CENTER)
    gtk_widget_set_hexpand(label, 1)
    gtk_widget_set_vexpand(label, 1)
    gtk_window_set_child(winPtr, label)

    gtk_window_present(winPtr)
}

g_signal_connect_data(
    gpointer(OpaquePointer(app)),
    "activate",
    unsafeBitCast(activateHandler, to: GCallback.self),
    nil, nil,
    GConnectFlags(rawValue: 0)
)

let status = g_application_run(
    UnsafeMutableRawPointer(app).assumingMemoryBound(to: GApplication.self),
    0,
    nil
)
g_object_unref(gpointer(OpaquePointer(app)))
exit(Int32(status))

#else

import Foundation
print("ParityMaterialSymbols is a Linux-only M-Symbols-1 proof; build target not active on this platform.")

#endif
