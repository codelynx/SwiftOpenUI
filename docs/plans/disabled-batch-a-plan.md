# Disabled Batch A

## Goal

Implement `.disabled(_:)` as a single-batch feature across GTK, Win32, and Web.

Batch A is the full feature for this modifier:

- add `\.isEnabled` environment state
- add `.disabled(_:)`
- make core interactive controls honor inherited enabled state

There should be no `disabled` Batch B.

## Scope

### In scope

- `EnvironmentValues.isEnabled`
- `disabled(_:)`
- nested disabled composition using ancestor `&&` semantics
- backend support for the main interactive controls:
  - `Button`
  - `TextField`
  - `SecureField`
  - `TextEditor`
  - `Toggle`
  - `Slider`
  - `Stepper`
  - `Picker`
  - `DatePicker` if cheap in the current renderer

### Out of scope

- visual styling parity with native SwiftUI
- accessibility semantics beyond basic disabled behavior
- Android

## Core design

Use a dedicated primitive wrapper instead of lowering directly to
`.environment(\.isEnabled, ...)`.

Reason:

- SwiftUI disabled state composes with ancestors
- parent `.disabled(true)` should not be undone by child `.disabled(false)`

So Batch A uses a `DisabledView` wrapper:

- stores `content`
- stores `isDisabled`
- backends compute:
  - `env.isEnabled = previous.isEnabled && !isDisabled`

## Backend intent

### GTK

- propagate `isEnabled` through render-time environment
- use `gtk_widget_set_sensitive(widget, ...)` on supported controls

### Win32

- propagate `isEnabled` through render-time environment
- use `EnableWindow(hwnd, FALSE/TRUE)` or equivalent disabled state handling

### Web

- propagate `isEnabled` through render-time environment
- use `disabled` attribute for form controls
- suppress click/submit behavior for non-form interactive wrappers if needed

## Tests

### Core

- default `EnvironmentValues.isEnabled == true`
- `.disabled(true)` stores wrapper state
- nested wrappers preserve structure for ancestor-composed semantics

### Backends

- disabled controls do not trigger actions/binding writes
- enabled controls still work
- nested `.disabled(true).disabled(false)` remains disabled

## Acceptance

- `.disabled(_:)` exists publicly
- main interactive controls honor inherited disabled state on GTK, Win32, and Web
- feature is completed in Batch A with no follow-up batch split
