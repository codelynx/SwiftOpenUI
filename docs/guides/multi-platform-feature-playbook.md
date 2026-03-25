# Multi-Platform Feature Playbook

## Goal

When a feature needs work across core plus multiple backends, organize the work so:

- the public API stays consistent
- backends do not invent different semantics
- `Implemented` vs `Partial` remains defensible
- parallel work does not create merge conflicts

This guide is for features such as `NavigationLink` parity, modifier-family completion, layout wrappers, and cross-backend rendering changes.

## Default Rule

Do not start with blind parallel coding on every platform.

Start with a shared contract, assign explicit ownership, and let each backend implement against that contract.

## Working Model

### 1. Write the feature contract first

Before anyone edits backend code, write a short task note that defines:

- public API shape
- expected behavior
- acceptable degraded behavior
- non-goals
- required tests
- tracker/parity implications

Keep it short. One page is enough for most features.

### 2. Freeze or land the core surface early

One owner should handle the shared layer first:

- `Sources/SwiftOpenUI/...`
- shared model structs
- modifier/view surface
- shared tests
- tracker/parity wording

Backend work should target a stable API whenever possible.

### 3. Split backend work by ownership

Assign each backend to one person or one agent with a disjoint write scope.

Typical split:

- GTK/Linux owner: `Sources/Backend/GTK4/Rendering/...`
- Win32 owner: `Sources/Backend/Win32/Rendering/...`
- Web owner: `Sources/Backend/Web/Rendering/...`
- Android owner: `Sources/Backend/Android/Rendering/...`
- coordinator: integration, docs, tracker, verification

Do not assign the same files to multiple workers.

### 4. Use a backend checklist

Each backend implementation should answer the same questions:

- Does it compile on that platform?
- Does the basic case render?
- Does the custom/composed case render?
- Is the fallback behavior explicit and acceptable?
- Were backend tests added or updated?
- Does the parity note need to stay `Partial`?

### 5. Reconcile centrally

One coordinator should integrate the result and make the final call on:

- `Implemented`
- `Partial`
- `Missing`

That same person should rerun:

- shared tests
- backend-specific builds where possible
- tracker regeneration
- parity/tracker doc updates

## What To Put In The Contract

For most features, use this structure:

### Summary

One paragraph describing the feature and why it matters.

### Public Surface

List the exact API being added or completed.

Example:

```swift
NavigationLink(title:destination:label:)
NavigationLink(value:title:label:)
background(_:alignment:)
background(alignment:_:)
overlay(_:alignment:)
```

### Behavioral Rules

State what must be true everywhere.

Example:

- string-label APIs must continue to work unchanged
- custom labels must preserve navigation behavior
- color backgrounds should keep existing optimized paths
- arbitrary-view backgrounds may lower to stacked composition

### Allowed Fallbacks

State what a platform may do temporarily.

Example:

- use native text button for text-only labels
- use custom child content for non-text labels
- lower arbitrary background to `ZStack` when no native wrapper exists

### Non-Goals

Prevent scope creep.

Example:

- no semantic parity for platform-only animation details
- no new native mutation path for arbitrary background wrappers
- no attempt to match Apple visual styling exactly

### Verification

List what must be exercised:

- core unit tests
- platform render tests if available
- doc/tracker update

## Good Ownership Pattern

Use this sequence:

1. coordinator writes the contract
2. core owner lands or freezes the shared API
3. backend owners implement in parallel
4. coordinator integrates, tests, and updates docs

This keeps the critical path short while still allowing parallel execution.

## Example Worker Brief

Use a brief like this for each backend worker:

```text
Feature: NavigationLink custom label parity
Ownership: Sources/Backend/GTK4/Rendering/*
Do not change public API
Assume core now stores both label text fallback and label view
Use native text button when text fallback is available
Use custom child rendering when only a custom label view exists
Preserve existing push/value navigation behavior
Add or update platform tests if available
Do not revert unrelated edits; other workers own other backends
```

That is enough to get consistent results without over-specifying the implementation.

## When To Stub

Stubs are acceptable when:

- the API shape matters now
- degraded behavior is predictable
- developers are unlikely to be misled
- the tracker can honestly remain `Partial`

Stubs are not acceptable when the API strongly implies a working behavior and a no-op would be misleading.

Examples:

- acceptable early stub: extra overload family that lowers to an existing implementation
- acceptable partial behavior: arbitrary background lowered to composition
- poor stub: `ScrollViewReader` where `scrollTo` does nothing

## `Implemented` vs `Partial`

Use these repo rules consistently:

- `Implemented`: the intended public surface for the tracked feature is present
- `Partial`: only part of the tracked public surface is present, or the fallback is intentionally limited
- behavioral or rendering caveats belong in parity notes, not in the meaning of `Implemented`

The coordinator should make this decision after integration, not backend owners independently.

## Verification Matrix

Before closing the work:

- run `swift test`
- run backend-specific builds/tests where the current host permits it
- regenerate `docs/api/implementation-tracker/` if tracker inputs changed
- update `docs/architecture/swiftui-parity-matrix.md` if backend notes changed
- confirm the docs do not claim less or more than the code actually supports

## Anti-Patterns

Avoid these:

- telling multiple workers to "implement parity" without file boundaries
- allowing each backend to define different fallback semantics
- merging backend work before the shared API is clear
- calling a feature `Implemented` because one platform is complete
- updating tracker docs without verifying the generator still runs

## Recommended Default For This Repo

For most cross-platform features in SwiftOpenUI:

- write a short contract in the task or a temporary design note
- keep one owner on `Sources/SwiftOpenUI`
- split backends by directory
- treat docs/tracker regeneration as part of done

That is the fastest reliable path without losing consistency.
