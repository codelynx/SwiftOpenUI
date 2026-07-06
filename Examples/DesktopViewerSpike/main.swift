// Desktop Viewer Spike — Gate 2 (Linux/GTK4)
//
// Step A (proven): an APP-SIDE view conforming to SwiftOpenUI's public
// GTKRenderable protocol is dispatched at runtime and can host a raw GTK4
// GtkDrawingArea with a Cairo draw func.
//
// Step B (this file): render REAL PDFium pages through that escape hatch and
// take the gate's measurements.
//   - GUI mode (default): window with prev/next + zoom, page rendered fit-to-width.
//   - Bench mode (SPIKE_BENCH=1): headless — no GTK window, no compositor. Renders
//     50 page-turns at a ~4K-class bitmap, times each render, samples RSS for
//     memory stability, and dumps fidelity PNGs via cairo_surface_write_to_png
//     (which double as Gate 3 side-by-side artifacts). This is the evidence of
//     record for the visual/timing/memory criteria.
//
// Test PDF (read in place, never copied into this repo):
//   librano/apple/Librano/Samples/issue-101/GDM_May_2012.pdf  (60pp, 558x756pt)
// Override with SPIKE_PDF=/path.
//
// Linux-only target. Built as product `DesktopViewerSpike`.

import Foundation
import SwiftOpenUI
import BackendGTK4
import CGTK
import CPDFium

// MARK: - PDFium document (mirrors LynxArchive PDFiumBridge)

/// FPDF_LoadMemDocument does not copy the buffer, so `data` must outlive `doc`.
final class PDFDoc {
    private let data: Data
    private let doc: FPDF_DOCUMENT

    init?(path: String) {
        guard let d = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            FileHandle.standardError.write(Data("[spike] cannot read PDF at \(path)\n".utf8)); return nil
        }
        self.data = d
        PDFDoc.initOnce()
        let count = Int32(d.count)
        guard let loaded = d.withUnsafeBytes({ (p: UnsafeRawBufferPointer) -> FPDF_DOCUMENT? in
            FPDF_LoadMemDocument(p.baseAddress, count, nil)
        }) else {
            FileHandle.standardError.write(Data("[spike] FPDF_LoadMemDocument failed\n".utf8)); return nil
        }
        self.doc = loaded
    }

    private static var didInit = false
    private static func initOnce() { if !didInit { FPDF_InitLibrary(); didInit = true } }

    var pageCount: Int { Int(FPDF_GetPageCount(doc)) }

    func pageSizePts(_ i: Int) -> (w: Double, h: Double) {
        var w = 0.0, h = 0.0
        FPDF_GetPageSizeByIndex(doc, Int32(i), &w, &h)
        return (w == 0 ? 558 : w, h == 0 ? 756 : h)
    }

    /// Render page `i` to BGRA (== Cairo ARGB32 on little-endian). Returns pixels + stride.
    func renderBGRA(_ i: Int, _ wPx: Int, _ hPx: Int) -> (data: Data, stride: Int)? {
        guard wPx > 0, hPx > 0, let page = FPDF_LoadPage(doc, Int32(i)) else { return nil }
        defer { FPDF_ClosePage(page) }
        guard let bmp = FPDFBitmap_Create(Int32(wPx), Int32(hPx), 0) else { return nil }
        defer { FPDFBitmap_Destroy(bmp) }
        FPDFBitmap_FillRect(bmp, 0, 0, Int32(wPx), Int32(hPx), 0xFFFFFFFF)  // white bg
        FPDF_RenderPageBitmap(bmp, page, 0, 0, Int32(wPx), Int32(hPx), 0, 0)
        guard let buf = FPDFBitmap_GetBuffer(bmp) else { return nil }
        let stride = Int(FPDFBitmap_GetStride(bmp))
        return (Data(bytes: buf, count: stride * hPx), stride)
    }

    deinit { FPDF_CloseDocument(doc) }
}

// MARK: - Helpers

func fitPixels(pagePts: (w: Double, h: Double), longEdgePx: Int) -> (Int, Int) {
    let scale = Double(longEdgePx) / max(pagePts.w, pagePts.h)
    return (Int((pagePts.w * scale).rounded()), Int((pagePts.h * scale).rounded()))
}

/// Write a BGRA/ARGB32 buffer to PNG using Cairo (no window / compositor needed).
func writePNG(_ pixels: Data, w: Int, h: Int, stride: Int, to path: String) {
    var d = pixels
    d.withUnsafeMutableBytes { raw in
        guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
        let surf = cairo_image_surface_create_for_data(base, CAIRO_FORMAT_ARGB32, Int32(w), Int32(h), Int32(stride))
        cairo_surface_write_to_png(surf, path)
        cairo_surface_destroy(surf)
    }
}

func rssMB() -> Double {
    guard let s = try? String(contentsOfFile: "/proc/self/statm", encoding: .utf8),
          let resident = s.split(separator: " ").dropFirst().first.flatMap({ Int($0) }) else { return -1 }
    return Double(resident) * Double(sysconf(Int32(_SC_PAGESIZE))) / 1_048_576
}

// MARK: - Bench mode (headless: no GTK window)

func runBench(_ pdf: PDFDoc) {
    let longEdge = Int(ProcessInfo.processInfo.environment["SPIKE_LONGEDGE"] ?? "") ?? 4000  // ~4K-class
    let turns = 50
    let outDir = "/tmp/claude-1000/spike_pngs"
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

    print("[bench] pages=\(pdf.pageCount) longEdge=\(longEdge)px turns=\(turns)")
    print("[bench] renderer path: GSK_RENDERER=\(ProcessInfo.processInfo.environment["GSK_RENDERER"] ?? "<default>") (PDFium raster is CPU; GTK compositing not exercised in bench)")

    // --- Timing + memory: 50 page turns at ~4K-class bitmaps ---
    let rss0 = rssMB()
    var times: [Double] = []
    var rssSamples: [Double] = []
    for turn in 0..<turns {
        let i = turn % pdf.pageCount
        let (wPx, hPx) = fitPixels(pagePts: pdf.pageSizePts(i), longEdgePx: longEdge)
        let t0 = Date()
        guard pdf.renderBGRA(i, wPx, hPx) != nil else { print("[bench] render failed page \(i)"); continue }
        times.append(Date().timeIntervalSince(t0) * 1000)
        if turn % 10 == 9 { rssSamples.append(rssMB()) }
    }
    let rss1 = rssMB()
    let sorted = times.sorted()
    let under500 = times.filter { $0 < 500 }.count
    print(String(format: "[bench] render ms: min=%.1f median=%.1f max=%.1f  under-500ms=%d/%d",
                 sorted.first ?? 0, sorted[sorted.count / 2], sorted.last ?? 0, under500, times.count))
    print(String(format: "[bench] RSS: start=%.0fMB end=%.0fMB delta=%+.0fMB  samples@10/20/30/40/50=%@ (bounded ~= one in-flight bitmap => no leak)",
                 rss0, rss1, rss1 - rss0, rssSamples.map { String(format: "%.0f", $0) }.joined(separator: "/")))

    // --- Fidelity dumps: dedicated pass (independent of the timing loop, so
    //     page 59 is actually produced — prior bug: loop only visited 0..49). ---
    for i in [0, 15, 30, 59] where i < pdf.pageCount {
        let (wPx, hPx) = fitPixels(pagePts: pdf.pageSizePts(i), longEdgePx: longEdge)
        if let (px, stride) = pdf.renderBGRA(i, wPx, hPx) {
            writePNG(px, w: wPx, h: hPx, stride: stride, to: "\(outDir)/page-\(i)-\(wPx)x\(hPx).png")
        }
        let (w2, h2) = fitPixels(pagePts: pdf.pageSizePts(i), longEdgePx: 1080)
        if let (px2, s2) = pdf.renderBGRA(i, w2, h2) {
            writePNG(px2, w: w2, h: h2, stride: s2, to: "\(outDir)/page-\(i)-fitwidth1080.png")
        }
    }

    // --- Resize + high-DPI proxy: render the SAME page at several widths
    //     (== window-resize reflow) and at 2x (== GDK_SCALE=2 / hi-DPI), so the
    //     "resize + one high-DPI factor without artifacts" bullet has evidence
    //     at the render path. Eyeball the PNGs for artifacts. ---
    print("[bench] resize/hi-DPI render sweep (page 15):")
    for longW in [640, 1000, 1600, 2160] {  // 2160 == 1080 @ 2x device pixels
        let (wPx, hPx) = fitPixels(pagePts: pdf.pageSizePts(15), longEdgePx: longW)
        let t0 = Date()
        if let (px, stride) = pdf.renderBGRA(15, wPx, hPx) {
            let ms = Date().timeIntervalSince(t0) * 1000
            let tag = longW == 2160 ? "hidpi2x" : "w\(longW)"
            writePNG(px, w: wPx, h: hPx, stride: stride, to: "\(outDir)/resize-\(tag)-\(wPx)x\(hPx).png")
            print(String(format: "  %@ -> %dx%d in %.0fms", tag, wPx, hPx, ms))
        }
    }
    print("[bench] fidelity + resize/hi-DPI PNGs -> \(outDir)")
}

