# Dismissal Confirmation Dialog Batch C Agent Prompts

## Core Prompt

```text
Implement Dismissal Confirmation Dialog Batch C core API.

Base branch:
- develop

Create:
- dismissal-confirmation-dialog-batch-c-core

Read first:
- docs/plans/dismissal-confirmation-dialog-batch-c-plan.md
- docs/plans/dismissal-confirmation-dialog-batch-c-worker-briefs.md

Scope:
- dismissalConfirmationDialog(_:shouldPresent:actions:)

Files:
- Sources/SwiftOpenUI/Modifiers/ConfirmationDialogModifier.swift
- Tests/SwiftOpenUITests/ViewTests/Phase4FViewTests.swift

Requirements:
- add the new public modifier
- lower it into existing ConfirmationDialogView
- preserve existing confirmationDialog behavior
- add storage tests

Do not:
- redesign modal infrastructure
- change platform backends in this branch
```

## GTK Prompt

```text
Verify GTK for Dismissal Confirmation Dialog Batch C.

Base branch:
- origin/dismissal-confirmation-dialog-batch-c-core

Create:
- gtk-dismissal-confirmation-dialog-batch-c

Scope:
- verification-first

Goal:
- confirm existing GTK confirmation-dialog rendering works with dismissalConfirmationDialog lowering
- add a GTK smoke test only if useful

Do not:
- change public API
- update tracker/parity docs
- redesign GTK modal presentation
```

## Win32 Prompt

```text
Verify Win32 for Dismissal Confirmation Dialog Batch C.

Base branch:
- origin/dismissal-confirmation-dialog-batch-c-core

Create:
- win32-dismissal-confirmation-dialog-batch-c

Scope:
- verification-first

Goal:
- confirm existing Win32 confirmation-dialog rendering works with dismissalConfirmationDialog lowering
- add focused tests only if useful

Do not:
- change public API
- update tracker/parity docs
- redesign Win32 dialog behavior
```

## Web Prompt

```text
Verify Web for Dismissal Confirmation Dialog Batch C.

Base branch:
- origin/dismissal-confirmation-dialog-batch-c-core

Create:
- web-dismissal-confirmation-dialog-batch-c

Scope:
- verification-first

Goal:
- confirm existing Web confirmation-dialog rendering works with dismissalConfirmationDialog lowering
- add descriptor/render coverage only if useful

Do not:
- change public API
- update tracker/parity docs
- redesign Web dialog behavior
```
