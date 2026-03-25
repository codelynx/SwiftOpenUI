# Safe Area Batch 1 Worker Briefs

Use these with [safe-area-batch-1-plan.md](/Users/kyoshikawa/Projects/SwiftOpenUI/docs/plans/safe-area-batch-1-plan.md).

Each worker owns only the files in their scope.

## Shared Batch Goal

Implement:

- `ignoresSafeArea`
- `safeAreaInset`

Batch rules:

- keep the public API SwiftUI-shaped
- do not invent platform-specific semantics outside the shared contract
- `safeAreaInset` must reserve space, not just overlay content
- `ignoresSafeArea` may be passthrough in Batch 1 if no safe-area reservation
  exists yet
- do not change tracker docs independently from the coordinator

## Core Owner Brief

### Scope

- `Sources/SwiftOpenUI/Layout/...`
- `Sources/SwiftOpenUI/Modifiers/...`
- shared tests in `Tests/SwiftOpenUITests/...`

### Deliver

Add:

- `SafeAreaRegions`
- `VerticalEdge`
- `HorizontalEdge`
- `IgnoresSafeAreaView`
- `SafeAreaInsetEdge`
- `SafeAreaInsetAlignment`
- `SafeAreaInsetView`

Add public modifiers:

```swift
ignoresSafeArea(_:edges:)
safeAreaInset(edge:alignment:spacing:content:) // vertical
safeAreaInset(edge:alignment:spacing:content:) // horizontal
```

### Requirements

- `ignoresSafeArea` stores `regions` and `edges`
- `safeAreaInset` stores:
  - edge
  - alignment
  - spacing
  - inset content
  - wrapped content
- default `spacing == nil` resolves to `0`
- keep wrappers primitive and backend-agnostic

### Do Not Do

- do not implement backend rendering in core
- do not lower the public API to ad hoc `VStack` / `HStack` in the modifier
  itself
- do not update tracker/parity docs as final truth yet

### Minimum Tests

- `SafeAreaRegions` option-set behavior
- `ignoresSafeArea` stores values correctly
- vertical `safeAreaInset` stores edge/alignment/spacing/content
- horizontal `safeAreaInset` stores edge/alignment/spacing/content

## GTK Worker Brief

### Scope

- `Sources/Backend/GTK4/Rendering/...`
- GTK tests only if needed

### Deliver

- GTK render support for `IgnoresSafeAreaView`
- GTK render support for `SafeAreaInsetView`

### Requirements

- `ignoresSafeArea` may render as passthrough
- `safeAreaInset` must reserve space for inset content
- support all four edges:
  - top
  - bottom
  - leading
  - trailing
- honor cross-axis alignment in a basic way
- honor `spacing`

### Acceptable Implementation

- explicit composition using existing stack/layout helpers
- native GTK containers where they match the shared contract

### Not Acceptable

- overlay-only rendering for `safeAreaInset`
- GTK-only default spacing
- edits to public API or non-GTK backends

### Suggested Verification

- top inset smoke test
- trailing inset smoke test
- spacing test if observable

## Win32 Worker Brief

### Scope

- `Sources/Backend/Win32/Rendering/WinRenderer.swift`
- `Sources/Backend/Win32/Rendering/LayoutEngine.swift` if needed
- Win32 tests only if needed

### Deliver

- Win32 render support for `IgnoresSafeAreaView`
- Win32 render support for `SafeAreaInsetView`

### Requirements

- `ignoresSafeArea` may be passthrough in Batch 1
- `safeAreaInset` must reserve space in HWND layout
- support all four edges
- honor cross-axis alignment in a basic way
- honor `spacing`

### Preferred Approach

- use shared layout math where practical
- keep Win32-specific code focused on measurement and placement

### Not Acceptable

- overlay-only `safeAreaInset`
- Win32-only semantic drift from the shared contract

### Suggested Verification

- render smoke test
- top/bottom layout reservation test
- leading/trailing layout reservation test

## Web Worker Brief

### Scope

- `Sources/Backend/Web/Rendering/...`
- web descriptor/tests only if needed

### Deliver

- Web render support for `IgnoresSafeAreaView`
- Web render support for `SafeAreaInsetView`

### Requirements

- `ignoresSafeArea` may be passthrough in Batch 1
- `safeAreaInset` must reserve space in DOM layout
- support all four edges
- honor cross-axis alignment in a basic way
- honor `spacing`

### Acceptable Implementation

- CSS/DOM composition
- flex/grid/container wrappers

### Optional But Not Required

- CSS `env(safe-area-inset-*)` usage

### Not Acceptable

- absolute-position overlay-only implementation
- web-only API changes

### Suggested Verification

- descriptor or render smoke test
- top inset case
- leading or trailing inset case

## Android Worker Brief

### Scope

- `Sources/Backend/Android/Rendering/...`
- Android tests only if needed

### Deliver

- Android render-node support for `IgnoresSafeAreaView`
- Android render-node support for `SafeAreaInsetView`

### Requirements

- `ignoresSafeArea` may be passthrough or metadata-only in Batch 1
- `safeAreaInset` must reserve space in emitted layout composition
- support all four edges
- honor cross-axis alignment in a basic way
- honor `spacing`

### Acceptable Implementation

- explicit render-node composition
- stack-based lowering in the backend

### Not Acceptable

- overlay-only `safeAreaInset`
- Android-specific public API changes

### Suggested Verification

- render-node smoke test
- top or bottom inset node shape
- leading or trailing inset node shape

## Coordinator Brief

### Scope

- review integration across all workers
- run shared verification
- update tracker/parity docs

### Responsibilities

- verify the public API matches the batch plan
- verify backends follow the same conceptual behavior
- decide `Implemented` vs `Partial`
- regenerate:
  - `docs/api/implementation-tracker/...`
- update:
  - `docs/architecture/swiftui-parity-matrix.md`

### Final Checks

- `swift test`
- backend-specific builds/tests where host permits
- no tracker/docs claims beyond what the code actually supports
