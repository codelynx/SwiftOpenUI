#pragma once

#include <gtk/gtk.h>

// --- CSS provider shims ---

static inline void
gtk_swift_add_css_provider_to_display(GdkDisplay *display,
                                      GtkCssProvider *provider,
                                      guint priority) {
    gtk_style_context_add_provider_for_display(
        display, GTK_STYLE_PROVIDER(provider), priority);
}

static inline void
gtk_swift_remove_css_provider_from_display(GdkDisplay *display,
                                           GtkCssProvider *provider) {
    gtk_style_context_remove_provider_for_display(
        display, GTK_STYLE_PROVIDER(provider));
}

/// Remove a CSS provider using gpointer (Swift-friendly).
static inline void
gtk_swift_remove_css_provider_gp(gpointer display, gpointer provider) {
    gtk_style_context_remove_provider_for_display(
        GDK_DISPLAY(display), GTK_STYLE_PROVIDER(provider));
}

// --- Label shims ---

static inline void
gtk_swift_label_set_xalign(GtkWidget *label, float xalign) {
    gtk_label_set_xalign(GTK_LABEL(label), xalign);
}

// --- Widget type shims ---

static inline gboolean
gtk_swift_is_widget(GtkWidget *widget) {
    return widget != NULL && GTK_IS_WIDGET(widget);
}

static inline GType
gtk_swift_get_widget_type(GtkWidget *widget) {
    return G_OBJECT_TYPE(widget);
}

// --- Focus shims ---

static inline gboolean
gtk_swift_grab_focus(GtkWidget *widget) {
    return gtk_widget_grab_focus(widget);
}

static inline void
gtk_swift_clear_focus(GtkWidget *widget) {
    GtkRoot *root = gtk_widget_get_root(widget);
    if (root) {
        gtk_root_set_focus(root, NULL);
    }
}

// --- Editable type check ---

static inline gboolean
gtk_swift_widget_is_editable(GtkWidget *widget) {
    return GTK_IS_EDITABLE(widget) ? TRUE : FALSE;
}

// --- Property setter shim (variadic g_object_set is not callable from Swift) ---

static inline void
g_object_set_double(gpointer object, const char *property, double value) {
    g_object_set(object, property, value, NULL);
}

// --- Gesture controller shim (GtkGesture → GtkEventController) ---

static inline void
gtk_swift_add_gesture(GtkWidget *widget, GtkGesture *gesture) {
    gtk_widget_add_controller(widget, GTK_EVENT_CONTROLLER(gesture));
}

// --- Scale (Slider) type check ---

static inline gboolean
gtk_swift_widget_is_scale(GtkWidget *widget) {
    return GTK_IS_RANGE(widget) ? TRUE : FALSE;
}

// --- Window titlebar helpers ---

/// Set or clear the window titlebar. Pass NULL to remove a custom titlebar.
static inline void
gtk_swift_set_root_window_titlebar(GtkWidget *widget, GtkWidget *titlebar) {
    GtkRoot *root = gtk_widget_get_root(widget);
    if (root && GTK_IS_WINDOW(root)) {
        gtk_window_set_titlebar(GTK_WINDOW(root), titlebar);
    }
}
