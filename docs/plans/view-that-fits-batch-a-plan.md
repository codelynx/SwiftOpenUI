# ViewThatFits Batch A

## Goal

Add a narrow `ViewThatFits { ... }` primitive to SwiftOpenUI that selects the first child whose measured size fits within the available space, falling back to the last child when none fit.

Batch A is intentionally small:

- `ViewThatFits { ... }`
- no axis parameter
- no advanced adaptive heuristics
- best-effort first-fit behavior on GTK, Win32, and Web

## Why now

`ViewThatFits` is a high-value adaptive layout primitive that already exists in the sibling `swiftlinuxui` project. SwiftOpenUI already has enough adjacent infrastructure to make this a practical port:

- `AnyView`
- primitive container views
- layout proposal/measurement types
- backend renderer patterns for primitive views

This should be materially cheaper than a deeper layout batch such as safe-area Batch 2.

## Scope

### In scope

- Add `ViewThatFits`
- Add `ViewThatFitsBuilder`
- Store children as `[AnyView]`
- Core construction/storage tests
- Backend rendering for GTK, Win32, and Web
- Fallback to last child when no child fits

### Out of scope

- axis-constrained `ViewThatFits(in:)`
- platform-perfect parity with native SwiftUI measurement rules
- advanced caching/invalidation optimization
- Android

## Proposed API

```swift
public struct ViewThatFits: View {
    public typealias Body = Never

    public let children: [AnyView]

    public init(@ViewThatFitsBuilder content: () -> [AnyView])
}
```

## Core behavior

- Children are evaluated in source order.
- The first child whose measured size fits inside the container wins.
- If none fit, the last child is rendered.
- Empty content is allowed but should degrade safely to `EmptyView`-like output on backends.

## Backend intent

### GTK

Likely the cheapest path.

- Port the existing `swiftlinuxui` implementation conceptually.
- Use a `GtkStack` or equivalent wrapper.
- Re-measure on size allocation and switch the visible child.

### Win32

- Measure children using the existing Win32 sizing/layout path.
- Render only the selected child into the host container.
- Recompute selection on rebuild/layout.

### Web

- Use a host wrapper plus DOM measurement.
- Render/select the first fitting child, fallback to last.
- Best-effort behavior is acceptable for Batch A.

## Tests

### Core

- construction stores all children
- builder preserves source order
- empty/single-child cases

### Backends

- multiple children render/select in order
- fallback to last child when none fit
- switching selection on size change when practical

## Acceptance

- Public `ViewThatFits` API exists
- GTK/Win32/Web render a reasonable first-fit adaptive container
- Tracker can move `ViewThatFits` from `Missing` to `Implemented` or `Partial` depending on final backend fidelity
