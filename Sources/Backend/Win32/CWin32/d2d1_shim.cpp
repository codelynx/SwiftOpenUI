// Direct2D COM wrappers for Swift interop.
// Compiled as C++ so COM vtable method calls dispatch correctly.
// Swift's C++ interop currently dispatches virtual calls statically
// (swiftlang/swift#62354), so we use these C-linkage wrappers instead.
// Opaque handle types are reinterpret_cast to real COM types here.

#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN

#include <d2d1.h>
#include <d2d1helper.h>
#include <dwrite.h>
#include <wincodec.h>
#include <stdlib.h>
#include "include/d2d1_shim.h"

// Convenience macros for casting opaque handles to COM types
#define AS_FACTORY(p)       reinterpret_cast<ID2D1Factory *>(p)
#define AS_HWND_TARGET(p)   reinterpret_cast<ID2D1HwndRenderTarget *>(p)
#define AS_TARGET(p)        reinterpret_cast<ID2D1RenderTarget *>(p)
#define AS_BRUSH(p)         reinterpret_cast<ID2D1Brush *>(p)
#define AS_SOLID_BRUSH(p)   reinterpret_cast<ID2D1SolidColorBrush *>(p)

static const IID kIID_ID2D1Factory = __uuidof(ID2D1Factory);

// --- Factory ---

HRESULT d2d1_CreateFactory(D2DFactory *ppFactory) {
    return D2D1CreateFactory(
        D2D1_FACTORY_TYPE_SINGLE_THREADED,
        kIID_ID2D1Factory,
        NULL,
        reinterpret_cast<void **>(ppFactory)
    );
}

void d2d1_Factory_Release(D2DFactory factory) {
    if (factory) AS_FACTORY(factory)->Release();
}

// --- HwndRenderTarget ---

HRESULT d2d1_Factory_CreateHwndRenderTarget(
    D2DFactory factory,
    HWND hwnd,
    UINT32 width,
    UINT32 height,
    D2DRenderTarget *ppTarget
) {
    auto f = AS_FACTORY(factory);
    D2D1_RENDER_TARGET_PROPERTIES rtProps = D2D1::RenderTargetProperties();
    D2D1_HWND_RENDER_TARGET_PROPERTIES hwndProps = D2D1::HwndRenderTargetProperties(
        hwnd, D2D1::SizeU(width, height)
    );
    return f->CreateHwndRenderTarget(
        rtProps, hwndProps,
        reinterpret_cast<ID2D1HwndRenderTarget **>(ppTarget)
    );
}

void d2d1_HwndRenderTarget_Release(D2DRenderTarget target) {
    if (target) AS_HWND_TARGET(target)->Release();
}

HRESULT d2d1_HwndRenderTarget_Resize(D2DRenderTarget target, UINT32 width, UINT32 height) {
    D2D1_SIZE_U size = D2D1::SizeU(width, height);
    return AS_HWND_TARGET(target)->Resize(size);
}

// --- Drawing ---

void d2d1_RenderTarget_BeginDraw(D2DRenderTarget target) {
    AS_TARGET(target)->BeginDraw();
}

HRESULT d2d1_RenderTarget_EndDraw(D2DRenderTarget target) {
    return AS_TARGET(target)->EndDraw();
}

void d2d1_RenderTarget_Clear(D2DRenderTarget target, float r, float g, float b, float a) {
    AS_TARGET(target)->Clear(D2D1::ColorF(r, g, b, a));
}

// --- Brush ---

HRESULT d2d1_RenderTarget_CreateSolidColorBrush(
    D2DRenderTarget target,
    float r, float g, float b, float a,
    D2DBrush *ppBrush
) {
    return AS_TARGET(target)->CreateSolidColorBrush(
        D2D1::ColorF(r, g, b, a),
        reinterpret_cast<ID2D1SolidColorBrush **>(ppBrush)
    );
}

