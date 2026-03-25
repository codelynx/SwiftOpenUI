# Search Scopes Batch D Worker Briefs

## Coordinator

Scope:

- define the erased scope model in core
- land the new `searchScopes` surface
- own tracker/parity/docs updates
- integrate backend branches

Rules:

- push a verified core base before backend handoff
- include verified remote hash in the handoff
- do not ask platform branches to edit tracker/parity docs

## Core Owner

Branch:

- `search-scopes-batch-d-core`

Files:

- `Sources/SwiftOpenUI/Modifiers/SearchableModifier.swift`
- `Tests/SwiftOpenUITests/ViewTests/Phase4FViewTests.swift`
- plan docs under `docs/plans/`

Responsibilities:

- add erased scope storage
- add the new public API
- keep `SearchableView` as the primitive
- add storage tests

Non-goals:

- no backend rendering here
- no `searchSuggestions(_:for:)`
- no Android work

## GTK Worker

Branch:

- `gtk-search-scopes-batch-d`

Files:

- `Sources/Backend/GTK4/Rendering/GTKRenderer.swift`
- `Sources/Backend/GTK4/Rendering/GTK4DescriptorTree.swift` if needed
- `Tests/BackendTests/GTK4Tests/GTK4RenderTests.swift`

Requirements:

- render a simple scope row below the current search UI
- preserve source order
- clicking a scope writes back to the bound selection
- hide scopes when searchable is dismissed

Acceptable fallback:

- simple horizontal button row
- no keyboard navigation parity

## Win32 Worker

Branch:

- `win32-search-scopes-batch-d`

Files:

- `Sources/Backend/Win32/Rendering/WinRenderer.swift`
- `Tests/BackendTests/Win32Tests/Win32RenderTests.swift`

Requirements:

- render visible scope controls below the current search UI
- preserve source order
- selecting a scope writes back to the bound selection
- keep tokens and suggestions intact

Acceptable fallback:

- simple button row or radio-button-like controls
- no native autosuggest/scope fidelity

## Web Worker

Branch:

- `web-search-scopes-batch-d`

Files:

- `Sources/Backend/Web/Rendering/WebRenderer.swift`
- `Sources/Backend/Web/Rendering/WebDescriptorTree.swift` if needed
- `Tests/BackendTests/WebTests/WebDescriptorTests.swift`

Requirements:

- render visible scope controls below the current search UI
- preserve source order
- clicking a scope writes back to the bound selection
- hide scopes when searchable is dismissed

Acceptable fallback:

- simple button row
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
