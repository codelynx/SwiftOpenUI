# Phase 3 Batch C — clipShape & clipped

## Goal

Add `.clipShape()` and `.clipped()` modifiers so views can be masked to arbitrary shapes or their own bounds.

## Existing Foundation

- Shape protocol + 5 shapes with `path(in:)` (Batch B)
- `.cornerRadius()` already clips on Win32 (`SetWindowRgn`) and Web (`overflow: hidden`) but NOT on GTK4 (CSS `border-radius` only styles, doesn't clip)
- Canvas `DrawingContext` has `save()`/`restore()` and path rendering on all backends
- GTK4 Cairo has `cairo_clip()` (needs shim binding)
- Win32 has `SetWindowRgn()` for region clipping
- Web has CSS `clip-path` and SVG `<clipPath>`

## Core Design (coordinator delivers)

### ClipShapeView

```swift
public struct ClipShapeView<Content: View, S: Shape>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let shape: S
    public var body: Never { fatalError() }
}

extension View {
    public func clipShape<S: Shape>(_ shape: S) -> ClipShapeView<Self, S> {
        ClipShapeView(content: self, shape: shape)
    }
}
```

### ClippedView

```swift
public struct ClippedView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public var body: Never { fatalError() }
}

extension View {
    public func clipped() -> ClippedView<Self> {
        ClippedView(content: self)
    }
}
```

`.clipped()` is equivalent to `.clipShape(Rectangle())` — clips to the view's bounds.

### Core Tests

- ClipShapeView stores shape and content
- ClippedView wraps content
- `.clipShape(Circle())` compiles and chains with other modifiers
- `.clipped()` compiles

---

## GTK4 Worker Instructions

### Context

GTK4's `.cornerRadius()` uses CSS `border-radius` which does NOT clip descendant content (documented in `CornerRadiusModifier.swift`). For real clipping, we need a different approach.

### Approach: GtkSnapshot clipping

GTK4 widgets can be clipped using `gtk_widget_set_overflow(widget, GTK_OVERFLOW_HIDDEN)` which clips child content to the widget's allocation. For shape-based clipping, use a `GtkDrawingArea` or custom snapshot with Cairo clip.

**Simpler approach for Batch C:** Wrap content in a container and use `overflow: hidden` CSS + shape the container with CSS `clip-path`.

```swift
extension ClipShapeView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        // Build CSS clip-path from shape
        let clipCSS = gtkBuildClipPathCSS(shape)
        applyCSSToWidget(widget, properties: "overflow: hidden; \(clipCSS)")
        return opaqueFromWidget(widget)
    }
}
```

### CSS clip-path generation

Map each shape to a CSS `clip-path` value:
- `Circle` → `clip-path: circle(50%);`
- `Ellipse` → `clip-path: ellipse(50% 50%);`
- `Rectangle` → `clip-path: inset(0);` (or just `overflow: hidden`)
- `RoundedRectangle` → `clip-path: inset(0 round Xpx);`
- `Capsule` → `clip-path: inset(0 round 9999px);`

### ClippedView

```swift
extension ClippedView: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        let widget = widgetFromOpaque(gtkRenderView(content))
        applyCSSToWidget(widget, properties: "overflow: hidden;")
        return opaqueFromWidget(widget)
    }
}
```

### Tests

`Tests/BackendTests/GTK4Tests/GTK4ClipShapeTests.swift`:
- ClipShapeView with Circle renders widget
- ClipShapeView with RoundedRectangle renders widget
- ClippedView renders widget
- Non-text content passes through

### Files to edit

- `Sources/Backend/GTK4/Rendering/GTKRenderer.swift`
- `Tests/BackendTests/GTK4Tests/GTK4ClipShapeTests.swift` — new

### Files NOT to edit

- `Sources/SwiftOpenUI/`, `docs/`, `CLAUDE.md`

---

## Win32 Worker Instructions

### Context

Win32's `.cornerRadius()` already uses `SetWindowRgn()` with `CreateRoundRectRgn()` to clip. This is the right mechanism — extend it for arbitrary shapes.

### Approach: Win32 regions

- `Rectangle` → use the HWND bounds directly (or `CreateRectRgn`)
- `RoundedRectangle` → `CreateRoundRectRgn()` (same as existing cornerRadius)
- `Circle` / `Ellipse` → `CreateEllipticRgn()`
- `Capsule` → `CreateRoundRectRgn()` with radius = min(w,h)/2

For complex shapes, `CreatePolygonRgn()` or `ExtCreateRegion()` from a path.

```swift
extension ClipShapeView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }
        var r = RECT()
        GetWindowRect(hwnd, &r)
        let w = r.right - r.left
        let h = r.bottom - r.top
        let rgn = winCreateShapeRegion(shape, width: w, height: h)
        if let rgn { SetWindowRgn(hwnd, rgn, true) }
        return hwnd
    }
}
```

### ClippedView

```swift
extension ClippedView: WinRenderable {
    public func winCreateWidget(in context: RenderContext) -> HWND? {
        guard let hwnd = winRenderView(content, in: context) else { return nil }
        var r = RECT()
        GetWindowRect(hwnd, &r)
        let rgn = CreateRectRgn(0, 0, r.right - r.left, r.bottom - r.top)
        SetWindowRgn(hwnd, rgn, true)
        return hwnd
    }
}
```

### Tests

`Tests/BackendTests/Win32Tests/Win32ClipShapeTests.swift`:
- ClipShapeView with Circle renders HWND
- ClipShapeView with RoundedRectangle renders HWND
- ClippedView renders HWND

### Files to edit

- `Sources/Backend/Win32/Rendering/WinRenderer.swift`
- `Tests/BackendTests/Win32Tests/Win32ClipShapeTests.swift` — new

### Files NOT to edit

- `Sources/SwiftOpenUI/`, `docs/`, `CLAUDE.md`

---

## Web Worker Instructions

### Context

Web's `.cornerRadius()` already uses `border-radius` + `overflow: hidden` which clips. For arbitrary shapes, use CSS `clip-path`.

### Approach: CSS clip-path

```swift
extension ClipShapeView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let wrapper = document.createElement("div")
        let clipCSS = webBuildClipPathCSS(shape)
        wrapper.style = .string("display: inline-block; overflow: hidden; \(clipCSS)")
        _ = wrapper.appendChild(child)
        return wrapper
    }
}
```

### CSS clip-path generation

- `Circle` → `clip-path: circle(50%);`
- `Ellipse` → `clip-path: ellipse(50% 50%);`
- `Rectangle` → `overflow: hidden;` (no clip-path needed)
- `RoundedRectangle` → `clip-path: inset(0 round Xpx);`
- `Capsule` → `clip-path: inset(0 round 9999px);`

### ClippedView

```swift
extension ClippedView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let wrapper = document.createElement("div")
        wrapper.style = .string("display: inline-block; overflow: hidden;")
        _ = wrapper.appendChild(child)
        return wrapper
    }
}
```

### Tests

`Tests/BackendTests/WebTests/WebClipShapeTests.swift`:
- ClipShapeView stores shape
- ClippedView wraps content
- CSS clip-path helper outputs correct values

### Files to edit

- `Sources/Backend/Web/Rendering/WebRenderer.swift`
- `Tests/BackendTests/WebTests/WebClipShapeTests.swift` — new

### Files NOT to edit

- `Sources/SwiftOpenUI/`, `docs/`, `CLAUDE.md`

---

## Handoff Protocol

Same as Batch A/B. Coordinator pushes core branch, workers start from it.

## Known Limitations

- **GTK4** CSS `clip-path` support depends on GTK4 version — some older builds may not support all values
- **Win32** region clipping is pixel-based, not anti-aliased — clipped edges may appear jagged
- **Web** CSS `clip-path` is well-supported in modern browsers but `inset(0 round Xpx)` may not work in older ones
- **Generic Shape clipping** (custom shapes beyond the 5 built-ins) deferred — would need Path-to-CSS-path or Path-to-region conversion

## Not In This Batch

- `.clipShape()` with generic custom Path-based shapes
- Anti-aliased clipping on Win32
- `ContainerRelativeShape`
