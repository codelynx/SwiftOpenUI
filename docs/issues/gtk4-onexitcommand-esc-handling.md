# GTK4/Win32: `.onExitCommand` (ESC key) not available

## Summary

`.onExitCommand { }` — the SwiftUI hook for the Escape key — is not
available on GTK4/Win32, so shared code must guard ESC handling with
`#if os(macOS)`. This is functional: in Synca the ESC handler clears the
Compare-Results filter field and defocuses it, an interaction Linux/
Windows users currently lack.

Known gap — previously flagged by the macOS-side agent as a Loop 1
prerequisite.

## Synca call sites (parity drivers)

- `apple/Synca/Synca/Views/CompareResultView.swift` — L440, in the filter `TextField`:
  ```swift
  .onExitCommand {
      clearFilter()
      filterFieldFocused = false
  }
  ```

## Proposed resolution

Declare `.onExitCommand(_:)` on the shared view protocol. GTK4: attach a
`GtkEventControllerKey` and fire the closure on `GDK_KEY_Escape`. Win32:
handle `WM_KEYDOWN` / `VK_ESCAPE` on the focused subtree.

## Acceptance

- Synca CRV drops the `#if os(macOS)` around `.onExitCommand`.
- Pressing ESC in the GTK4 filter field clears + defocuses it (verified on real hardware — Linux-side agent).
- `Examples/Parity` entry demonstrating ESC handling on all backends.

## Resolution (GTK4 implemented, Linux-side)

Implemented via the **existing** window keyboard-shortcut infrastructure
rather than a bespoke per-widget controller:

- **Core** (`Modifiers/OnExitCommandModifier.swift`): `OnExitCommandView<Content>`
  + `View.onExitCommand(perform:)`. Uses the `body: some View { content }`
  pass-through model (like `TextSelectionView`), so backends without an
  override — including Win32 — compile and stay inert with no extra code.
- **GTK4** (`GTKRenderer.swift`): `OnExitCommandView` `GTKRenderable`
  registers a modifier-less `KeyboardShortcut(.escape, modifiers: [])` in
  the window-scoped `KeyboardShortcutRegistry` bound to the action, and
  unregisters on widget destroy (mirrors `FocusedValueView`). The window's
  existing key controller (`gtkAttachKeyboardShortcutController`) already
  dispatches Escape — `.escape` was already in the keysym map.

**Scope note (window vs responder-chain):** dispatch is window-scoped,
not strictly focus/responder-chain-scoped like SwiftUI. For Synca's
single-filter-field-per-window case this is behaviourally identical; a
window with multiple competing Escape handlers would resolve to the
most-recently-registered (registry `.last(where:)`). Acceptable and
documented; revisit if a real multi-handler case appears.

Synca guard removed (filter `TextField`); GTK4 build green, test suite
green.

**Remaining for full close:** runtime confirmation that ESC in the GTK4
filter field clears + defocuses (interactive session), plus the
macOS-reference `Examples/Parity` entry.

## Win32 note (for a future pass)

Win32 needs a real handler eventually: subclass/hook `WM_KEYDOWN` /
`VK_ESCAPE` on the focused subtree, or reuse the Win32 keyboard-shortcut
path if one exists. Pass-through for now.
