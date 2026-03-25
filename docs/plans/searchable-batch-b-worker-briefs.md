# Searchable Batch B Worker Briefs

## Core Owner

Branch:

- `searchable-batch-b-core`

Scope:

- `Sources/SwiftOpenUI/Modifiers/SearchableModifier.swift`
- searchable core tests
- Batch B plan docs

Responsibilities:

- add token-based searchable overloads
- define shared erased token storage
- keep the existing primitive shape coherent
- add storage tests

Do not:

- add suggestions/scopes/completion in this batch
- redesign backend presentation from scratch
- update tracker/parity docs as final truth

## GTK Worker

Branch:

- `gtk-searchable-batch-b`

Base:

- `origin/searchable-batch-b-core`

Scope:

- GTK searchable renderer/descriptors/tests

Responsibilities:

- render visible token state
- preserve token state across rebuilds
- keep existing placement/isPresented behavior

## Win32 Worker

Branch:

- `win32-searchable-batch-b`

Base:

- `origin/searchable-batch-b-core`

Scope:

- Win32 searchable renderer/tests

Responsibilities:

- render visible token state
- preserve token state across rebuilds
- keep current top-of-content fallback for placement unless a better Win32 layout is cheap

## Web Worker

Branch:

- `web-searchable-batch-b`

Base:

- `origin/searchable-batch-b-core`

Scope:

- Web searchable descriptors/rendering/tests

Responsibilities:

- describe and render token state
- preserve token state through host rebuilds
- keep current Batch A placement fallback unless a cheap improvement exists

## Coordinator

Responsibilities:

- merge the core branch first
- review GTK/Win32/Web for consistent token fallback semantics
- regenerate tracker
- update parity wording for token support
- push and clean up branches
