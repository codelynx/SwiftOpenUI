import CGTK
import CGTKBridge
import Foundation

/// Counter for generating unique CSS class names.
private var cssClassCounter: Int = 0
private let cssCounterLock = NSLock()

/// Apply inline CSS to a widget using a unique class name.
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

    let display = gtk_widget_get_display(widget)
    gtk_swift_add_css_provider_to_display(
        display,
        provider,
        UInt32(GTK_STYLE_PROVIDER_PRIORITY_USER)
    )

    gtk_widget_add_css_class(widget, className)
    g_object_unref(gpointer(provider))
}
