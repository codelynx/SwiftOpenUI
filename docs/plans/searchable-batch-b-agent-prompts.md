# Searchable Batch B Agent Prompts

## Core

```text
Implement Searchable Batch B core support.

Base branch:
- develop

Branch:
- searchable-batch-b-core

Scope:
- Sources/SwiftOpenUI/Modifiers/SearchableModifier.swift
- searchable core tests
- docs/plans/searchable-batch-b-*.md

Required API:
- searchable(text:tokens:placement:prompt:token:)
- searchable(text:editableTokens:placement:prompt:token:)

Requirements:
- add a shared erased token storage model
- preserve the existing SearchableView primitive
- keep placement and isPresented from Batch A
- add storage tests

Do not:
- add searchSuggestions/searchScopes/searchCompletion
- change tracker/parity docs as final truth
```

## GTK

```text
Implement GTK Searchable Batch B.

Base branch:
- origin/searchable-batch-b-core

Branch:
- gtk-searchable-batch-b

Scope:
- GTK searchable rendering/descriptors/tests

Requirements:
- render visible token state
- preserve token state across rebuilds
- keep existing Batch A fallback placement behavior unless a cheap improvement exists

Do not:
- change public API
- update tracker/parity docs as final truth
```

## Win32

```text
Implement Win32 Searchable Batch B.

Base branch:
- origin/searchable-batch-b-core

Branch:
- win32-searchable-batch-b

Scope:
- Win32 searchable rendering/tests

Requirements:
- render visible token state
- preserve token state across rebuilds
- current top search-field fallback is acceptable for placement

Do not:
- change public API
- update tracker/parity docs as final truth
```

## Web

```text
Implement Web Searchable Batch B.

Base branch:
- origin/searchable-batch-b-core

Branch:
- web-searchable-batch-b

Scope:
- Web searchable rendering/descriptors/tests

Requirements:
- render and describe token state
- preserve token state through rebuilds
- keep current Batch A placement fallback unless a cheap improvement exists

Do not:
- change public API
- update tracker/parity docs as final truth
```
