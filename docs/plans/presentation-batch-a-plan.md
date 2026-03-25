# Presentation Batch A Plan

## Goal

Expand the existing `sheet` and `alert` primitives in a way that is useful for app code, cheap to implement across GTK/Win32/Web, and honest about what is still deferred.

Batch A is intentionally narrow:

- `sheet(isPresented:onDismiss:content:)`
- `sheet(item:onDismiss:content:)`
- `alert(_:isPresented:actions:)`
- `alert(_:isPresented:actions:message:)`

Deferred to later batches:

- error-based `alert`
- `presenting:` alert families
- alert/confirmation dialog builder DSL parity
- `fullScreenCover`
- `popover`
- Android backend work

## Why This Scope

`sheet` already has working backend presentation on GTK/Win32/Web. Adding `onDismiss` and item-based presentation is a meaningful step toward production usage without reopening modal infrastructure.

`alert` already has working backend presentation too, but the public API only exposes one legacy-shaped overload. Batch A adds the canonical iOS 15+ overload shapes first. This improves the tracked public surface and keeps backend work small because the same primitive storage can still drive rendering.

## Core Contract

### Sheet

Add a shared primitive that can represent both binding-driven and item-driven sheet presentation.

Expected stored state:

- presenter content
- either `isPresented: Binding<Bool>?` or `item` binding storage
- optional `onDismiss: (() -> Void)?`
- sheet content builder/result

Recommended model:

- keep `SheetModifierView` for the `isPresented` family
- add `ItemSheetModifierView` for the item family

Behavior rules:

- if `isPresented == true`, present
- if `isPresented == false`, dismiss if active
- if item binding is non-`nil`, present
- if item binding becomes `nil`, dismiss if active
- user/programmatic dismissal must:
  - dismiss the active sheet
  - set `isPresented = false` or `item = nil`
  - call `onDismiss` exactly once per dismissal cycle

Batch A fallback:

- item sheet content may be rendered from the current bound item snapshot; dynamic in-place item swapping while already presented does not need special behavior beyond a rebuild-safe update

### Alert

Keep the existing primitive renderer shape.

Expected stored state:

- presenter content
- `isPresented: Binding<Bool>`
- title string
- message string
- `[AlertButton]`

Add canonical overload declarations:

- `alert(_:isPresented:actions:)`
- `alert(_:isPresented:actions:message:)`

Batch A API simplification:

- `actions` stays `[AlertButton]`
- `message` stays `String`

This is not full SwiftUI DSL parity, but it is still useful and moves the overload surface toward the canonical families tracked in the reference.

## Backend Contract

All active backends already have basic sheet and alert presentation.

Backend work should focus on:

- `sheet`:
  - honor `onDismiss`
  - add item-based presentation/dismissal
  - avoid duplicate presentation on rebuild
- `alert`:
  - no major renderer redesign expected
  - only adapt to any core storage changes if needed

Batch A backend fallback is acceptable if:

- sheet presentation style stays the backend's existing modal approach
- alert stays the backend's existing modal/dialog approach

## Status Rules

Implementation tracker remains surface-first.

Expected tracker movement after Batch A:

- `sheet`: should move closer to curated family parity, and may reach full implementation if the curated family count is satisfied by the new signatures
- `alert`: should remain `Partial`, but with more overloads present than today

Parity matrix remains behavior-first.

Expected parity note after Batch A:

- `sheet`: likely `~` on GTK/Win32/Web until item dismissal and `onDismiss` behavior are verified across all active backends
- `alert`: likely remains `Y` or `~` depending on whether the existing backend behavior still matches the expanded overload surface without new limitations

## Tests

Core/shared tests:

- `sheet(isPresented:onDismiss:content:)` stores `onDismiss`
- item-sheet primitive stores the item binding
- alert overloads store title/message/buttons correctly

Backend tests where feasible:

- sheet dismiss updates binding/item and calls `onDismiss`
- no duplicate modal creation on rebuild
- alert overloads still render through the existing backend path

## Branch Model

- `presentation-batch-a-core`
- `gtk-presentation-batch-a`
- `win32-presentation-batch-a`
- `web-presentation-batch-a`

Coordinator owns:

- core API design
- merge conflict resolution
- tracker regeneration
- parity/doc truth

Platform workers own:

- backend renderer changes
- backend-specific tests
