# Dismissal Confirmation Dialog Batch D Worker Briefs

## Shared Batch D Contract

Scope:

- real dismissal-interception semantics for `dismissalConfirmationDialog(_:shouldPresent:actions:)`
- sheet presenters only

Not in scope:

- `popover`
- `fullScreenCover`
- scene/window dismissal interception
- `interactiveDismissDisabled`
- Android

Behavior required on all active backends:

- if sheet content carries dismissal-confirmation configuration
- and the user attempts to dismiss the sheet
- the sheet stays open
- the confirmation-dialog binding becomes `true`
- the confirmation dialog is then shown through the existing confirmation-dialog rendering path

Programmatic parent teardown remains unchanged:

- `isPresented = false`
- `item = nil`

Those must still dismiss immediately.

## GTK Brief

Branch:

- `gtk-dismissal-confirmation-dialog-batch-d`

Files likely:

- `Sources/Backend/GTK4/Rendering/GTKRenderer.swift`
- GTK tests if needed

GTK responsibilities:

- detect dismissal-confirmation configuration in `SheetModifierView` and `ItemSheetModifierView`
- intercept `close-request`
- inject `dismiss` environment action that requests confirmation instead of destroying the sheet
- preserve normal programmatic dismiss behavior

Definition of done:

- close button / window close request no longer destroys the sheet immediately when interception config exists
- intercepted close sets `shouldPresent = true`
- normal sheet closing still works when no dismissal-confirmation config exists

## Win32 Brief

Branch:

- `win32-dismissal-confirmation-dialog-batch-d`

Files likely:

- `Sources/Backend/Win32/Rendering/WinRenderer.swift`
- Win32 tests

Win32 responsibilities:

- detect dismissal-confirmation configuration in `SheetModifierView` and `ItemSheetModifierView`
- intercept `WM_CLOSE`
- inject `dismiss` environment action that requests confirmation instead of destroying the sheet
- preserve normal programmatic dismiss behavior

Definition of done:

- titlebar close / close path no longer destroys the popup immediately when interception config exists
- intercepted close sets `shouldPresent = true`
- external `isPresented = false` / `item = nil` still closes immediately

## Web Brief

Branch:

- `web-dismissal-confirmation-dialog-batch-d`

Files likely:

- `Sources/Backend/Web/Rendering/WebRenderer.swift`
- `Sources/Backend/Web/Rendering/WebViewHost.swift` only if host state must participate
- Web tests

Web responsibilities:

- detect dismissal-confirmation configuration in sheet content
- intercept the close button / sheet dismiss path
- inject `dismiss` environment action for sheet content if needed
- preserve normal programmatic dismiss behavior

Definition of done:

- user-triggered sheet close requests confirmation instead of removing the overlay
- intercepted close sets `shouldPresent = true`
- external sheet teardown still removes the overlay immediately
