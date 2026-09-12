import CGTK
import CGtkSource
import CGTKBridge
import SwiftOpenUI
import Foundation

// Ctrl+Space completion for the GtkSourceView `CodeEditor`. A key controller on
// the view triggers the host's async `completionProvider`; the result is applied
// on the main thread. (This step inserts the first candidate; a picker popover is
// layered on next.)
//
// `@unchecked Sendable`: main-thread-confined — the raw GTK pointers are only
// touched inside `@MainActor` methods; the Task hops back to the main actor before
// applying anything.
final class CodeEditorCompletionController: @unchecked Sendable {
    let viewRaw: UnsafeMutableRawPointer
    let bufferRaw: UnsafeMutableRawPointer
    let provider: @Sendable (String, Int, Int) async -> [CodeCompletionItem]

    private var items: [CodeCompletionItem] = []
    private var popover: UnsafeMutablePointer<GtkWidget>?
    /// The identifier word to the left of the caret at the moment Ctrl+Space was
    /// pressed. Used to narrow the (large, unfiltered) sourcekit-lsp candidate set
    /// client-side — sourcekit returns every in-scope symbol and expects the
    /// editor to filter by what was typed.
    private var prefix: String = ""

    init(
        viewRaw: UnsafeMutableRawPointer,
        bufferRaw: UnsafeMutableRawPointer,
        provider: @escaping @Sendable (String, Int, Int) async -> [CodeCompletionItem]
    ) {
        self.viewRaw = viewRaw
        self.bufferRaw = bufferRaw
        self.provider = provider
    }

    /// Gather buffer text + caret (on the GTK main thread), ask the provider off
    /// the main thread, then apply the result back on the main actor.
    @MainActor
    func trigger() {
        guard let cStr: UnsafeMutablePointer<CChar> = gtk_swift_source_buffer_get_text(bufferRaw) else { return }
        let text: String = String(cString: cStr)
        g_free(UnsafeMutableRawPointer(cStr))
        var line: Int32 = 0
        var col: Int32 = 0
        gtk_swift_source_buffer_get_cursor_line_col(bufferRaw, &line, &col)
        let l: Int = Int(line)
        let c: Int = Int(col)
        prefix = Self.identifierPrefix(text: text, line: l, column: c)
        Task { [self] in
            let result: [CodeCompletionItem] = await provider(text, l, c)
            await MainActor.run { self.present(result) }
        }
    }

    /// The identifier word (letters / digits / `_`) ending at the caret on
    /// `line` / `column` (both 0-based). Empty when the char before the caret is
    /// not an identifier char (e.g. just after `.` or a space).
    private static func identifierPrefix(text: String, line: Int, column: Int) -> String {
        let lines: [Substring] = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard line >= 0, line < lines.count else { return "" }
        let chars: [Character] = Array(lines[line])
        let end: Int = min(max(column, 0), chars.count)
        var start: Int = end
        while start > 0 {
            let ch: Character = chars[start - 1]
            if ch.isLetter || ch.isNumber || ch == "_" { start -= 1 } else { break }
        }
        return String(chars[start..<end])
    }

