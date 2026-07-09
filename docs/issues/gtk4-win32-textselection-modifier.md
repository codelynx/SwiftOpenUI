# GTK4/Win32: `.textSelection(.enabled)` not available

## Summary

`.textSelection(.enabled)` is macOS-only, so shared code that wants
user-selectable label text must guard it with `#if os(macOS)`. On
GTK4, selectable text maps naturally to `gtk_label_set_selectable`;
Win32 needs a read-only selectable control or equivalent.

Unlike the cosmetic-modifier cluster, this one is mildly *functional* —
without it, Linux/Windows users cannot select/copy path and summary
text — so a real implementation (not just a no-op) is the goal, though a
no-op signature would already remove the guards.

## Synca call sites (parity drivers)

- `apple/Synca/Synca/Views/CompareResultView.swift` — L571 (sync summary status line), L1069 (path label)

## Proposed resolution

Declare `.textSelection(_:)` on the shared view protocol. GTK4:
`gtk_label_set_selectable(true)` on `.enabled`. Win32: read-only
selectable static/edit control (or defer to no-op with signature
present).

## Acceptance

- Synca CRV drops both `#if os(macOS)` guards around `.textSelection`.
- GTK4 label text is selectable at runtime (verified on real hardware — Linux-side agent).
- `Examples/Parity` entry with a selectable Text on all backends.

## Resolution (GTK4 implemented, Linux-side)

Implemented `.textSelection(_:)` with a real GTK4 backing (not a no-op):

- **Core** (`Modifiers/TextSelectionModifier.swift`): `TextSelectability`
  enum (`.enabled`/`.disabled`) + `TextSelectionView<Content>` wrapper +
  `View.textSelection(_:)`. Mirrors the `MonospacedDigitView` pattern —
  `body: some View { content }`, so backends without an override pass
  through automatically.
- **GTK4** (`GTKRenderer.swift` + `shim.h`): `TextSelectionView`
  `GTKRenderable` extension renders the wrapped content and calls a new
  `gtk_swift_label_set_selectable` shim (`GTK_IS_LABEL`-guarded, safe
  no-op if the wrapped widget isn't a label) → `gtk_label_set_selectable`.
- **Win32**: no code needed — falls back to the `body` pass-through
  (same as `MonospacedDigitView`), so the modifier compiles and is inert
  there until a Win32 selectable-control impl lands.

Synca guards removed (CRV status line + path row); GTK4 build green,
SwiftOpenUI test suite green.

**Remaining for full close:** runtime confirmation that a GTK4 label is
actually mouse-selectable (needs an interactive session, not just a
build), plus the macOS-reference `Examples/Parity` entry.
