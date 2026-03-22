# Shared Layout Foundation Plan

## Goal

Move core layout policy toward shared Swift code so SwiftOpenUI behaves more like
SwiftUI across backends without forcing sample code to compensate for backend
quirks.

The target is not pixel-perfect parity. The target is:

- client code stays SwiftUI-shaped
- layout behavior is reasonably close to macOS SwiftUI
- container layout policy is shared where practical
- backend-specific work is limited to measurement and native placement

This work is motivated by issues such as calculator button label centering on
GTK. The fix should live in shared layout/rendering behavior, not in sample code.

## Current State

The codebase already has some layout-related primitives in core:

- `ProposedViewSize`
- `Alignment`
- `EdgeInsets`

But layout execution is uneven across backends:

- **Win32** already has a custom layout engine for stacks, frames, and z-stack
  placement.
- **GTK4** relies more heavily on native GTK containers and alignment defaults.
- **Web** uses DOM/CSS layout primitives.
- **Android** is still early and uses Compose-oriented JSON output.

This means layout policy is currently duplicated or implicit in platform
containers, which makes parity harder to maintain.

## Non-Goals

This phase does not try to:

- replace all native layout with a pure cross-platform engine
- make every backend behave identically
- implement the full SwiftUI `Layout` protocol in one step
- solve advanced baseline/alignment-guide behavior immediately

## Architecture Direction

We should split responsibilities like this:

### Shared core layout owns

- proposal propagation
- container measurement rules
- stack/frame/z-stack alignment behavior
- spacing rules
- child placement math

### Backends own

- intrinsic measurement of native content
- text measurement
- mapping placements to native widget/window APIs
- clipping, scrolling, focus, hit testing, repaint behavior
- platform-native window sizing and resize constraints

This means a future `Layout` implementation becomes the shared "brain", while
each backend remains responsible for the platform-native "eyes and hands".

## Proposed Foundation Types

Add shared layout execution primitives in `Sources/SwiftOpenUI/Layout/`:

- `LayoutMeasureContext`
  - asks the backend to measure a child view under a `ProposedViewSize`
- `LayoutSubview`
  - abstract child handle used by shared layout code
- `LayoutMeasurement`
  - measured size and relevant layout metadata
- `LayoutPlacement`
  - child origin + size within a container

The exact names may change, but the contract should be:

1. parent proposes size to child
2. backend measures child
3. shared layout computes container size and child placements
4. backend applies placements to native widgets

## Migration Strategy

Use incremental migration, not a rewrite.

### Phase 1: Foundation

- add shared layout types and execution contract
- no visible behavior change yet
- document backend adapter responsibilities

### Phase 2: Frame

- migrate `FrameView` alignment and sizing logic first
- use this as the proving ground for shared proposal/placement flow
- verify calculator-style vertical centering and fixed-frame behavior

### Phase 3: Stacks

- migrate `VStack`
- migrate `HStack`
- migrate `ZStack`

These are the highest-value containers because they define most visible layout
behavior across examples and parity screens.

### Phase 4: Grids

- migrate `Grid`
- migrate lazy stacks/grids where appropriate

Only do this after the stack/frame contract is stable.

### Phase 5: Public Layout protocol

- implement the public `Layout` protocol on top of the shared foundation
- then consider `AlignmentGuide`

## First Targets

The first container behaviors to centralize should be:

1. `FrameView`
2. `VStack`
3. `HStack`
4. `ZStack`

Why:

- they are visible in almost every example
- they affect centering and fixed-size behavior directly
- Win32 already contains logic we can use as a behavioral reference
- they are simpler than grid/lazy layout

## Backend Implications

### GTK4

GTK should rely less on native container defaults for core SwiftUI layout
semantics.

GTK remains responsible for:

- measuring labels, entries, buttons, and other native widgets
- creating actual widgets
- applying final positions/sizes or native constraints

### Win32

Win32 already has the most explicit layout engine. The likely path is to move
layout policy out of `LayoutEngine.swift` into shared code while preserving
Win32's measurement and window-placement behavior.

### Web

Web can often express placements through CSS, but the sizing/placement decisions
should still come from shared layout policy where possible.

### Android

Android can adopt the same shared layout model later, even if the initial
backend continues to emit Compose-oriented layout descriptions.

## Testing Strategy

We should add tests at three levels:

### Core layout tests

- proposal propagation
- frame alignment
- stack spacing/alignment
- z-stack placement

### Backend adapter tests

- measurement bridges
- placement application to native widgets

### Parity/example validation

- update parity notes to reflect ownership
- use existing examples to visually validate cross-backend behavior

## Success Criteria

This work is successful when:

- sample code does not need backend-specific tweaks to look reasonable
- calculator-style centering issues are fixed through shared layout behavior
- GTK and Win32 become closer for the same SwiftOpenUI view tree
- adding the future public `Layout` protocol is straightforward instead of
  requiring another architecture reset

## Immediate Next Step

Implement the shared layout foundation scaffolding, then migrate `FrameView`
first.
