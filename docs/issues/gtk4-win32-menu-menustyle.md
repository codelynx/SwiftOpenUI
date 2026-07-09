# GTK4/Win32: `Menu` + `.menuStyle` missing — forces a divergent dual implementation

## Summary

`Menu { } label: { }` with `.menuStyle(.borderlessButton)` is not
available on GTK4/Win32. This is the one *behavioral* parity gap in
Synca's shared UI (all the others are dropped-modifier compile gaps):
the merge-resolution control is a genuine dual implementation, not a
guarded modifier.

- macOS: a dropdown `Menu` offering Use Source / Use Destination / Keep Both.
- GTK4/Win32: a **cycle button** fallback — each tap advances
  useSource → useDestination → keepBoth → useSource.

The cycle-button works but has worse discoverability than a dropdown.
Closing this gap collapses the largest remaining `#elseif os(Linux) ||
os(Windows)` block in the shared layer.

## Synca call sites (parity drivers)

- `apple/Synca/Synca/Views/CompareResultView.swift` — L935 (`#if os(macOS)` Menu vs `#elseif os(Linux) || os(Windows)` cycle-button), ~40 lines. This is the classification's only "framework-gap requiring a real primitive," highest effort.

## Proposed resolution

Implement `Menu` + `.menuStyle`. GTK4: `GtkPopoverMenu` / `GMenuModel`
anchored to the label. Win32: `TrackPopupMenu` from the label's HWND.
Once available, replace the Synca cycle-button fallback with the shared
`Menu` and delete the `#elseif` branch.

## Acceptance

- Synca merge-resolution control uses a single shared `Menu`; the cycle-button `#elseif` branch is deleted.
- GTK4 popover shows all three resolutions and invokes `onResolutionChange` (verified on real hardware — Linux-side agent).
- `Examples/Parity` entry: a labeled `Menu` with 3 actions on all backends.

## Resolution (Option A — SwiftUI-shaped generic `Menu`; GTK4 full, Win32/Web minimal)

Design agreed with the owner (Option A over a parallel type). Note: a
non-SwiftUI-shaped `Menu(_ title:) { MenuItem(…) }` (string items via
GMenuModel) already existed; the gap was the **view-shaped** SwiftUI API.

- **Core** (`Views/Menu.swift`): `Menu` is now generic
  `Menu<Label: View, Content: View>` with `init(content:label:)` and a
  `init(_ title:) where Label == Text` convenience — matches SwiftUI, so
  Synca compiles unmodified. `MenuElement`/`MenuItem`/`SubMenu`/`MenuBuilder`
  are untouched (they back `.contextMenu`, a separate mechanism).
- **`.menuStyle`** (`ControlStyleModifiers.swift`): `MenuStyleType`
  (`.automatic` / `.borderlessButton`) as an env value, mirroring
  `buttonStyle`/`textFieldStyle`.
- **GTK4** (full): `GtkMenuButton` with the rendered `label` as its child
  (new `gtk_swift_menu_button_set_child` shim), a `gtk_popover_new` popover
  holding the rendered `content` (items are normal Buttons → actions +
  env-capture already work), `.borderlessButton` → `set_has_frame(false)`
  (new shim). Custom popovers don't auto-dismiss on item tap, so each
  descendant `GtkButton` gets a `clicked` handler that pops the popover
  down after it fires (act-then-dismiss; `@State` lives in the view model,
  not the widget, so hiding can't drop the mutation).
- **Win32 / Web (minimal, per owner OK):** Win32 renders the view `label`
  as the trigger; the view-shaped popup (items are Views, not the string
  MenuElements `TrackPopupMenu` needs) is a Windows-side follow-up. Web
  renders the `label` into the trigger and the `content` views into the
  dropdown (functional). Neither validated on-platform.
- **Synca:** the `#if os(macOS)` Menu / `#elseif` cycle-button fork is
  deleted; the merge-resolution control is one shared `Menu` on all
  platforms. GTK4 + Synca build green; suite 757 pass / 3 skip / 0 fail.

### Open items (for review)

1. **Reconcile (§5 of the design write-up).** `Menu` is a `Body = Never`
   primitive rendered only in `gtkCreateWidget` — describe-opaque, like the
   pre-existing `Menu`. Synca's trigger (`ActionBadge`) is *dynamic* (it
   reflects the current resolution), so a value change could go stale on a
   narrow reconcile — the same class as `gtk4-passthrough-modifier-reconcile-safety`,
   but harder because the popover content lives in a **detached surface**
   (not the button's normal child tree), so describing children for
   reconcile may not slot-match. Deferred pending a decision: describe
   through the popover surface, or accept rebuild-on-change. **This is the
   riskiest unknown and wants the reviewer's read.**
2. Item dismissal correctness (act-then-dismiss) needs an interactive check.
3. Win32/Web view-shaped popup parity (currently minimal).
4. `Examples/Parity` entry (macOS-reference side).
