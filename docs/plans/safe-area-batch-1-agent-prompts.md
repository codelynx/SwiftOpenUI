# Safe Area Batch 1 Agent Prompts

Use these prompts with:

- [safe-area-batch-1-plan.md](/Users/kyoshikawa/Projects/SwiftOpenUI/docs/plans/safe-area-batch-1-plan.md)
- [safe-area-batch-1-worker-briefs.md](/Users/kyoshikawa/Projects/SwiftOpenUI/docs/plans/safe-area-batch-1-worker-briefs.md)

## Core Prompt

```text
Implement the core safe-area layer for SwiftOpenUI Batch 1.

Scope:
- Sources/SwiftOpenUI/Layout/*
- Sources/SwiftOpenUI/Modifiers/*
- Tests/SwiftOpenUITests/*

Requirements:
- Add SafeAreaRegions option set with .container, .keyboard, .all
- Add VerticalEdge and HorizontalEdge enums
- Add IgnoresSafeAreaView primitive wrapper
- Add SafeAreaInsetEdge and SafeAreaInsetAlignment storage enums
- Add SafeAreaInsetView primitive wrapper
- Add public APIs:
  - ignoresSafeArea(_:edges:)
  - safeAreaInset(edge:alignment:spacing:content:) for VerticalEdge
  - safeAreaInset(edge:alignment:spacing:content:) for HorizontalEdge
- Default spacing nil to 0
- Keep the wrappers backend-agnostic

Do not:
- Implement backend rendering
- Lower the API to ad hoc VStack/HStack inside the modifier implementation
- Update tracker/parity docs as final truth

Verification:
- Add shared unit tests for storage shape
- Run swift test

You are not alone in the codebase. Do not revert unrelated edits.
```

## GTK Prompt

```text
Implement GTK4 support for SwiftOpenUI Batch 1 safe-area APIs.

Scope:
- Sources/Backend/GTK4/Rendering/*
- GTK tests only if needed

Assume core already provides:
- IgnoresSafeAreaView
- SafeAreaInsetView
- SafeAreaInsetEdge
- SafeAreaInsetAlignment

Requirements:
- Render IgnoresSafeAreaView safely; passthrough is acceptable in Batch 1
- Render SafeAreaInsetView with reserved space, not overlay-only
- Support edges: top, bottom, leading, trailing
- Honor cross-axis alignment in a basic way
- Honor spacing
- Use existing stack/layout helpers where practical

Do not:
- Change public API
- Edit non-GTK backends
- Invent GTK-only default spacing or semantics

Suggested verification:
- top inset smoke test
- trailing inset smoke test
- spacing test if observable

You are not alone in the codebase. Do not revert unrelated edits.
```

## Win32 Prompt

```text
Implement Win32 support for SwiftOpenUI Batch 1 safe-area APIs.

Scope:
- Sources/Backend/Win32/Rendering/WinRenderer.swift
- Sources/Backend/Win32/Rendering/LayoutEngine.swift if needed
- Win32 tests only if needed

Assume core already provides:
- IgnoresSafeAreaView
- SafeAreaInsetView
- SafeAreaInsetEdge
- SafeAreaInsetAlignment

Requirements:
- Render IgnoresSafeAreaView safely; passthrough is acceptable in Batch 1
- Render SafeAreaInsetView with reserved space in layout, not overlay-only
- Support edges: top, bottom, leading, trailing
- Honor cross-axis alignment in a basic way
- Honor spacing
- Reuse shared layout math where practical

Do not:
- Change public API
- Edit non-Win32 backends
- Create Win32-only semantic drift from the shared contract

Suggested verification:
- render smoke test
- top/bottom layout reservation test
- leading/trailing layout reservation test

You are not alone in the codebase. Do not revert unrelated edits.
```

## Web Prompt

```text
Implement Web support for SwiftOpenUI Batch 1 safe-area APIs.

Scope:
- Sources/Backend/Web/Rendering/*
- Web descriptor/tests only if needed

Assume core already provides:
- IgnoresSafeAreaView
- SafeAreaInsetView
- SafeAreaInsetEdge
- SafeAreaInsetAlignment

Requirements:
- Render IgnoresSafeAreaView safely; passthrough is acceptable in Batch 1
- Render SafeAreaInsetView with reserved DOM layout space, not absolute-position overlay only
- Support edges: top, bottom, leading, trailing
- Honor cross-axis alignment in a basic way
- Honor spacing
- CSS/DOM composition is acceptable

Optional:
- Using CSS env safe-area values, but this is not required in Batch 1

Do not:
- Change public API
- Edit non-Web backends

Suggested verification:
- descriptor or render smoke test
- top inset case
- leading or trailing inset case

You are not alone in the codebase. Do not revert unrelated edits.
```

## Android Prompt

```text
Implement Android support for SwiftOpenUI Batch 1 safe-area APIs.

Scope:
- Sources/Backend/Android/Rendering/*
- Android tests only if needed

Assume core already provides:
- IgnoresSafeAreaView
- SafeAreaInsetView
- SafeAreaInsetEdge
- SafeAreaInsetAlignment

Requirements:
- Render IgnoresSafeAreaView safely; passthrough or metadata-only is acceptable in Batch 1
- Render SafeAreaInsetView as reserved-space composition, not overlay-only
- Support edges: top, bottom, leading, trailing
- Honor cross-axis alignment in a basic way
- Honor spacing
- Backend lowering to render-node composition is acceptable

Do not:
- Change public API
- Edit non-Android backends

Suggested verification:
- render-node smoke test
- top or bottom inset node shape
- leading or trailing inset node shape

You are not alone in the codebase. Do not revert unrelated edits.
```

## Coordinator Prompt

```text
Integrate and review SwiftOpenUI Batch 1 safe-area work after backend workers finish.

Scope:
- integration review
- shared verification
- docs/tracker updates

Requirements:
- Verify public API matches the safe-area batch plan
- Verify all backends follow the same conceptual contract
- Decide whether ignoresSafeArea and safeAreaInset are Implemented or Partial
- Run swift test
- Run backend-specific verification where host permits
- Update:
  - docs/api/implementation-tracker/modifiers-01-layout.md
  - docs/architecture/swiftui-parity-matrix.md
- Regenerate tracker docs if needed

Do not:
- Mark features Implemented if any backend still violates the shared contract
- Leave tracker/doc claims ahead of the code
```
