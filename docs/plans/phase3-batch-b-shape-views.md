# Phase 3 Batch B — Shape Views

## Goal

Add Circle, Rectangle, RoundedRectangle, Capsule, Ellipse as View types with `.fill()` and `.stroke()` modifiers. These are the most commonly used SwiftUI visual primitives.

## Existing Foundation

- `Path` struct with full drawing commands (`Sources/SwiftOpenUI/Views/Path.swift`)
- `StrokeStyle`, `Shading`, `LineCap`, `LineJoin` types (same file)
- Canvas `DrawingContext.stroke(_:with:style:)` and `.fill(_:with:)` already work on GTK4 (Cairo) and Win32 (D2D)
- Web has Canvas2D imperative drawing but Path-based stroke/fill not yet wired

## Core Design (coordinator delivers)

### Shape Protocol

```swift
/// A 2D shape that can describe itself as a Path within a rectangle.
public protocol Shape: View {
    func path(in rect: CGRect) -> Path
}
```

Shapes are Views — they render themselves by generating a Path and filling it. Default rendering: filled with the foreground color.

### Concrete Shapes

All in `Sources/SwiftOpenUI/Views/Shapes.swift`:

```swift
public struct Circle: Shape, PrimitiveView {
    public typealias Body = Never
    public init() {}
    public func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect)
    }
}

public struct Rectangle: Shape, PrimitiveView {
    public typealias Body = Never
    public init() {}
    public func path(in rect: CGRect) -> Path {
        Path(rect)
    }
}

public struct RoundedRectangle: Shape, PrimitiveView {
    public typealias Body = Never
    public let cornerRadius: Double
    public let style: RoundedCornerStyle
    public init(cornerRadius: Double, style: RoundedCornerStyle = .circular) {
        self.cornerRadius = cornerRadius
        self.style = style
    }
}

public struct Capsule: Shape, PrimitiveView {
    public typealias Body = Never
    public let style: RoundedCornerStyle
    public init(style: RoundedCornerStyle = .circular) {
        self.style = style
    }
}

public struct Ellipse: Shape, PrimitiveView {
    public typealias Body = Never
    public init() {}
    public func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect)
    }
}

public enum RoundedCornerStyle {
    case circular
    case continuous
}
```

### Shape Modifiers

```swift
/// A shape filled with a color.
public struct FilledShape<S: Shape>: View, PrimitiveView {
    public typealias Body = Never
    public let shape: S
    public let color: Color
}

/// A shape stroked with a color and style.
public struct StrokedShape<S: Shape>: View, PrimitiveView {
    public typealias Body = Never
    public let shape: S
    public let color: Color
    public let style: StrokeStyle
}

extension Shape {
    public func fill(_ color: Color) -> FilledShape<Self>
    public func stroke(_ color: Color, lineWidth: Double = 1) -> StrokedShape<Self>
    public func stroke(_ color: Color, style: StrokeStyle) -> StrokedShape<Self>
}
```

### Default Rendering

A bare `Circle()` without `.fill()` or `.stroke()` should render as filled with the current foreground color (black by default). This matches SwiftUI behavior.

### Path Generation Notes

- **Circle**: `Path(ellipseIn: rect)` — inscribed in the bounding rect
- **Rectangle**: `Path(rect)` — fills the bounding rect
- **RoundedRectangle**: Needs `Path.addRoundedRect(in:cornerRadius:)` — add to Path if missing. Four arcs + four lines.
- **Capsule**: RoundedRectangle where cornerRadius = min(width, height) / 2
- **Ellipse**: Same as Circle — `Path(ellipseIn: rect)`

### Core Tests

`Tests/SwiftOpenUITests/ViewTests/ShapeTests.swift`:
- Each shape generates a non-empty Path
- Circle path in a square rect
- Rectangle path matches rect
- RoundedRectangle stores cornerRadius
- Capsule cornerRadius derived from rect dimensions
- FilledShape stores shape + color
- StrokedShape stores shape + color + style
- `.fill()` and `.stroke()` return correct wrapper types

