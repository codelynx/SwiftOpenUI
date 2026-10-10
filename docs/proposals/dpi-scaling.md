# Proposal: Logical-Coordinate Contract and DPI Scaling

**Status:** Draft / RFC
**Scope:** Core coordinate semantics + Win32 backend (primary); GTK4, Web, macOS (confirming they already comply)
**Related:** PRs #8 and #11 (Win32 DPI changes, under review); `.untracked/dpi-baseline/` capture aid

## Goal

Define a single, backend-independent rule for what a numeric dimension in
SwiftOpenUI *means* — e.g. the `60` in `.frame(width: 60)`, `.padding(8)`,
`Font.custom(size: 14)` — and specify how each backend maps that logical unit
onto physical device pixels at arbitrary display scales (100%, 150%, 200%, …).

The contract: **every dimension in core API is a logical point (1pt = 1px at
100% / 96 DPI). Backends are responsible for multiplying by the display scale
factor at render time.** This matches SwiftUI, where client code never multiplies
by a scale factor itself.

"Write SwiftUI, run anywhere" has to include "render correctly at any display
scale." Today that holds on three of four backends and is incomplete on Win32.

## Problem

On Win32, the DPI scale factor (`GetDpiForWindow(hwnd) / 96.0`) is applied
**only to font sizes** and is recomputed ad hoc at several call sites. Based on
code inspection (`Sources/Backend/Win32/Rendering/`), the following are **not**
scaled:

- Explicit layout geometry — `.frame(width:height:)`, `.padding()`, spacing,
  offsets appear to flow through `LayoutEngine` as raw pixels (`* scale` in
  `LayoutEngine.swift` is applied to font sizes only).
- There is **no `WM_DPICHANGED` handler** even though the process declares
  `PerMonitorV2` awareness (`win32_SetProcessDpiAwarenessContextPerMonitorV2()`
  in `Win32Backend.swift`). Windows therefore expects the app to re-layout on a
  DPI change (monitor move, scale change) and it does not.

Consequence at 200% scale: text renders ~2× but a fixed-size box stays its
100% pixel size → clipping, overlap, and layout that diverges from the macOS
SwiftUI reference.

### What #8 and #11 already do (and don't)

PRs #8 and #11 (both open, #11 stacked on #8) are already fixing specific
instances of this, each at its own call site:

- **#8** scales window sizes (`defaultWindowSize`, `windowSizing(.size)`,
  min/max track sizes) by `GetDpiForWindow`, scales `measureText`, scales the
  Material Symbol STATIC box, and pins the D2D render target to 96 DPI so
  drawing coordinates equal the layout engine's physical pixels.
- **#11** scales the navigation header, back button and title, and measures the
  back button from its text instead of a fixed 60px.

These are correct, targeted fixes. What neither PR introduces:

- a **single points→pixels chokepoint** — scaling is added call site by call
  site (window creation, `measureText`, glyph box, nav header), so the
  "scale lives in N places" problem is being *extended*, not resolved;
- a **`WM_DPICHANGED` handler** — DPI is still read once at window/render time;
  a live scale change or monitor move does not re-lay-out.

This RFC's contribution is therefore **consolidation + dynamic DPI**, layered on
top of (not instead of) #8/#11: adopt their scaling behavior, route it through
one chokepoint, and make PerMonitorV2 awareness truthful. The migration section
treats #8/#11 as the behavioral baseline to preserve.

### DPI scale is derived in scattered places (Win32)

| Location | Use |
|---|---|
| `LayoutEngine.swift:52` (`fontParameters`) | font point size → px |
| `WinRenderer.swift:3132` (`createHFont`) | HFONT height |
| `WinRenderer.swift:3185` (`createEmojiHFont`) | emoji HFONT height |
| `WinRenderer.swift:4236` (material symbol) | glyph pixel height |

Four independent `dpi / 96.0` computations, each font-only. No single place owns
"points → pixels," so geometry was never brought along.

## Current state per backend

| Backend | Logical unit | Who scales to device px | Dynamic DPI change | Status |
|---|---|---|---|---|
| macOS (SwiftUI) | point | AppKit/SwiftUI | automatic | ✅ reference |
| GTK4 | CSS px (logical) | GTK (integer `scale-factor`; fractional via `GDK_DPI_SCALE`) | automatic | ✅ (fractional relies on env) |
| Web | CSS px (logical) | browser (`devicePixelRatio`) | automatic | ✅ |
| Win32 | **mixed** — fonts in points, geometry in raw px | manual, font-only | **none** (no `WM_DPICHANGED`) | ❌ incomplete |

GTK4 and Web get DPI "for free" because their primitives are logical by
definition. macOS is the reference. Win32 is the only backend that must do the
multiplication itself, and currently does it partially.

## Proposed design

### 1. Core: dimensions are logical points (documentation + contract, no code change)

Make explicit in `docs/architecture/` and in the `View`/modifier doc comments
that all dimensions are logical points. No new type is proposed (a `Points`
wrapper was considered and rejected as churn — SwiftUI uses bare `CGFloat`).
Core stays platform-independent and scale-unaware.

### 2. Win32: one chokepoint for points → pixels

Introduce a single scale source on the render context instead of recomputing
`dpi / 96.0` in four places:

```swift
// RenderContext (Win32)
var dpi: UINT                 // from GetDpiForWindow at window/relayout time
var scale: Double { Double(dpi) / 96.0 }
func px(_ points: Double) -> Int32 { Int32((points * scale).rounded()) }
```

- `LayoutEngine` multiplies **all** geometry (frame sizes, padding, spacing,
  offsets, min/ideal/max) by `scale`, not just fonts.
