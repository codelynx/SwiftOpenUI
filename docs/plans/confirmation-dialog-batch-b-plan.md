# Confirmation Dialog Batch B Plan

## Goal

Expand `confirmationDialog` from the current narrow action-sheet-style overload to the canonical iOS 15+ family shape that carries title visibility and optional message content.

Batch B scope:

- `confirmationDialog(_:isPresented:titleVisibility:actions:)`
- `confirmationDialog(_:isPresented:titleVisibility:actions:message:)`

Deferred:

- `dismissalConfirmationDialog(_:shouldPresent:actions:)`
- full SwiftUI builder DSL parity beyond the simplified action/message forms
- Android backend work

## Why This Scope

`confirmationDialog` already has backend rendering on GTK, Win32, and Web through the shared primitive. The current limitation is public surface shape, not backend absence.

This batch should do for `confirmationDialog` what Presentation Batch A and Alert Batch B did for their families:

- move the public API closer to canonical SwiftUI shape
- keep the primitive renderer model stable
- avoid reopening modal infrastructure unless a backend truly needs it

## Core Contract

Current primitive stores:

- `content`
- `title`
- `isPresented`
- `[AlertButton]`

Batch B should extend it with:

- `titleVisibility`
- optional `message`

Recommended supporting type:

- `Visibility`
  - `.automatic`
  - `.visible`
  - `.hidden`

Recommended primitive shape:

- keep `ConfirmationDialogView`
- add:
  - `titleVisibility: Visibility`
  - `message: String`

Public overloads:

- `confirmationDialog(_:isPresented:titleVisibility:actions:)`
- `confirmationDialog(_:isPresented:titleVisibility:actions:message:)`

Compatibility rule:

- keep the existing `confirmationDialog(_:isPresented:actions:)` overload as a convenience that lowers to:
  - `titleVisibility: .automatic`
  - `message: ""`

## Backend Contract

GTK, Win32, and Web should continue using their existing confirmation-dialog presentation approach.

Batch B backend expectations:

- no modal redesign required
- if `titleVisibility == .hidden`, the backend may still need a simplified fallback
- acceptable fallback:
  - keep dialog title text hidden only within body content if native shell title cannot be suppressed cleanly

Message support:

- render message text when non-empty
- preserve current vertical action-sheet style

## Status Rules

Implementation tracker:

- `confirmationDialog` should remain `Implemented` if the curated tracked family is already satisfied by the new overload shape
- if tracker wording changes, it should describe titleVisibility/message support explicitly

Parity matrix:

- `.confirmationDialog()` likely stays `Y`
- unless a backend ends up with a real titleVisibility limitation that should be called out as `~`

## Verification

Core:

- storage tests for titleVisibility and message
- compatibility test for the old convenience overload

Backends:

- GTK smoke coverage for message rendering if GTK needs a small tweak
- Win32 verification that message text still maps cleanly to MessageBoxW
- Web descriptor/render coverage for titleVisibility/message if the primitive shape changes