void d2d1_SolidColorBrush_SetColor(D2DBrush brush, float r, float g, float b, float a) {
    AS_SOLID_BRUSH(brush)->SetColor(D2D1::ColorF(r, g, b, a));
}

void d2d1_SolidColorBrush_Release(D2DBrush brush) {
    if (brush) AS_SOLID_BRUSH(brush)->Release();
}

// --- Fill shapes ---

void d2d1_RenderTarget_FillRectangle(
    D2DRenderTarget target,
    D2DBrush brush,
    float x, float y, float width, float height
) {
    AS_TARGET(target)->FillRectangle(
        D2D1::RectF(x, y, x + width, y + height), AS_BRUSH(brush)
    );
}

void d2d1_RenderTarget_FillEllipse(
    D2DRenderTarget target,
    D2DBrush brush,
    float centerX, float centerY, float radiusX, float radiusY
) {
    AS_TARGET(target)->FillEllipse(
        D2D1::Ellipse(D2D1::Point2F(centerX, centerY), radiusX, radiusY),
        AS_BRUSH(brush)
    );
}

void d2d1_RenderTarget_FillRoundedRectangle(
    D2DRenderTarget target,
    D2DBrush brush,
    float x, float y, float width, float height,
    float radiusX, float radiusY
) {
    D2D1_ROUNDED_RECT rrect = D2D1::RoundedRect(
        D2D1::RectF(x, y, x + width, y + height), radiusX, radiusY
    );
    AS_TARGET(target)->FillRoundedRectangle(rrect, AS_BRUSH(brush));
}

// --- Stroke (outline) shapes ---

void d2d1_RenderTarget_DrawRectangle(
    D2DRenderTarget target,
    D2DBrush brush,
    float x, float y, float width, float height,
    float strokeWidth
) {
    AS_TARGET(target)->DrawRectangle(
        D2D1::RectF(x, y, x + width, y + height),
        AS_BRUSH(brush), strokeWidth
    );
}

void d2d1_RenderTarget_DrawRoundedRectangle(
    D2DRenderTarget target,
    D2DBrush brush,
    float x, float y, float width, float height,
    float radiusX, float radiusY,
    float strokeWidth
) {
    D2D1_ROUNDED_RECT rrect = D2D1::RoundedRect(
        D2D1::RectF(x, y, x + width, y + height), radiusX, radiusY
    );
    AS_TARGET(target)->DrawRoundedRectangle(rrect, AS_BRUSH(brush), strokeWidth);
}

void d2d1_RenderTarget_DrawEllipse(
    D2DRenderTarget target,
    D2DBrush brush,
    float centerX, float centerY, float radiusX, float radiusY,
    float strokeWidth
) {
    AS_TARGET(target)->DrawEllipse(
        D2D1::Ellipse(D2D1::Point2F(centerX, centerY), radiusX, radiusY),
        AS_BRUSH(brush), strokeWidth
    );
}

// ==========================================================================
// DirectWrite
// ==========================================================================

#define AS_DWRITE_FACTORY(p)    reinterpret_cast<IDWriteFactory *>(p)
#define AS_TEXT_FORMAT(p)       reinterpret_cast<IDWriteTextFormat *>(p)
#define AS_TEXT_LAYOUT(p)       reinterpret_cast<IDWriteTextLayout *>(p)

HRESULT dwrite_CreateFactory(DWriteFactory *ppFactory) {
    return DWriteCreateFactory(
        DWRITE_FACTORY_TYPE_SHARED,
        __uuidof(IDWriteFactory),
        reinterpret_cast<IUnknown **>(ppFactory)
    );
}

void dwrite_Factory_Release(DWriteFactory factory) {
    if (factory) AS_DWRITE_FACTORY(factory)->Release();
}

