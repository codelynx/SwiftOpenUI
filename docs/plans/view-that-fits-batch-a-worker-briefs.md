# ViewThatFits Batch A Worker Briefs

## Shared scope

- Implement backend support for `ViewThatFits { ... }`
- First child that fits wins
- Fallback to last child if none fit
- Preserve source order
- Keep scope narrow; no axis parameter in Batch A

## GTK

### Goal

Port the existing `swiftlinuxui` concept into SwiftOpenUI's GTK renderer.

### Files

- `Sources/Backend/GTK4/Rendering/GTKRenderer.swift`
- GTK tests as needed

### Notes

- Prefer a direct primitive implementation.
- Reuse the existing `swiftlinuxui` approach where it fits the current renderer architecture.
- If exact allocation-driven switching is difficult in tests, prioritize correct runtime behavior and smoke coverage.

## Win32

### Goal

Add a simple first-fit adaptive container to the Win32 renderer.

### Files

- `Sources/Backend/Win32/Rendering/WinRenderer.swift`
- Win32 render tests

### Notes

- Measure candidate children using the existing layout/render path.
- Render/select only the chosen child.
- Keep the implementation straightforward; no speculative optimization.

## Web

### Goal

Add a best-effort adaptive first-fit container in the Web renderer.

### Files

- `Sources/Backend/Web/Rendering/WebRenderer.swift`
- `Sources/Backend/Web/Rendering/WebDescriptorTree.swift` only if needed
- Web tests

### Notes

- Best-effort DOM measurement is acceptable.
- Preserve source order and fallback-to-last behavior.
- Avoid overengineering descriptor state unless required.

## Rules

- Edit only backend files and backend tests
- Do not change public API
- Do not update tracker/parity docs as final truth
- If backend fidelity is weaker than ideal, state the limitation explicitly
