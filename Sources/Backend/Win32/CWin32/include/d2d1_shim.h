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

// --- Stroke Style ---

typedef struct D2DStrokeStyleImpl *D2DStrokeStyle;

// Create a stroke style with line cap, join, and optional dash pattern.
// capStyle: 0 = flat, 1 = square, 2 = round, 3 = triangle
// lineJoin: 0 = miter, 1 = bevel, 2 = round, 3 = miter-or-bevel
// dashes:   pointer to an array of dash/gap lengths (NULL = solid)
// dashCount: number of elements in the dashes array (0 = solid)
// dashOffset: starting offset into the dash pattern
HRESULT d2d1_Factory_CreateStrokeStyle(
    D2DFactory factory,
    int capStyle,
    int lineJoin,
    const float *dashes,
    int dashCount,
    float dashOffset,
    D2DStrokeStyle *ppStyle
);
void d2d1_StrokeStyle_Release(D2DStrokeStyle style);

// Styled draw functions (with stroke style parameter)
void d2d1_RenderTarget_DrawLineStyled(
    D2DRenderTarget target,
    D2DBrush brush,
    float x1, float y1, float x2, float y2,
    float strokeWidth,
    D2DStrokeStyle style
);

void d2d1_RenderTarget_DrawRectangleStyled(
    D2DRenderTarget target,
    D2DBrush brush,
    float x, float y, float width, float height,
    float strokeWidth,
    D2DStrokeStyle style
);

void d2d1_RenderTarget_DrawRoundedRectangleStyled(
    D2DRenderTarget target,
    D2DBrush brush,
    float x, float y, float width, float height,
    float radiusX, float radiusY,
    float strokeWidth,
    D2DStrokeStyle style
);

void d2d1_RenderTarget_DrawEllipseStyled(
    D2DRenderTarget target,
    D2DBrush brush,
    float centerX, float centerY, float radiusX, float radiusY,
    float strokeWidth,
    D2DStrokeStyle style
);

// --- Path Geometry ---

typedef struct D2DPathGeometryImpl *D2DPathGeometry;
typedef struct D2DGeometrySinkImpl *D2DGeometrySink;

HRESULT d2d1_Factory_CreatePathGeometry(D2DFactory factory, D2DPathGeometry *ppGeometry);
HRESULT d2d1_PathGeometry_Open(D2DPathGeometry geometry, D2DGeometrySink *ppSink);

void d2d1_GeometrySink_BeginFigure(D2DGeometrySink sink, float x, float y, int filled);
void d2d1_GeometrySink_AddLine(D2DGeometrySink sink, float x, float y);
void d2d1_GeometrySink_AddBezier(D2DGeometrySink sink,
    float c1x, float c1y, float c2x, float c2y, float ex, float ey);
void d2d1_GeometrySink_AddArc(D2DGeometrySink sink,
    float ex, float ey, float rx, float ry, float rotation, int sweep, int arcSize);
void d2d1_GeometrySink_EndFigure(D2DGeometrySink sink, int closed);
HRESULT d2d1_GeometrySink_Close(D2DGeometrySink sink);
void d2d1_GeometrySink_Release(D2DGeometrySink sink);
void d2d1_PathGeometry_Release(D2DPathGeometry geometry);

void d2d1_RenderTarget_FillGeometry(D2DRenderTarget target, D2DPathGeometry geometry, D2DBrush brush);
void d2d1_RenderTarget_DrawGeometry(D2DRenderTarget target, D2DPathGeometry geometry,
    D2DBrush brush, float strokeWidth);
void d2d1_RenderTarget_DrawGeometryStyled(D2DRenderTarget target, D2DPathGeometry geometry,
    D2DBrush brush, float strokeWidth, D2DStrokeStyle style);

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

// Draw a line between two points
void d2d1_RenderTarget_DrawLine(
    D2DRenderTarget target,
    D2DBrush brush,
    float x1, float y1, float x2, float y2,
    float strokeWidth
);

// --- WIC (Windows Imaging Component) ---

typedef struct WICFactoryImpl *WICFactory;
typedef struct WICBitmapImpl *WICBitmap;

// Create WIC imaging factory
HRESULT wic_CreateFactory(WICFactory *ppFactory);
void wic_Factory_Release(WICFactory factory);

// Load an image file (PNG, JPEG, BMP, GIF, TIFF, ICO) and convert to
// a 32bpp BGRA pixel buffer. Caller must free *ppPixels with free().
// Returns image dimensions in *outWidth / *outHeight.
HRESULT wic_LoadImageFile(
    WICFactory factory,
    const WCHAR *filePath,
    UINT32 *outWidth,
    UINT32 *outHeight,
    BYTE **ppPixels
);

// Transform
void d2d1_RenderTarget_SetTransform(
    D2DRenderTarget target,
    float m11, float m12, float m21, float m22, float dx, float dy
);

// Set transform to identity (reset)
void d2d1_RenderTarget_SetTransformIdentity(D2DRenderTarget target);

#ifdef __cplusplus
}
#endif
