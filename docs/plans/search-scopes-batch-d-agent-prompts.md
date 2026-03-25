# Search Scopes Batch D Agent Prompts

## Core

```text
Implement Search Scopes Batch D core API.

Base:
- develop

Branch:
- search-scopes-batch-d-core

Scope:
- searchScopes(_:scopes:)

Read first:
- docs/plans/search-scopes-batch-d-plan.md
- docs/plans/search-scopes-batch-d-worker-briefs.md

Files:
- Sources/SwiftOpenUI/Modifiers/SearchableModifier.swift
- Tests/SwiftOpenUITests/ViewTests/Phase4FViewTests.swift
- docs/plans/search-scopes-batch-d-*.md

Requirements:
- keep SearchableView as the primitive
- add erased scope storage and selection write-back plumbing
- add the public searchScopes API
- add storage tests

Do not:
- implement backend rendering
- add searchSuggestions(_:for:)
- add Android work
```

## GTK

```text
Implement GTK support for Search Scopes Batch D.

Base:
- origin/search-scopes-batch-d-core

Branch:
- gtk-search-scopes-batch-d

Scope:
- render a simple scope row under the searchable UI
- clicking a scope writes back to the bound selection

Files:
- Sources/Backend/GTK4/Rendering/GTKRenderer.swift
- Sources/Backend/GTK4/Rendering/GTK4DescriptorTree.swift if needed
- Tests/BackendTests/GTK4Tests/GTK4RenderTests.swift

Rules:
- keep token and suggestion rendering intact
- hide scopes when searchable is dismissed
- do not change public API
- do not update tracker/parity docs
```

## Win32

```text
Implement Win32 support for Search Scopes Batch D.

Base:
- origin/search-scopes-batch-d-core

Branch:
- win32-search-scopes-batch-d

Scope:
- render simple scope controls under the searchable UI
- selecting a scope writes back to the bound selection

Files:
- Sources/Backend/Win32/Rendering/WinRenderer.swift
- Tests/BackendTests/Win32Tests/Win32RenderTests.swift

Rules:
- keep token and suggestion rendering intact
- honor dismissed-state hiding
- do not change public API
- do not update tracker/parity docs
```

## Web

```text
Implement Web support for Search Scopes Batch D.

Base:
- origin/search-scopes-batch-d-core

Branch:
- web-search-scopes-batch-d

Scope:
- render simple scope controls under the searchable UI
- clicking a scope writes back to the bound selection

Files:
- Sources/Backend/Web/Rendering/WebRenderer.swift
- Sources/Backend/Web/Rendering/WebDescriptorTree.swift if needed
- Tests/BackendTests/WebTests/WebDescriptorTests.swift

Rules:
- keep token and suggestion rendering intact
- hide scopes when searchable is dismissed
- do not change public API
- do not update tracker/parity docs
```
