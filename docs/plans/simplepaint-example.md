# SimplePaint Example Plan

## Goal

Add a small but credible paint app to `Examples/Showcase/` that demonstrates SwiftOpenUI as a productivity-style UI toolkit, not just a demo toolkit.

The app should feel closer to "Pinta Lite" than a gesture toy:

- simple enough to understand in one file
- complete enough to use for actual drawing
- single shared app code for macOS, Linux, and Windows
- explicitly not blocked on Web support

`~/Projects/Pinta` is a reference for tool organization and window structure, not a source to port directly.

## Product Definition

This example is intentionally **MacPaint-class**, not Photoshop-class.

### Must Have in v1

- drawing canvas
- pencil tool
- eraser tool
- straight line tool
- rectangle tool
- ellipse tool
- stroke color selection
- brush size selection
- undo and redo
- clear/new canvas
- top toolbar
- inspector panel for tool options and colors
- stable cross-platform layout on macOS, Linux, and Windows

### Explicitly Out of Scope for v1

- layers
- selections
- text tool
- gradients
- filters/effects
- blend modes
- file browser integration
- document-based app APIs
- print support
- web target

## Why This Example Matters

Current showcase apps prove basic widgets and layout, but they do not prove that SwiftOpenUI can support a real app shell with:

- toolbar actions
- split layout
- inspector-style controls
- continuous pointer input
- custom drawing
- undoable document state

SimplePaint should become the first showcase app that exercises those concerns together.

## Target Platforms

### Supported

- macOS
- Linux GTK4
- Windows Win32

### Not a Release Target for This Plan

- Web

Reason: `Canvas` is not in a state where a Web version should be part of the success criteria yet. The example should not wait on that backend.

## Architecture Direction

The current draft used a retained vector-stroke document model. That is the right v1 choice for SwiftOpenUI today.

Why:

- it stays inside the current cross-platform `Canvas` API
- it avoids introducing bitmap/image compositing primitives first
- undo/redo is straightforward
- shapes and freehand drawing can share one rendering path

This is not how a full raster editor would eventually want to store its document, but it is the best fit for a small, honest showcase example.

## App Layout

The app should present as a three-region productivity window:

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Toolbar: New  Undo  Redo   Pencil Eraser Line Rect Ellipse   Size  │
├───────────────┬───────────────────────────────────────┬─────────────┤
│ Tool strip    │                                       │ Inspector   │
│               │               Canvas                   │             │
│               │                                       │ Color       │
│               │                                       │ Brush       │
│               │                                       │ Tool opts   │
├───────────────┴───────────────────────────────────────┴─────────────┤
│ Status: tool, cursor position, canvas size                           │
└──────────────────────────────────────────────────────────────────────┘
```

### Proposed SwiftOpenUI Structure

- top-level `VStack`
- app content in `NavigationSplitView`
- left column: compact tool list / tool palette
- center column: drawing canvas
- right column: inspector panel
- toolbar for global actions and quick tool switching

This keeps the example aligned with existing SwiftOpenUI primitives instead of inventing a custom window manager.

`NavigationSplitView` is not optional for this concept. If it fails to support the app shell cleanly on macOS, Linux, or Windows, the correct response is to fix `NavigationSplitView`, not to retreat to an ad hoc stacked layout. That is part of the proof of concept.

## UI Breakdown

### Toolbar

Toolbar actions should be limited to high-value commands:

- `New`
- `Undo`
- `Redo`
- primary tool shortcuts

The toolbar is for quick actions, not every setting.

### Left Tool Panel

The left panel should stay narrow and simple:

- pencil
- eraser
- line
- rectangle
- ellipse

This gives the app a recognizably "paint app" structure without needing a large command surface.

### Center Canvas

The canvas should be the visual focus:

- white drawing surface
- neutral surrounding background
- fixed default document size
- drag-to-draw interaction
- live preview while shape tools are in progress

### Right Inspector

The inspector should carry adjustable state, not commands:

- current color swatches
- brush size slider
- selected tool readout
- shape mode options if needed later

For v1, the inspector can stay intentionally small.

## Document Model

```swift
enum PaintTool {
    case pencil
    case eraser
    case line
    case rectangle
    case ellipse
}

struct PaintPoint {
    var x: Double
    var y: Double
}

struct PaintColor {
    var r: Double
    var g: Double
    var b: Double
}

