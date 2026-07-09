# GTK4: `HStack` does not split width equally among `.frame(maxWidth: .infinity)` children

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

Give `HStack` (and the flexible-frame path) SwiftUI's equal-division
semantics for flexible children: distribute the available width
equally among `maxWidth == .infinity` children regardless of their
content natural width (e.g. request width 0 for such wrappers so
`GtkBox` splits the remainder evenly, while non-flexible siblings —
like a spacer button between two zones — keep their natural size).
This must not regress the many single-flexible-child layouts that
currently rely on the natural-width request, so it needs its own
slice + tests.

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