---

## GTK4 Worker Instructions

### Context

Canvas already renders paths via Cairo (`GTKRenderer.swift` lines 4299-4370). The `applyPathElements` helper walks `Path.elements` and emits Cairo calls. Shapes need to render as filled/stroked paths using this existing infrastructure.

### What to implement

Add `GTKRenderable` extensions in `GTKRenderer.swift`.

### Shape rendering strategy

Each shape renders as a `GtkDrawingArea` with a Cairo draw callback — same pattern as Canvas. The draw callback:

1. Gets the allocated width/height from the widget
2. Calls `shape.path(in: CGRect(x: 0, y: 0, width: w, height: h))`
3. Applies path elements via the existing `applyPathElements` helper
4. Calls `cairo_fill()` (for bare shapes and FilledShape) or `cairo_stroke()` (for StrokedShape)

### Bare shapes (default fill)

For bare `Circle()`, `Rectangle()`, etc. without `.fill()` or `.stroke()`:
- Read the current foreground color from environment (or default to black)
- Fill the path with that color

### FilledShape / StrokedShape

- `FilledShape`: set `cairo_set_source_rgba` to the fill color, apply path, `cairo_fill()`
- `StrokedShape`: set `cairo_set_source_rgba` to the stroke color, set `cairo_set_line_width`, apply path, `cairo_stroke()`

### Sizing

Shapes should expand to fill available space (like SwiftUI). Use `gtk_widget_set_hexpand(widget, 1)` and `gtk_widget_set_vexpand(widget, 1)`. When used with `.frame()`, the frame modifier constrains the size.

### Tests

`Tests/BackendTests/GTK4Tests/GTK4ShapeTests.swift`:
- Circle renders a widget (not nil)
- Rectangle renders a widget
- RoundedRectangle renders a widget
- FilledShape renders a widget
- StrokedShape renders a widget
- Shape with .frame() produces correct size

### Files to edit

- `Sources/Backend/GTK4/Rendering/GTKRenderer.swift` — shape extensions
- `Tests/BackendTests/GTK4Tests/GTK4ShapeTests.swift` — new

### Files NOT to edit

- `Sources/SwiftOpenUI/` — coordinator owns
- `docs/` — coordinator owns

---

## Win32 Worker Instructions

### Context

Canvas renders paths via D2D (`WinRenderer.swift` lines 7090-7339). `fill()` uses fast paths for rectangles/ellipses and `ID2D1PathGeometry` for complex paths. Shapes need to render as D2D surfaces with filled/stroked paths.

### What to implement

Add `WinRenderable` extensions in `WinRenderer.swift`.

### Shape rendering strategy

Each shape renders as a D2D surface (same as Canvas). The draw callback:

1. Gets the surface dimensions
2. Calls `shape.path(in: CGRect(...))`
3. Uses existing `fill(_:with:)` or `stroke(_:with:style:)` on the drawing context

### Bare shapes (default fill)

For bare shapes, fill with the current foreground color (default black).

### FilledShape / StrokedShape

Use the existing D2D drawing context methods.

### Sizing

D2D surfaces have explicit dimensions. When no `.frame()` is applied, use a reasonable default (e.g., the parent context width/height or a standard size). When `.frame()` is applied, use those dimensions.

### Tests

`Tests/BackendTests/Win32Tests/Win32ShapeTests.swift`:
- Circle renders an HWND
- Rectangle renders an HWND
- FilledShape renders an HWND
- StrokedShape renders an HWND
- Shape with .frame() produces correct dimensions

### Files to edit

- `Sources/Backend/Win32/Rendering/WinRenderer.swift` — shape extensions
- `Tests/BackendTests/Win32Tests/Win32ShapeTests.swift` — new

### Files NOT to edit

- `Sources/SwiftOpenUI/` — coordinator owns
- `docs/` — coordinator owns

---

## Web Worker Instructions

### Context

