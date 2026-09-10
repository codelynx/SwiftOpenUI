// CGtkSource — a thin, OpaquePointer-only shim over GtkSourceView 5, kept in its
// own system-library module (pkgConfig "gtksourceview-5") so the gtksourceview
// include path + link don't have to be forced onto the gtk4-only CGTK module.
//
// Every function takes/returns `void*` (an opaque GtkWidget* / GtkTextBuffer*),
// so the Swift caller treats the handles as `OpaquePointer`/`gpointer` and never
// imports GtkSourceView's C types alongside CGTK's — avoiding cross-module
// GtkWidget/GtkTextBuffer redefinitions. Signal wiring stays on the CGTK side
// (the buffer is just a gpointer to g_signal_connect_data).
#ifndef LYREBIRD_CGTKSOURCE_SHIM_H
#define LYREBIRD_CGTKSOURCE_SHIM_H

#include <gtksourceview/gtksource.h>

// Create a code editor view configured for Swift: syntax highlighting, a
// line-number gutter, a monospace font, 4-space soft tabs, and auto-indent.
// Returns the GtkSourceView as an opaque GtkWidget*.
static inline void *
gtk_swift_source_view_new(void) {
    GtkSourceView *view = GTK_SOURCE_VIEW(gtk_source_view_new());
    gtk_source_view_set_show_line_numbers(view, TRUE);
    gtk_source_view_set_auto_indent(view, TRUE);
    gtk_source_view_set_highlight_current_line(view, TRUE);
    gtk_source_view_set_tab_width(view, 4);
    gtk_source_view_set_insert_spaces_instead_of_tabs(view, TRUE);

    // Monospace is a GtkTextView property in GtkSourceView 5 (there is no
    // gtk_source_view_set_monospace).
    GtkTextView *tv = GTK_TEXT_VIEW(view);
    gtk_text_view_set_monospace(tv, TRUE);

    GtkSourceBuffer *buf =
        GTK_SOURCE_BUFFER(gtk_text_view_get_buffer(tv));
    GtkSourceLanguageManager *lm = gtk_source_language_manager_get_default();
    GtkSourceLanguage *lang =
        gtk_source_language_manager_get_language(lm, "swift");
    if (lang) {
        gtk_source_buffer_set_language(buf, lang);
        gtk_source_buffer_set_highlight_syntax(buf, TRUE);
    }
    return (void *)view;
}

// The view's GtkSourceBuffer as an opaque GtkTextBuffer* (it is a subclass, so
// the base gtk_text_buffer_* API applies).
static inline void *
gtk_swift_source_view_get_buffer(void *view) {
    return (void *)gtk_text_view_get_buffer(GTK_TEXT_VIEW(view));
}

static inline void
gtk_swift_source_buffer_set_text(void *buffer, const char *text, int length) {
    gtk_text_buffer_set_text((GtkTextBuffer *)buffer, text, length);
}

// Full buffer contents. Caller must g_free the returned string.
static inline char *
gtk_swift_source_buffer_get_text(void *buffer) {
    GtkTextIter start, end;
    gtk_text_buffer_get_bounds((GtkTextBuffer *)buffer, &start, &end);
    return gtk_text_buffer_get_text((GtkTextBuffer *)buffer, &start, &end, FALSE);
}

// The currently selected text, or an empty string when nothing is selected.
// Caller must g_free the returned string.
static inline char *
gtk_swift_source_buffer_get_selected_text(void *buffer) {
    GtkTextBuffer *b = (GtkTextBuffer *)buffer;
    GtkTextIter start, end;
    if (!gtk_text_buffer_get_selection_bounds(b, &start, &end)) {
        return g_strdup("");
    }
    return gtk_text_buffer_get_text(b, &start, &end, FALSE);
}

// Cursor position as 0-based (line, column-in-characters).
static inline void
gtk_swift_source_buffer_get_cursor_line_col(void *buffer, int *line, int *col) {
    GtkTextBuffer *b = (GtkTextBuffer *)buffer;
    GtkTextMark *insert = gtk_text_buffer_get_insert(b);
    GtkTextIter it;
    gtk_text_buffer_get_iter_at_mark(b, &it, insert);
    *line = gtk_text_iter_get_line(&it);
    *col = gtk_text_iter_get_line_offset(&it);
}

// Insert `text` at the cursor (replacing any selection).
static inline void
gtk_swift_source_buffer_insert_at_cursor(void *buffer, const char *text) {
    GtkTextBuffer *b = (GtkTextBuffer *)buffer;
    gtk_text_buffer_begin_user_action(b);
    if (gtk_text_buffer_get_has_selection(b)) {
        gtk_text_buffer_delete_selection(b, FALSE, TRUE);
    }
    gtk_text_buffer_insert_at_cursor(b, text, -1);
    gtk_text_buffer_end_user_action(b);
}

// The caret's rectangle in widget coordinates (for anchoring a popover).
static inline void
gtk_swift_source_view_get_cursor_rect(void *view, int *x, int *y, int *w, int *h) {
    GtkTextView *tv = GTK_TEXT_VIEW(view);
    GtkTextBuffer *b = gtk_text_view_get_buffer(tv);
    GtkTextMark *insert = gtk_text_buffer_get_insert(b);
    GtkTextIter it;
    gtk_text_buffer_get_iter_at_mark(b, &it, insert);
    GdkRectangle loc;
    gtk_text_view_get_iter_location(tv, &it, &loc);
    int bx = 0, by = 0;
    gtk_text_view_buffer_to_window_coords(tv, GTK_TEXT_WINDOW_WIDGET,
                                          loc.x, loc.y, &bx, &by);
    *x = bx; *y = by; *w = loc.width; *h = loc.height;
}

// Apply a named style scheme (e.g. "Adwaita-dark", "classic") when present.
static inline void
gtk_swift_source_buffer_set_style_scheme(void *buffer, const char *scheme_id) {
    GtkSourceStyleSchemeManager *sm =
        gtk_source_style_scheme_manager_get_default();
    GtkSourceStyleScheme *scheme =
        gtk_source_style_scheme_manager_get_scheme(sm, scheme_id);
    if (scheme) {
        gtk_source_buffer_set_style_scheme((GtkSourceBuffer *)buffer, scheme);
    }
}

#endif /* LYREBIRD_CGTKSOURCE_SHIM_H */
