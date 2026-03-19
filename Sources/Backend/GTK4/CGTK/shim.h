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

// --- Image pixel size ---

static inline void
gtk_swift_image_set_pixel_size(GtkWidget *image, int size) {
    gtk_image_set_pixel_size(GTK_IMAGE(image), size);
}

// --- GtkPasswordEntry ---

static inline void
gtk_swift_password_entry_set_show_peek_icon(GtkWidget *entry, gboolean show) {
    gtk_password_entry_set_show_peek_icon(GTK_PASSWORD_ENTRY(entry), show);
}

// --- GtkSpinButton ---

static inline GtkWidget *
gtk_swift_spin_button_new_with_range(double min, double max, double step) {
    return gtk_spin_button_new_with_range(min, max, step);
}

static inline void
gtk_swift_spin_button_set_value(GtkWidget *widget, double value) {
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(widget), value);
}

static inline double
gtk_swift_spin_button_get_value(GtkWidget *widget) {
    return gtk_spin_button_get_value(GTK_SPIN_BUTTON(widget));
}

// --- GtkGrid shims ---

static inline void
gtk_swift_grid_attach(GtkWidget *grid, GtkWidget *child,
                      gint col, gint row, gint width, gint height) {
    gtk_grid_attach(GTK_GRID(grid), child, col, row, width, height);
}

static inline void
gtk_swift_grid_set_row_spacing(GtkWidget *grid, guint spacing) {
    gtk_grid_set_row_spacing(GTK_GRID(grid), spacing);
}

static inline void
gtk_swift_grid_set_column_spacing(GtkWidget *grid, guint spacing) {
    gtk_grid_set_column_spacing(GTK_GRID(grid), spacing);
}

static inline void
gtk_swift_grid_set_column_homogeneous(GtkWidget *grid, gboolean homogeneous) {
    gtk_grid_set_column_homogeneous(GTK_GRID(grid), homogeneous);
}

// --- GtkExpander shims ---

static inline GtkWidget *
gtk_swift_expander_new(const char *label) {
    return gtk_expander_new(label);
}

static inline void
gtk_swift_expander_set_child(GtkWidget *expander, GtkWidget *child) {
    gtk_expander_set_child(GTK_EXPANDER(expander), child);
}

static inline void
gtk_swift_expander_set_expanded(GtkWidget *expander, gboolean expanded) {
    gtk_expander_set_expanded(GTK_EXPANDER(expander), expanded);
}

static inline gboolean
gtk_swift_expander_get_expanded(GtkWidget *expander) {
    return gtk_expander_get_expanded(GTK_EXPANDER(expander));
}

// --- Label markup ---

static inline void
gtk_swift_label_set_markup(GtkWidget *label, const char *markup) {
    gtk_label_set_markup(GTK_LABEL(label), markup);
}

// --- GtkStack / GtkStackSwitcher shims ---

static inline void
gtk_swift_stack_set_transition_type(GtkWidget *stack, GtkStackTransitionType type) {
    gtk_stack_set_transition_type(GTK_STACK(stack), type);
}

static inline GtkWidget *
gtk_swift_stack_add_titled(GtkWidget *stack, GtkWidget *child,
                           const char *name, const char *title) {
    GtkStackPage *page = gtk_stack_add_titled(GTK_STACK(stack), child, name, title);
    (void)page;
    return child;
}

static inline void
gtk_swift_stack_set_visible_child_name(GtkWidget *stack, const char *name) {
    gtk_stack_set_visible_child_name(GTK_STACK(stack), name);
}

static inline void
gtk_swift_stack_switcher_set_stack(GtkWidget *switcher, GtkWidget *stack) {
    gtk_stack_switcher_set_stack(GTK_STACK_SWITCHER(switcher), GTK_STACK(stack));
}

// --- GtkListView / GtkListItem / GtkStringObject shims ---

static inline gpointer
gtk_swift_signal_list_item_factory_new(void) {
    return (gpointer)gtk_signal_list_item_factory_new();
}

static inline gpointer
gtk_swift_string_list_new(void) {
    return (gpointer)gtk_string_list_new(NULL);
}

static inline void
gtk_swift_string_list_append(gpointer list, const char *string) {
    gtk_string_list_append(GTK_STRING_LIST(list), string);
}

static inline gpointer
gtk_swift_no_selection_new(gpointer model) {
    return (gpointer)gtk_no_selection_new(G_LIST_MODEL(model));
}

static inline GtkWidget *
gtk_swift_list_view_new(gpointer model, gpointer factory) {
    return gtk_list_view_new(GTK_SELECTION_MODEL(model),
                             GTK_LIST_ITEM_FACTORY(factory));
}

static inline void
gtk_swift_list_item_set_child(gpointer list_item, GtkWidget *child) {
    gtk_list_item_set_child(GTK_LIST_ITEM(list_item), child);
}

static inline GtkWidget *
gtk_swift_list_item_get_child(gpointer list_item) {
    return gtk_list_item_get_child(GTK_LIST_ITEM(list_item));
}

static inline gpointer
gtk_swift_list_item_get_item(gpointer list_item) {
    return gtk_list_item_get_item(GTK_LIST_ITEM(list_item));
}

static inline const char *
gtk_swift_string_object_get_string(gpointer string_object) {
    return gtk_string_object_get_string(GTK_STRING_OBJECT(string_object));
}

// --- GtkGridView shims ---

static inline GtkWidget *
gtk_swift_grid_view_new(gpointer model, gpointer factory) {
    return gtk_grid_view_new(GTK_SELECTION_MODEL(model),
                             GTK_LIST_ITEM_FACTORY(factory));
}

static inline void
gtk_swift_grid_view_set_min_columns(GtkWidget *view, guint min_columns) {
    gtk_grid_view_set_min_columns(GTK_GRID_VIEW(view), min_columns);
}

static inline void
gtk_swift_grid_view_set_max_columns(GtkWidget *view, guint max_columns) {
    gtk_grid_view_set_max_columns(GTK_GRID_VIEW(view), max_columns);
}

// --- GtkOrientable ---

static inline void
gtk_swift_orientable_set_orientation(GtkWidget *widget, GtkOrientation orientation) {
    gtk_orientable_set_orientation(GTK_ORIENTABLE(widget), orientation);
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
