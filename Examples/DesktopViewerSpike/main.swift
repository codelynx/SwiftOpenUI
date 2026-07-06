// Desktop Viewer Spike — Gate 2 (Linux/GTK4)
//
// Step A: prove that an APP-SIDE view conforming to SwiftOpenUI's public
// `GTKRenderable` protocol is dispatched at runtime and can host a raw GTK4
// `GtkDrawingArea` with a Cairo draw func. This is the dominant residual risk
// flagged in docs/design/linux/swiftopenui-migration-review.md (§6 Q1): the
// dispatch mechanism provably exists, but app-side (vs backend-side) conformance
// was untested. If this window shows the Cairo test pattern + page number, the
// escape hatch is confirmed and Step B (swap the draw for a PDFium page bitmap)
// is unblocked.
//
// Linux-only target (raw CGTK). Built as product `DesktopViewerSpike`.

import Foundation
import SwiftOpenUI
import BackendGTK4
import CGTK

// MARK: - App-side primitive view via the GTKRenderable escape hatch

/// Holds per-widget state for the Cairo draw callback (page number).
private final class PageCanvasContext {
    var page: Int
    init(page: Int) { self.page = page }
}

/// A SwiftOpenUI primitive view that renders a raw GTK4 drawing area and paints
/// it with Cairo — entirely app-side, mirroring LynxArchive's ResizeObserverView
/// pattern but conforming to SwiftOpenUI's `GTKRenderable` instead.
struct PageCanvas: View, GTKRenderable {
    let page: Int

    var body: Never { fatalError("PageCanvas is a primitive view") }

    func gtkCreateWidget() -> OpaquePointer {
        FileHandle.standardError.write(Data("[spike] gtkCreateWidget() called by backend — app-side GTKRenderable dispatched (page \(page))\n".utf8))
        let area = gtk_drawing_area_new()!
        gtk_widget_set_hexpand(area, 1)
        gtk_widget_set_vexpand(area, 1)

        let ctx = PageCanvasContext(page: page)
        let ctxPtr = Unmanaged.passRetained(ctx).toOpaque()
        let gobject = UnsafeMutableRawPointer(area).assumingMemoryBound(to: GObject.self)
        g_object_set_data_full(gobject, "spike-page-canvas-context", ctxPtr) { userData in
            Unmanaged<PageCanvasContext>.fromOpaque(userData!).release()
        }

        let areaPtr = UnsafeMutableRawPointer(area).assumingMemoryBound(to: GtkDrawingArea.self)
        gtk_drawing_area_set_draw_func(
            areaPtr,
            { _, cr, width, height, userData in
                guard let cr, let userData else { return }
                let ctx = Unmanaged<PageCanvasContext>.fromOpaque(userData).takeUnretainedValue()
                Self.draw(cr: cr, width: Int(width), height: Int(height), page: ctx.page)
            },
            ctxPtr,
            nil
        )
        return OpaquePointer(area)
    }

    /// Draw a recognizable test pattern so a human can confirm the escape hatch
    /// actually paints: page-tinted background, red border, diagonal cross,
    /// centered page label.
    private static func draw(cr: OpaquePointer, width: Int, height: Int, page: Int) {
        FileHandle.standardError.write(Data("[spike] Cairo draw func fired — \(width)x\(height) page \(page)\n".utf8))
        let w = Double(width), h = Double(height)

        // Background — tint shifts per page so page turns are visually obvious.
        let tint = 0.90 - Double(page % 5) * 0.06
        cairo_set_source_rgb(cr, tint, tint, 0.98)
        cairo_paint(cr)

        // Red border.
        cairo_set_source_rgb(cr, 0.85, 0.1, 0.1)
        cairo_set_line_width(cr, 4)
        cairo_rectangle(cr, 4, 4, w - 8, h - 8)
        cairo_stroke(cr)

        // Diagonal cross.
        cairo_set_source_rgb(cr, 0.2, 0.3, 0.8)
        cairo_set_line_width(cr, 1.5)
        cairo_move_to(cr, 0, 0);  cairo_line_to(cr, w, h); cairo_stroke(cr)
        cairo_move_to(cr, w, 0);  cairo_line_to(cr, 0, h); cairo_stroke(cr)

        // Page label.
        cairo_set_source_rgb(cr, 0.05, 0.05, 0.05)
        cairo_select_font_face(cr, "sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
        cairo_set_font_size(cr, 32)
        let label = "GTKRenderable OK — page \(page + 1)"
        cairo_move_to(cr, 40, h / 2)
        label.withCString { cairo_show_text(cr, $0) }
    }
}

// MARK: - Reader UI

struct SpikeReaderView: View {
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            Text("Desktop Viewer Spike — page \(page + 1)")
                .padding()
            PageCanvas(page: page)
                .frame(minWidth: 400, minHeight: 300)
            HStack {
                Button("◀ Prev") { if page > 0 { page -= 1 } }
                Button("Next ▶") { page += 1 }
            }
            .padding()
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

struct DesktopViewerSpikeApp: App {
    var body: some Scene {
        WindowGroup("Desktop Viewer Spike") {
            SpikeReaderView()
        }
    }
}

GTK4Backend().run(DesktopViewerSpikeApp.self)