HRESULT dwrite_CreateTextFormat(
    DWriteFactory factory,
    const WCHAR *fontFamily,
    float fontSize,
    int bold,
    int italic,
    DWriteTextFormat *ppFormat
) {
    return AS_DWRITE_FACTORY(factory)->CreateTextFormat(
        fontFamily,
        NULL,
        bold ? DWRITE_FONT_WEIGHT_BOLD : DWRITE_FONT_WEIGHT_NORMAL,
        italic ? DWRITE_FONT_STYLE_ITALIC : DWRITE_FONT_STYLE_NORMAL,
        DWRITE_FONT_STRETCH_NORMAL,
        fontSize,
        L"en-us",
        reinterpret_cast<IDWriteTextFormat **>(ppFormat)
    );
}

void dwrite_TextFormat_Release(DWriteTextFormat format) {
    if (format) AS_TEXT_FORMAT(format)->Release();
}

void dwrite_TextFormat_SetTextAlignment(DWriteTextFormat format, int alignment) {
    DWRITE_TEXT_ALIGNMENT a;
    switch (alignment) {
        case 1:  a = DWRITE_TEXT_ALIGNMENT_TRAILING; break;
        case 2:  a = DWRITE_TEXT_ALIGNMENT_CENTER; break;
        default: a = DWRITE_TEXT_ALIGNMENT_LEADING; break;
    }
    AS_TEXT_FORMAT(format)->SetTextAlignment(a);
}

void dwrite_TextFormat_SetParagraphAlignment(DWriteTextFormat format, int alignment) {
    DWRITE_PARAGRAPH_ALIGNMENT a;
    switch (alignment) {
        case 1:  a = DWRITE_PARAGRAPH_ALIGNMENT_FAR; break;
        case 2:  a = DWRITE_PARAGRAPH_ALIGNMENT_CENTER; break;
        default: a = DWRITE_PARAGRAPH_ALIGNMENT_NEAR; break;
    }
    AS_TEXT_FORMAT(format)->SetParagraphAlignment(a);
}

HRESULT dwrite_CreateTextLayout(
    DWriteFactory factory,
    const WCHAR *text,
    UINT32 textLength,
    DWriteTextFormat format,
    float maxWidth,
    float maxHeight,
    DWriteTextLayout *ppLayout
) {
    return AS_DWRITE_FACTORY(factory)->CreateTextLayout(
        text, textLength,
        AS_TEXT_FORMAT(format),
        maxWidth, maxHeight,
        reinterpret_cast<IDWriteTextLayout **>(ppLayout)
    );
}

void dwrite_TextLayout_Release(DWriteTextLayout layout) {
    if (layout) AS_TEXT_LAYOUT(layout)->Release();
}

HRESULT dwrite_TextLayout_GetMetrics(
    DWriteTextLayout layout,
    float *outWidth,
    float *outHeight
) {
    DWRITE_TEXT_METRICS metrics;
    HRESULT hr = AS_TEXT_LAYOUT(layout)->GetMetrics(&metrics);
    if (SUCCEEDED(hr)) {
        if (outWidth) *outWidth = metrics.width;
        if (outHeight) *outHeight = metrics.height;
    }
    return hr;
}

void d2d1_RenderTarget_DrawText(
    D2DRenderTarget target,
    const WCHAR *text,
    UINT32 textLength,
    DWriteTextFormat format,
    D2DBrush brush,
    float x, float y, float width, float height
) {
    D2D1_RECT_F layoutRect = D2D1::RectF(x, y, x + width, y + height);
    AS_TARGET(target)->DrawText(
        text, textLength,
        AS_TEXT_FORMAT(format),
        layoutRect,
        AS_BRUSH(brush)
    );
}

// --- WIC (Windows Imaging Component) ---

#define AS_WIC_FACTORY(p) reinterpret_cast<IWICImagingFactory *>(p)

HRESULT wic_CreateFactory(WICFactory *ppFactory) {
    // Ensure COM is initialized (safe to call multiple times)
    CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);

    return CoCreateInstance(
        CLSID_WICImagingFactory,
        NULL,
        CLSCTX_INPROC_SERVER,
        IID_IWICImagingFactory,
        reinterpret_cast<void **>(ppFactory)
    );
}

