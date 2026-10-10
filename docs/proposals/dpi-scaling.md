# Proposal: Logical-Coordinate Contract and DPI Scaling

**Status:** Draft / RFC
**Scope:** Core coordinate semantics + Win32 backend (primary); GTK4, Web, macOS (confirming they already comply)
**Related:** PRs #8 and #11 (Win32 DPI changes, both with changes requested). A DPI-baseline capture script and its screenshots currently live outside version control (see "Open questions" for a proposed tracked home).

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
**only to font sizes** and is recomputed ad hoc at several call sites. Two
observations, at different confidence levels:

- **Hypothesis (from code inspection, not yet confirmed by running):** explicit
  layout geometry — `.frame(width:height:)`, `.padding()`, spacing, offsets —
  appears to flow through `LayoutEngine` as raw pixels; the only `* scale` in
  `LayoutEngine.swift` is on font sizes. **This is a code-reading claim and must
  be verified empirically** by the 150%/200% client-rect captures below (if a
  fixed-frame example's client rect fails to scale ~linearly, the hypothesis
  holds). #8 already DPI-scales *some* geometry (window sizes), so the current
  picture is partial, not uniformly unscaled.
- **Confirmed:** there is **no `WM_DPICHANGED` handler** even though the process declares
  `PerMonitorV2` awareness (`win32_SetProcessDpiAwarenessContextPerMonitorV2()`
  in `Win32Backend.swift`). Windows therefore expects the app to re-layout on a
  DPI change (monitor move, scale change) and it does not.

Consequence at 200% scale: text renders ~2× but a fixed-size box stays its
100% pixel size → clipping, overlap, and layout that diverges from the macOS
SwiftUI reference.

### What #8 and #11 attempt (both have changes requested)

PRs #8 and #11 (both open, #11 stacked on #8) fix specific instances of this,
each at its own call site. **Both currently have changes requested** — their
reviews (read in full, not just the descriptions) are the authoritative account
of where they stand:

- **#8** scales window sizes, `measureText`, and the Material Symbol STATIC box,
  and pins the D2D render target to 96 DPI (layout coords == physical px, a good
  move). Review asks for three changes before it lands:
  1. It **dropped the shared 800×600 automatic window default** (the same
     constant GTK4 uses) and the 300×200 fallback minimum, leaving automatic
     windows at `CW_USEDEFAULT` — a behaviour change beyond DPI that diverges
     from GTK4; automatic windows also now skip the min/max clamp. These must be
     preserved and DPI-scaled. *The 100% baseline below is direct evidence of
     the pre-PR behaviour: every automatic window opens at exactly 800×600
     client.*
  2. **Font scaling is incomplete after the 96-DPI pin** — the dropdown picker
     (`Win32DropdownPicker.swift`), segmented picker (`WinRenderer.swift`), and
     `D2DSurface.swift` explicit-font/animated text paths still feed unscaled
     sizes to the pinned target, so their text renders at ~half size at 200%.
  3. A `NavigationSplitView` expansion hunk belongs in #11.
- **#11** scales the nav header/back-button/title and measures the back button
  from its text. Review asks one fix: it computes `Int32(Double(dpi)/96.0)` and
  **truncates the fractional scale before multiplying**, so 125/150/175% all
  collapse to 1× (and 250%→2×). The fix is to keep the ratio as a `Double` and
  round each final dimension — `Int32((32 * scale).rounded())`.

What neither PR introduces (the gap this RFC fills):

- a **single points→pixels chokepoint** — scaling is added call site by call
  site (window creation, `measureText`, glyph box, nav header), so the
  "scale lives in N places" problem is being *extended*, not resolved. The #11
  truncation bug is exactly the kind of error a shared helper prevents;
- a **`WM_DPICHANGED` handler** — DPI is still read once at window/render time;
  a live scale change or monitor move does not re-lay-out.

