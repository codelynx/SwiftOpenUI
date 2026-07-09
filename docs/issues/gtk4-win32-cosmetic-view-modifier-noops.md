# GTK4/Win32: Missing cosmetic view-modifier signatures force `#if os(macOS)` in acceptance apps

## Summary

Several purely-cosmetic SwiftUI view modifiers are not declared on the
GTK4/Win32 backends, so any shared-codebase app that uses them must wrap
each call in `#if os(macOS)`. Because the modifiers don't *exist* on the
non-Apple backends, omitting the guard is a compile error — not a
graceful no-op. Declaring these modifier signatures (initially as
no-ops, later with real backend behavior where it makes sense) lets the
shared layer drop the guards entirely.

This is the single highest-leverage parity gap for the Synca acceptance
app: it accounts for ~8 of the remaining `#if os` blocks in Synca's
shared UI.

## Affected modifiers

| Modifier | Backend behavior wanted | Priority |
|---|---|---|
| `.controlSize(_:)` | Map `.small`/`.large` to widget size hints; no-op acceptable initially | high (4 call sites) |
| `.listStyle(.plain)` | Map to plain GtkListBox styling; no-op acceptable | medium |
| `.textFieldStyle(.plain)` | Borderless entry; no-op acceptable | low |
| `.monospacedDigit()` | Tabular figures; no-op acceptable | low |
| `.accessibilityIdentifier(_:)` | Set widget name / automation id; no-op acceptable | low |

## Synca call sites (parity drivers)

- `apple/Synca/Synca/Views/CompareResultView.swift` — `.controlSize(.small)` (×2: L292, L558), `.listStyle(.plain)` (L387), `.textFieldStyle(.plain)` (L440), `.monospacedDigit()` (L484)
- `apple/Synca/Synca/ContentView.swift` — `.controlSize(.large)` + `.accessibilityIdentifier("actionButton")` (L598), `.controlSize(.small)` (L605)

## Proposed resolution

Declare the modifier signatures on the shared view protocol so they
compile on every backend. Start as no-ops on GTK4/Win32 where a faithful
rendering isn't ready; upgrade `.controlSize` and `.listStyle` to real
backend behavior when convenient. The win is removing the compile-time
requirement for `#if os(macOS)`, not perfect fidelity on day one.

## Acceptance

- Synca's shared layer compiles on GTK4/Win32 with the listed `#if os(macOS)` guards removed.
- A `Examples/Parity` entry exercises `.controlSize`/`.listStyle` on all three backends.
- macOS reference behavior unchanged (owned by the macOS-side agent).

## Resolution (Linux-side, GTK4-verified)

Mostly a no-op-was-already-there discovery: **4 of the 5 modifiers
already existed** with SwiftUI-matching call forms, so the Synca guards
were stale, not blocked on missing primitives:

- `.controlSize(_:)` — `ControlSize` enum (`.mini/.small/.regular/.large/.extraLarge`) in `Modifiers/TypographyModifiers.swift`
- `.monospacedDigit()` — `Modifiers/TypographyModifiers.swift`
- `.listStyle(.plain)` — `Modifiers/ListStyleModifier.swift`
- `.textFieldStyle(.plain)` — `TextFieldStyleType.plain` in `Modifiers/ControlStyleModifiers.swift`

Only `.accessibilityIdentifier(_:)` was missing — **added** as a
pass-through in `Modifiers/AccessibilityModifiers.swift`.

Synca guards removed (GTK4 build green): `.controlSize` ×4,
`.listStyle(.plain)`, `.monospacedDigit()`, `.accessibilityIdentifier`,
and `.textFieldStyle(.plain)` pulled out of its guard (its sibling
`.onExitCommand` stays guarded pending
[[gtk4-onexitcommand-esc-handling]]).

**Remaining for full close (macOS-side):** `Examples/Parity` entry +
macOS-reference verification. The GTK4 build side is done.
