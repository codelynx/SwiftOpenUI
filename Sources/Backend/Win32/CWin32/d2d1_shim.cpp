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
