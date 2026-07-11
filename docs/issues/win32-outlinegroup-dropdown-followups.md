# Win32: follow-ups from the OutlineGroup / D2D dropdown work

> **Open.** Filed alongside commit `629323a` ("Win32: native OutlineGroup
> tree, D2D dropdown Picker, WinMeasurable, rendering fixes"), which shipped
> the features below with these limitations documented in its message. This
> issue exists so the follow-ups aren't buried in git history.
>
> All surfaced by exercising Synca's Compare/Sync UI on Windows (the
> living-example loop).

## Summary

The Win32 backend gained a native `OutlineGroup` tree renderer
(`Win32OutlineTree.swift`), a Direct2D dropdown `Picker`
(`Win32DropdownPicker.swift`), and a `WinMeasurable` intrinsic-sizing
protocol (`Win32Measure.swift`). Four follow-ups remain.

## 1. OutlineGroup expansion state resets on an ancestor structural rebuild

The native tree keeps expansion state in a retained `Win32OutlineModel`
(not SwiftUI `@State`), so expand/collapse works and survives the arrow
click. But `OutlineGroup.winCreateWidget` allocates a **fresh** model with
an empty `expanded` set on every call, and the model dies when the hosting
view does a structural rebuild (`DestroyWindow` + re-render). So any state
change an ancestor reads — e.g. typing in Synca's Compare filter, or
flipping the sync-mode picker, after expanding some folders — collapses the
tree back to roots.

- **Root cause:** same as
  [`win32-conditional-view-rebuild.md`](./win32-conditional-view-rebuild.md)
  — there is no positional child-state reconciliation across a parent
  rebuild, so per-subtree state can't be carried over. The positional keys
  (`"0"`, `"1"`, …) are stable across rebuilds, so once reconciliation exists
  the expanded set could be re-attached by key.
- **Direction:** hoist expansion state above the rebuild boundary (a
  reconciled child-state store keyed by the OutlineGroup's identity), or a
  general child-`@State` reconciliation pass.
- **Impact:** expand/collapse is usable in the common case; the reset only
  bites when an ancestor rebuilds while folders are expanded.

## 2. OutlineGroup rows are intrinsic-width (trailing alignment ineffective)

Row bodies are pinned to their intrinsic width rather than stretched to the
list viewport, so a `Spacer()` / trailing element inside a row view has no
slack to push against. In Synca's `TreeRow` the `(N)` rollup count sits
right after the name instead of at the list's right edge.

- **Direction:** stretch each row to the content width **and** re-run the
  row's HStack layout at that width. Win32 stacks don't currently reflow on
  resize, so this needs a measure/allocate pass on the row subtree.

## 3. `.font()` size is not applied to icons

`iconFontLocked` stops an enclosing `.font()` from overwriting a Material
Symbols glyph's font (which turned the glyph into a `notdef` box). The
trade-off: a `.font()` **size** is ignored for icons — they keep their
`.imageScale`-derived size. Icons should be sized with `.imageScale`.

- **Direction:** when a `.font()` reaches an icon-locked control, re-create
  the glyph font in the Material Symbols family at the requested size **and**
  re-size the control (then let the parent re-layout). Lifetime: update the
  control's `FontCleanupInfo` so the resized font is freed and the previous
  one isn't leaked (this runs on every ancestor rebuild).

## 4. `WinMeasurable` adoption + missing Win32 tests

`WinMeasurable` (`winIntrinsicSize`) is implemented and adopted by `Picker`.
Natural next adopters: the D2D segmented control and `OutlineGroup`, so
parents can size them without a throwaway render.

No focused Win32 tests cover the new controls yet. Worth adding, coordinated
with whoever owns `Tests/BackendTests/Win32Tests/Win32RenderTests.swift`:
- `DisclosureGroup(content:label:)` renders the label view (not just `title`).
- The D2D dropdown: open on click/keyboard, select, dismiss (click-outside /
  re-click guard / Esc), and the `dropdownMetrics` intrinsic size.
