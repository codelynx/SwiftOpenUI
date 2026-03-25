# Search Suggestions Batch C Plan

## Goal

Add a usable first-pass search suggestion surface on top of the now-complete `searchable` families, without taking on full search scopes or the iOS 18 suggestion matching API in the same batch.

Batch C scope:

- `searchSuggestions(_:)`
- `searchCompletion(_:)`

Deferred:

- `searchSuggestions(_:for:)`
- `searchScopes(_:scopes:)`
- Android backend work

## Why This Scope

`searchable` now has full curated family coverage, but the broader search experience is still missing suggestion UI. The next highest-value addition is:

- visible search suggestions
- completion values that can populate the search field

`searchScopes` is a separate state model. The iOS 18 `searchSuggestions(_:for:)` variant adds matching/filter semantics that should not be mixed into the first suggestion batch.

## Core Contract

Batch C should extend the existing search primitive with optional suggestion state.

Recommended shape:

- keep `SearchableView` as the single primitive search container
- add:
  - `suggestions: [SearchSuggestionValue]`
  - `suggestionMode: SearchSuggestionMode?`

Supporting types:

- `SearchSuggestionValue`
  - `id: String`
  - `label: String`
  - `completion: String?`

- `SearchSuggestionMode`
  - `.suggestions`

Public API direction:

- `searchSuggestions(_:)` should accept a lightweight builder/content shape that the core lowers into erased `SearchSuggestionValue` entries
- `searchCompletion(_:)` should mark a suggestion row with the completion text that will be inserted into the bound search text when chosen

Batch C does not need a full arbitrary suggestion view tree. A pragmatic first pass is:

- builder collects text-like suggestion entries
- each entry becomes a visible suggestion row with optional completion payload

## Behavior Rules

- suggestions are shown only when:
  - search UI is effectively visible
  - suggestion list is non-empty

- selecting a suggestion with a completion value:
  - writes completion into the search text binding
  - may hide the suggestion list if that matches the backend’s simplest behavior

- selecting a suggestion without an explicit completion value:
  - uses its visible label as the completion text

- `searchCompletion(_:)` is a data marker first in Batch C
  - backend styling can stay simple

## Backend Contract

GTK, Win32, and Web should all support the same minimum Batch C fallback:

- render suggestion rows under the existing search field
- preserve source order
- update the bound search text when a suggestion row is activated
- keep token display from Batch B intact when tokens are also present

Acceptable Batch C fallback:

- plain list rows or simple buttons
- no keyboard navigation parity
- no inline highlight matching

Not acceptable:

- silently dropping suggestion rows
- rendering suggestions but not wiring completion selection back to the text binding

## Status Rules

Implementation tracker:

- `searchSuggestions` should move from `Missing` to `Implemented`
- `searchCompletion` should move from `Missing` to `Implemented`
- `searchScopes` remains `Missing`

Parity matrix:

- `.searchable()` remains `~`
- suggestion UI should be called out as Batch C fallback
- scopes remain absent

## Verification

Core:

- storage tests for lowered suggestion rows
- `searchCompletion` value propagation tests

Backends:

- GTK render/descriptor tests for suggestion rows and completion activation
- Win32 render tests for suggestion list presence and completion write-back
- Web descriptor or host tests for suggestion rows and completion write-back