- The four font call sites read `context.scale` instead of calling
  `win32_GetDpiForWindow` themselves.
- Rounding rule: round half-up at the final px conversion; keep intermediate
  layout math in floating point to avoid accumulated drift (esp. at 150%).

### 3. Win32: handle `WM_DPICHANGED`

Add a handler in the window proc (`Win32Backend.swift`) that, on
`WM_DPICHANGED`, does both of the following — applying the OS-suggested
rectangle is mandatory, not optional, under PerMonitorV2:

1. **Apply the suggested rectangle.** `lParam` is a `RECT*` with the position
   and size Windows wants the window to adopt for the new DPI. Call
   `SetWindowPos(hwnd, nil, l, t, r-l, b-t, SWP_NOZORDER | SWP_NOACTIVATE)`.
   Skipping this is the documented cause of windows that keep their old
   physical size (and so halve/double visually) across a monitor move.
2. **Refresh scale and rebuild.** Update `context.dpi` from the new DPI
   (`HIWORD(wParam)`), then drive a full relayout through the **existing**
   host lifecycle — the same `WM_SWIFTUI_REBUILD` → `host.rebuild()` path used
   today — so no new rebuild mechanism is introduced. The resize in step 1 and
   the rebuild in step 2 must be ordered so the rebuild lays out against the new
   client size (resize first, then rebuild), matching how `host.rebuild()`
   already reacts to size changes.

This makes PerMonitorV2 awareness truthful: moving the window between a 100%
and a 200% monitor, or changing the display scale live, re-lays-out correctly.
Open item: confirm `host.rebuild()` reads the current client rect rather than a
cached size; if it caches, the resize path must invalidate that cache.

### 4. GTK4 fractional scaling (follow-up, lower priority)

Integer scales work today. Confirm 150% behaves (it depends on `GDK_DPI_SCALE`
/ compositor fractional scaling) and document the expectation; no code change
proposed yet.

## Testing & verification

DPI correctness is a visual property, so the verification is screenshot-based,
layered on the existing parity harness:

1. **Baseline evidence (done for 100%).** `.untracked/capture-dpi-baseline.ps1`
   captures all 16 mapped examples at the current system scale into
   `.untracked/dpi-baseline/<scale>/`. 100% is captured; 150% and 200% require
   setting the Windows display scale (no per-app DPI override exists — see
   below). This is the before/after reference for #8/#11.
2. **Expected invariant — measure the client area, not the outer window.** The
   precise invariant is on the **content / client rect**: at 200% the client
   area and everything in it should be ≈2× the 100% client area, text and
   geometry scaling together.

   Caveat about the current baseline numbers: `capture-dpi-baseline.ps1`
   measures the **outer visible window** (`GetWindowRect` cropped to the DWM
   `EXTENDED_FRAME_BOUNDS`), i.e. client area *plus* title bar and borders,
   minus the drop shadow. Non-client chrome scales with DPI too, but in
   discrete steps (caption-button widths, 1px borders that become 2px), so the
   outer bounds are **only approximately** linear across scales — a few px of
   non-linearity is chrome, not a layout bug. So `ColorMixer 322×482` → "~644×964
   at 200%" is a sanity band, not an exact target. For a strict pass/fail, the
   capture should additionally record the **client rect** (`GetClientRect` on
   the SwiftOpenUI window) and assert ≈2× on that; that is the number the layout
   contract actually governs. (Action item: extend the script to log client
   rect alongside the visible bounds.)
3. **Layout parity fixtures.** Consider extending `Tests/LayoutParityTests/`
   with scale-parameterized fixtures once the chokepoint lands, so DPI
   regressions are caught without manual capture.

### Why DPI can't be faked per-app

The Win32 backend derives scale solely from `GetDpiForWindow`, which reflects
the monitor the window is on. There is no environment variable or flag to
simulate a different DPI for one process (`__COMPAT_LAYER=DPIUNAWARE` only
bitmap-stretches a 96-DPI render — not a faithful high-DPI layout). So each
baseline scale requires actually changing the Windows display scale. This is an
argument *for* the `WM_DPICHANGED` work: once it lands, a live scale change
becomes a supported, observable code path rather than a restart-only scenario.

## Migration / rollout

1. Land the Win32 scale chokepoint (`context.scale` + geometry scaling) — this
   is the behavioral core; expect it to subsume much of #8/#11.
2. Land `WM_DPICHANGED`.
3. Capture 150%/200% baselines; diff against 100% and the macOS reference.
4. Document the logical-point contract in `docs/architecture/`.
5. (Later) GTK4 fractional-scale confirmation.

## Open questions

- **#8/#11 sequencing.** The PR *descriptions* have been read (see "What #8/#11
  already do" above) but not a line-by-line diff review. Recommended order: land
  #8/#11 first (they fix real, user-visible breakage now), then do the chokepoint
  refactor as a follow-up that routes their per-call-site scaling through
  `context.scale` without changing behavior, then add `WM_DPICHANGED`. Do **not**
  rewrite #8/#11 as part of this RFC — consolidate after they merge, so the
  refactor has a green, scaled baseline to preserve and diff against. Note #8
  pins the D2D render target to 96 DPI (layout coords == physical px); the
  chokepoint must keep that invariant.
- **Rounding at 150%.** Half-up rounding can produce 1px seams between adjacent
  scaled boxes. Decide whether to round at the leaf or distribute rounding in the
  layout pass.
- **Non-integer GTK scales.** Does the Linux CI/display env actually exercise
  150%, or only integer scales?
- **Image/bitmap assets.** `Image(decoded:)` pixel buffers are physical pixels;
  define whether they are point-sized (scaled, blurry at 2×) or pixel-exact.
