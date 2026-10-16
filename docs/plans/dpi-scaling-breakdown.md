# Plan: DPI / Logical-Coordinate Contract — work breakdown

Implementation breakdown for the RFC in
[`docs/proposals/dpi-scaling.md`](../proposals/dpi-scaling.md) (PR #16).
Decomposes the RFC's migration plan and open questions into discrete,
independently-reviewable units with dependencies and owners.

**Platform reality:** the work is ~90% Windows. GTK4/Web/macOS already scale
automatically (logical-pixel primitives); Linux's only task is D8
(fractional-scale *confirmation*, not a fix).

## Tracking

| Unit | Tracked by | Status |
|------|-----------|--------|
| D0 — adopt RFC | PR #16 (this) | draft |
| D1 — revised #8 | PR #8 | **done** (merged 2026-10-15 via `fix/win32-dpi-defaults`) |
| D2 — revised #11 | PR #11 | **done** (merged 2026-10-15 as rebased `fix/win32-nav-dpi-truncation`; #11 closed) |
| D3 — scale chokepoint | #17 | **done** — D3a (API geometry) #35, D3b (control constants) #36, chevron follow-up #38 |
| D4 — WM_DPICHANGED | #18 | **in review** — PR #39; synthetic tests pass, live two-monitor test pending |
| D5 — 150%/200% captures | #19 | 150% captured 2026-10-15 — hypothesis confirmed (see below); 200% pending |
| D6 — tracked capture tooling | #20 | partial — `capture-windows.ps1` made DPI-aware (#35); evidence under `docs/evidence/dpi/` |
| D7 — document the contract | _unfiled_ (coordinator) | — |
| D8 — GTK4 fractional scaling | #21 | open |

- [ ] D0 adopt RFC (#16)
- [x] D1 revised #8 — contributor
- [x] D2 revised #11 — contributor
- [x] D3 scale chokepoint (#17)
  - [x] D3a — API geometry → logical points (#35)
  - [x] D3b — hard-coded control constants (#36, follow-up #38)
- [ ] D4 WM_DPICHANGED (#18) — PR #39, needs a two-monitor test
- [ ] D5 150%/200% captures (#19)
- [ ] D6 tracked capture tooling (#20)
- [ ] D7 document the contract
- [ ] D8 GTK4 fractional scaling (#21)

## Status update — 2026-10-15

D1 and D2 landed, plus related Win32 work that D3 builds on:

- #22/#24: every text-bearing control gets a DPI-scaled Segoe UI body font (before, plain `Text` and EDIT controls used the unscaled bitmap System font).
- #25: the automatic window grows to fit content (still DPI-scaled 800×600 minimum).
- #31/#33: bounded expansion for finite `maxWidth`/`maxHeight` — caps are stored in **raw pixels** today; D3 must scale them.
- #34: a single `dpiScaleFactor(for:)` + `defaultBodyFontSize` replaced ~12 hand-written `GetDpiForWindow/96` copies — the seed of D3's chokepoint.

**D5 at 150% (144 DPI), all 16 examples captured:** the RFC's "geometry isn't scaled" hypothesis is confirmed. Text, font-derived sizes, the automatic window default and the navigation header scale; `.frame`, `.padding`, stack spacing, `.offset`, borders, and explicit window sizes (`.defaultWindowSize`, `.windowSizing(.size/.contentFixed)`) do not. Wherever fixed geometry contains text, the text outgrows it:

| Example | At 150% | Cause |
|---|---|---|
| ColorMixer | "B: 220" clipped; bottom row cut off | `.defaultWindowSize` + `.contentFixed` and fixed `.frame`s unscaled |
| Calculator | cramped; title doesn't fit | fixed 56×56 button frames + content-fixed window unscaled |
| Modifiers | `60×30` text overflows its box; `.offset` text clipped; tight padding | `.frame`, `.padding`, `.offset` unscaled |
| SimplePaint | window/canvas stay at 100% size (usable) | explicit window and canvas sizes unscaled |
| Parity examples on automatic sizing (StateData, Environment, Focus, …) | correct | only text-driven sizing involved |

Captures: [`docs/evidence/dpi/150/`](../evidence/dpi/150/).

## D3a — landed 2026-10-15 (#35)

Chokepoint helpers in `LayoutEngine.swift`: `px(_:for:)`, `pxExact(_:for:)`, `pxForNewWindow(_:)`, `pxToPoints(_:for:)`. Each view converts its API inputs once at creation:

- frame (incl. bounded caps)
- padding, spacing, offset, position
- border, corner radius, shadow, stroke
- window sizes

Canvas, drag/drop and GeometryReader switched to points together, so input and drawing stay in one space.

**Deviation from the RFC text:** the scale is read per window with `dpiScaleFactor(for: hwnd)` rather than stored in a new `RenderContext.scale` field, which would touch 46 construction sites. Per-monitor DPI is per top-level window, so this is equivalent. D4 (`WM_DPICHANGED`) rebuilds the tree, which re-reads it.

**Rounding:** each converted value rounds to the nearest pixel (`px`), with `pxExact` kept for layout math and D2D. No seams were seen at 150%; revisit if they appear.

**Remaining for D3:**

- **D3b:** ~130 hard-coded control constants (slider track, stepper, tab bar, toolbar, dropdown, segmented picker, DisclosureGroup, NavigationSplitView divider, text-measure padding).
- Bitmap image sizing (open question below).

Evidence: [`docs/evidence/dpi/150-d3a/`](../evidence/dpi/150-d3a/) on `develop`.

## Critical path

```
D0 (adopt RFC)
      │
      ▼
D1 + D2  (contributor — revised #8 / #11)
      │
      ▼
D3 (scale chokepoint, behaviour-preserving)
      │
      ▼
D4 (WM_DPICHANGED)

D5 / D6 / D7 / D8 parallelize once their deps clear.
```

## Units

### D0 — Adopt the RFC
- **Scope:** merge `docs/proposals/dpi-scaling.md` (PR #16) once the coordinate
  contract and the #8/#11 sequencing are agreed.
- **Depends on:** —
- **Owner:** coordinator + reviewers
- **Done when:** RFC merged (or explicitly accepted as the design of record).

### D1 — Revised #8 (contributor-owned; tracked via PR #8, not a new issue)
- **Scope:** address the review on #8 —
  1. restore the shared 800×600 automatic window default + 300×200 fallback
     minimum, both DPI-scaled (don't leave automatic windows at `CW_USEDEFAULT`);
  2. scale the remaining D2D text paths after the 96-DPI pin — dropdown
     (`Win32DropdownPicker.swift`), segmented picker (`WinRenderer.swift`), and
     `D2DSurface.swift` explicit-font + animated paths;
  3. move the `NavigationSplitView` expansion hunk to #11.
- **Files:** `Win32Backend.swift`, `Win32DropdownPicker.swift`, `WinRenderer.swift`, `D2DSurface.swift`
- **Depends on:** — (rebase onto current `develop`)
- **Owner:** contributor (@vitalyster)
- **Done when:** #8 review resolved; automatic windows open at DPI-scaled 800×600; all text scales at 200%.

### D2 — Revised #11 (contributor-owned; tracked via PR #11)
- **Scope:** fix the fractional-DPI truncation — keep the ratio a `Double` and
  round each final dimension (`Int32((x * scale).rounded())`) in
  `layoutNavContainer` and `NavigationStack.winCreateWidget`. Current code
  computes `Int32(Double(GetDpiForWindow)/96.0)`, collapsing 150% to 1×.
- **Files:** `Win32Navigation.swift`
- **Depends on:** D1 (stacked)
- **Owner:** contributor
- **Done when:** header/back button scale correctly at 125/150/175%.

### D3 — Scale chokepoint
- **Scope:** add `context.scale` + `px()` to the Win32 render context; route
  D1/D2's per-call-site scaling through it; scale **all** geometry in
  `LayoutEngine` (frame, padding, spacing, offsets, min/ideal/max), not just
  fonts. Behaviour-preserving refactor. Preserve #8's 96-DPI render-target pin
  (layout coords == physical px).
- **Files:** `LayoutEngine.swift`, `WinRenderer.swift`, `Win32Backend.swift`, render-context type
- **Depends on:** **D1, D2 merged** (needs their green, scaled baseline to diff against)
- **Owner:** Windows
- **Done when:** no `win32_GetDpiForWindow/96` recomputed outside the chokepoint; captures unchanged vs. post-D1/D2.

### D4 — `WM_DPICHANGED` handler
- **Scope:** in the window proc, on `WM_DPICHANGED`: apply the OS-suggested
  `RECT*` via `SetWindowPos` (SWP_NOZORDER|SWP_NOACTIVATE), refresh
  `context.dpi` from `HIWORD(wParam)`, then rebuild via the existing
  `WM_SWIFTUI_REBUILD` → `host.rebuild()` path (resize before rebuild).
- **Files:** `Win32Backend.swift`
- **Depends on:** D3
- **Owner:** Windows
- **Done when:** dragging a window between 100% and 200% monitors re-lays-out correctly.

### D5 — Empirical verification (150%/200% captures)
- **Scope:** capture client rects at 150% and 200% (manual Settings scale
  route only); confirm or refute the RFC's "geometry unscaled" hypothesis and
  the unscaled-text claim. 100% baseline already recorded.
- **Depends on:** D1 (to measure the fix); explicit approval to change display scale
- **Owner:** Windows
- **Done when:** `dimensions.csv` for /150 and /200 exist; client rects scale ~linearly or the deviation is explained.

### D6 — Tracked home for the capture tooling
- **Scope:** move the capture script out of gitignored `.untracked/` to a
  tracked location (e.g. `scripts/`, alongside `screenshots/capture-windows.ps1`
  which it extends); store reference captures under `docs/evidence/dpi/` or
  similar. File moves only.
- **Depends on:** D5
- **Owner:** Windows

### D7 — Document the logical-point contract
- **Scope:** state in `docs/architecture/` and in `View`/modifier doc comments
  that all dimensions are logical points; backends scale at render time.
- **Depends on:** D0
- **Owner:** coordinator

### D8 — GTK4 fractional-scale confirmation (lower priority)
- **Scope:** confirm 150% behaves on GTK4 (depends on `GDK_DPI_SCALE` /
  compositor fractional scaling); document the expectation. Verification, not a fix.
- **Depends on:** D7 (contract)
- **Owner:** Linux

## Open design questions (resolve before/within D3)

- **Rounding at 150%** — `.rounded()` at the leaf can leave 1px seams between
  adjacent boxes. Round at the leaf, or distribute rounding in the layout pass?
- **Image/bitmap assets** — `Image(decoded:)` buffers are physical pixels.
  Point-sized (scaled, blurry at 2×) or pixel-exact?
