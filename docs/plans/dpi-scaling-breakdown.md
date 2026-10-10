# Plan: DPI / Logical-Coordinate Contract — work breakdown

Implementation breakdown for the RFC in
[`docs/proposals/dpi-scaling.md`](../proposals/dpi-scaling.md) (PR #16).
Decomposes the RFC's migration plan and open questions into discrete,
independently-reviewable units with dependencies and owners.

**Platform reality:** the work is ~90% Windows. GTK4/Web/macOS already scale
automatically (logical-pixel primitives); Linux's only task is D8
(fractional-scale *confirmation*, not a fix).

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