void wic_Factory_Release(WICFactory factory) {
    AS_WIC_FACTORY(factory)->Release();
}

HRESULT wic_LoadImageFile(
    WICFactory factory,
    const WCHAR *filePath,
    UINT32 *outWidth,
    UINT32 *outHeight,
    BYTE **ppPixels
) {
    IWICBitmapDecoder *decoder = NULL;
    HRESULT hr = AS_WIC_FACTORY(factory)->CreateDecoderFromFilename(
        filePath, NULL, GENERIC_READ,
        WICDecodeMetadataCacheOnLoad, &decoder
    );
    if (FAILED(hr)) return hr;

    IWICBitmapFrameDecode *frame = NULL;
    hr = decoder->GetFrame(0, &frame);
    if (FAILED(hr)) { decoder->Release(); return hr; }

    // Convert to 32bpp BGRA
    IWICFormatConverter *converter = NULL;
    hr = AS_WIC_FACTORY(factory)->CreateFormatConverter(&converter);
    if (FAILED(hr)) { frame->Release(); decoder->Release(); return hr; }

    hr = converter->Initialize(
        frame,
        GUID_WICPixelFormat32bppBGRA,
        WICBitmapDitherTypeNone,
        NULL, 0.0,
        WICBitmapPaletteTypeMedianCut
    );
    if (FAILED(hr)) {
        converter->Release(); frame->Release(); decoder->Release();
        return hr;
    }

    UINT w = 0, h = 0;
    converter->GetSize(&w, &h);
    *outWidth = w;
    *outHeight = h;

    UINT stride = w * 4;
    UINT bufferSize = stride * h;
    BYTE *pixels = (BYTE *)malloc(bufferSize);
    if (!pixels) {
        converter->Release(); frame->Release(); decoder->Release();
        return E_OUTOFMEMORY;
    }

    hr = converter->CopyPixels(NULL, stride, bufferSize, pixels);
    if (FAILED(hr)) {
        free(pixels);
        *ppPixels = NULL;
    } else {
        *ppPixels = pixels;
    }

    converter->Release();
    frame->Release();
    decoder->Release();
    return hr;
}

// --- Line ---

void d2d1_RenderTarget_DrawLine(
    D2DRenderTarget target,
    D2DBrush brush,
    float x1, float y1, float x2, float y2,
    float strokeWidth
) {
    AS_TARGET(target)->DrawLine(
        D2D1::Point2F(x1, y1),
        D2D1::Point2F(x2, y2),
        AS_BRUSH(brush),
        strokeWidth
    );
}

// --- Stroke Style ---

#define AS_STROKE_STYLE(p) reinterpret_cast<ID2D1StrokeStyle *>(p)

static D2D1_CAP_STYLE mapCapStyle(int cap) {
    switch (cap) {
    case 1: return D2D1_CAP_STYLE_SQUARE;
    case 2: return D2D1_CAP_STYLE_ROUND;
    case 3: return D2D1_CAP_STYLE_TRIANGLE;
    default: return D2D1_CAP_STYLE_FLAT;
    }
}

static D2D1_LINE_JOIN mapLineJoin(int join) {
    switch (join) {
    case 1: return D2D1_LINE_JOIN_BEVEL;
    case 2: return D2D1_LINE_JOIN_ROUND;
    case 3: return D2D1_LINE_JOIN_MITER_OR_BEVEL;
    default: return D2D1_LINE_JOIN_MITER;
    }
}

