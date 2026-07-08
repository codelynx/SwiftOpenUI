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
