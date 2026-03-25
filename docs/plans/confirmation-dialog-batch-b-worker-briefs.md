# Confirmation Dialog Batch B Worker Briefs

## Core Owner

Branch:

- `confirmation-dialog-batch-b-core`

Scope:

- `Sources/SwiftOpenUI/Modifiers/ConfirmationDialogModifier.swift`
- confirmation-dialog core tests
- Batch B plan docs

Responsibilities:

- add titleVisibility support
- add message support
- preserve the existing convenience overload
- keep lowering to the same primitive

Do not:

- add `dismissalConfirmationDialog` in this batch
- redesign backend presentation
- update tracker/parity docs as final truth

## GTK Worker

Branch:

- `gtk-confirmation-dialog-batch-b`

Base:

- `origin/confirmation-dialog-batch-b-core`

Scope:

- GTK confirmation-dialog renderer/tests only if needed

Responsibilities:

- verify existing GTK presentation still works with titleVisibility/message
- add GTK tests if a backend-specific change is needed

## Win32 Worker

Branch:

- `win32-confirmation-dialog-batch-b`

Base:

- `origin/confirmation-dialog-batch-b-core`

Scope:

- Win32 confirmation-dialog renderer/tests only if needed

Responsibilities:

- verify MessageBoxW path still behaves correctly with titleVisibility/message lowering
- add Win32 tests if a backend-specific change is needed

## Web Worker

Branch:

- `web-confirmation-dialog-batch-b`

Base:

- `origin/confirmation-dialog-batch-b-core`

Scope:

- Web confirmation-dialog renderer/descriptors/tests only if needed

Responsibilities:

- verify modal overlay still behaves correctly with titleVisibility/message lowering
- add Web tests if a backend-specific change is needed

## Coordinator

Responsibilities:

- merge the core branch first
- decide whether backend branches are no-op or require light verification/test commits
- regenerate tracker
- update parity wording if needed
- push and clean up branches
