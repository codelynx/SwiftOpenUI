# Dismissal Confirmation Dialog Batch C Worker Briefs

## Core

Branch:

- `dismissal-confirmation-dialog-batch-c-core`

Files:

- `Sources/SwiftOpenUI/Modifiers/ConfirmationDialogModifier.swift`
- `Tests/SwiftOpenUITests/ViewTests/Phase4FViewTests.swift`
- planning docs

Required:

- add `dismissalConfirmationDialog(_:shouldPresent:actions:)`
- lower it into the existing `ConfirmationDialogView`
- do not introduce a new primitive unless strictly necessary
- add storage tests

Do not:

- redesign modal infrastructure
- touch platform backends in the core branch

## GTK

Branch:

- `gtk-dismissal-confirmation-dialog-batch-c`

Files:

- GTK backend files only if needed
- GTK tests only if useful

Expected work:

- verification-first
- confirm existing GTK confirmation-dialog rendering works with the new lowering
- add a small smoke test only if helpful

Do not:

- change public API
- update tracker/parity docs
- redesign GTK modal presentation

## Win32

Branch:

- `win32-dismissal-confirmation-dialog-batch-c`

Files:

- Win32 backend files only if needed
- Win32 tests only if useful

Expected work:

- verification-first
- confirm existing `MessageBoxW`-based confirmation dialog works with the new lowering
- add focused tests only if a real Win32 path changes

Do not:

- change public API
- update tracker/parity docs
- redesign Win32 dialog behavior

## Web

Branch:

- `web-dismissal-confirmation-dialog-batch-c`

Files:

- Web backend files only if needed
- Web tests only if useful

Expected work:

- verification-first
- confirm existing overlay-based confirmation dialog works with the new lowering
- add descriptor/render coverage only if the primitive shape requires it

Do not:

- change public API
- update tracker/parity docs
- redesign Web dialog presentation

## Coordinator

Responsibilities:

- land core API first
- push verified core base with confirmed remote hash
- collect platform verification handoffs
- merge/cherry-pick any narrow backend follow-ups
- regenerate tracker
- update parity/docs
- push `develop`
