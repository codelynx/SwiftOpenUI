# Confirmation Dialog Batch B Agent Prompts

## Core

```text
Implement Confirmation Dialog Batch B core support.

Base branch:
- develop

Branch:
- confirmation-dialog-batch-b-core

Scope:
- Sources/SwiftOpenUI/Modifiers/ConfirmationDialogModifier.swift
- confirmation-dialog core tests
- docs/plans/confirmation-dialog-batch-b-*.md

Required API:
- confirmationDialog(_:isPresented:titleVisibility:actions:)
- confirmationDialog(_:isPresented:titleVisibility:actions:message:)

Requirements:
- add titleVisibility support
- add message support
- preserve the old convenience overload
- keep lowering to the same primitive

Do not:
- add dismissalConfirmationDialog in this batch
- redesign modal infrastructure
- update tracker/parity docs as final truth
```

## GTK

```text
Verify GTK behavior for Confirmation Dialog Batch B.

Base branch:
- origin/confirmation-dialog-batch-b-core

Branch:
- gtk-confirmation-dialog-batch-b

Scope:
- GTK confirmation-dialog files/tests only if needed

Goal:
- confirm existing GTK confirmation-dialog rendering still works with titleVisibility/message after lowering to the primitive
- add GTK tests only if a GTK-specific adjustment is required

Do not:
- change public API
- update tracker/parity docs as final truth
```

## Win32

```text
Verify Win32 behavior for Confirmation Dialog Batch B.

Base branch:
- origin/confirmation-dialog-batch-b-core

Branch:
- win32-confirmation-dialog-batch-b

Scope:
- Win32 confirmation-dialog files/tests only if needed

Goal:
- confirm existing Win32 confirmation-dialog rendering still works with titleVisibility/message after lowering to the primitive
- add Win32 tests only if a Win32-specific adjustment is required

Do not:
- change public API
- update tracker/parity docs as final truth
```

## Web

```text
Verify Web behavior for Confirmation Dialog Batch B.

Base branch:
- origin/confirmation-dialog-batch-b-core

Branch:
- web-confirmation-dialog-batch-b

Scope:
- Web confirmation-dialog files/tests only if needed

Goal:
- confirm existing Web confirmation-dialog rendering still works with titleVisibility/message after lowering to the primitive
- add Web tests only if a Web-specific adjustment is required

Do not:
- change public API
- update tracker/parity docs as final truth
```
