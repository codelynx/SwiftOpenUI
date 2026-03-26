# Disabled Batch A Worker Briefs

## Shared scope

- implement `.disabled(_:)` support for backend interactive controls
- read inherited `EnvironmentValues.isEnabled`
- apply ancestor-composed semantics:
  - `effectiveIsEnabled = previous.isEnabled && !wrapper.isDisabled`

## GTK

### Files

- `Sources/Backend/GTK4/Rendering/GTKRenderer.swift`
- GTK tests

### Goal

- `DisabledView: GTKRenderable` should update environment and render content
- controls should set GTK sensitivity from `env.isEnabled`

## Win32

### Files

- `Sources/Backend/Win32/Rendering/WinRenderer.swift`
- Win32 render tests

### Goal

- `DisabledView: WinRenderable` should update environment and render content
- interactive controls should use disabled/native non-interactive state

## Web

### Files

- `Sources/Backend/Web/Rendering/WebRenderer.swift`
- Web tests

### Goal

- `DisabledView: WebRenderable` should update environment and render content
- form controls should receive `disabled`
- button-like interactions should be suppressed when disabled

## Rules

- only edit backend files and backend tests
- do not change public API
- do not update tracker/parity docs as final truth
- keep this feature in Batch A only