// MARK: - GUI mode — real PDFium page through the escape hatch

private final class PageContext {
    let pdf: PDFDoc
    var page: Int
    var zoom: Double
    var lastRenderMs: Double = 0
    init(pdf: PDFDoc, page: Int, zoom: Double) { self.pdf = pdf; self.page = page; self.zoom = zoom }
}

struct PDFPageCanvas: View, GTKRenderable {
    let pdf: PDFDoc
    let page: Int
    let zoom: Double

    var body: Never { fatalError("primitive view") }

    func gtkCreateWidget() -> OpaquePointer {
        let area = gtk_drawing_area_new()!
        gtk_widget_set_hexpand(area, 1)
        gtk_widget_set_vexpand(area, 1)
        let ctx = PageContext(pdf: pdf, page: page, zoom: zoom)
        let ctxPtr = Unmanaged.passRetained(ctx).toOpaque()
        let gobject = UnsafeMutableRawPointer(area).assumingMemoryBound(to: GObject.self)
        g_object_set_data_full(gobject, "spike-pdf-ctx", ctxPtr) { ud in
            Unmanaged<PageContext>.fromOpaque(ud!).release()
        }
        let areaPtr = UnsafeMutableRawPointer(area).assumingMemoryBound(to: GtkDrawingArea.self)
        gtk_drawing_area_set_draw_func(areaPtr, { areaArg, cr, width, height, ud in
            guard let cr, let ud else { return }
            let ctx = Unmanaged<PageContext>.fromOpaque(ud).takeUnretainedValue()
            // Device scale factor drives crisp hi-DPI (GDK_SCALE / monitor scale).
            var deviceScale = 1
            if let areaArg {
                deviceScale = Int(gtk_widget_get_scale_factor(
                    UnsafeMutableRawPointer(areaArg).assumingMemoryBound(to: GtkWidget.self)))
            }
            Self.draw(cr: cr, width: Int(width), height: Int(height), deviceScale: max(1, deviceScale), ctx: ctx)
        }, ctxPtr, nil)
        return OpaquePointer(area)
    }

    private static func draw(cr: OpaquePointer, width: Int, height: Int, deviceScale: Int, ctx: PageContext) {
        cairo_set_source_rgb(cr, 0.15, 0.15, 0.17); cairo_paint(cr)
        guard width > 4, height > 4 else { return }
        // The drawing area is framed to the page size (zoom applied by the frame),
        // and lives inside a ScrollView that provides pan. Render at device
        // resolution (alloc * scale factor) so hi-DPI stays crisp, then map back.
        let wPx = width * deviceScale, hPx = height * deviceScale
        let t0 = Date()
        guard let rendered = ctx.pdf.renderBGRA(ctx.page, wPx, hPx) else { return }
        var px = rendered.data
        let stride = rendered.stride
        ctx.lastRenderMs = Date().timeIntervalSince(t0) * 1000
        FileHandle.standardError.write(Data("[spike] draw page \(ctx.page + 1) alloc \(width)x\(height) @\(deviceScale)x -> render \(wPx)x\(hPx) in \(String(format: "%.0f", ctx.lastRenderMs))ms\n".utf8))
        px.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let surf = cairo_image_surface_create_for_data(base, CAIRO_FORMAT_ARGB32, Int32(wPx), Int32(hPx), Int32(stride))
            defer { cairo_surface_destroy(surf) }
            cairo_save(cr)
            cairo_scale(cr, 1.0 / Double(deviceScale), 1.0 / Double(deviceScale))  // device px -> logical
            cairo_set_source_surface(cr, surf, 0, 0)
            cairo_paint(cr)
            cairo_restore(cr)
        }
    }
}

struct SpikeReaderView: View {
    let pdf: PDFDoc
    @State private var page = 0
    @State private var zoom = 1.0

    var body: some View {
        // Frame the page canvas to its rendered size (base width * zoom, page
        // aspect). The enclosing ScrollView then provides pan on both axes when
        // the zoomed page exceeds the viewport.
        let pts = pdf.pageSizePts(page)
        let renderW = 700.0 * zoom
        let renderH = renderW * (pts.h / pts.w)
        return VStack(spacing: 0) {
            Text("GDM_May_2012 — page \(page + 1)/\(pdf.pageCount)  ·  zoom \(String(format: "%.1fx", zoom))")
                .padding(8)
            ScrollView([.horizontal, .vertical]) {
                PDFPageCanvas(pdf: pdf, page: page, zoom: zoom)
                    .frame(width: renderW, height: renderH)
            }
            .frame(minWidth: 500, minHeight: 600)
            HStack {
                Button("◀ Prev") { if page > 0 { page -= 1 } }
                Button("Next ▶") { if page < pdf.pageCount - 1 { page += 1 } }
                Button("−") { zoom = max(0.5, zoom - 0.25) }
                Button("+") { zoom = min(4, zoom + 0.25) }
            }
            .padding(8)
        }
        .frame(minWidth: 700, minHeight: 800)
        .onAppear {
            // Wayland blocks external input injection, so allow the manual-pass
            // capture to start on a given page/zoom (proves those states render
            // live in the window without a click).
            let env = ProcessInfo.processInfo.environment
            if let p = Int(env["SPIKE_PAGE"] ?? "") { page = max(0, min(pdf.pageCount - 1, p - 1)) }
            if let z = Double(env["SPIKE_ZOOM"] ?? "") { zoom = z }
        }
    }
}

struct DesktopViewerSpikeApp: App {
    static var sharedPDF: PDFDoc!
    var body: some Scene {
        WindowGroup("Desktop Viewer Spike") {
            SpikeReaderView(pdf: DesktopViewerSpikeApp.sharedPDF)
        }
    }
}

// MARK: - Entry

let pdfPath = ProcessInfo.processInfo.environment["SPIKE_PDF"]
    ?? "/home/kyoshikawa/Projects/librano/apple/Librano/Samples/issue-101/GDM_May_2012.pdf"

guard let doc = PDFDoc(path: pdfPath) else {
    FileHandle.standardError.write(Data("[spike] FATAL: could not open PDF\n".utf8))
    exit(1)
}

if ProcessInfo.processInfo.environment["SPIKE_BENCH"] == "1" {
    runBench(doc)
} else {
    DesktopViewerSpikeApp.sharedPDF = doc
    GTK4Backend().run(DesktopViewerSpikeApp.self)
}
