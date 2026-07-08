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
