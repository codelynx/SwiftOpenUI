# Dismissal Confirmation Dialog Batch C Plan

## Goal

Add the first `dismissalConfirmationDialog` family to SwiftOpenUI without reopening modal infrastructure.

Batch C scope:

- `dismissalConfirmationDialog(_:shouldPresent:actions:)`

Deferred:

- any additional overload family beyond the base dismissal-confirmation form
- `dialogSeverity(_:)`
- `dialogSuppressionToggle(isSuppressed:)`
- Android backend work

## Why This Scope

SwiftOpenUI already has working `confirmationDialog` primitives on GTK, Win32, and Web. The missing piece is public surface for a newer confirmation-dialog family, not absence of modal rendering.

This batch should:

- extend the public API in a way that fits the existing confirmation-dialog model
- keep backend changes small or avoid them entirely if the primitive lowering is stable
- preserve current cross-platform behavior instead of inventing a new modal subsystem

## Core Contract

Current primitive:

- `ConfirmationDialogView`
  - `content`
  - `title`
  - `isPresented`
  - `titleVisibility`
  - `message`
  - `buttons`

Recommended Batch C lowering:

- add a new public modifier:
  - `dismissalConfirmationDialog(_:shouldPresent:actions:)`
- lower it into `ConfirmationDialogView`
- treat:
  - `title` = provided string
  - `isPresented` = `shouldPresent`
  - `titleVisibility` = `.automatic`
  - `message` = `""`
  - `buttons` = provided actions

This keeps the primitive stable and lets backends reuse existing rendering.

## Backend Contract

GTK, Win32, and Web should continue using their existing confirmation-dialog presentation path.

Expected Batch C behavior:

- no backend-specific redesign required
- dismissal-confirmation form should render like the existing confirmation dialog
- existing button behavior and dismissal semantics should remain unchanged

Acceptable fallback:

- same fallback-level presentation already used for `.confirmationDialog()`
- no need for iOS-native dismissal heuristics or special visual treatment in this batch

## Status Rules

Implementation tracker:

- `dismissalConfirmationDialog` should move from `Missing` to `Implemented` once the public surface exists

Parity matrix:

- `.confirmationDialog()` note may mention dismissal-confirmation support if useful
- backend status should stay aligned with current fallback-level confirmation-dialog behavior

## Verification

Core:

- storage test for `dismissalConfirmationDialog(_:shouldPresent:actions:)`
- confirm the primitive lowering preserves title and action list

Backends:

- verification-only passes are expected unless a backend exposes a real issue
- backend smoke tests are acceptable if a platform wants explicit coverage

## Branch Model

Coordinator:

- `dismissal-confirmation-dialog-batch-c-core`

Platform branches:

- `gtk-dismissal-confirmation-dialog-batch-c`
- `win32-dismissal-confirmation-dialog-batch-c`
- `web-dismissal-confirmation-dialog-batch-c`

Coordinator owns:

- core API
- tracker/parity/docs
- final integration and cleanup
