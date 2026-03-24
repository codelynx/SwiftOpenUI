# Proposal: Portable Graphics Context for SwiftOpenUI

## Goal

Provide a platform-independent 2D drawing layer -- analogous to
CoreGraphics on Apple or Cairo on Linux -- so that client code using
`Canvas` does not need `#if` branches for different platforms.

Features not yet implemented on a backend are gated at compile time
(see "Platform gap mechanism" below), not silently dropped.

This is **not** scoped to SimplePaint. Any app using `Canvas` benefits:
charts, diagrams, games, custom controls.

## Problem

Today, any Canvas-using code requires two code paths:

```swift
#if os(macOS)
SwiftUI.Canvas { context, size in          // GraphicsContext + Path
    drawStrokeMac(context, stroke: stroke)
}
#else
Canvas(width: 600, height: 440) { context, w, h in  // DrawingContext (imperative)
    drawStroke(context, stroke: stroke)
}
#endif
```

Two view signatures, two drawing functions, duplicated logic. This
contradicts "write SwiftUI, run anywhere."

## Current API Differences

| | SwiftUI (macOS) | SwiftOpenUI |
|---|---|---|
| Canvas init | `Canvas { context, size in }` | `Canvas(width:height:) { context, w, h in }` |
| Context type | `GraphicsContext` | `DrawingContext` |
| Drawing model | Path-based: `context.stroke(path, with:)` | Imperative: `context.moveTo(); context.stroke()` |
| Color | `with: .color(.red)` | `context.setColor(r:g:b:)` |
| Transforms | Full affine via `.transform` | `scale(x:y:)` only |
| Stroke style | lineCap, lineJoin, dash | lineCap/lineJoin wired via D2D stroke styles; dash not yet |
| Clipping | `context.clip(to:)` | Not implemented |

## Verified Backend Implementation Status

Audited against actual source code, not documentation.

### Portable today (implemented on all three backends)

| Operation | GTK4 (Cairo) | Win32 (D2D) | Web (Canvas2D) |
|-----------|-------------|-------------|----------------|
| moveTo, lineTo | Direct cairo call | Deferred path array | Direct JS call |
| rectangle | Direct cairo call | Deferred path array | Direct JS call |
| arc (full + partial) | Direct cairo call | Deferred; partial arcs approximated with line segments | Direct JS call |
| stroke | All path types | All path types | All path types |
| setColor (RGB + RGBA) | cairo_set_source_rgb/rgba | Stores in context state | Sets strokeStyle + fillStyle |
| setLineWidth | Direct cairo call | Stores in context state | Direct JS property |
| paint (fill entire surface) | Direct cairo call | FillRectangle on full area | fillRect on full area |
| save / restore | Direct cairo call | Full state push/pop (colors, lineWidth, transform) | Direct JS call |
| scale | Direct cairo call | 3x2 transform matrix composition | Direct JS call |

### Partially portable (behavioral differences across backends)

| Operation | GTK4 | Win32 | Web | Issue |
|-----------|------|-------|-----|-------|
| fill | All path types | All path types (via ID2D1PathGeometry) | All path types | |
| setLineCap | Wired to cairo | Wired via D2D stroke style | Wired to Canvas2D | |
| setLineJoin | Wired to cairo | Wired via D2D stroke style | Wired to Canvas2D | |

### Not implemented on any backend

These operations are supported by the underlying native APIs (Cairo,
D2D, Canvas2D) but SwiftOpenUI has not exposed them in `DrawingContext`:

| Operation | Cairo support | D2D support | Canvas2D support |
|-----------|-------------|-------------|-----------------|
| translate | Yes | Yes (transform matrix) | Yes |
| rotate | Yes | Yes (transform matrix) | Yes |
| Bezier curves (cubic) | Yes | Yes (ID2D1PathGeometry) | Yes |
| Quadratic curves | Yes | Yes (ID2D1PathGeometry) | Yes |
| Clipping | Yes | Yes (PushAxisAlignedClip / geometry) | Yes |
| Dash patterns | Yes | Yes (ID2D1StrokeStyle) | Yes |
| Blend modes | Yes | Partial | Yes |
| Image drawing | Not wired | Not wired | Not wired |
| Text drawing | Not wired | Not wired | Not wired |