HRESULT d2d1_Factory_CreateStrokeStyle(
    D2DFactory factory,
    int capStyle,
    int lineJoin,
    const float *dashes,
    int dashCount,
    float dashOffset,
    D2DStrokeStyle *ppStyle
) {
    D2D1_DASH_STYLE dashStyle = (dashes && dashCount > 0)
        ? D2D1_DASH_STYLE_CUSTOM
        : D2D1_DASH_STYLE_SOLID;
    D2D1_STROKE_STYLE_PROPERTIES props = D2D1::StrokeStyleProperties(
        mapCapStyle(capStyle),   // startCap
        mapCapStyle(capStyle),   // endCap
        mapCapStyle(capStyle),   // dashCap
        mapLineJoin(lineJoin),
        10.0f,                   // miterLimit
        dashStyle,
        dashOffset
    );
    ID2D1StrokeStyle *style = nullptr;
    HRESULT hr = AS_FACTORY(factory)->CreateStrokeStyle(
        props, dashes, static_cast<UINT32>(dashCount), &style);
    *ppStyle = reinterpret_cast<D2DStrokeStyle>(style);
    return hr;
}

void d2d1_StrokeStyle_Release(D2DStrokeStyle style) {
    AS_STROKE_STYLE(style)->Release();
}

void d2d1_RenderTarget_DrawLineStyled(
    D2DRenderTarget target,
    D2DBrush brush,
    float x1, float y1, float x2, float y2,
    float strokeWidth,
    D2DStrokeStyle style
) {
    AS_TARGET(target)->DrawLine(
        D2D1::Point2F(x1, y1),
        D2D1::Point2F(x2, y2),
        AS_BRUSH(brush),
        strokeWidth,
        AS_STROKE_STYLE(style)
    );
}

void d2d1_RenderTarget_DrawRectangleStyled(
    D2DRenderTarget target,
    D2DBrush brush,
    float x, float y, float width, float height,
    float strokeWidth,
    D2DStrokeStyle style
) {
    D2D1_RECT_F rect = D2D1::RectF(x, y, x + width, y + height);
    AS_TARGET(target)->DrawRectangle(rect, AS_BRUSH(brush), strokeWidth, AS_STROKE_STYLE(style));
}

void d2d1_RenderTarget_DrawRoundedRectangleStyled(
    D2DRenderTarget target,
    D2DBrush brush,
    float x, float y, float width, float height,
    float radiusX, float radiusY,
    float strokeWidth,
    D2DStrokeStyle style
) {
    D2D1_ROUNDED_RECT rr = { D2D1::RectF(x, y, x + width, y + height), radiusX, radiusY };
    AS_TARGET(target)->DrawRoundedRectangle(rr, AS_BRUSH(brush), strokeWidth, AS_STROKE_STYLE(style));
}

void d2d1_RenderTarget_DrawEllipseStyled(
    D2DRenderTarget target,
    D2DBrush brush,
    float centerX, float centerY, float radiusX, float radiusY,
    float strokeWidth,
    D2DStrokeStyle style
) {
    D2D1_ELLIPSE ellipse = D2D1::Ellipse(D2D1::Point2F(centerX, centerY), radiusX, radiusY);
    AS_TARGET(target)->DrawEllipse(ellipse, AS_BRUSH(brush), strokeWidth, AS_STROKE_STYLE(style));
}

// --- Path Geometry ---

#define AS_PATH_GEOMETRY(p)   reinterpret_cast<ID2D1PathGeometry *>(p)
#define AS_GEOMETRY_SINK(p)   reinterpret_cast<ID2D1GeometrySink *>(p)

HRESULT d2d1_Factory_CreatePathGeometry(D2DFactory factory, D2DPathGeometry *ppGeometry) {
    return AS_FACTORY(factory)->CreatePathGeometry(
        reinterpret_cast<ID2D1PathGeometry **>(ppGeometry));
}

HRESULT d2d1_PathGeometry_Open(D2DPathGeometry geometry, D2DGeometrySink *ppSink) {
    return AS_PATH_GEOMETRY(geometry)->Open(
        reinterpret_cast<ID2D1GeometrySink **>(ppSink));
}

