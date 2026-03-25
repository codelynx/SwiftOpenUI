# Search Suggestions Batch C Agent Prompts

## Core

```text
Implement Search Suggestions Batch C core API.

Base:
- develop

Branch:
- search-suggestions-batch-c-core

Scope:
- searchSuggestions(_:)
- searchCompletion(_:)

Read first:
- docs/plans/search-suggestions-batch-c-plan.md
- docs/plans/search-suggestions-batch-c-worker-briefs.md

Files:
- Sources/SwiftOpenUI/Modifiers/SearchableModifier.swift
- Tests/SwiftOpenUITests/ViewTests/Phase4FViewTests.swift
- docs/plans/search-suggestions-batch-c-*.md

Requirements:
- keep SearchableView as the primitive
- add erased suggestion storage
- add public APIs for searchSuggestions and searchCompletion
- add storage tests

Do not:
- implement backend rendering
- add searchScopes
- add searchSuggestions(_:for:)
```

## GTK

```text
Implement GTK support for Search Suggestions Batch C.

Base:
- origin/search-suggestions-batch-c-core

Branch:
- gtk-search-suggestions-batch-c

Scope:
- render suggestion rows under searchable search field
- selecting a suggestion writes completion text into the search binding

Files:
- Sources/Backend/GTK4/Rendering/GTKRenderer.swift
- Sources/Backend/GTK4/Rendering/GTK4DescriptorTree.swift if needed
- Tests/BackendTests/GTK4Tests/GTK4RenderTests.swift

Rules:
- keep token rendering intact
- keep placement behavior at existing fallback level
- do not change public API
- do not update tracker/parity docs
```

## Win32

```text
Implement Win32 support for Search Suggestions Batch C.

Base:
- origin/search-suggestions-batch-c-core

Branch:
- win32-search-suggestions-batch-c

Scope:
- render suggestion rows under searchable search field
- selecting a suggestion writes completion text into the search binding

Files:
- Sources/Backend/Win32/Rendering/WinRenderer.swift
- Tests/BackendTests/Win32Tests/Win32RenderTests.swift

Rules:
- keep token rendering intact
- keep placement behavior at existing fallback level
- do not change public API
- do not update tracker/parity docs
```

## Web

```text
Implement Web support for Search Suggestions Batch C.

Base:
- origin/search-suggestions-batch-c-core

Branch:
- web-search-suggestions-batch-c

Scope:
- render suggestion rows under searchable search field
- clicking a suggestion writes completion text into the search binding

Files:
- Sources/Backend/Web/Rendering/WebRenderer.swift
- Sources/Backend/Web/Rendering/WebDescriptorTree.swift if needed
- Tests/BackendTests/WebTests/WebDescriptorTests.swift

Rules:
- keep token rendering intact
- keep placement behavior at existing fallback level
- do not change public API
- do not update tracker/parity docs
```
