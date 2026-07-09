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

## Resolution (no framework change — the pattern already works on GTK4)

Chose **option (a)** — make the existing hidden-Button idiom work — over
adding a new non-host-control API, because every constituent piece is
already implemented on GTK4 and it keeps Synca's code identical to what a
SwiftUI developer writes (no Synca-specific hack, no API divergence):

- `.keyboardShortcut(_:modifiers:)` on a Button registers into the
  window-scoped `KeyboardShortcutRegistry` (Button GTKRenderable path).
- `HiddenView` renders its content first (so the Button's
  `gtkCreateWidget` runs and the shortcut **registers**), then wraps it
  opacity-0 / can-target-0 / sensitive-0 — invisible and inert, but
  registered.
- `BackgroundView` renders a non-color/non-shape background (here the
  hidden hook) via its `ZStack { background; content }` fallback, so the
  hook is actually in the tree.
- The window's `gtkAttachKeyboardShortcutController` dispatches the key
  to the registry — the same path `.onExitCommand`
  ([[gtk4-onexitcommand-esc-handling]]) uses in the same window.
- The action sets `@FocusState`, and `FocusedView` does a real
  `gtk_swift_grab_focus` on the bound widget.

`.command` maps to Ctrl on GTK4, so Synca's ⌘F becomes **Ctrl+F** on
Linux (the right convention). Resolution was **pure Synca guard removal**
— both `#if os(macOS)` guards (the `.background(findShortcutHook)` attach
and the `findShortcutHook` definition) dropped. GTK4 build green, no
unused-symbol warnings.

**Remaining for full close:** runtime confirmation that Ctrl+F focuses
the GTK4 filter field (interactive session), plus the macOS-reference
`Examples/Parity` entry.
