# GTK4: `List` / `OutlineGroup` render all rows eagerly (not virtualized) — freezes on large data

## Summary

SwiftOpenUI's `List` renderable builds a widget for **every** row up front
and appends them all to a `GtkListBox`. For large data sets this freezes
the main loop (widget construction is O(rows)) and balloons memory —
there's no virtualization, so off-screen rows cost the same as visible
ones.

`GTKRenderer.swift` (`extension List: GTKRenderable`, ~L4368):

```swift
let listBox = gtk_list_box_new()!
for child in gtkRenderChildren(content) {   // renders ALL rows
    ...
    gtk_list_box_append(listBoxOp, row)     // appends ALL rows
}
```

## Impact (found in Synca)

Synca's Compare Result view renders a diff tree via `List { OutlineGroup(…) }`.
A folder comparison producing ~18,000 changes (and, in Merge mode, ~2,460
`Menu` widgets, one per modified row) **hangs the app** — GTK shows "Synca
is not responding", CPU pegs, RSS climbs past ~600 MB. The *comparison*
itself runs off-main and finishes in seconds; it's purely the **eager row
rendering** that freezes the UI. Small results (a handful of rows) render
instantly.

## The fix (the lazy primitive already exists)

GTK4's `GtkListView` is model-backed and lazy — it only realizes widgets
for **visible** rows, recycling them on scroll. SwiftOpenUI **already has**
a `GtkListView`-based lazy list (`GTKRenderer.swift` ~L5037,
"Create a GtkListView-based lazy list widget") — but `List`/`OutlineGroup`
don't route through it; they use the eager `GtkListBox` path.

Proposed: back `List` (and the `OutlineGroup` tree) with the lazy
`GtkListView` + a `GListModel`, materializing rows via the factory only as
they scroll into view. `OutlineGroup` maps to a `GtkTreeListModel` for
lazy expansion. This makes list/tree rendering O(visible) instead of
O(total).

## Acceptance

- A `List`/`OutlineGroup` with tens of thousands of rows renders and
  scrolls smoothly without freezing (row widgets created lazily).
- Memory scales with visible rows, not total rows.
- Existing small-list behavior/appearance unchanged.

## Notes

- App-side mitigation in the meantime: build the row model off the main
  thread and/or cap/paginate very large results, but the real fix is
  framework-level virtualization.
