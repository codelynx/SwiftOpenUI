# Alert Batch B Plan

## Goal

Finish the remaining curated `alert` family by adding the error-based overload without reopening the renderer design.

Batch B scope:

- `alert(isPresented:error:actions:)`

Deferred:

- `presenting:` alert families
- builder-DSL parity for actions/message
- error-message closure variants if we decide to model them separately later
- Android backend work

## Why This Scope

The current tracker shows `alert` at `3/4` curated families. GTK, Win32, and Web already render the shared `AlertModifierView` primitive, so the cheapest high-value step is to add the missing error-driven family and lower it into that existing primitive.

This keeps Batch B core-heavy and avoids another round of backend-specific alert redesign unless a backend discovers a real limitation during verification.

## Core Contract

Add a generic overload on `View`:

- `alert(isPresented:error:actions:)`

Recommended first-pass signature:

```swift
func alert<E>(
    isPresented: Binding<Bool>,
    error: E?,
    actions: (E) -> [AlertButton] = { _ in [AlertButton("OK")] }
) -> AlertModifierView<Self> where E: Error
```

Lowering rules:

- If `error == nil`, the effective alert should not present, even if `isPresented == true`
- If `error != nil`, derive:
  - title from `LocalizedError.errorDescription` when available, otherwise `localizedDescription`
  - message from `failureReason` and `recoverySuggestion` when available
  - buttons from the `actions(error)` closure
- The overload should still lower to the existing `AlertModifierView`

This is intentionally simpler than full SwiftUI DSL parity, but it completes the tracked missing family.

## Backend Contract

Backend goal for GTK, Win32, and Web:

- no new public API
- no new modal infrastructure
- render the lowered primitive correctly once title/message/buttons come from the error-based overload

Expected backend work:

- likely none, unless a backend assumes title/message are always user-authored and needs a small test or adaptation

## Status Rules

Implementation tracker:

- `alert` should move from `Partial` to `Implemented` once this family exists and the tracker is regenerated

Parity matrix:

- `.alert()` will likely remain `~`
- reason: even with all curated families present, the backend surface still uses the simplified `[AlertButton]` + `String` model instead of full SwiftUI builder parity

## Verification

Core:

- storage tests for the new overload
- nil-error suppression test
- title/message derivation test for `LocalizedError`

Backends:

- existing alert tests should still pass
- add backend tests only if a backend needs special handling for the derived title/message/buttons
