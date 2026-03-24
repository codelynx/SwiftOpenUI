import WinSDK
import CWin32

/// Singleton manager for Direct2D and DirectWrite factories.
/// All rendering runs on the main thread (single-threaded factory).
public class D2DRenderer {
    public static let shared = D2DRenderer()

    /// Exposed for stroke style creation in Canvas DrawingContext.
    var d2dFactory: D2DFactory? { factory }
    private var factory: D2DFactory?
    private var dwriteFactory: DWriteFactory?

    /// Cached text formats keyed by (fontSize, bold, italic).
    private var textFormatCache: [TextFormatKey: DWriteTextFormat] = [:]

    private init() {
        var f: D2DFactory?
        let hr = d2d1_CreateFactory(&f)
        if hr >= 0 {
            factory = f
        }

        var dwf: DWriteFactory?
        let hr2 = dwrite_CreateFactory(&dwf)
        if hr2 >= 0 {
            dwriteFactory = dwf
        }
    }

    deinit {
        for fmt in textFormatCache.values {
            dwrite_TextFormat_Release(fmt)
        }
        if let dwf = dwriteFactory {
            dwrite_Factory_Release(dwf)
        }
        if let f = factory {
            d2d1_Factory_Release(f)
        }
    }

    // MARK: - Render targets

    /// Create a render target bound to an HWND.
    public func createRenderTarget(for hwnd: HWND, width: UInt32, height: UInt32) -> D2DRenderTarget? {
        guard let f = factory else { return nil }
        var target: D2DRenderTarget?
        let hr = d2d1_Factory_CreateHwndRenderTarget(f, hwnd, width, height, &target)
        return hr >= 0 ? target : nil
    }

    /// Resize an existing render target.
    public func resize(_ target: D2DRenderTarget, width: UInt32, height: UInt32) {
        d2d1_HwndRenderTarget_Resize(target, width, height)
    }

    /// Release a render target.
    public func releaseRenderTarget(_ target: D2DRenderTarget) {
        d2d1_HwndRenderTarget_Release(target)
    }

    // MARK: - Brushes

    /// Create a solid color brush on a render target.
    public func createBrush(_ target: D2DRenderTarget, r: Float, g: Float, b: Float, a: Float = 1.0) -> D2DBrush? {
        var brush: D2DBrush?
        let hr = d2d1_RenderTarget_CreateSolidColorBrush(target, r, g, b, a, &brush)
        return hr >= 0 ? brush : nil
    }

    /// Release a brush.
    public func releaseBrush(_ brush: D2DBrush) {
        d2d1_SolidColorBrush_Release(brush)
    }

    // MARK: - Text

    /// Get or create a cached text format for the given parameters.
    public func textFormat(
        fontFamily: String = "Segoe UI",
        fontSize: Float = 14,
        bold: Bool = false,
        italic: Bool = false
    ) -> DWriteTextFormat? {
        let key = TextFormatKey(fontSize: fontSize, bold: bold, italic: italic)
        if let cached = textFormatCache[key] {
            return cached
        }

        guard let dwf = dwriteFactory else { return nil }
        var format: DWriteTextFormat?
        let hr = fontFamily.withCString(encodedAs: UTF16.self) { wstr in
            dwrite_CreateTextFormat(dwf, wstr, fontSize, bold ? 1 : 0, italic ? 1 : 0, &format)
        }
        if hr >= 0, let fmt = format {
            dwrite_TextFormat_SetParagraphAlignment(fmt, 2) // vertically center
            textFormatCache[key] = fmt
            return fmt
        }
        return nil
    }

    /// Measure text and return (width, height) using DirectWrite.
    /// More accurate than GDI's GetTextExtentPoint32W.
    public func measureText(
        _ text: String,
        format: DWriteTextFormat,
        maxWidth: Float = 10000,
        maxHeight: Float = 10000
    ) -> (Float, Float) {
        guard let dwf = dwriteFactory else { return (0, 0) }
        var layout: DWriteTextLayout?
        let hr = text.withCString(encodedAs: UTF16.self) { wstr in
            dwrite_CreateTextLayout(dwf, wstr, UInt32(text.utf16.count), format, maxWidth, maxHeight, &layout)
        }
        guard hr >= 0, let layout = layout else { return (0, 0) }

        var w: Float = 0
        var h: Float = 0
        dwrite_TextLayout_GetMetrics(layout, &w, &h)
        dwrite_TextLayout_Release(layout)
        return (ceilf(w), ceilf(h))
    }

    /// Draw text onto a render target.
    public func drawText(
        _ text: String,
        target: D2DRenderTarget,
        format: DWriteTextFormat,
        brush: D2DBrush,
        x: Float, y: Float, width: Float, height: Float
    ) {
        text.withCString(encodedAs: UTF16.self) { wstr in
            d2d1_RenderTarget_DrawText(target, wstr, UInt32(text.utf16.count),
                                        format, brush, x, y, width, height)
        }
    }

    // MARK: - Image loading (WIC)

    private var wicFactory: WICFactory?

    /// Load an image file (PNG, JPEG, BMP, GIF, TIFF, ICO) via WIC.
    /// Returns pixel data as 32bpp BGRA, along with dimensions.
    /// Caller is responsible for freeing the returned pixel buffer.
    public func loadImageFile(_ path: String) -> (pixels: UnsafeMutablePointer<UInt8>, width: UInt32, height: UInt32)? {
        // Lazy-init WIC factory
        if wicFactory == nil {
            var f: WICFactory?
            let hr = wic_CreateFactory(&f)
            if hr >= 0 { wicFactory = f }
        }
        guard let wic = wicFactory else { return nil }

        var w: UInt32 = 0
        var h: UInt32 = 0
        var pixels: UnsafeMutablePointer<UInt8>?

        let hr = path.withCString(encodedAs: UTF16.self) { wstr in
            wic_LoadImageFile(wic, wstr, &w, &h, &pixels)
        }

        guard hr >= 0, let px = pixels, w > 0, h > 0 else { return nil }
        return (px, w, h)
    }

    /// Create an HBITMAP from 32bpp BGRA pixel data.
    /// The returned HBITMAP must be freed with DeleteObject.
    public func createHBitmap(pixels: UnsafeMutablePointer<UInt8>, width: UInt32, height: UInt32) -> HBITMAP? {
        var bmi = BITMAPINFO()
        bmi.bmiHeader.biSize = DWORD(MemoryLayout<BITMAPINFOHEADER>.size)
        bmi.bmiHeader.biWidth = LONG(width)
        bmi.bmiHeader.biHeight = -LONG(height)  // top-down
        bmi.bmiHeader.biPlanes = 1
        bmi.bmiHeader.biBitCount = 32
        bmi.bmiHeader.biCompression = DWORD(BI_RGB)

        var ppvBits: UnsafeMutableRawPointer?
        let hBitmap = CreateDIBSection(nil, &bmi, UINT(DIB_RGB_COLORS), &ppvBits, nil, 0)

        if hBitmap != nil, let dest = ppvBits {
            let byteCount = Int(width) * Int(height) * 4
            memcpy(dest, pixels, byteCount)
        }

        return hBitmap
    }
}

// MARK: - Text format cache key

private struct TextFormatKey: Hashable {
    let fontSize: Float
    let bold: Bool
    let italic: Bool
}
