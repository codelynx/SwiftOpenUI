# Toolbar Batch B Plan

## Goal

Finish the remaining curated `toolbar` base families in one batch so `toolbar` itself no longer needs a follow-up Batch C.

Batch B scope:

- `toolbar(_:for:)`
- `toolbar(removing:)`

Deferred:

- `toolbarVisibility(_:for:)`
- `toolbarBackground(_:for:)`
- `toolbarBackgroundVisibility(_:for:)`
- `toolbarForegroundStyle(_:for:)`
- `toolbarColorScheme(_:for:)`
- `toolbarRole(_:)`
- `toolbarTitleMenu(content:)`
- `toolbarTitleDisplayMode(_:)`
- Android backend work

## Why This Scope

After Batch A:

- `toolbar(content:)` is implemented
- `toolbar(id:content:)` is implemented
- the tracker still shows `toolbar` as partial because two curated base families are missing

The cleanest way to avoid a `Toolbar Batch C` is to finish those two remaining base families together now.

## Core Contract

Batch B should add a separate toolbar configuration wrapper instead of overloading `ToolbarView` itself.

Recommended types:

- `ToolbarVisibility`
  - `.automatic`
  - `.visible`
  - `.hidden`

- `ToolbarPlacementTarget`
  - `.automatic`
  - `.navigationBar`
  - `.bottomBar`
  - `.tabBar`

- `ToolbarConfiguration`
  - `visibility: ToolbarVisibility?`
  - `visibilityTarget: ToolbarPlacementTarget?`
  - `removedPlacements: [ToolbarItemPlacement]`

- `ToolbarConfigurationView`
  - wraps any `View`
  - stores toolbar configuration

Public API direction:

- `toolbar(_:for:)` should store visibility + target
- `toolbar(removing:)` should store removed placements
- both should compose with existing `.toolbar { ... }` / `.toolbar(id:)` in either order

## Behavior Rules

- Batch B is configuration-first
- storing visibility/removal configuration must not lose toolbar items
- storing toolbar items must not lose previously attached configuration
- repeated `toolbar(removing:)` calls should preserve order and avoid duplicates
- later backend batches may choose how much native fidelity to provide, but the core surface must be real now

## Backend Contract

GTK, Win32, and Web should implement a practical first pass:

- if toolbar visibility is `.hidden` for the relevant toolbar target:
  - suppress toolbar chrome for that target

- if placements are removed:
  - omit those placements from rendered toolbar items

Acceptable Batch B fallback:

- only the active/top navigation toolbar target is honored
- `.automatic` behaves like backend default

Not acceptable:

- silently ignoring stored removal configuration
- storing visibility but leaving an obviously visible toolbar unchanged when the backend can suppress it cheaply

## Status Rules

Implementation tracker:

- `toolbar` should move from `Partial` to `Implemented`

Parity matrix:

- `.toolbar()` remains `Y`
- note Batch B fallback if toolbar target handling is narrower than SwiftUI

## Verification

Core:

- storage tests for visibility + target
- storage tests for removed placements
- composition tests for `.toolbar { ... }` with configuration wrappers in both orders where feasible

Backends:

- GTK tests for hidden header bar and removed placements
- Win32 tests for suppressed nav header / filtered placements
- Web tests for hidden toolbar region / filtered items
