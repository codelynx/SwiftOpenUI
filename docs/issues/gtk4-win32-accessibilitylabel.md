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

## Resolution (GTK4 implemented, Linux-side)

First real GTK4 accessibility wiring in the framework (prior
`accessibilityIdentifier` was a pure pass-through).

- **Core** (`Modifiers/AccessibilityModifiers.swift`): `AccessibilityLabelView<Content>`
  + `View.accessibilityLabel(_ label: String)`, body-passthrough model
  (like `TextSelectionView`) → Win32/other backends compile and stay
  inert with no extra code.
- **GTK4** (`GTKRenderer.swift` + `shim.h`): `AccessibilityLabelView`
  `GTKRenderable` sets the accessible label on the content's top widget
  via a new `gtk_swift_accessible_set_label` shim → `GTK_ACCESSIBLE_PROPERTY_LABEL`.
  The shim wraps `gtk_accessible_update_property`, which is **variadic**
  and therefore not callable from Swift directly (`GTK_IS_ACCESSIBLE`
  guard is defensive — every GtkWidget is a GtkAccessible in GTK4).
- **Win32**: no code — `body` pass-through; a future pass maps to the
  UI Automation `Name` property.

Applied to the wrapped content's **top widget** (the view's accessibility
element), matching SwiftUI semantics — for Synca's action badge that's
the badge container announcing the label instead of the icon's symbol
name. Synca CRV guard removed; GTK4 build green, test suite green.

**Remaining for full close:** runtime confirmation with a screen reader
(Orca) that the badge announces the label (interactive session), plus the
macOS-reference `Examples/Parity` entry.

## Known limitations (from review)

1. **Dynamic labels on fast-path reconcile — RESOLVED.** The label is now
   represented in the GTK4 descriptor tree (kind `.widgetProperty`), so a
   *changed* label is re-applied on the narrow in-place mutation path, not
   only on the create path. Fixed alongside `.textSelection` in
   [[gtk4-passthrough-modifier-reconcile-safety]].
2. **Possible double-announce.** Setting the label on the container widget
   does not suppress child a11y nodes on GTK4, so a screen reader may read
   both the container label *and* the inner content (e.g. the icon's
   symbol). If the Orca test confirms this, the remedy is to set the inner
   content's role to `GTK_ACCESSIBLE_ROLE_PRESENTATION` (a11y "none") so
   only the label is announced. Deferred pending the interactive check.
