# Web: `.frame(maxWidth: .infinity)` children in an `HStack` neither grow nor split equally

> **Open.** The parity sibling of the resolved GTK4 issue
> [`gtk4-hstack-maxwidth-infinity-not-equal.md`](./gtk4-hstack-maxwidth-infinity-not-equal.md)
> and its [proposal](../proposals/gtk4-flexible-hstack-layout.md). Win32
> was verified to match the spec; **Web is the remaining outlier.** Found
> by code inspection on the macOS-side agent's Web parity check; a browser
> runtime confirmation is still owed.

## Summary

On the Web backend, an `HStack` containing `.frame(maxWidth: .infinity)`
children does not match SwiftUI's equal-division of flexible children.
There are **two** distinct defects, the first more fundamental than the
gap the GTK4 fix addressed:

1. **Flexible frames do not grow at all.** `FrameView.webCreateElement`
   (`Sources/Backend/Web/Rendering/WebRenderer.swift:1905`) renders a
   `maxWidth: .infinity` frame with only `max-width: 99999px` and no
   `flex-grow`. Because CSS `flex-grow` defaults to `0`, a `max-width`
   cap alone never makes the flex item expand — two
   `.frame(maxWidth: .infinity)` drop zones stay at content width instead
   of filling the row.

2. **No `min-width: 0`.** Even once grow is added, flex items default to
   `min-width: auto`, which floors them at content size — so unequal-content
   flexible children would still divide **unequally** (the classic flexbox
   equal-division gotcha, and the direct analog of the GTK4 defect).

## Repro

Two `.frame(maxWidth: .infinity)` drop zones in an `HStack` (Synca's
`DualFolderView`): on Web they sit at their content widths rather than
each filling half the row; give one a long path and they also differ in
width. macOS fills and splits equally; GTK4 now does too.

## Root cause

`WebRenderer.swift:1905-1926` — the FrameView wrapper emits
`max-width: 99999px; display: flex; flex-direction: column; …` for a
`maxWidth: .infinity` frame, but never `flex: 1 1 0` or `min-width: 0`.
No other Web code path compensates (the `flex: 1` sites at lines 164,
1187, 1199, … are the intrinsic-root wrapper, `Spacer`, and layout
scaffolding, not the flexible-frame child path).

## Direction (not a blind `flex: 1`)

The fix must be **axis-aware**, mirroring the GTK4 proposal's
flexible-child classification:

- Flexible frame inside a **row** (`HStack`) → `flex: 1 1 0; min-width: 0`.
- Flexible frame inside a **column** (`VStack`) → `width: 100%`
  (`flex-grow` on the cross axis does nothing).

FrameView does not currently know its parent's layout axis, so this needs
the same parent-axis signal the GTK4 path introduced — it is not a
one-line CSS tweak.

## Impact

Cosmetic-to-moderate: any Web app using `.frame(maxWidth: .infinity)`
children in an `HStack` for equal columns (side-by-side panes, split
layouts, Synca's drop zones) gets content-width, unequal columns instead
of equal fills. Blocks Web from the cross-backend flexible-HStack parity
the other three platforms now share.
