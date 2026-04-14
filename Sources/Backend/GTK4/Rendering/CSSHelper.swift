import CGTK
import CGTKBridge
import Foundation

/// Counter for generating unique CSS class names.
private var cssClassCounter: Int = 0
private let cssCounterLock = NSLock()

/// Single fixed GObject data key for all CSS cleanup contexts on a widget.
/// Using one key avoids leaking GLib quarks (which are interned forever).
private let cssCleanupDataKey = "gtk-swift-css-cleanups"

/// Apply inline CSS to a widget using a unique class name.
/// The provider is attached to the widget via a shared cleanup list so it is
/// automatically removed from the display when the widget is destroyed.
///
/// `disabledProperties`, when provided, are applied on top of the base rules
/// via a `:disabled` pseudo-class — the widget's sensitivity state governs
/// which set wins. Callers that skip it get GTK's default disabled styling,
/// which usually means the base rules continue to apply even when the
/// widget is insensitive (so a filled .borderedProminent button would keep
/// its full-strength color when disabled, giving no visual signal).
func applyCSSToWidget(
    _ widget: UnsafeMutablePointer<GtkWidget>,
    properties: String,
    disabledProperties: String? = nil
) {
    cssCounterLock.lock()
    cssClassCounter += 1
    let className = "gtk-swift-css-\(cssClassCounter)"
    cssCounterLock.unlock()

    let typeName = String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
    let cssNode: String
    switch typeName {
    case "GtkBox":    cssNode = "box"
    case "GtkLabel":  cssNode = "label"
    case "GtkButton": cssNode = "button"
    case "GtkImage":  cssNode = "image"
    default:          cssNode = typeName.lowercased().replacingOccurrences(of: "gtk", with: "")
    }
    var css = """
        .\(className) { \(properties) }
        \(cssNode).\(className) { \(properties) }
        button.\(className) { \(properties) }
        label.\(className) { \(properties) }
        """

    if let disabledProperties {
        css += """

            .\(className):disabled { \(disabledProperties) }
            \(cssNode).\(className):disabled { \(disabledProperties) }
            button.\(className):disabled { \(disabledProperties) }
            label.\(className):disabled { \(disabledProperties) }
            """
    }

    let provider = gtk_css_provider_new()!
    gtk_css_provider_load_from_string(provider, css)

    let display = gtk_widget_get_display(widget)!
    gtk_swift_add_css_provider_to_display(
        display,
        provider,
        UInt32(GTK_STYLE_PROVIDER_PRIORITY_USER)
    )

    gtk_widget_add_css_class(widget, className)

    // Get or create the cleanup list for this widget (single fixed key).
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    let list: CSSCleanupList
    if let existing = g_object_get_data(gobject, cssCleanupDataKey) {
        list = Unmanaged<CSSCleanupList>.fromOpaque(existing).takeUnretainedValue()
    } else {
        list = CSSCleanupList()
        let retained = Unmanaged.passRetained(list).toOpaque()
        g_object_set_data_full(gobject, cssCleanupDataKey, retained) { userData in
            let l = Unmanaged<CSSCleanupList>.fromOpaque(userData!).takeRetainedValue()
            l.removeAll()
        }
    }

    // Add this provider to the cleanup list (takes an extra ref)
    list.add(display: gpointer(display), provider: gpointer(provider))

    // Release our local ref — the display and the cleanup list each hold one
    g_object_unref(gpointer(provider))
}

/// Holds all CSS providers attached to a single widget, keyed under one
/// fixed GObject data key to avoid leaking GLib quarks.
private class CSSCleanupList {
    private var entries: [(display: gpointer, provider: gpointer)] = []

    func add(display: gpointer, provider: gpointer) {
        g_object_ref(provider)
        entries.append((display: display, provider: provider))
    }

    func removeAll() {
        for entry in entries {
            gtk_swift_remove_css_provider_gp(entry.display, entry.provider)
            g_object_unref(entry.provider)
        }
        entries.removeAll()
    }
}
