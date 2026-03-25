# Safe Area Padding Batch A

## Scope

Batch A covers the `safeAreaPadding` family:

- `safeAreaPadding()`
- `safeAreaPadding(_ length: Int)`
- `safeAreaPadding(_ edges: Edge.Set, _ length: Int? = nil)`

This batch is intentionally narrower than a full native safe-area implementation.

## Goal

Add the public SwiftUI-shaped `safeAreaPadding` surface and make it usable across
GTK, Win32, and Web with an explicit synthetic fallback model.

The point of this batch is:

- correct public API shape
- predictable cross-platform behavior
- honest partial-parity documentation

The point of this batch is not:

- true device safe-area measurement
- keyboard-aware padding
- platform-native notch/titlebar inset fidelity

## Why This Fits Now

Batch 1 already established the core safe-area vocabulary:

- `SafeAreaRegions`
- `VerticalEdge`
- `HorizontalEdge`
- `SafeAreaInsetEdge`
- `SafeAreaInsetAlignment`
- `IgnoresSafeAreaView`
- `SafeAreaInsetView`

`safeAreaPadding` can build on that work without inventing a new layout model.

## Public API Contract

Add a new primitive wrapper:

```swift
public struct SafeAreaPaddingView<Content: View>: View, PrimitiveView {
    public let content: Content
    public let edges: Edge.Set
    public let length: Int?
}
```

Add these overloads:

```swift
public func safeAreaPadding() -> SafeAreaPaddingView<Self>
public func safeAreaPadding(_ length: Int) -> SafeAreaPaddingView<Self>
public func safeAreaPadding(_ edges: Edge.Set, _ length: Int? = nil) -> SafeAreaPaddingView<Self>
```

## Batch A Semantics

### Stored Meaning

- `edges` selects which edges are padded
- `length != nil` means explicit padding amount
- `length == nil` means "use backend synthetic safe-area padding"

### Backend Fallback Rule

Backends do not need true measured safe-area values in Batch A.

Instead:

- explicit length uses that exact amount
- nil length uses a backend-defined synthetic default

Recommended synthetic default for Batch A:

- `16` points/pixels on selected edges

This is not SwiftUI-perfect. It is an intentional approximation until the repo
has a real safe-area measurement model.

### Interaction With Existing Modifiers

- `safeAreaPadding` is padding-like, not inset-reservation-like
- it should compose like ordinary padding around the wrapped content
- it does not replace `safeAreaInset`
- it does not need to fully model nested `ignoresSafeArea` interactions in Batch A

## Expected Tracker Result

Implementation tracker:

- `safeAreaPadding` becomes `Implemented` once the public surface exists

Parity matrix:

- Core becomes `Y`
- GTK, Win32, and Web should start as `~`
- notes must say the batch uses synthetic safe-area padding, not measured native insets

## Branch Model

- `safe-area-padding-batch-a-core`
- `gtk-safe-area-padding-batch-a`
- `win32-safe-area-padding-batch-a`
- `web-safe-area-padding-batch-a`

All platform branches should be created from the core branch commit, not directly from `develop`.

## Core Responsibilities

Core owns:

- public API
- primitive storage type
- shared tests
- tracker regeneration
- final parity-matrix wording

## Backend Responsibilities

GTK:

- lower to padding/container layout with synthetic default when `length == nil`

Win32:

- lower to existing padding/container layout with synthetic default when `length == nil`

Web:

- lower to CSS padding with synthetic default when `length == nil`

Android:

- deferred

## Verification

Shared:

- `swift test`

Core tests:

- `safeAreaPadding()` stores `.all` and `length == nil`
- `safeAreaPadding(_ length:)` stores `.all` and explicit length
- `safeAreaPadding(_ edges:_:)` stores the selected edges and explicit/nil length correctly

Backend tests:

- explicit-length path works
- nil-length path uses backend synthetic default
- selected edges are honored

## Definition of Done

Batch A is done when:

- the core `safeAreaPadding` family exists
- GTK, Win32, and Web all render it safely
- the synthetic fallback is consistent and documented
- tracker/parity docs do not overclaim native safe-area fidelity
