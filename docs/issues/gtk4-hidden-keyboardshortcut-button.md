# GTK4/Win32: No pattern for a global `.keyboardShortcut` without a visible control

## Summary

On macOS, Synca registers a ⌘F "Find" shortcut by placing a hidden,
zero-size `Button(...).keyboardShortcut("f", modifiers: .command).hidden()`
in the view hierarchy — the shortcut registers even though nothing
renders. The equivalent pattern is unproven on GTK4/Win32, so ⌘F (focus
the filter field) is macOS-only today; SwiftOpenUI users click the field
to focus it.

Need either (a) `.hidden()` reliably keeping a `.keyboardShortcut`-
bearing control registered but non-rendering, or (b) a first-class
window-scoped shortcut API that doesn't require a host control.

Related: [[gtk4-onexitcommand-esc-handling]] (both are keyboard-input
parity gaps); see also the keyboard-shortcut scope/lifecycle notes in
the Synca memory follow-ups.

## Synca call sites (parity drivers)

- `apple/Synca/Synca/Views/CompareResultView.swift` — L218 `.background(findShortcutHook)` and L252 `findShortcutHook` (the hidden ⌘F button), both currently `#if os(macOS)`.

## Proposed resolution

Prefer a window-scoped shortcut registration API (`.keyboardShortcut`
on a non-rendering modifier, or a `Commands`-style registration) so no
hidden host control is needed. GTK4: `GtkShortcutController` at window
scope. Win32: accelerator table / `WM_HOTKEY` at window scope.

## Acceptance

- Synca registers ⌘F on all backends without a platform guard.
- ⌘F focuses the GTK4 filter field at runtime (verified on real hardware — Linux-side agent).
- `Examples/Parity` entry: a window-scoped shortcut with no visible control.
