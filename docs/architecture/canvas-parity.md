# Canvas Parity: SwiftUI vs SwiftOpenUI Backends

Comparison of SwiftUI's `Canvas` view capabilities and what each backend supports.

Last updated: 2026-03-19

## SwiftUI Canvas Overview

SwiftUI's `Canvas` is a high-level 2D rendering surface that provides:
- Immediate-mode drawing within a retained render pass
- Path construction (lines, arcs, curves, rectangles, ellipses)
- Stroke and fill with full style control (caps, joins, dash patterns, miter limits)
- Transform stack (translate, rotate, scale, concatenate)
- Graphics state save/restore (full state including clip, transform, blend mode)
- Alpha/opacity per-draw-call
- Resolved images, text, and child views drawn into the canvas
- Symbols (SF Symbols resolved at draw time)
- Blend modes and compositing control
- Filters (blur, shadow, color matrix)
- Shading styles (gradients, tiled images)
- Participates in SwiftUI's declarative invalidation and layout pipeline

## Backend Comparison

| Capability | SwiftUI | GTK4 (Cairo) | Win32 (D2D) | Web | Android |
|------------|---------|--------------|-------------|-----|---------|
| **Paths** | | | | | |
| moveTo / lineTo | Y | Y | Y | - | - |
| rectangle | Y | Y | Y | - | - |
| ellipse / circle | Y | Y | Y | - | - |
| arc (full) | Y | Y | Y | - | - |
| arc (partial) | Y | Y | ~ (stroke-only, line segments) | - | - |
| bezier curves | Y | Y | - | - | - |
| quadratic curves | Y | Y | - | - | - |
| **Stroke / Fill** | | | | | |
| stroke() | Y | Y | Y | - | - |
| fill() | Y | Y | Y | - | - |
| Line width | Y | Y | Y | - | - |
| Line cap styles | Y | Y | - | - | - |
| Line join styles | Y | Y | - | - | - |
| Dash patterns | Y | Y | - | - | - |
| Miter limit | Y | - | - | - | - |
| **Color / Alpha** | | | | | |
| RGB color | Y | Y | Y | - | - |
| RGBA (alpha) | Y | Y | Y | - | - |
| **Transforms** | | | | | |
| scale | Y | Y | Y | - | - |
| rotate | Y | Y | - | - | - |
| translate | Y | Y | - | - | - |
| concatenate | Y | Y | - | - | - |
| **State** | | | | | |
| save / restore | Y | Y | Y | - | - |
| Color in state | Y | Y | Y | - | - |
| Transform in state | Y | Y | Y | - | - |
| Clip in state | Y | Y | - | - | - |
| **Advanced** | | | | | |
| Resolved text | Y | - | - | - | - |
| Resolved images | Y | - | - | - | - |
| Resolved child views | Y | - | - | - | - |
| SF Symbols | Y | - | - | - | - |
| Blend modes | Y | - | - | - | - |
| Filters (blur, etc.) | Y | - | - | - | - |
| Gradients / shading | Y | - | - | - | - |
| Compositing control | Y | - | - | - | - |
| paint() (fill surface) | Y | Y | Y | - | - |

## Per-Backend Notes

### GTK4 (Cairo)

Cairo is a mature 2D graphics library with strong path, transform, and compositing support.
Most of the core Canvas API maps directly to Cairo calls.

- **Strengths**: Full path support (bezier, quadratic, arc), line cap/join styles, proper clip regions, save/restore with full state, surface-to-surface painting.
- **Gaps**: No resolved views/images/symbols (SwiftUI-specific), no built-in blur/filter effects (would need separate Cairo surface compositing).
- **Implementation**: `DrawingContext.cr` wraps a Cairo context (`cairo_t*`). Extensions in `GTKRenderer.swift` call `cairo_*` functions directly.

### Win32 (Direct2D)

D2D provides hardware-accelerated 2D rendering with good path, transform, and alpha support.
The Canvas implementation uses a retained-path model with deferred stroke/fill.

- **Strengths**: D2D-backed (antialiased, alpha-capable, transform-aware), path accumulation with deferred stroke/fill for rectangles and ellipses, state save/restore includes transform matrix.
- **Gaps**:
  - **Partial arcs**: Stroke-only approximation via line segments. `fill()` skips arc elements (filling arbitrary arc segments would require `ID2D1PathGeometry`). Acceptable for most stroke use cases; visible at large radii or animated zoom.
  - **Stroke styles**: Line cap, join, dash patterns not yet implemented. Would require `ID2D1StrokeStyle` creation via a new shim.
  - **Curves**: Bezier and quadratic curves not implemented. Would require `ID2D1PathGeometry` with `ID2D1GeometrySink` via new shims.
  - **Rotate/translate**: Not yet exposed (D2D `SetTransform` infrastructure exists but only `scale` is wired up).
  - **Clip regions**: Not implemented.
  - **No resolved views/images/symbols/filters** (same as all backends).
- **Implementation**: `DrawingContext.cr` holds an `OpaquePointer` to a `D2DCanvasContext` class. Path elements are accumulated and executed on `stroke()`/`fill()`. D2D render target and brush are managed by `CanvasDrawState` with proper lifecycle cleanup.
- **Adding new capabilities**: Most gaps can be closed by adding C-linkage wrappers to `d2d1_shim.h` / `d2d1_shim.cpp` for the relevant D2D COM calls, then wiring them into the `DrawingContext` extensions.

### Web (DOM/Canvas2D)

Not yet implemented. The browser's `<canvas>` element with Canvas2D API would be a natural fit and could achieve near-complete parity with the drawing API.

### Android (Skia/Canvas)

Not yet implemented. Android's `Canvas` API (backed by Skia) provides strong 2D drawing capabilities that would map well to this API.

## Practical Assessment

| Backend | Level | Good For |
|---------|-------|----------|
| GTK4 | Strong subset | Custom drawing, charts, vector graphics, interactive overlays |
| Win32 | Functional subset | Basic custom drawing, charts, simple vector scenes |
| Web | Not implemented | — |
| Android | Not implemented | — |

None of the backends currently match the full SwiftUI `Canvas` which includes resolved views, symbols, filters, blend modes, and declarative invalidation. All backends implement the core 2D drawing primitives that cover the majority of real-world Canvas usage.

## Adding Canvas Support to a New Backend

1. Create a native drawing surface (Cairo surface, D2D render target, Canvas2D context, Skia canvas, etc.)
2. Extend `DrawingContext` with platform-specific methods that interpret the `cr` field as your native context
3. Implement `Canvas: YourRenderable` to create the surface and invoke the user's `drawHandler`
4. Ensure `stroke()` and `fill()` execute accumulated paths (not immediate-mode drawing)
5. Implement `save()`/`restore()` with full state including transforms
6. See GTK4 (`GTKRenderer.swift`) and Win32 (`WinRenderer.swift`) for reference implementations