struct Stroke {
    var tool: PaintTool
    var points: [PaintPoint]   // freehand: many points, shapes: start/end
    var color: PaintColor
    var lineWidth: Double
}
```

### View State

- `@State var committedStrokes: [Stroke]`
- `@State var redoStrokes: [Stroke]`
- `@State var activeStroke: Stroke?`
- `@State var selectedTool: PaintTool`
- `@State var selectedColor: PaintColor`
- `@State var brushSize: Double`

### Behavior

- commit on drag end
- `Undo` pops from `committedStrokes` into `redoStrokes`
- `Redo` restores from `redoStrokes`
- any new drawing clears redo history
- `New` clears both stacks after confirmation if we have a dialog path; otherwise clear immediately in v1

## Rendering Model

Render by replaying committed strokes plus the active preview stroke on every draw pass.

Order:

1. paint canvas background
2. draw committed strokes
3. draw active preview stroke

### Stroke Rules

- pencil: polyline with rounded caps/join where supported
- eraser: same geometry as pencil, but rendered in canvas background color
- line: start to end
- rectangle: bounding box from drag start/end
- ellipse: ellipse from drag start/end

## Gesture Model

Attach `.onDrag(minimumDistance:onChanged:onEnded:)` directly to the canvas.

### onChanged

- if `activeStroke` is nil, create it from `startLocation`
- pencil and eraser append sampled points as the pointer moves
- line/rectangle/ellipse update the second point only

### onEnded

- finalize the last geometry update
- append to `committedStrokes` if the stroke is valid
- clear `activeStroke`
- clear redo history

## Cross-Platform Code Strategy

Use one shared `main.swift` for the app, matching the existing showcase pattern.

### Allowed Platform Differences

- import and launch boilerplate
- thin compatibility wrappers if SwiftUI on macOS needs a slightly different `Canvas` or gesture call site

### Avoid

- separate app logic per platform
- separate layout per platform
- separate document model per platform

The plan should optimize for one codepath with small compatibility seams, not parallel implementations.

## Existing SwiftOpenUI Features We Should Use

- `Canvas`
- `.onDrag(...)`
- `NavigationSplitView`
- `.navigationSplitViewColumnWidth(...)`
- `toolbar`
- `Button`
- `Slider`
- `VStack`, `HStack`, `ZStack`
- `Color`

## Framework Gaps — Audit Results (2026-03-23)

This example should also help us sharpen SwiftOpenUI itself. The following gaps were audited against the current codebase.

### Critical — Must Fix Before Phase 3

#### 1. Canvas does NOT redraw on @State change (GTK4, Win32)

**Status: BLOCKER**

The `Canvas` draw handler runs once at widget creation. When `@State` changes in an ancestor view (e.g. appending a stroke), the native canvas widget persists with stale content. GTK4's `gtk_drawing_area_set_draw_func` callback is not re-invoked. Win32's `WM_PAINT` is not triggered. The Web backend works by accident — it recreates the `<canvas>` DOM element on state change.

This completely blocks the retained-stroke rendering model. Without this fix, nothing will appear on screen during or after drawing.

**Fix options:**
1. Track Canvas widgets in ViewHost and call `gtk_widget_queue_draw()` (GTK4) / `InvalidateRect()` (Win32) when state changes trigger a re-render
2. Destroy and recreate the canvas widget on state change (matches Web behavior, less efficient)

**Relevant files:**
- `Sources/Backend/GTK4/Rendering/GTKRenderer.swift` — Canvas rendering, `gtk_drawing_area_set_draw_func`
- `Sources/Backend/Win32/Rendering/WinRenderer.swift` — Canvas rendering, `canvasPaintProc`

#### 2. Win32 missing `setLineCap()` / `setLineJoin()`

**Status: REQUIRED for acceptable freehand quality**

Both methods are no-ops on Win32. D2D stroke styling requires `ID2D1StrokeStyle` creation via `ID2D1Factory::CreateStrokeStyle()`, which needs additional C bindings not yet in `d2d1_shim`. Without round caps/joins, the pencil tool will produce jagged, disconnected line segments.

GTK4 and Web both support these fully.

**Relevant files:**
- `Sources/Backend/Win32/Rendering/WinRenderer.swift` — DrawingContext extension
- Win32 D2D shim C bindings

### Confirmed Working — No Framework Changes Needed

| Feature | GTK4 | Win32 | Notes |
|---------|------|-------|-------|
| **NavigationSplitView 3-column** | Y | Y | Nested GtkPaned / HWNDs + layout proc |
| **Column width modifiers** | Y | Y | Mirror-walking extraction, min/ideal/max |
| **Draggable dividers** | Y | Y | Native GtkPaned / WM_MOUSEMOVE hit-test |
| **Column visibility binding** | Y | Y | `gtk_widget_set_visible` / `ShowWindow` |
| **Toolbar multiple items** | Y | Y | Via `ToolbarProvider` extraction |
| **Toolbar leading/trailing** | Y | Y | `pack_start`/`pack_end` (GTK4), positioned (Win32) |
| **Drag gesture on Canvas** | Y | Y | Gesture attaches to canvas widget correctly |
| **Canvas basic drawing** | Y | Y | Color, paths, stroke, fill, line width |
| **`setLineCap` / `setLineJoin`** | Y | **N** | See critical gap #2 above |

### NavigationSplitView Acceptance Criteria

Since `NavigationSplitView` is required as the app shell (not optional), the following must hold:

- [ ] Left panel respects `.navigationSplitViewColumnWidth()` on initial layout
- [ ] Right inspector respects column width constraints
- [ ] Center canvas expands to fill remaining space
- [ ] Dividers are draggable on GTK4 and Win32
- [ ] Window resize does not break column proportions
- [ ] GTK4: GtkPaned positions stay stable across resize
- [ ] Win32: `SplitViewState` recalculates correctly on `WM_SIZE`
- [ ] Column visibility (`.doubleColumn`, `.detailOnly`) works if used

### Non-Blocking Notes

- **Toolbar API** accepts one `ToolbarItem` per `.toolbar()` call. Multiple items require chaining `.toolbar()` modifiers. Acceptable for v1 (SimplePaint needs ~5 toolbar items).
- **Win32 column visibility** is currently static at creation time (does not respond to binding changes dynamically). Acceptable for v1 since SimplePaint does not toggle visibility.
- **Ellipse rendering** requires `save()` + `scale()` + `arc()` trick. Win32 `scale()` is supported. Line width will be distorted by scale — acceptable visual tradeoff for v1.
- **Web backend** is explicitly out of scope for this plan.

## Implementation Phases

### Phase 1: Lock the Example Shape

- settle exact v1 feature list
- settle window layout
- decide final target name: `SimplePaint`
- confirm no Web requirement

### Phase 2: Close Framework Gaps

- [ ] **Fix Canvas redraw on @State change (GTK4)** — call `gtk_widget_queue_draw()` when view tree re-renders a Canvas
- [ ] **Fix Canvas redraw on @State change (Win32)** — call `InvalidateRect()` when view tree re-renders a Canvas
- [ ] **Add Win32 `setLineCap()` / `setLineJoin()`** — wire `ID2D1Factory::CreateStrokeStyle()` through D2D shim
- [ ] Validate `NavigationSplitView` 3-column shell with toolbar on GTK4 and Win32
- [ ] If split view behavior is wrong, fix it before proceeding with example polish

### Phase 3: Build the Example

- create `Examples/Showcase/SimplePaint/main.swift`
- implement shared model and rendering
- build toolbar, left tool panel, center canvas, right inspector
- wire undo/redo/new
- tune default window size and split widths

### Phase 4: Wire Project Metadata

- add `SimplePaint` target to `Package.swift`
- add it to Apple example project metadata if applicable
- update docs that list showcase examples

### Phase 5: Verify Per Platform

- macOS build and run
- Linux build and run
- Windows build and run
- confirm layout, drawing, undo/redo, tool switching, and inspector behavior

## Proposed Files

| File | Action |
|------|--------|
| `Examples/Showcase/SimplePaint/main.swift` | Create |
| `Package.swift` | Edit |
| `apple/Examples/project.yml` | Edit if showcase targets are mirrored there |
| `docs/guides/running-examples.md` | Edit |
| `docs/guides/examples-plan.md` | Edit |
| `CLAUDE.md` | Edit if showcase examples are listed there |

## Verification Checklist

### Functional

- can draw freehand repeatedly without losing previous strokes
- can erase
- can draw line, rectangle, and ellipse previews
- can commit shapes correctly
- undo works for multiple steps
- redo works after undo
- redo clears after a new stroke
- color changes affect newly drawn strokes
- brush size changes affect newly drawn strokes

### Layout

- toolbar appears and remains usable
- `NavigationSplitView` behaves correctly as the main shell
- left tool panel stays narrow and stable
- inspector panel stays visible and usable
- canvas gets the majority of window space

### Cross-Platform

- one source file remains the implementation center
- no platform requires a separate app design
- only thin bootstrap compatibility code differs

## Risks

### Canvas redraw — highest priority framework fix

Confirmed blocker. Without Canvas invalidation on state change, the entire rendering model fails. This is Phase 2 work that must land before any example code is useful.

### NavigationSplitView under a real app shell

Three-column layout is implemented and confirmed on GTK4/Win32, but this is the first time it will serve as the core productivity layout. If it breaks under toolbar + canvas + inspector composition, the right fix is in SwiftOpenUI, not in the example design.

### Win32 freehand rendering quality

Confirmed: `setLineCap()` and `setLineJoin()` are no-ops on Win32 today. Phase 2 includes fixing this. Without the fix, pencil strokes will look visibly worse than GTK4/macOS.

### Canvas performance under long sessions

Replay rendering is fine for a showcase app, but very large stroke counts may eventually need caching. Acceptable to defer past v1.

### Scope creep

The app becomes much less likely to ship if we add layers, selections, file formats, or image processing to the first cut.

## Recommendation

Build `SimplePaint` as a disciplined v1:

- retained vector strokes, not a bitmap engine
- `NavigationSplitView` shell, and fix it if it does not hold up
- top toolbar plus right inspector
- macOS, Linux, and Windows only

That gives SwiftOpenUI a real productivity-style showcase app without first signing up for a full raster editor or document framework.