Crucially, **the chokepoint this RFC proposes is the same fix the reviews are
already asking for, generalised**: the `px()` helper below (keep the ratio as a
`Double`, round at the end) *is* #11's requested fix, and an HWND-aware
default-format helper routed through `context.scale` is what #8's incomplete
font paths need. So this RFC is not competing with #8/#11 — it is the shared
mechanism their individual review points converge on.

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
| Win32 (on `develop` today) | **mixed** — fonts scaled; most geometry unscaled (window-size scaling is in **unmerged** #8, not yet on `develop`) | manual, per-call-site | **none** (no `WM_DPICHANGED`) | ❌ incomplete |

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

1. **Baseline evidence (100% captured).** A capture script launches all 16
   mapped examples at the current system scale and records, per example, both
   the client rect (`GetClientRect`) and the outer visible bounds
   (`GetWindowRect`) plus a PNG. 150% and 200% require setting the Windows
   display scale (no per-app DPI override exists — see below). This is the
   before/after reference for #8/#11.

   Measured at **100% (96 DPI)** on `develop` @ `15c640d` (Win11 Pro 26200,
   Swift 6.2.4) — client px (the metric the contract governs) vs. outer px:

   | Example | Client | Outer |
   |---|---|---|
   | all 11 Parity + HelloWorld + Stopwatch (automatic windows) | 800×600 | 816×639 |
   | ColorMixer | 320×450 | 336×489 |
   | Calculator | 227×380 | 243×419 |
   | SimplePaint | 960×540 | 976×579 |

   The uniform 800×600 client for every automatic window is the direct evidence
   for #8's review point 1 (the shared automatic default that #8 currently
   removes).
2. **Expected invariant — measure the client area, not the outer window.** The
   precise pass/fail is on the **client rect**: at 200% each client area should
   be ≈2× its 100% value (800×600 → ~1600×1200), text and geometry scaling
   together. Outer bounds include a fixed 16×39px of chrome at 100% (title bar +
   borders) that scales in discrete steps, so they are only *approximately*
   linear — logged for reference, not used for pass/fail.
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

This order is a **recommendation for discussion**; it matches the "Open
questions" sequencing exactly (single source of truth):

1. **Land revised #8 and #11** once their review points are addressed (restore
   the 800×600/300×200 defaults scaled by DPI; finish the unscaled font paths;
   keep the DPI ratio a `Double` and round at the end). They fix real,
   user-visible breakage now and establish the scaled behaviour to preserve.
2. **Chokepoint refactor** (`context.scale` + `px()` + all-geometry scaling)
   that routes #8/#11's per-call-site scaling through one helper **without
   changing behaviour** — verified by diffing against the post-#8/#11 captures.
   Must preserve #8's 96-DPI-pinned render target (layout coords == physical px).
3. **`WM_DPICHANGED`** handler for live/ dynamic DPI.
4. Capture 150%/200% baselines at each step; diff against 100% and macOS.
5. Document the logical-point contract in `docs/architecture/`.
6. (Later) GTK4 fractional-scale confirmation.

## Open questions

- **#8/#11 sequencing.** The full reviews **and the diffs** have been read and
  the claims above verified against the code: #8's `case .automatic: break`
  leaves `requestedSize` nil so automatic windows fall to `CW_USEDEFAULT` (the
  800×600/300×200 defaults removed), while `measureText`/`FlatButtonState` each
  recompute `win32_GetDpiForWindow/96` locally; #11 literally computes
  `Int32(Double(win32_GetDpiForWindow(...)) / 96.0)` in `layoutNavContainer` and
  `NavigationStack.winCreateWidget`, truncating 150% to 1×. Recommended order
  (same as Migration): revised #8/#11 first, then the behaviour-preserving
  chokepoint refactor, then `WM_DPICHANGED`. Do **not** rewrite #8/#11 as part of
  this RFC — consolidate after they merge, so the refactor has a green, scaled
  baseline to diff against. (Not yet verified by running: #8's claim that the
  dropdown/segmented/`D2DSurface` text paths remain unscaled — those files are
  unchanged by #8, so the assertion rests on the review, not the diff.)
- **Home for the DPI-baseline script and screenshots.** The capture script and
  its PNGs/`dimensions.csv` currently live under gitignored `.untracked/`, so
  this committed doc can't reference them directly (hence the inlined 100% table
  above). Proposed: move the script to a tracked location (e.g. `scripts/` or
  alongside `screenshots/capture-windows.ps1`, which it extends) and store
  reference captures under `docs/evidence/dpi/` or similar. File moves are **out
  of scope for this PR** — flagging for a follow-up.
- **Rounding at 150%.** `.rounded()` at the leaf can produce 1px seams between
  adjacent scaled boxes. Decide whether to round at the leaf or distribute
  rounding in the layout pass. (This is why the shared `px()` helper matters —
  it localises the rule.)
- **Non-integer GTK scales.** Does the Linux CI/display env actually exercise
  150%, or only integer scales?
- **Image/bitmap assets.** `Image(decoded:)` pixel buffers are physical pixels;
  define whether they are point-sized (scaled, blurry at 2×) or pixel-exact.
