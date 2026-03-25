# Search Suggestions Batch C Worker Briefs

## Coordinator

Scope:

- define the erased suggestion model in core
- land the new `searchSuggestions` / `searchCompletion` surface
- own tracker/parity/docs updates
- integrate backend branches

Rules:

- push a verified core base before backend handoff
- include verified remote hash in the handoff
- do not ask platform branches to edit tracker/parity docs

## Core Owner

Branch:

- `search-suggestions-batch-c-core`

Files:

- `Sources/SwiftOpenUI/Modifiers/SearchableModifier.swift`
- `Tests/SwiftOpenUITests/ViewTests/Phase4FViewTests.swift`
- plan docs under `docs/plans/`

Responsibilities:

- add erased suggestion storage
- add the new public APIs
- keep `SearchableView` as the primitive
- add storage tests

Non-goals:

- no backend-specific rendering
- no scopes
- no iOS 18 `searchSuggestions(_:for:)`

## GTK Worker

Branch:

- `gtk-search-suggestions-batch-c`

Files:

- `Sources/Backend/GTK4/Rendering/GTKRenderer.swift`
- `Sources/Backend/GTK4/Rendering/GTK4DescriptorTree.swift` if needed
- `Tests/BackendTests/GTK4Tests/GTK4RenderTests.swift`

Requirements:

- render suggestion rows below the search field
- preserve source order
- selecting a row writes completion text into the search binding
- keep Batch A/B fallback behavior for placement and tokens

Acceptable fallback:

- simple vertical list of buttons/rows
- no keyboard navigation parity

## Win32 Worker

Branch:

- `win32-search-suggestions-batch-c`

Files:

- `Sources/Backend/Win32/Rendering/WinRenderer.swift`
- `Tests/BackendTests/Win32Tests/Win32RenderTests.swift`

Requirements:

- render a visible suggestion list under the search field
- preserve source order
- selecting a row writes completion text into the search binding
- keep token row support intact

Acceptable fallback:

- simple static-button or listbox style suggestion rows
- no native autosuggest parity

## Web Worker

Branch:

- `web-search-suggestions-batch-c`

Files:

- `Sources/Backend/Web/Rendering/WebRenderer.swift`
- `Sources/Backend/Web/Rendering/WebDescriptorTree.swift` if needed
- `Tests/BackendTests/WebTests/WebDescriptorTests.swift`

Requirements:

- render suggestion rows below the search field
- preserve source order
- clicking a row writes completion text into the search binding
- keep token display intact when suggestions are also present

Acceptable fallback:

- simple list or stacked buttons
- no keyboard navigation parity

## Worker Handoff Format

- Branch:
- Commit:
- Base commit:
- Changed files:
- What was implemented:
- What remains partial:
- Tests run:
- Merge or cherry-pick:
