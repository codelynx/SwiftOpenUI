import CGTK
import CGTKBridge
import Foundation

/// Counter for generating unique CSS class names.
private var cssClassCounter: Int = 0
private let cssCounterLock = NSLock()

/// Apply inline CSS to a widget using a unique class name.
/// The provider is attached to the widget via g_object_set_data_full so it is
/// automatically removed from the display when the widget is destroyed,
/// preventing unbounded provider accumulation on rebuilds.
func applyCSSToWidget(_ widget: UnsafeMutablePointer<GtkWidget>, properties: String) {
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
    let css = """
        .\(className) { \(properties) }
        \(cssNode).\(className) { \(properties) }
        button.\(className) { \(properties) }
        label.\(className) { \(properties) }
        """

    let provider = gtk_css_provider_new()!
    gtk_css_provider_load_from_string(provider, css)

    let display = gtk_widget_get_display(widget)!
    gtk_swift_add_css_provider_to_display(
        display,
        provider,
        UInt32(GTK_STYLE_PROVIDER_PRIORITY_USER)
    )

    gtk_widget_add_css_class(widget, className)

    // Attach cleanup context to the widget. When the widget is destroyed,
    // the destroy notify removes the provider from the display.
    let dataKey = "gtk-swift-css-provider-\(className)"
    let ctx = Unmanaged.passRetained(
        CSSProviderCleanup(display: gpointer(display), provider: gpointer(provider))
    ).toOpaque()
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    g_object_set_data_full(gobject, dataKey, ctx) { userData in
        let cleanup = Unmanaged<CSSProviderCleanup>.fromOpaque(userData!).takeRetainedValue()
        cleanup.remove()
    }

    // Release our local ref — the display and the cleanup context each hold one
    g_object_unref(gpointer(provider))
}

/// Captures a display + provider pair so the provider can be removed
/// from the display when the owning widget is destroyed.
private class CSSProviderCleanup {
    let displayPtr: gpointer
    let providerPtr: gpointer

    init(display: gpointer, provider: gpointer) {
        self.displayPtr = display
        self.providerPtr = provider
        // Take an extra ref so the provider stays alive until we remove it
        g_object_ref(provider)
    }

    func remove() {
        gtk_swift_remove_css_provider_gp(displayPtr, providerPtr)
        g_object_unref(providerPtr)
    }
}
