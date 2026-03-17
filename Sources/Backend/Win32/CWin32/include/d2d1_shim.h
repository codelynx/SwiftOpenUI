#pragma once

// Direct2D C shim layer for Swift.
//
// Swift's C++ interop (as of Swift 6.2) has a known bug where virtual
// method calls are dispatched statically instead of through the vtable.
// COM interfaces like ID2D1RenderTarget rely on vtable dispatch for all
// methods, so calling them directly from Swift produces incorrect results.
//
// This header provides C-linkage wrapper functions that the .cpp file
// implements as proper C++ COM vtable calls. When Swift's C++ interop
// gains correct virtual dispatch, these shims can be removed.
//
// All D2D COM pointers are exposed as opaque struct pointers so Swift
// imports them as distinct types rather than raw UnsafeMutableRawPointer.

#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN

#include <windows.h>

// Opaque handles for D2D/DWrite COM objects.
// Using struct pointers so Swift imports them as distinct OpaquePointer types.
typedef struct D2DFactoryImpl *D2DFactory;
typedef struct D2DRenderTargetImpl *D2DRenderTarget;
typedef struct D2DBrushImpl *D2DBrush;
typedef struct DWriteFactoryImpl *DWriteFactory;
typedef struct DWriteTextFormatImpl *DWriteTextFormat;
typedef struct DWriteTextLayoutImpl *DWriteTextLayout;

#ifdef __cplusplus
extern "C" {
#endif

// Factory
HRESULT d2d1_CreateFactory(D2DFactory *ppFactory);
void d2d1_Factory_Release(D2DFactory factory);

// HwndRenderTarget
HRESULT d2d1_Factory_CreateHwndRenderTarget(
    D2DFactory factory,
    HWND hwnd,
    UINT32 width,
    UINT32 height,
    D2DRenderTarget *ppTarget
);
void d2d1_HwndRenderTarget_Release(D2DRenderTarget target);
HRESULT d2d1_HwndRenderTarget_Resize(D2DRenderTarget target, UINT32 width, UINT32 height);

// Drawing
void d2d1_RenderTarget_BeginDraw(D2DRenderTarget target);
HRESULT d2d1_RenderTarget_EndDraw(D2DRenderTarget target);
void d2d1_RenderTarget_Clear(D2DRenderTarget target, float r, float g, float b, float a);

// Brush
HRESULT d2d1_RenderTarget_CreateSolidColorBrush(
    D2DRenderTarget target,
    float r, float g, float b, float a,
    D2DBrush *ppBrush
);
void d2d1_SolidColorBrush_SetColor(D2DBrush brush, float r, float g, float b, float a);
void d2d1_SolidColorBrush_Release(D2DBrush brush);

// Fill shapes
void d2d1_RenderTarget_FillRectangle(
    D2DRenderTarget target,
    D2DBrush brush,
    float x, float y, float width, float height
);

void d2d1_RenderTarget_FillEllipse(
    D2DRenderTarget target,
    D2DBrush brush,
    float centerX, float centerY, float radiusX, float radiusY
);

void d2d1_RenderTarget_FillRoundedRectangle(
    D2DRenderTarget target,
    D2DBrush brush,
    float x, float y, float width, float height,
    float radiusX, float radiusY
);

// Stroke (outline) shapes
void d2d1_RenderTarget_DrawRectangle(
    D2DRenderTarget target,
    D2DBrush brush,
    float x, float y, float width, float height,
    float strokeWidth
);

void d2d1_RenderTarget_DrawRoundedRectangle(
    D2DRenderTarget target,
    D2DBrush brush,
    float x, float y, float width, float height,
    float radiusX, float radiusY,
    float strokeWidth
);

void d2d1_RenderTarget_DrawEllipse(
    D2DRenderTarget target,
    D2DBrush brush,
    float centerX, float centerY, float radiusX, float radiusY,
    float strokeWidth
);

// --- DirectWrite ---

// Factory
HRESULT dwrite_CreateFactory(DWriteFactory *ppFactory);
void dwrite_Factory_Release(DWriteFactory factory);

// TextFormat (font configuration)
HRESULT dwrite_CreateTextFormat(
    DWriteFactory factory,
    const WCHAR *fontFamily,
    float fontSize,
    int bold,      // 0 = normal, 1 = bold
    int italic,    // 0 = normal, 1 = italic
    DWriteTextFormat *ppFormat
);
void dwrite_TextFormat_Release(DWriteTextFormat format);

// Set text alignment on a format
void dwrite_TextFormat_SetTextAlignment(DWriteTextFormat format, int alignment);
    // alignment: 0 = leading, 1 = trailing, 2 = center
void dwrite_TextFormat_SetParagraphAlignment(DWriteTextFormat format, int alignment);
    // alignment: 0 = near (top), 1 = far (bottom), 2 = center

// TextLayout (for measuring text)
HRESULT dwrite_CreateTextLayout(
    DWriteFactory factory,
    const WCHAR *text,
    UINT32 textLength,
    DWriteTextFormat format,
    float maxWidth,
    float maxHeight,
    DWriteTextLayout *ppLayout
);
void dwrite_TextLayout_Release(DWriteTextLayout layout);

// Get text metrics (for measuring)
HRESULT dwrite_TextLayout_GetMetrics(
    DWriteTextLayout layout,
    float *outWidth,
    float *outHeight
);

// Draw text on a D2D render target
void d2d1_RenderTarget_DrawText(
    D2DRenderTarget target,
    const WCHAR *text,
    UINT32 textLength,
    DWriteTextFormat format,
    D2DBrush brush,
    float x, float y, float width, float height
);

#ifdef __cplusplus
}
#endif
