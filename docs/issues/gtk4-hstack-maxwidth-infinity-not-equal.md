# GTK4: `HStack` does not split width equally among `.frame(maxWidth: .infinity)` children

> **✅ RESOLVED** (SwiftOpenUI `a684384`; Synca workaround removed
> `280b2ed`). Implemented as a `GtkCustomLayout`-backed flexible-HStack
> equal-division on the expanding fallback path (gated to 2+ flexible
> children). Design + review + test matrix:
> [`../proposals/gtk4-flexible-hstack-layout.md`](../proposals/gtk4-flexible-hstack-layout.md).
> Runtime-verified (Synca drop zones equal & stable). The "interim
> workaround" below is now removed; kept here for history.

## Summary

On the GTK4 backend, an `HStack` containing multiple
`.frame(maxWidth: .infinity)` children does **not** give them equal
width the way SwiftUI does. GTK's `GtkBox` allocates each child its
*natural* size plus an equal share of the leftover space
(`natural + extra/N`), so a flexible child whose content has a larger
natural width ends up **wider** than its flexible siblings.

SwiftUI instead divides the available width equally among flexible
children *first*, then proposes that width to each child's content
(which wraps/truncates to fit). Content never drives the split.

## Repro

Two `.frame(maxWidth: .infinity)` drop zones side by side in an
`HStack` (Synca's `DualFolderView`): when one zone shows a long file
path and the other a short hint, the long-path zone becomes visibly
wider on GTK4 while staying equal on macOS. Selecting a folder appears
to "resize" the dashed frame.

## Root cause

`GtkBox` distributes space by child natural size. A `.frame(maxWidth:
.infinity)` child's wrapper reports its content's natural width
(`gtkFrameParentFlexibleAxes` sets `size_request` width to `-1` =
natural), so unequal content naturals → unequal allocations.

## Impact

Any layout relying on SwiftUI's "flexible siblings are equal"
assumption — split panes, two/three-up card rows, symmetric drop
zones — renders asymmetrically on GTK4 when the children's content
differs in natural width.

## Fix direction

**Root cause (corrected after investigation): `GtkBox` structurally
cannot do this.** GtkBox allocates each child its **natural** width
first, then distributes only the *leftover* space equally among
`hexpand` children — so a flexible child whose content has a larger
natural width always ends up wider. Two things that look like fixes but
are NOT:

- **`gtk_widget_set_size_request(w, 0, …)`** sets the child's *minimum*,
  not its natural. GtkBox bases allocation on natural when space allows,
  so a 0 minimum changes nothing about the split. (This was the original
  "request width 0" idea — it does not work.)
- **`gtk_box_set_homogeneous(TRUE)`** equalizes *all* children — wrong
  when a non-flexible sibling (the swap button between two zones) must
  keep its natural size.

SwiftOpenUI's two HStack paths are a build-time `GtkFixed`
(`gtkRenderSharedHStack`, no expansion) and this native `GtkBox`
(`gtkRenderFallbackHStack`, natural-biased). **Neither implements
allocation-time flexible distribution**, which is what SwiftUI's
"split the remainder equally among flexible children, respecting each
child's minimum" requires.

**Real fix (a proper slice, not a config tweak):** an allocation-time
custom horizontal layout for the flexible case — either a
`GtkLayoutManager` subclass (GObject-level C) or a size-allocate-driven
equalizer that, on each resize, measures non-flexible children at
natural, then assigns the flexible children equal slices of the
remainder (down to their minimums). Higher effort + regression risk
(must not disturb single-flexible-child, spacer, and divider layouts) —
needs design + a layout test matrix, and is worth reviewing with the
core/mac agent since it changes a foundational layout path. Until then,
the Synca fixed-width workaround below stands.

## Interim workaround (Synca)

Synca pins each drop zone to a fixed width on the SwiftOpenUI path
(`#if !os(macOS)`), keeping the two zones equal and content-
independent, while macOS keeps the responsive `.frame(maxWidth:
.infinity)`. See `FolderDropZone.swift` (`WORKAROUND` referencing this
issue).

## Related

- Ellipsizing labels in a flexible frame: a `.lineLimit(1)` label
  wrapped in `.frame(maxWidth: .infinity)` now fills-and-ellipsizes
  instead of sitting at full natural width (fixed in
  `gtkFrameParentFlexibleAxes`), which is a prerequisite for the
  fixed-width workaround to truncate long paths cleanly rather than
  clip them.