    /// Show `items` in a popover at the caret. Clicking (or activating) a row
    /// inserts its text.
    @MainActor
    private func present(_ candidates: [CodeCompletionItem]) {
        dismiss()
        let filtered: [CodeCompletionItem] = Self.filter(candidates, prefix: prefix)
        guard !filtered.isEmpty else { return }
        items = filtered
        let view: UnsafeMutablePointer<GtkWidget> = viewRaw.assumingMemoryBound(to: GtkWidget.self)

        guard let popover = gtk_popover_new() else { return }

        guard let listBox = gtk_list_box_new() else { return }
        let listBoxOp: OpaquePointer = OpaquePointer(listBox)
        gtk_list_box_set_selection_mode(listBoxOp, GTK_SELECTION_SINGLE)
        for candidate: CodeCompletionItem in filtered {
            let label: UnsafeMutablePointer<GtkWidget> = candidate.label.withCString { (c: UnsafePointer<CChar>) in
                gtk_label_new(c)
            }
            gtk_widget_set_halign(label, GTK_ALIGN_START)
            let row = gtk_list_box_row_new()!
            gtk_list_box_row_set_child(
                UnsafeMutableRawPointer(row).assumingMemoryBound(to: GtkListBoxRow.self),
                label
            )
            gtk_list_box_append(listBoxOp, row)
        }

        let scrolled = gtk_scrolled_window_new()!
        let scrolledOp: OpaquePointer = OpaquePointer(scrolled)
        gtk_scrolled_window_set_policy(scrolledOp, GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_set_child(scrolledOp, listBox)
        gtk_widget_set_size_request(scrolled, 280, min(220, 26 * Int32(filtered.count)))

        gtk_swift_popover_set_child(popover, scrolled)
        gtk_widget_set_parent(popover, view)

        var rx: Int32 = 0, ry: Int32 = 0, rw: Int32 = 0, rh: Int32 = 0
        gtk_swift_source_view_get_cursor_rect(viewRaw, &rx, &ry, &rw, &rh)
        gtk_swift_popover_set_pointing_to(popover, rx, ry, rw, rh)

        // Insert on row activation.
        let activateBox: UnsafeMutableRawPointer = Unmanaged.passRetained(IntClosureBox { [weak self] (index: Int) in
            self?.insert(at: index)
        }).toOpaque()
        g_signal_connect_data(
            gpointer(listBox),
            "row-activated",
            unsafeBitCast({ (_: gpointer?, rowPtr: gpointer?, userData: gpointer?) in
                guard let userData, let rowPtr else { return }
                let row = rowPtr.assumingMemoryBound(to: GtkListBoxRow.self)
                let index: Int = Int(gtk_list_box_row_get_index(row))
                Unmanaged<IntClosureBox>.fromOpaque(userData).takeUnretainedValue().closure(index)
            } as @convention(c) (gpointer?, gpointer?, gpointer?) -> Void, to: GCallback.self),
            activateBox,
            { (data: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                if let data { Unmanaged<IntClosureBox>.fromOpaque(data).release() }
            },
            GConnectFlags(rawValue: 0)
        )

        gtk_swift_popover_popup(popover)
        self.popover = popover
    }

    @MainActor
    private func insert(at index: Int) {
        guard index >= 0, index < items.count else { dismiss(); return }
        // Replace the already-typed prefix (rather than append) so picking
        // `OscSin` after typing `Osc` yields `OscSin`, not `OscOscSin`.
        items[index].insertText.withCString { (c: UnsafePointer<CChar>) in
            gtk_swift_source_buffer_replace_prefix_at_cursor(bufferRaw, c)
        }
        dismiss()
    }

    /// Narrow the raw sourcekit-lsp candidate set to those matching the typed
    /// `prefix` (case-insensitive), preferring a `label`/`insertText` that starts
    /// with the prefix, then a contains-match, each ordered alphabetically. An
    /// empty prefix (member access after `.`) passes the set through unchanged —
    /// sourcekit has already scoped it.
    private static func filter(_ candidates: [CodeCompletionItem], prefix: String) -> [CodeCompletionItem] {
        guard !prefix.isEmpty else { return candidates }
        let lp: String = prefix.lowercased()
        var starts: [CodeCompletionItem] = []
        var contains: [CodeCompletionItem] = []
        for item: CodeCompletionItem in candidates {
            let label: String = item.label.lowercased()
            let insert: String = item.insertText.lowercased()
            if label.hasPrefix(lp) || insert.hasPrefix(lp) {
                starts.append(item)
            } else if label.contains(lp) {
                contains.append(item)
            }
        }
        starts.sort { $0.label.lowercased() < $1.label.lowercased() }
        contains.sort { $0.label.lowercased() < $1.label.lowercased() }
        return starts + contains
    }

    @MainActor
    private func dismiss() {
        if let pop: UnsafeMutablePointer<GtkWidget> = popover {
            gtk_swift_popover_popdown(pop)
            gtk_widget_unparent(pop)
            popover = nil
        }
    }
}

/// Add a Ctrl+Space key controller to `view` (a GtkSourceView) that drives
/// `controller.trigger()`.
func gtkAttachCodeEditorCompletion(view: UnsafeMutableRawPointer, controller: CodeEditorCompletionController) {
    let box: UnsafeMutableRawPointer = Unmanaged.passRetained(controller).toOpaque()
    guard let keyController = gtk_event_controller_key_new() else { return }
    g_signal_connect_data(
        gpointer(keyController),
        "key-pressed",
        unsafeBitCast({ (_: OpaquePointer?, keyval: guint, _: guint, state: guint, userData: gpointer?) -> gboolean in
            guard let userData else { return 0 }
            // Ctrl+Space: GDK_KEY_space = 0x20, GDK_CONTROL_MASK = 1<<2 = 4.
            let isCtrl: Bool = (state & 4) != 0
            guard isCtrl, keyval == 0x20 else { return 0 }
            let ctrl = Unmanaged<CodeEditorCompletionController>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { ctrl.trigger() }
            return 1 // consumed
        } as @convention(c) (OpaquePointer?, guint, guint, guint, gpointer?) -> gboolean, to: GCallback.self),
        box,
        { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
            if let userData { Unmanaged<CodeEditorCompletionController>.fromOpaque(userData).release() }
        },
        GConnectFlags(rawValue: 0)
    )
    gtk_widget_add_controller(view.assumingMemoryBound(to: GtkWidget.self), keyController)
}
