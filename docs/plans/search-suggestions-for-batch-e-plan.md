# Search Suggestions For Batch E Plan

## Goal

Complete the remaining curated `searchSuggestions` family by adding a pragmatic first-pass `searchSuggestions(_:for:)` surface that filters lowered suggestion rows in core.

Batch E scope:

- `searchSuggestions(_:for:)`

Deferred:

- `searchPresentationToolbarBehavior(_:)`
- `searchDictationBehavior(_:)`
- Android backend work

## Why This Scope

After Batch D:

- `searchable` is implemented
- `searchCompletion` is implemented
- `searchScopes` is implemented
- `searchSuggestions` is still partial because the iOS 18 family `searchSuggestions(_:for:)` is missing

The cleanest next step is to finish that family without inventing a new backend primitive. The existing suggestion UI already renders lowered rows and completion write-back; Batch E should reuse that path.

## Core Contract

Keep `SearchableView` as the single primitive search container.

Batch E should:

- add a second public suggestion family:
  - `searchSuggestions(_:for:)`
- reuse existing `SearchSuggestionValue`
- extend `SearchSuggestionMode` with:
  - `.suggestionsFor`

Recommended first-pass API shape:

- live on `SearchableView`
- accept lowered suggestion values plus a query string
- filter rows in core before they reach the backend

This is intentionally pragmatic rather than SwiftUI-exact. The important thing for Batch E is:

- the public family exists
- matching/filter semantics are real
- backends do not need a second suggestion rendering system

## Behavior Rules

- if the query is empty:
  - keep all supplied suggestions

- if the query is non-empty:
  - keep rows whose visible label contains the query, case-insensitively
  - also match against explicit completion text when present

- source order must be preserved after filtering

- completion behavior remains unchanged:
  - picking a rendered row writes `completion ?? label` into the search binding

## Backend Contract

GTK, Win32, and Web should be able to reuse their existing Batch C suggestion rendering unchanged.

Batch E backend expectation:

- no new UI primitive required
- render whatever filtered suggestion rows the core passes down
- preserve existing token/scope/suggestion composition

Acceptable Batch E outcome:

- backend branches are verification-only if the existing suggestion UI already works with the lowered state

## Status Rules

Implementation tracker:

- `searchSuggestions` should move from `Partial` to `Implemented`

Parity matrix:

- `.searchable()` remains `~`
- note that `searchSuggestions(_:for:)` uses core-side filtered fallback rows on GTK/Win32/Web

## Verification

Core:

- storage test for filtered suggestion rows
- case-insensitive filtering test
- source-order preservation test
- explicit completion matching test

Backends:

- verification-only passes are acceptable if no renderer change is needed
- add backend tests only if a backend needs a code change