void d2d1_GeometrySink_BeginFigure(D2DGeometrySink sink, float x, float y, int filled) {
    AS_GEOMETRY_SINK(sink)->BeginFigure(
        D2D1::Point2F(x, y),
        filled ? D2D1_FIGURE_BEGIN_FILLED : D2D1_FIGURE_BEGIN_HOLLOW);
}

void d2d1_GeometrySink_AddLine(D2DGeometrySink sink, float x, float y) {
    AS_GEOMETRY_SINK(sink)->AddLine(D2D1::Point2F(x, y));
}

void d2d1_GeometrySink_AddBezier(D2DGeometrySink sink,
    float c1x, float c1y, float c2x, float c2y, float ex, float ey
) {
    AS_GEOMETRY_SINK(sink)->AddBezier(D2D1::BezierSegment(
        D2D1::Point2F(c1x, c1y), D2D1::Point2F(c2x, c2y), D2D1::Point2F(ex, ey)));
}

void d2d1_GeometrySink_AddArc(D2DGeometrySink sink,
    float ex, float ey, float rx, float ry, float rotation, int sweep, int arcSize
) {
    D2D1_ARC_SEGMENT seg;
    seg.point = D2D1::Point2F(ex, ey);
    seg.size = D2D1::SizeF(rx, ry);
    seg.rotationAngle = rotation;
    seg.sweepDirection = sweep ? D2D1_SWEEP_DIRECTION_COUNTER_CLOCKWISE : D2D1_SWEEP_DIRECTION_CLOCKWISE;
    seg.arcSize = arcSize ? D2D1_ARC_SIZE_LARGE : D2D1_ARC_SIZE_SMALL;
    AS_GEOMETRY_SINK(sink)->AddArc(seg);
}

void d2d1_GeometrySink_EndFigure(D2DGeometrySink sink, int closed) {
    AS_GEOMETRY_SINK(sink)->EndFigure(closed ? D2D1_FIGURE_END_CLOSED : D2D1_FIGURE_END_OPEN);
}

HRESULT d2d1_GeometrySink_Close(D2DGeometrySink sink) {
    return AS_GEOMETRY_SINK(sink)->Close();
}

void d2d1_GeometrySink_Release(D2DGeometrySink sink) {
    if (sink) AS_GEOMETRY_SINK(sink)->Release();
}

void d2d1_PathGeometry_Release(D2DPathGeometry geometry) {
    if (geometry) AS_PATH_GEOMETRY(geometry)->Release();
}

void d2d1_RenderTarget_FillGeometry(D2DRenderTarget target, D2DPathGeometry geometry, D2DBrush brush) {
    AS_TARGET(target)->FillGeometry(AS_PATH_GEOMETRY(geometry), AS_BRUSH(brush));
}

void d2d1_RenderTarget_DrawGeometry(D2DRenderTarget target, D2DPathGeometry geometry,
    D2DBrush brush, float strokeWidth
) {
    AS_TARGET(target)->DrawGeometry(AS_PATH_GEOMETRY(geometry), AS_BRUSH(brush), strokeWidth);
}

void d2d1_RenderTarget_DrawGeometryStyled(D2DRenderTarget target, D2DPathGeometry geometry,
    D2DBrush brush, float strokeWidth, D2DStrokeStyle style
) {
    AS_TARGET(target)->DrawGeometry(AS_PATH_GEOMETRY(geometry), AS_BRUSH(brush),
        strokeWidth, AS_STROKE_STYLE(style));
}

// --- Transform ---

void d2d1_RenderTarget_SetTransform(
    D2DRenderTarget target,
    float m11, float m12, float m21, float m22, float dx, float dy
) {
    D2D1_MATRIX_3X2_F matrix = D2D1::Matrix3x2F(m11, m12, m21, m22, dx, dy);
    AS_TARGET(target)->SetTransform(matrix);
}

void d2d1_RenderTarget_SetTransformIdentity(D2DRenderTarget target) {
    AS_TARGET(target)->SetTransform(D2D1::IdentityMatrix());
}
