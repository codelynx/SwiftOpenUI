# GTK4/Win32: `.accessibilityLabel` not modeled

## Summary

`.accessibilityLabel(_:)` is not modeled on GTK4/Win32, so shared code
that provides screen-reader labels must guard it with `#if os(macOS)`.
In Synca the sync/merge action badges carry accessibility labels
("will be copied to destination", etc.) instead of exposing the raw SF
symbol name to VoiceOver; on Linux/Windows the badge falls back to the
ambient widget description.

## Synca call sites (parity drivers)

- `apple/Synca/Synca/Views/CompareResultView.swift` — L852, `.accessibilityLabel(action.accessibilityLabel)` on the action badge. The label text (`SyncAction.accessibilityLabel`) is already platform-neutral; only the modifier is missing.

## Proposed resolution

Declare `.accessibilityLabel(_:)` on the shared view protocol. GTK4:
`gtk_accessible_update_property` with `GTK_ACCESSIBLE_PROPERTY_LABEL`.
Win32: expose via UI Automation `Name` property (or no-op signature to
start, since the label string already exists in shared code).

## Acceptance

- Synca CRV drops the `#if os(macOS)` around `.accessibilityLabel`.
- Orca (GTK4) reads the action-badge label instead of the icon name (verified on real hardware — Linux-side agent).
- `Examples/Parity` entry with an accessibility-labeled control.
