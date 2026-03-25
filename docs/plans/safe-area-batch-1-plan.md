# Safe Area Batch 1 Plan

## Scope

Batch 1 covers:

- `ignoresSafeArea`
- `safeAreaInset`

These two should be implemented together because they need the same shared
safe-area model and touch the same backend layout/rendering paths.

## Goal

Add a minimal but coherent safe-area system that is useful for app layouts
across GTK4, Win32, Web, and Android without waiting for full Apple-platform
safe-area parity.

The target is:

- SwiftUI-shaped public API
- honest `Implemented` / `Partial` status
- predictable cross-platform fallback behavior
- room for later expansion into `safeAreaPadding`

## Non-Goals

This batch does not try to:

- reproduce Apple notch/home-indicator behavior exactly
- add full environment-driven safe-area propagation
- implement all SwiftUI safe-area region semantics in one step
- guarantee pixel parity with real SwiftUI
- land `safeAreaPadding`

## Current State

The repo already has:

- `Edge.Set`
- `Alignment`
- shared stack/frame/z-stack layout helpers
- backend-specific stack and overlay rendering

The repo does not yet have:

- `VerticalEdge`
- `HorizontalEdge`
- `SafeAreaRegions`
- any safe-area modifier implementation
- backend-specific safe-area measurement/inset plumbing

## Public API Contract

### New Shared Types

Add these core types in `Sources/SwiftOpenUI/Layout/`:

```swift
public struct SafeAreaRegions: OptionSet {
    public let rawValue: Int

    public static let container: SafeAreaRegions
    public static let keyboard: SafeAreaRegions
    public static let all: SafeAreaRegions
}

public enum VerticalEdge {
    case top
    case bottom
}

public enum HorizontalEdge {
    case leading
    case trailing
}
```

Initial expectation:

- `.container` is the only region with meaningful behavior in this batch
- `.keyboard` may exist as an API placeholder but can behave like `.container`
  or be ignored in non-mobile backends

### `ignoresSafeArea`

Add one SwiftOpenUI modifier family:

```swift
public func ignoresSafeArea(
    _ regions: SafeAreaRegions = .all,
    edges: Edge.Set = .all
) -> IgnoresSafeAreaView<Self>
```

### `safeAreaInset`

Add both tracked families:

```swift
public func safeAreaInset<V: View>(
    edge: VerticalEdge,
    alignment: HorizontalAlignment = .center,
    spacing: Int? = nil,
    @ViewBuilder content: () -> V
) -> SafeAreaInsetView<Self, V>

public func safeAreaInset<V: View>(
    edge: HorizontalEdge,
    alignment: VerticalAlignment = .center,
    spacing: Int? = nil,
    @ViewBuilder content: () -> V
) -> SafeAreaInsetView<Self, V>
```

This is enough to reach the tracked `safeAreaInset` family count without
inventing extra overloads first.

## Behavioral Contract

### `ignoresSafeArea`

Meaning in Batch 1:

- marks a view as opting out of safe-area reservation for the specified edges
- affects future safe-area-aware layout wrappers
- may be a visible no-op on platforms with zero native/synthetic safe area

That is acceptable in Batch 1 as long as:

- the API exists
- the semantics are documented
- backends do not fake unsafe behavior inconsistently

### `safeAreaInset`

Meaning in Batch 1:

- inserts extra content at one edge of the container
- reserves layout space for that inset
- leaves the base content visible in the remaining area
- alignment controls cross-axis placement of the inset content
- `spacing` controls the gap between inset content and the base content

Conceptually:

- top/bottom behaves like a vertical composition
- leading/trailing behaves like a horizontal composition

This is a layout reservation feature first, not merely an overlay.

### Default Spacing

Use:

- `0` when `spacing == nil`

Do not invent platform-specific defaults in this batch.

### Relationship Between The Two

Batch 1 only requires limited interaction:

- `ignoresSafeArea` should be stored and propagated
- future safe-area-aware parents may consult it
- `safeAreaInset` itself does not need to fully honor every nested
  `ignoresSafeArea` combination in the first pass

The important part is not to design the types in a way that blocks that future.

## Core Representation

Add dedicated primitive wrappers instead of lowering everything immediately to
`VStack` / `HStack` in the public layer.

Suggested shapes:

```swift
public struct IgnoresSafeAreaView<Content: View>: View, PrimitiveView {
    public let content: Content
    public let regions: SafeAreaRegions
    public let edges: Edge.Set
}

public enum SafeAreaInsetEdge {
    case top
    case bottom
    case leading
    case trailing
}

public enum SafeAreaInsetAlignment {
    case horizontal(HorizontalAlignment)
    case vertical(VerticalAlignment)
}

public struct SafeAreaInsetView<Content: View, Inset: View>: View, PrimitiveView {
    public let content: Content
    public let inset: Inset
    public let edge: SafeAreaInsetEdge
    public let alignment: SafeAreaInsetAlignment
    public let spacing: Int
}
```

Reason:

- keeps the public API explicit
- makes backend ownership clear
- avoids fragile re-lowering through unrelated view wrappers
- preserves room for future descriptor/tracker notes

## Backend Contract

### Shared Rule

All backends may start with synthetic safe-area behavior.

Synthetic in this context means:

- native safe-area insets may be zero
- `safeAreaInset` still reserves space and places the inset content
- `ignoresSafeArea` may have no visible effect if no safe area is otherwise
  applied

That is acceptable for Batch 1.

### GTK4

Owner files:

- `Sources/Backend/GTK4/Rendering/GTKRenderer.swift`
- descriptor files only if needed

Requirements:

- render `safeAreaInset` using explicit top/bottom or leading/trailing
  container composition
- alignment should use existing stack alignment helpers where possible
- `ignoresSafeArea` may initially render as passthrough

Do not:

- invent GTK-only safe-area padding defaults
- hide content behind header bars unless native data supports it

### Win32

Owner files:

- `Sources/Backend/Win32/Rendering/WinRenderer.swift`
- `Sources/Backend/Win32/Rendering/LayoutEngine.swift` if needed
- descriptor files only if needed

Requirements:

- `safeAreaInset` should reserve space in HWND layout, not just overlay
- use the existing shared layout helpers where practical
- `ignoresSafeArea` may initially be passthrough unless a synthetic safe area
  already exists

### Web

Owner files:

- `Sources/Backend/Web/Rendering/WebRenderer.swift`
- descriptor files only if needed

Requirements:

- `safeAreaInset` should produce reserved-edge DOM layout
- CSS composition is acceptable
- optional future enhancement: use CSS env safe-area values, but not required
  in this batch
- `ignoresSafeArea` may initially be passthrough

### Android

Owner files:

- `Sources/Backend/Android/Rendering/AndroidRenderer.swift`
- any Android host/render bridge files if needed

Requirements:

- emit distinct render nodes or a clear composition for `safeAreaInset`
- reserved space matters more than exact native inset integration
- `ignoresSafeArea` may initially be metadata or passthrough

## Implementation Status Rules

### `ignoresSafeArea`

Mark `Implemented` when:

- core API exists
- the modifier is renderable on all current backends
- no backend crashes or drops content

Visible effect may still be minimal in Batch 1.

Mark `Partial` if:

- only some tracked surface is present, or
- a backend cannot safely carry the wrapper through rendering

### `safeAreaInset`

Mark `Implemented` when:

- both vertical and horizontal families exist
- all backends reserve edge space and render inset content
- alignment and spacing are supported at least in a basic, documented way

Mark `Partial` if:

- only vertical or only horizontal edges work, or
- one or more backends degrade to overlay-without-reservation, or
- alignment is ignored in a way that changes the conceptual API contract

## Testing Checklist

### Core Tests

Add unit tests for:

- `SafeAreaRegions` option set basics
- `VerticalEdge` / `HorizontalEdge` construction
- `ignoresSafeArea` stores regions and edges correctly
- `safeAreaInset` stores edge, alignment, spacing, and inset content correctly

### Backend Tests

Each backend should add what the host allows:

- construction/render smoke test
- top or leading inset case
- bottom or trailing inset case
- spacing preserved in layout metadata or render tree if observable

### Docs / Tracker

Update after integration:

- `docs/api/implementation-tracker/modifiers-01-layout.md`
- `docs/architecture/swiftui-parity-matrix.md`
- regenerate tracker docs if source inputs changed

## Worker Briefs

### Core Owner

Scope:

- `Sources/SwiftOpenUI/Layout/...`
- new safe-area modifier file(s)
- shared tests

Deliver:

- `SafeAreaRegions`
- `VerticalEdge`
- `HorizontalEdge`
- `IgnoresSafeAreaView`
- `SafeAreaInsetView`
- public modifier APIs

Do not implement backend-specific behavior in core.

### GTK Worker

Scope:

- GTK renderer files only

Deliver:

- renderable `safeAreaInset`
- passthrough or basic support for `ignoresSafeArea`
- GTK tests if available

Do not edit public API or non-GTK backends.

### Win32 Worker

Scope:

- Win32 renderer/layout files only

Deliver:

- reserved-space `safeAreaInset`
- passthrough or basic support for `ignoresSafeArea`
- Win32 tests if available

### Web Worker

Scope:

- Web renderer/descriptor files only

Deliver:

- CSS/DOM reserved-edge `safeAreaInset`
- passthrough or basic support for `ignoresSafeArea`
- web descriptor/test updates if needed

### Android Worker

Scope:

- Android renderer/bridge files only

Deliver:

- render-node support for `safeAreaInset`
- passthrough or metadata support for `ignoresSafeArea`
- Android render tests

## Integration Order

1. core API and primitive wrappers
2. `ignoresSafeArea` passthrough support on all backends
3. `safeAreaInset` vertical + horizontal support on all backends
4. tests
5. tracker/parity update

## Recommended Commit Shape

Prefer either:

1. one core commit, then one integration commit for backends and docs

or

1. one single commit after all backends converge

Avoid mixing partial backend work with final tracker claims.