The native APIs support all of these. The gap is purely in SwiftOpenUI's
`DrawingContext` extension layer, not in platform capability.

## Design Principles

1. **Portable subset first.** Define the operations that all backends
   implement today and build the public API around them. Do not expose
   operations in the public API until they work on all backends.

2. **Platform gaps are compile-time gated where practical for initial
   milestones, not silent no-ops.** See "Platform gap mechanism" below.

3. **CoreGraphics/Cairo mental model, SwiftUI-shaped API.** The drawing
   primitives follow CoreGraphics concepts (paths, stroke/fill, affine
   transforms, graphics state save/restore) but the public API matches
   SwiftUI naming (`GraphicsContext`, `Path`, `StrokeStyle`).

4. **Imperative API remains as the backend layer.** The current
   `DrawingContext` with `moveTo`/`lineTo`/`stroke` is the internal
   implementation bridge to Cairo, D2D, and DOM Canvas. The public API
   wraps it; it is not removed.

5. **Canvas gets its size from layout, not init.** Aligning with SwiftUI
   requires Canvas to receive its resolved size from the layout system,
   not from `Canvas(width:height:)`. This is an architectural change --
   see Milestone 1.

## Platform Gap Mechanism

Swift's `@available` checks OS versions, not rendering backends.
`#if canImport(BackendGTK4)` gates code per compile target, but
SwiftOpenUI's value is shared source across targets.

For the initial milestones, the practical approach is:

- **Portable subset operations**: No annotation. Guaranteed everywhere.
- **Extended operations**: Gated with `#if canImport(BackendGTK4)` or
  similar per-backend guards. Client code that needs bezier curves on
  GTK4 wraps the call in a compile-time check.
- **Future**: If the project adopts a custom availability annotation
  (e.g., `@backendAvailable(gtk4, web)`), extended operations can
  migrate to that. This is not required for the initial milestones.

The mechanism is intentionally simple. A more sophisticated system can
be designed later if the project's cross-compilation model demands it.

## Milestones

### Milestone 0: Canvas invalidation on state change (prerequisite)

Canvas must reliably repaint when `@State` changes during interaction.
Without this, no Canvas API -- unified or not -- is usable for
interactive apps.

**Status**: Complete on Win32 and GTK4. Win32 fixed via `RedrawWindow`
after onDrag callbacks. GTK4 already handled via narrow mutation path
(`gtkSetCanvasContent` + `gtk_widget_queue_draw`). Web to be verified.

### Milestone 1: Canvas size from layout

Change the public `Canvas` API so size is no longer constructor-owned
state. The draw closure receives the resolved layout size, not a value
baked in at init time.

**Why this is not trivial**: The current `Canvas` primitive stores
`width`/`height` in its struct fields and passes `(Int, Int)` into the
draw closure. The real work is two things:

1. Changing the public API so `Canvas` no longer treats width/height as
   constructor-owned state.
2. Making the canvas widget participate correctly in parent-driven
   layout so its resolved size reflects the layout system's decision,
   not a fixed init value.

Each backend already knows the resolved size at paint time (Win32 via
`GetClientRect`, GTK4 via allocated width/height, Web via element
dimensions). The gap is that the `Canvas` primitive bypasses layout by
owning its size directly, and the backends create widgets at exactly
that fixed size without opting into parent-driven expansion.

**Per-backend work**:
- **GTK4**: Set `hexpand`/`vexpand` when Canvas should fill proposed
  space. In the `draw` signal, pass allocated size to the closure.
  Relatively straightforward -- GTK already has this concept.
- **Win32**: Canvas HWND must participate in stack layout expansion
  when the parent allocates more space (not greedily always, but when
  layout context dictates). On `WM_PAINT`, pass `GetClientRect`
  dimensions into the closure instead of stored init values.
- **Web**: Pass resolved canvas element dimensions in the paint callback.

**Decision required before implementation**:

The old `Canvas(width:height:)` init must have clearly defined semantics:

