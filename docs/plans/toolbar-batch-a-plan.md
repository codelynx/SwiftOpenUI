# Toolbar Batch A Plan

## Goal

Expand the existing `toolbar` API so it is useful for real app navigation chrome on GTK, Win32, and Web without introducing SwiftUI's full customizable toolbar system yet.

Batch A scope:

- `toolbar(content:)` with multiple items in one closure
- `toolbar(id:content:)`

Deferred to later batches:

- `toolbar(_:for:)`
- `toolbar(removing:)`
- customizable toolbar persistence/identity behavior
- toolbar visibility/background/color-scheme APIs
- Android backend work

## Why This Scope

The backends already know how to render arrays of toolbar items:

- GTK extracts multiple toolbar items into the header bar
- Win32 renders multiple leading/trailing items into the navigation header or a fallback toolbar row
- Web renders toolbar items into the current navigation header area

The main limitation is core surface:

- only one `ToolbarItem` can be produced today
- there is no `toolbar(id:content:)` family

Batch A therefore focuses on core surface parity and leaves the visibility/configuration families for a later batch.

## Core Contract

Add a dedicated toolbar-content builder that can flatten one or more `ToolbarItem` values into `[AnyToolbarItem]`.

Recommended additions:

- `@resultBuilder ToolbarContentBuilder`
- a lightweight `ToolbarContent` carrier that stores `[AnyToolbarItem]`
- `ToolbarView` gains:
  - `toolbarItems: [AnyToolbarItem]`
  - optional `toolbarID: String?`

New/updated API:

- `toolbar(content:)`
  - now accepts multiple toolbar items in one closure
- `toolbar(id:content:)`
  - stores the id on `ToolbarView`

Batch A simplification:

- `toolbarID` is stored but backend behavior may treat it as informational only
- no customizable persistence semantics are required yet

## Backend Contract

All active backends already render toolbar arrays, so backend work should be small.

Expected backend tasks:

- adapt to any `ToolbarView` storage changes
- keep multi-item rendering stable
- ignore `toolbarID` behaviorally if there is no customization model yet

Fallbacks allowed:

- GTK: existing header-bar extraction remains the behavior
- Win32: existing nav-header / fallback toolbar row remains the behavior
- Web: existing navigation header-right area remains the behavior

## Status Rules

Implementation tracker remains surface-first.

Expected tracker movement after Batch A:

- `toolbar` should move from `1/4` to `2/4` curated families

Parity matrix remains behavior-first.

Expected parity note after Batch A:

- `toolbar` may remain `Y` if current backend behavior still accurately reflects the supported surface
- note should mention that `toolbar(id:content:)` stores id but does not yet implement customizable toolbar persistence

## Tests

Core/shared tests:

- multiple toolbar items are flattened in source order
- `toolbar(id:content:)` stores the id
- existing single-item toolbar behavior still works

Backend tests where feasible:

- GTK/Win32/Web render multiple items without dropping order
- mixed leading/trailing placements still route correctly

## Branch Model

- `toolbar-batch-a-core`
- `gtk-toolbar-batch-a`
- `win32-toolbar-batch-a`
- `web-toolbar-batch-a`

Coordinator owns:

- core API design
- merge conflict resolution
- tracker regeneration
- parity/doc truth

Platform workers own:

- backend renderer changes
- backend-specific tests