Canvas renders via Canvas2D API but **Path-based stroke/fill is not yet wired for Web**. Shapes can be rendered using either:
- SVG elements (clean, scalable, CSS-styleable)
- Canvas2D with Path rendering
- Pure CSS (for simple shapes like circles and rectangles)

### Recommended approach: SVG

SVG is the cleanest fit for shape views on Web:
- `<svg>` container with `width="100%" height="100%"` to fill available space
- Shape-specific SVG element inside: `<circle>`, `<rect>`, `<ellipse>`
- Fill and stroke are native SVG attributes
- Scales naturally with CSS layout

### What to implement

Add `WebRenderable` extensions in `WebRenderer.swift`.

### Shape rendering

- **Circle**: `<svg><circle cx="50%" cy="50%" r="50%" fill="..."/></svg>`
  - Or use viewBox for precise sizing: `<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="50"/></svg>`
- **Rectangle**: `<svg><rect width="100%" height="100%" fill="..."/></svg>`
- **RoundedRectangle**: `<svg><rect width="100%" height="100%" rx="..." fill="..."/></svg>`
- **Capsule**: RoundedRectangle with rx = 50% of shorter dimension
- **Ellipse**: `<svg><ellipse cx="50%" cy="50%" rx="50%" ry="50%" fill="..."/></svg>`

### Bare shapes (default fill)

Use `fill="black"` as default (or read foreground color from environment if accessible).

### FilledShape / StrokedShape

- `FilledShape`: set SVG `fill` attribute to the color
- `StrokedShape`: set SVG `stroke` attribute, `stroke-width`, `fill="none"`

### Sizing

SVG elements with `width="100%" height="100%"` expand to fill the parent container. When used with `.frame()`, the frame wrapper constrains the size.

### Alternative: CSS-only for simple cases

If SVG feels heavy, simpler CSS approach:
- Circle: `<div>` with `border-radius: 50%; background: color;`
- Rectangle: `<div>` with `background: color;`
- RoundedRectangle: `<div>` with `border-radius: Xpx; background: color;`

Choose whichever approach is more consistent with the existing Web renderer patterns.

### Tests

`Tests/BackendTests/WebTests/WebShapeTests.swift`:
- Circle produces an element (not undefined)
- FilledShape wraps shape with color
- StrokedShape wraps shape with color and style
- Shape modifier chaining works

### Files to edit

- `Sources/Backend/Web/Rendering/WebRenderer.swift` — shape extensions
- `Tests/BackendTests/WebTests/WebShapeTests.swift` — new

### Files NOT to edit

- `Sources/SwiftOpenUI/` — coordinator owns
- `docs/` — coordinator owns

---

## Handoff Protocol

1. Coordinator pushes core branch with Shape protocol, 5 shapes, fill/stroke modifiers, core tests
2. Each platform worker:
   - `git fetch origin`
   - `git switch -C <platform>-shape-views-batch-b origin/<core-branch>`
   - `git rev-parse HEAD` — verify matches handoff hash
3. Platform workers edit ONLY their backend files + backend tests
4. Platform workers report back: branch, commit, base commit, changed files, tests run
5. Coordinator reviews and merges

## Known Limitations

- **RoundedRectangle** `style: .continuous` (superellipse) is visually identical to `.circular` in this batch — true continuous corners require platform-specific curve math
- **Web** may use SVG or CSS — either is acceptable as long as fill/stroke/sizing work
- **Win32** D2D fast paths exist for rectangles and ellipses — use them instead of generic PathGeometry where possible
- **Default sizing**: Shapes expand to fill available space; without `.frame()`, they may fill the entire parent. This matches SwiftUI behavior but may look unexpected in simple examples.

## Not In This Batch

- `.clipShape()` — clipping mask is a different rendering problem (Batch C)
- `.fill(style:)` with FillStyle (eoFill) — defer
- `.stroke(style:antialiased:)` — defer antialiased parameter
- `InsettableShape` protocol — defer
- `ShapeStyle` protocol (gradients, materials) — defer