| Option | Behavior | Migration impact |
|--------|----------|-----------------|
| **A: Fixed default size** | Equivalent to new-init + `.frame(width:height:)`. Canvas proposes that size to layout but can be overridden by parent. | Non-breaking. Old call sites behave the same unless parent overrides. |
| **B: Intrinsic minimum** | Canvas has a minimum size of width x height but can grow if parent offers more space. | Subtle behavior change -- old canvases may grow unexpectedly. |
| **C: Deprecated** | Marked `@available(*, deprecated)`. Migration to new init + `.frame()`. | Breaking for existing code. Clean long-term but disruptive. |

**Recommendation**: Option A. It preserves existing behavior, matches
SwiftUI's model (Canvas has no intrinsic size -- it takes whatever the
parent proposes), and the `.frame()` modifier is already the standard
way to constrain size.

**Deliverable**: `Canvas { context, size in }` compiles and receives
correct layout-resolved size on all backends. `Canvas(width:height:)`
coexists as Option A convenience.

**Size type**: Use Foundation's `CGSize` (available on all platforms via
swift-corelibs-foundation). This gives the cleanest compatibility with
SwiftUI call sites and avoids introducing a project-specific type that
diverges from the ecosystem.

### Milestone 2: Path type + portable stroke/fill

Introduce `SwiftOpenUI.Path` with the operations that all backends
can already support:

```swift
public struct Path {
    public mutating func move(to point: CGPoint)
    public mutating func addLine(to point: CGPoint)
    public mutating func addRect(_ rect: CGRect)
    public mutating func addEllipse(in rect: CGRect)
    public mutating func addArc(center:radius:startAngle:endAngle:clockwise:)
}
```

Add path-based drawing to the context:

```swift
context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 2))
context.fill(path, with: .color(.blue))
```

**Blockers before this ships**:
- ~~Win32: Wire lineCap/lineJoin via D2D stroke styles~~ (done)
- Win32: Implement fill for arbitrary paths via ID2D1PathGeometry

Backend implementations walk `Path` elements and emit native calls.

**Deliverable**: Drawing code using the portable subset compiles
identically across platforms.

### Milestone 3: Portable drawing context (public API)

Expose a SwiftUI-compatible drawing context wrapping the backend-specific
`DrawingContext`. Scope is strictly limited to the portable subset plus
operations added to all backends during this milestone:

```swift
// Portable subset -- guaranteed on all backends
context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: 2))
context.fill(path, with: .color(.blue))
context.concatenate(CGAffineTransform(scaleX: 2, y: 2))
```

**Prerequisites**: translate and rotate must be implemented on all three
backends before they can appear in this API. They are currently missing
on all backends despite native API support.

**Non-goals for this milestone**: Image drawing, text drawing, resolved
symbols, filters, blend modes, child view rendering, clipping, bezier
curves, dash patterns. These require further backend work and should be
separate proposals.

**Deliverable**: `Canvas { context, size in }` with a SwiftUI-shaped
portable drawing context for the supported subset. On macOS,
`import SwiftUI` provides the real type; on other platforms, SwiftOpenUI
provides the compatible type.

## What Unified Client Code Looks Like

```swift
// No #if os(macOS) in the view layer
Canvas { context, size in
    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))

    for stroke in strokes {
        var path = Path()
        path.move(to: stroke.points[0])
        for point in stroke.points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(path, with: .color(stroke.color),
                        style: StrokeStyle(lineWidth: stroke.width))
    }
}
.frame(width: 600, height: 440)
.onDrag(...)
```

Same code, all platforms. Platform differences handled at the framework
level, not in client code.

## Decisions Made

1. **CGSize/CGPoint**: Use Foundation's `CGSize` (available on all
   platforms via swift-corelibs-foundation). Cleanest SwiftUI
   compatibility.

2. **Canvas(width:height:) semantics**: Option A (fixed default size).
   Equivalent to new init + `.frame(width:height:)`. Non-breaking.

## Open Questions

1. **Performance**: Path intermediate representation adds allocation.
   For high-frequency drawing, should the imperative `DrawingContext`
   remain accessible as a low-level escape hatch?

2. **StrokeStyle.lineCap in portable subset**: lineCap/lineJoin are
   now wired on all three backends (GTK4 via Cairo, Win32 via D2D
   stroke styles, Web via Canvas2D). They can be included in the
   portable subset.
