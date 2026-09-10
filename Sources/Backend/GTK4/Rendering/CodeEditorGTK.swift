import CGTK
import CGtkSource
import CGTKBridge
import SwiftOpenUI

// GTK4 rendering for `CodeEditor`: a GtkSourceView (Swift highlighting +
// line-number gutter, from the CGtkSource shim) inside a scrolled window, with a
// two-way text binding wired through the buffer's "changed" signal — the same
// shape as the plain `TextEditor` render, but the widget is created via the
// OpaquePointer-only CGtkSource shim so gtksourceview's C types never cross into
// this file.
extension CodeEditor: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let viewRaw: UnsafeMutableRawPointer = gtk_swift_source_view_new()
        let view: UnsafeMutablePointer<GtkWidget> = viewRaw.assumingMemoryBound(to: GtkWidget.self)
        let bufferRaw: UnsafeMutableRawPointer = gtk_swift_source_view_get_buffer(viewRaw)

        // Best-effort dark scheme; ignored when the scheme id isn't installed.
        "Adwaita-dark".withCString { (id: UnsafePointer<CChar>) in
            gtk_swift_source_buffer_set_style_scheme(bufferRaw, id)
        }

        let current: String = text.wrappedValue
        if !current.isEmpty {
            current.withCString { (c: UnsafePointer<CChar>) in
                gtk_swift_source_buffer_set_text(bufferRaw, c, Int32(current.utf8.count))
            }
        }

        let binding: Binding<String> = text
        let box: UnsafeMutableRawPointer = Unmanaged.passRetained(StringClosureBox { (newText: String) in
            if newText != binding.wrappedValue {
                binding.wrappedValue = newText
            }
        }).toOpaque()
        g_signal_connect_data(
            gpointer(bufferRaw),
            "changed",
            unsafeBitCast({ (bufferPtr: gpointer?, userData: gpointer?) in
                guard let userData, let bufferPtr else { return }
                let box = Unmanaged<StringClosureBox>.fromOpaque(userData).takeUnretainedValue()
                guard let cStr: UnsafeMutablePointer<CChar> = gtk_swift_source_buffer_get_text(bufferPtr) else { return }
                let result: String = String(cString: cStr)
                g_free(UnsafeMutableRawPointer(cStr))
                box.closure(result)
            } as @convention(c) (gpointer?, gpointer?) -> Void, to: GCallback.self),
            box,
            { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                if let userData { Unmanaged<StringClosureBox>.fromOpaque(userData).release() }
            },
            GConnectFlags(rawValue: 0)
        )

        // Mirror the selection out (for line-level evaluation). "mark-set" fires
        // whenever the caret or selection bound moves.
        if let selectionBinding: Binding<String> = selection {
            let selBox: UnsafeMutableRawPointer = Unmanaged.passRetained(StringClosureBox { (sel: String) in
                if sel != selectionBinding.wrappedValue {
                    selectionBinding.wrappedValue = sel
                }
            }).toOpaque()
            g_signal_connect_data(
                gpointer(bufferRaw),
                "mark-set",
                unsafeBitCast({ (bufferPtr: gpointer?, _: gpointer?, _: gpointer?, userData: gpointer?) in
                    guard let userData, let bufferPtr else { return }
                    let box = Unmanaged<StringClosureBox>.fromOpaque(userData).takeUnretainedValue()
                    guard let cStr: UnsafeMutablePointer<CChar> = gtk_swift_source_buffer_get_selected_text(bufferPtr) else { return }
                    let result: String = String(cString: cStr)
                    g_free(UnsafeMutableRawPointer(cStr))
                    box.closure(result)
                } as @convention(c) (gpointer?, gpointer?, gpointer?, gpointer?) -> Void, to: GCallback.self),
                selBox,
                { (userData: gpointer?, _: UnsafeMutablePointer<GClosure>?) in
                    if let userData { Unmanaged<StringClosureBox>.fromOpaque(userData).release() }
                },
                GConnectFlags(rawValue: 0)
            )
        }

        let scrolled = gtk_scrolled_window_new()!
        gtk_scrolled_window_set_policy(OpaquePointer(scrolled), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC)
        gtk_scrolled_window_set_child(OpaquePointer(scrolled), view)
        gtk_widget_set_vexpand(scrolled, 1)
        gtk_widget_set_hexpand(scrolled, 1)

        return opaqueFromWidget(scrolled)
    }
}
