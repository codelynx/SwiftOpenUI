# Searchable Batch A Worker Briefs

Use these with [searchable-batch-a-plan.md](/Users/kyoshikawa/Projects/SwiftOpenUI/docs/plans/searchable-batch-a-plan.md).

Each worker owns only the files in their scope.

## Shared Batch Goal

Implement Batch A for `searchable`:

- `searchable(text:placement:prompt:)`
- `searchable(text:isPresented:placement:prompt:)`

Batch rules:

- keep the public API SwiftUI-shaped
- do not invent token/suggestion/scope APIs in this batch
- keep `.automatic` behavior stable
- placement may be advisory for non-default cases in Batch A
- do not edit tracker docs independently from the coordinator

Android is out of scope for this batch.

## Core Owner Brief

### Branch

- `searchable-batch-a-core`

### Scope

- `Sources/SwiftOpenUI/Modifiers/...`
- `Sources/SwiftOpenUI/Layout/...` if a placement type lives there
- shared tests in `Tests/SwiftOpenUITests/...`

### Deliver

Add:

- `SearchFieldPlacement`
- optional `isPresented` storage on `SearchableView`
- stored `placement` on `SearchableView`

Add public APIs:

```swift
searchable(text:placement:prompt:)
searchable(text:isPresented:placement:prompt:)
```

### Requirements

- existing convenience behavior still works
- `.automatic` is the default placement
- prompt default remains `"Search"`
- `isPresented` is stored, not dropped
- primitive view remains backend-agnostic

### Do Not Do

- do not implement backend rendering in core
- do not add tokens, suggestions, or scopes
- do not update tracker/parity docs as final truth

### Minimum Tests

- placement stored correctly
- `isPresented` stored correctly
- convenience overload lowers to `.automatic`
- prompt default preserved

## GTK Worker Brief

### Branch

- `gtk-searchable-batch-a`

### Scope

- `Sources/Backend/GTK4/Rendering/...`
- GTK tests only if needed

### Deliver

- GTK support for `SearchableView` with stored placement and optional
  presentation binding

### Requirements

- keep `GtkSearchEntry`
- `.automatic` continues to render a search entry above content
- preserve prompt behavior
- preserve text binding updates
- honor `isPresented` where practical
- if full presentation toggling is awkward, fallback to always-visible is
  acceptable in Batch A

### Not Acceptable

- dropping the `isPresented` binding entirely
- inventing GTK-only placement semantics
- changing core API

### Suggested Verification

- existing searchable smoke test still passes
- `isPresented` path renders safely
- non-default placement does not crash or lose state

## Win32 Worker Brief

### Branch

- `win32-searchable-batch-a`

### Scope

- `Sources/Backend/Win32/Rendering/WinRenderer.swift`
- Win32 tests only if needed

### Deliver

- Win32 support for `SearchableView` with stored placement and optional
  presentation binding

### Requirements

- keep current `EDIT`-based implementation
- `.automatic` remains top-of-content search UI
- preserve cue-banner prompt behavior
- preserve text binding updates
- honor `isPresented` where practical
- visibility toggle is acceptable; always-visible fallback is also acceptable if
  implemented coherently

### Not Acceptable

- silently ignoring the new storage in a way that breaks future extension
- Win32-only semantic drift from the shared contract

### Suggested Verification

- current searchable tests continue to pass
- `isPresented` path renders safely
- no regressions in search text binding

## Web Worker Brief

### Branch

- `web-searchable-batch-a`

### Scope

- `Sources/Backend/Web/Rendering/...`
- web descriptor/tests only if needed

### Deliver

- Web support for `SearchableView` with stored placement and optional
  presentation binding

### Requirements

- keep current `<input type="search">` baseline
- `.automatic` remains search-above-content
- preserve placeholder and text binding behavior
- honor `isPresented` where practical
- visibility-based fallback is acceptable for Batch A

### Not Acceptable

- changing core API
- adding token/suggestion logic in this batch
- ignoring new storage in descriptor paths if the backend describes it

### Suggested Verification

- current searchable tests continue to pass
- descriptor coverage for new storage where appropriate
- `isPresented` path does not break rendering

## Coordinator Brief

### Scope

- review integration across all workers
- run shared verification
- update tracker/parity docs

### Responsibilities

- verify public API matches the batch plan
- verify all backends preserve `.automatic` behavior
- decide whether Batch A moves `searchable` from `1 / 4` to `2 / 4`
- regenerate tracker docs
- update parity matrix notes

### Final Checks

- `swift test`
- tracker regeneration
- no tracker/doc claims beyond what the code actually supports

## Deferred Work

Explicitly deferred to Batch B:

- token families
- editable-token families
- `searchSuggestions`
- `searchScopes`
- `searchCompletion`
- Android backend work
