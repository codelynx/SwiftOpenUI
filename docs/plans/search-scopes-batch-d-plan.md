# Search Scopes Batch D Plan

## Goal

Add the first `searchScopes` family on top of the existing searchable primitive, with real scope selection write-back on GTK, Win32, and Web.

Batch D scope:

- `searchScopes(_:scopes:)`

Deferred:

- `searchSuggestions(_:for:)`
- `searchPresentationToolbarBehavior(_:)`
- `searchDictationBehavior(_:)`
- Android backend work

## Why This Scope

After Batch C:

- `searchable` is implemented
- `searchCompletion` is implemented
- `searchSuggestions` is partial
- `searchScopes` is the next highest-value missing search surface

`searchScopes` is a separate state model from suggestions:

- suggestions are completion candidates
- scopes are mutually exclusive search filters

They should not be mixed into one batch.

## Core Contract

Keep `SearchableView` as the single primitive search container.

Batch D should extend it with optional scope state:

- `scopes: [SearchScopeValue]`
- `selectedScopeID: String?`
- `scopeMode: SearchScopeMode?`
- an erased selection writer used by backends when the user picks a scope

Recommended supporting types:

- `SearchScopeMode`
  - `.scopes`

- `SearchScopeValue`
  - `id: String`
  - `label: String`

- `SearchScopeSelectionBox`
  - stores current selected id
  - stores a write-back closure from selected id to the original typed binding

Public API direction:

- `searchScopes(_:scopes:)` should live on `SearchableView`
- the typed selection binding should be lowered immediately into:
  - selected scope id string
  - erased scope rows
  - erased selection writer

Batch D does not need SwiftUI-exact scope view builders. A pragmatic first pass is:

- builder collects text-like scope labels
- each scope entry is lowered to a simple `SearchScopeValue`

## Behavior Rules

- scope controls are shown only when:
  - search UI is effectively visible
  - scope list is non-empty

- exactly one selected scope id should be reflected in the primitive at a time

- selecting a scope row:
  - updates the bound selection through the erased writer
  - updates visible selected styling if the backend supports it

- `searchScopes` should compose with existing Batch A/B/C search UI:
  - search field
  - tokens
  - suggestions
  - scopes

## Backend Contract

GTK, Win32, and Web should all support the same minimum Batch D fallback:

- render simple mutually exclusive scope controls below the existing search UI
- preserve source order
- selecting a scope writes back to the original bound selection
- keep tokens and suggestions intact when scopes are also present

Acceptable Batch D fallback:

- simple segmented-button style or horizontal button row
- no keyboard navigation parity
- no native platform scope picker fidelity

Not acceptable:

- rendering scopes without updating the bound selection
- silently dropping the current selected scope state

## Status Rules

Implementation tracker:

- `searchScopes` should move from `Missing` to `Implemented`
- `searchSuggestions` remains `Partial` until `searchSuggestions(_:for:)`

Parity matrix:

- `.searchable()` remains `~`
- note that scopes use simple fallback controls on GTK/Win32/Web
- placement and token editing remain fallback-level

## Verification

Core:

- storage tests for selected scope id lowering
- builder tests for scope rows and source order
- write-back plumbing tests where feasible

Backends:

- GTK tests for visible scope row order and dismissed-state hiding
- Win32 tests for scope buttons and selection write-back
- Web descriptor/host tests for scope list and click-to-select behavior
