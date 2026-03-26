# Dismissal Confirmation Dialog Batch D Plan

## Goal

Implement real dismissal-interception semantics for `dismissalConfirmationDialog`.

Batch D scope:

- `dismissalConfirmationDialog(_:shouldPresent:actions:)`
- interception of attempted dismiss for `sheet(isPresented:onDismiss:content:)`
- interception of attempted dismiss for `sheet(item:onDismiss:content:)`

Deferred:

- `popover`, `fullScreenCover`, `inspector`, or window-scene interception
- `interactiveDismissDisabled` coordination
- `dialogSeverity(_:)`
- `dialogSuppressionToggle(isSuppressed:)`
- Android backend work

## Why This Scope

Batch C added the public surface, but the current implementation only lowers to a normal binding-driven `confirmationDialog`.

That means SwiftOpenUI still does **not** support the defining behavior of the API:

- an attempted dismiss of the enclosing presentation should be intercepted
- the enclosing presentation should remain active
- the confirmation dialog should be shown instead

The missing work is in sheet/presenter lifecycle handling, not confirmation-dialog rendering.

## Core Contract

Current state:

- `dismissalConfirmationDialog(_:shouldPresent:actions:)` returns `ConfirmationDialogView`
- all backends render it like ordinary `confirmationDialog`
- no parent-dismiss interception exists

Recommended Batch D core shape:

- add an internal dismissal-confirmation carrier/protocol that `ConfirmationDialogView` can expose
- mark `dismissalConfirmationDialog` instances as dismissal-interception dialogs
- preserve the existing public API and return type
- keep ordinary `confirmationDialog` behavior unchanged

Required semantic distinction:

- ordinary `confirmationDialog`:
  - shows when its own binding becomes true
- `dismissalConfirmationDialog`:
  - does not by itself mean “present now because the binding is true”
  - is used by enclosing presentation backends as interception configuration
  - when a dismiss attempt happens, the backend sets `shouldPresent = true`
  - the sheet remains visible
  - the confirmation dialog is rendered on top of the sheet content

## Presenter Contract

For this batch, presenters should treat dismissal interception as applying only to sheets.

When a sheet content tree carries dismissal-confirmation configuration:

- user-initiated dismiss attempts should be intercepted
- the sheet should remain active
- the dismissal-confirmation binding should be set to `true`

Dismiss attempts that should be intercepted:

- environment `dismiss()`
- window/dialog close button
- titlebar/window-manager close request
- platform modal close button / overlay close

Dismiss paths that should **not** be intercepted in Batch D:

- programmatic parent teardown from outside the sheet
  - `isPresented = false`
  - `item = nil`

Those should continue dismissing the sheet immediately.

## Backend Contract

GTK:

- detect dismissal-confirmation configuration in presented sheet content
- on `close-request`, set the config binding to `true` and cancel the close
- inject `dismiss` environment action that requests confirmation instead of closing

Win32:

- detect dismissal-confirmation configuration in presented sheet content
- on `WM_CLOSE`, set the config binding to `true` and keep the sheet open
- inject `dismiss` environment action that requests confirmation instead of destroying the popup

Web:

- detect dismissal-confirmation configuration in presented sheet content
- close button / overlay dismiss path should request confirmation instead of hiding the sheet
- inject `dismiss` environment action for sheet content if missing

Acceptable Batch D fallback:

- confirmation dialog may still use the existing backend-specific fallback presentation style
- native iOS/macOS sheet-dismiss affordance parity is not required

## Status Rules

Implementation tracker:

- `dismissalConfirmationDialog` should move from `Partial` to `Implemented`
  only when attempted parent-dismiss interception exists for the Batch D sheet scope

Parity matrix:

- `.confirmationDialog()` note should explicitly say dismissal interception is implemented for sheets
- non-sheet presenters remain deferred

## Verification

Core:

- construction/storage test still passes
- add a test-only carrier/protocol assertion if the new core shape needs one

GTK:

- attempted sheet dismiss sets the dismissal-confirmation binding instead of closing
- sheet remains active while the dialog becomes presented

Win32:

- attempted sheet dismiss sets the dismissal-confirmation binding instead of destroying the window
- programmatic dismiss still closes immediately

Web:

- close button or dismiss path sets the dismissal-confirmation binding instead of removing the overlay
- programmatic dismiss still removes the sheet

## Branch Model

Coordinator:

- `dismissal-confirmation-dialog-batch-d-core`

Platform branches:

- `gtk-dismissal-confirmation-dialog-batch-d`
- `win32-dismissal-confirmation-dialog-batch-d`
- `web-dismissal-confirmation-dialog-batch-d`

Coordinator owns:

- core dismissal-confirmation carrier/protocol
- tracker/parity/docs
- final integration and cleanup
