# Searchable Batch B Plan

## Goal

Expand `searchable` beyond the Batch A text-only families by adding token-based search state in a way that is useful, renderer-friendly, and still honest about backend limitations.

Batch B scope:

- `searchable(text:tokens:placement:prompt:token:)`
- `searchable(text:editableTokens:placement:prompt:token:)`

Deferred:

- `searchSuggestions`
- `searchScopes`
- `searchCompletion`
- Android backend work

## Why This Scope

The tracker already shows `searchable` as close to parity. The remaining curated family set is the token-based surface:

- token-backed search
- editable-token search

These two families need a shared token model. They should be designed together instead of added as isolated overloads.

Suggestions and scopes are a separate presentation problem and should stay out of this batch.

## Core Contract

Batch A primitive today stores:

- `content`
- `text`
- `prompt`
- `placement`
- optional `isPresented`

Batch B should extend that primitive with optional token state.

Recommended model:

- keep `SearchableView` as the single primitive
- add optional token configuration fields:
  - `tokens: Binding<[SearchTokenValue]>?`
  - `editableTokens: Binding<[SearchTokenValue]>?`
  - `tokenLabel: (SearchTokenValue) -> String`

Because `View` storage cannot hold an arbitrary generic token type directly once erased for renderer use, Batch B should introduce a small erased token wrapper.

Recommended supporting types:

- `SearchTokenValue`
  - stores stable identity string
  - stores label string
  - wraps the original token only as far as needed to rehydrate closures during primitive construction

Pragmatic alternative:

- keep the generic overloads
- lower them immediately into:
  - plain text
  - `[SearchToken]` style erased values with `id` + `label`

## Behavior Rules

- `tokens` family:
  - selected tokens are read-only from the backend perspective in Batch B
  - backend may display them and keep them in sync, but does not need full native token editor behavior yet

- `editableTokens` family:
  - backend may use the same visual treatment as `tokens` in Batch B
  - true in-place token editing may fall back to text-only behavior plus visible selected-token chips

- `placement` and `isPresented` rules from Batch A still apply

## Backend Contract

GTK, Win32, and Web should all support the same minimum Batch B fallback:

- render the search field
- render selected tokens as lightweight chips/tags when token bindings are non-empty
- preserve the bound token arrays across rebuilds
- do not promise native token-field editing parity

Acceptable Batch B fallback:

- token lists displayed above or beside the existing search field
- editable-token family may behave the same as token family for now

Not acceptable:

- silently ignoring token bindings
- dropping token state on rebuild

## Status Rules

Implementation tracker:

- `searchable` should move from `Partial` to `Implemented` once both token families are present

Parity matrix:

- `.searchable()` should likely remain `~`
- placement is still fallback-level on GTK/Win32/Web
- token editing is still simplified

## Verification

Core:

- storage tests for token and editable-token overloads
- erased token label/id tests

Backends:

- GTK descriptor/render tests for visible token state
- Win32 render tests for token container presence and preservation
- Web descriptor tests for token state serialization
