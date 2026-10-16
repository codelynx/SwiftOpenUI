# Logical coordinates: every dimension is a point

Every dimension in the SwiftOpenUI core API is a **logical point**. One
point is one pixel at 100% display scale (96 DPI on Windows); at 150% it is
1.5 physical pixels. App code never multiplies by a scale factor, exactly as
in SwiftUI. Backends convert to device pixels when they render.

Decided in [RFC #16](../proposals/dpi-scaling.md) (D7). Status of the Win32
implementation: [`docs/plans/dpi-scaling-breakdown.md`](../plans/dpi-scaling-breakdown.md).

## What is a point

These are all logical points:

| API | Values in points |
| --- | --- |
| `.frame(...)` | `width`, `height`, `minWidth` … `maxHeight` (`.infinity` stays unbounded) |
| `.padding(...)`, `.safeAreaPadding(...)` | every inset, including the 8pt / 16pt defaults |
| `VStack`, `HStack`, `Grid`, `LazyVStack`, … | `spacing` (default 8pt), `Spacer(minLength:)` |
| `.offset(x:y:)`, `.position(x:y:)` | both coordinates |
| `.border(_:width:)`, `.cornerRadius(_:)`, `.shadow(radius:x:y:)` | widths, radii, offsets |
| `Shape.stroke(...)`, `StrokeStyle` | `lineWidth`, `dash`, `dashPhase` |
| `Font.system(size:)` and text styles | font size |
| `Canvas` | its size, and every coordinate drawn in it |
| `WindowGroup` / `Window` | `.defaultWindowSize`, `.windowSizeConstraints`, `.windowSizing(.size)` |
| `.navigationSplitViewColumnWidth(...)` | ideal, min, max |

Values the framework **hands back** to app code are points too:

- `GeometryProxy.size`
- `DragGestureValue` (`startLocation`, `location`, `translation`) and the
  drag `minimumDistance`
- drop locations
- the size passed to a `Canvas` draw handler

Undecided: images loaded from files keep their bitmap's pixel size as their
natural size. Whether that should be treated as points (scaled up, softer at
200%) or stay pixel-exact is an open question in RFC #16.

## How each backend meets the contract

| Backend | Unit its toolkit uses | What the backend does |
| --- | --- | --- |
| macOS | SwiftUI points | Nothing; native SwiftUI |
| GTK4 | GTK logical pixels (GDK applies the scale factor) | Nothing; pass values through |
| Web | CSS pixels (the browser applies `devicePixelRatio`) | Nothing; pass values through |
| Android | Jetpack Compose `dp` | Pass values through as `dp`; pointer input arrives in pixels and is divided by `density` (`ComposeRenderHost.kt`) |
| Win32 | Physical pixels (`HWND` geometry; Direct2D targets pinned to 96 DPI) | Converts explicitly through a chokepoint, below |

Win32 is the only backend whose toolkit does not scale for us, so it is the
only one with conversion code.

## Win32 rules

The helpers live in `Sources/Backend/Win32/Rendering/LayoutEngine.swift`:

| Helper | Use for |
| --- | --- |
| `px(_:for:)` | points → pixels, rounded to the nearest pixel; window and control geometry |
| `pxExact(_:for:)` | points → pixels, unrounded; layout math and Direct2D drawing |
| `pxForNewWindow(_:)` | points → pixels before a window exists (uses the system DPI) |
| `pxToPoints(_:for:)` | pixels → points, for values handed back to app code |
| `dpiScaleFactor(for:)` | the raw ratio, when a whole calculation needs it |
| `defaultBodyFontSize` | the 14pt default text size; never write `14` |

1. **Convert once, where the view is created.** Each `winCreateWidget`
   converts its point inputs at the top and works in pixels from then on.
   Layout functions (`performVerticalLayout`, `computeFrameLayout`, …) only
   ever see pixels; never convert inside them.
2. **Never pass a literal to window geometry.** A number written in
   `CreateWindowExW`, `SetWindowPos` or a D2D draw call is a point and goes
   through `px`/`pxExact`. `0` is the only safe literal.
3. **Convert back when handing values to app code**, with `pxToPoints`.
   Input and drawing must agree: Canvas draws under a base DPI transform, so
   gesture locations in points land where the pointer is.
4. **Hairlines stay physical.** 1px borders, their 0.5/1px alignment
   insets, `Divider`'s line and native control glyphs are not scaled, so
   they stay crisp, as native Windows controls do.
5. **Read the DPI from the window you are sizing**, never a cached or
   global value. Per-monitor DPI belongs to a top-level window and changes
   when it moves.
6. **DPI changes re-render.** On `WM_DPICHANGED` the window applies the
   suggested size, then re-renders its root at the new DPI (RFC #16 D4,
   PR #39). Code that converts at creation is therefore correct after a
   move, as long as it reads the DPI per rule 5.

## GTK4 at fractional scale

Confirmed at 150% on GNOME Shell 50 (Wayland) with GTK 4.22 (RFC #16 D8,
issue #21). GTK needs no conversion code, at fractional scales too:

- **Geometry stays in points.** GTK reports a surface scale of 1.5 and
  lays out in logical pixels, so an 800×600pt window is 1200×900 device
  pixels and a 100pt frame is 150px. Window sizes are identical at 100% and
  150%. Text is rendered at device resolution and is crisp.
- **Canvas is crisp.** Cairo drawing in a `Canvas` is rasterized at 1.5×,
  not drawn at 2× and scaled down.
- **1pt hairlines are soft.** A 1pt border is 1.5 device pixels and falls
  between pixels, so it renders as a two-pixel soft line. Native GTK widget
  borders do the same; unlike Win32 (rule 4) we do not snap hairlines to
  physical pixels. Bitmaps are resampled and slightly soft. At 200% both
  are sharp.
- **The integer scale factor is 2 at 150%.** `gtk_widget_get_scale_factor`
  rounds up; use `gdk_surface_get_scale` for the real value. Nothing in the
  backend reads either today.
- **`GDK_SCALE` and `GDK_DPI_SCALE` have no effect** under Wayland: the
  output is identical to an unset run. Display scaling comes from the
  compositor only.
- **Not tested:** GNOME's text-only "Large Text" setting
  (`text-scaling-factor`), which could make text outgrow fixed frames the
  way Win32 text did before D3; and X11 sessions.

Evidence and the probe view used: `docs/evidence/dpi/gtk4-150/`.

## Testing

- `swift test` runs in a process that is **not** DPI-aware, so it always
  sees 96 DPI and every helper is the identity. Tests prove 100% behaviour,
  not scaling.
- Above 100%, verify with screenshots: change the display scale and run
  `screenshots/capture-windows.ps1` (DPI-aware since #35). Keep the display
  awake; a sleeping display drops Direct2D-drawn controls from captures.
- Reference captures: `docs/evidence/dpi/150/` (before), `150-d3a/`,
  `150-d3b/` (after).
- GTK4: `screenshots/capture-linux-scaled.sh 1.5 [target…]` runs the
  examples on a private headless GNOME Shell at the given scale, so your
  own desktop is left alone. Each example renders its own window to PNG,
  enabled by `SWIFTOPENUI_GTK_CAPTURE=<file.png>` (`GTKCapture.swift`).
