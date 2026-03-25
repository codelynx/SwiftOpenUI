# Searchable Batch A Plan

## Scope

Batch A covers two `searchable` families:

- `searchable(text:placement:prompt:)`
- `searchable(text:isPresented:placement:prompt:)`

This batch intentionally does not include:

- token families
- `searchSuggestions`
- `searchScopes`
- `searchCompletion`

## Goal

Expand SwiftOpenUI's current `searchable` support from a single baseline overload
to a coherent first-step family that is useful for real apps and practical for
GTK4, Win32, and Web to implement in parallel.

The target is:

- SwiftUI-shaped public API for the first two canonical `searchable` families
- a shared core model for `placement` and optional presentation binding
- backend behavior that is consistent enough to document honestly
- no premature token/suggestion/scope model

## Non-Goals

Batch A does not try to:

- implement token-based searching
- add suggestions UI
- add scopes UI
- guarantee Apple-platform placement fidelity
- solve every toolbar/sidebar integration detail
- implement Android in the same pass

Android is explicitly deferred for this batch.

## Current State

The repo currently has:

- one overload in `Sources/SwiftOpenUI/Modifiers/SearchableModifier.swift`
- one primitive `SearchableView`
- working backend renderers on:
  - GTK4
  - Win32
  - Web

The tracker currently reports:

- `searchable` is `Partial`
- `1 overload(s) are present vs 4 curated reference families`

Reference basis:

- `docs/api/swiftui-reference-2025-clade.md`
- `docs/api/implementation-tracker/modifiers-09-search.md`

## Canonical Family Target

The curated reference currently treats these as the four canonical
`searchable` families:

1. `searchable(text:placement:prompt:)`
2. `searchable(text:isPresented:placement:prompt:)`
3. `searchable(text:tokens:placement:prompt:token:)`
4. `searchable(text:editableTokens:placement:prompt:token:)`

Batch A implements only the first two.

Expected tracker result after Batch A:

- `searchable` remains `Partial`
- family coverage moves from `1 / 4` to `2 / 4`

## Branch Model

All workers branch from the same `develop` base commit after the plan is
landed.

Recommended branches:

- `searchable-batch-a-core`
- `gtk-searchable-batch-a`
- `win32-searchable-batch-a`
- `web-searchable-batch-a`

The coordinator does not wait serially for each backend to finish. Backend
branches are intended to run in parallel.

## Public API Contract

### Core Storage

Extend `SearchableView` so it stores:

- wrapped content
- `Binding<String>` search text
- prompt string
- placement
- optional `Binding<Bool>` presentation state

Suggested shape:

```swift
public struct SearchableView<Content: View>: View, PrimitiveView {
    public typealias Body = Never

    public let content: Content
    public let text: Binding<String>
    public let prompt: String
    public let placement: SearchFieldPlacement
    public let isPresented: Binding<Bool>?
}
```

### Placement Type

Add a shared `SearchFieldPlacement` type in core.

Batch A rule:

- the type must exist and be stored by the primitive view
- backends may treat non-default placements as advisory in the first pass
- exact placement fidelity is not required yet

The important part is to avoid designing the type in a way that blocks later
toolbar/sidebar integration.

### Public Overloads

Add:

```swift
public func searchable(
    text: Binding<String>,
    placement: SearchFieldPlacement = .automatic,
    prompt: String = "Search"
) -> SearchableView<Self>

public func searchable(
    text: Binding<String>,
    isPresented: Binding<Bool>,
    placement: SearchFieldPlacement = .automatic,
    prompt: String = "Search"
) -> SearchableView<Self>
```

The current no-placement overload may remain as a convenience entry point if it
lowers to the new canonical storage with `.automatic`.

## Behavioral Contract

### Placement

Batch A meaning:

- placement is part of the public contract
- it must be stored in the primitive view
- `.automatic` must behave sensibly everywhere
- non-default placements may fall back to existing top-of-content search UI in
  Batch A

That fallback is acceptable as long as:

- behavior is documented honestly
- the backend does not ignore placement in a way that breaks state shape or API
  expectations

### `isPresented`

Batch A meaning:

- controls whether search UI is considered presented
- backends should honor it where practical
- if a backend cannot fully model collapsed presentation yet, it may render the
  search field persistently but should still store and use the binding
  consistently

Acceptable first-pass fallback:

- always-visible search field
- `isPresented` still wired for future use and used where trivial

Not acceptable:

- adding the overload but dropping the binding entirely
- backend-specific behavior that makes the binding meaningless or incoherent

### Existing Behavior

Current backends all render:

- a search field above the content
- prompt/placeholder text
- text binding updates

Batch A should preserve that behavior for `.automatic`.

## Backend Contract

### Shared Rule

All three backends may keep the current visible-search-above-content layout as
the baseline shape for `.automatic`.

All three backends should:

- store and consult `placement`
- support the optional `isPresented` binding
- preserve text binding behavior
- preserve prompt behavior

### GTK4

Expected Batch A behavior:

- continue using `GtkSearchEntry`
- `.automatic` stays above content
- optional presentation binding may toggle visibility if easy, otherwise remain
  always visible

### Win32

Expected Batch A behavior:

- continue using `EDIT`
- `.automatic` stays above content
- optional presentation binding may toggle child visibility if practical

### Web

Expected Batch A behavior:

- continue using `<input type="search">`
- `.automatic` stays above content
- optional presentation binding may toggle DOM visibility if easy

## Testing Contract

### Core Tests

Add tests that cover:

- placement stored correctly
- `isPresented` stored correctly
- old convenience overload lowers to `.automatic`
- prompt default preserved

### Backend Tests

Each backend should add tests where feasible for:

- placement stored or rendered in the expected primitive/backend shape
- `isPresented` path does not break rendering
- existing text binding behavior remains intact

### Coordinator Verification

Final verification should include:

- `swift test`
- tracker regeneration
- parity matrix update

## Docs Contract

Coordinator-owned:

- `docs/api/implementation-tracker/...`
- `docs/architecture/swiftui-parity-matrix.md`

Workers must not independently edit tracker docs as final truth.

Batch A expected docs outcome:

- implementation tracker still marks `searchable` as `Partial`
- parity matrix notes that GTK4 / Win32 / Web support `placement` and
  `isPresented` storage with first-pass fallback semantics where applicable
