# GTK4 Animation Improvements — Implementation Plan

## Context

Animation basics work on GTK4 (opacity, offset, scale via CSS transitions). Four improvement areas identified. Splitting into two batches: **Batch A** (low-risk mechanical work) and **Batch B** (Transition API, higher complexity).

---

## Batch A: Rotation Animation + Descriptors + Tests

### A1. Integrate rotationEffect into the animation pipeline

**Problem:** `RotationView` applies CSS directly but doesn't store the angle on the widget. The ViewHost rebuild can't capture/interpolate rotation during `withAnimation()`.

**Files:**
- `Sources/Backend/GTK4/Rendering/GTKRenderer.swift`
  - Add `gtkSwiftRotationKey` constant
  - `RotationView.gtkCreateWidget()`: store angle via `setWidgetDouble`, remove the wrapper GtkBox (apply transform directly like offset/scale do), combine with existing offset/scale values
  - `buildTransformCSS()`: add `rotation: Double = 0` parameter, append `rotate({angle}deg)` when non-zero
  - Update `OffsetView` and `ScaleEffectView` call sites to read and pass current rotation

- `Sources/Backend/GTK4/Rendering/GTKViewHost.swift`
  - Capture `oldRotation` from old child before teardown (line ~220)
  - Read `newRotation` from new child after build
  - Include rotation in `transformChanged` check
  - Pass rotation to both `buildTransformCSS()` calls (old values + new values)

### A2. Add GTKDescribable conformance to animation views (prerequisite work)

**Scope clarification:** Adding descriptors for animation views does NOT avoid full rebuilds today. The narrow-mutation gate (`gtkCanApplyTextColorHostMutation`) only allows text/color/canvas/slider/padding update intents. New animation descriptor kinds will still fall through to full rebuild. This work improves descriptor tree fidelity and is prerequisite infrastructure for future narrow-mutation support — it does not provide an immediate performance win.

**Files:**
- `Sources/Backend/GTK4/Rendering/GTK4DescriptorTree.swift`
  - Add descriptor kinds: `.opacity`, `.offset`, `.scale`, `.rotation`, `.animated`
  - Add descriptor structs: `GTK4OpacityDescriptor`, `GTK4OffsetDescriptor`, `GTK4ScaleDescriptor`, `GTK4RotationDescriptor`
  - Add `GTK4DescriptorProps` enum cases
  - Add update intents (descriptive-only — will not trigger in-place mutation until the mutation gate is extended in a future batch)

- `Sources/Backend/GTK4/Rendering/GTKRenderer.swift`
  - Add `GTKDescribable` conformance to each view following the existing pattern (e.g., `DisabledView`)

### A3. Animation tests

**New file:** `Tests/SwiftOpenUITests/AnimationTests.swift`
- Animation struct default values and factory methods
- `withAnimation` sets/consumes pending animation
- OpacityView, OffsetView, ScaleEffectView wrapper correctness

**New file:** `Tests/BackendTests/GTK4Tests/GTK4AnimationTests.swift`
- `gtk_widget_get_opacity` after rendering `.opacity(0.5)`
- Widget data stored correctly for offset, scale, rotation
- `buildTransformCSS` output verification (including combined offset + scale + rotation ordering)
- AnimatedView applies CSS transition property
- **Transform composition test:** verify `offset + scale + rotation` produces correct combined CSS string with correct function ordering

---

## Batch B: Transition API (Core + GTK4)

**Status: Design incomplete.** The findings below identify structural problems that need resolution before implementation.

### B1. Core Transition types

**New file:** `Sources/SwiftOpenUI/Modifiers/TransitionModifier.swift`

```swift
public struct AnyTransition {
    // Built-ins: .opacity, .scale, .identity
    // Composable: .combined(with:), .asymmetric(insertion:removal:)
}

public struct TransitionView<Content: View>: View, PrimitiveView {
    let content: Content
    let transition: AnyTransition
}

extension View {
    public func transition(_ t: AnyTransition) -> TransitionView<Self>
}
```

Minimal first pass: `.opacity`, `.scale`, `.identity` only. `.slide`, `.move(edge:)`, `.asymmetric`, `.combined` can follow.

### B2. GTK4 Transition rendering — OPEN PROBLEMS

**File:** `Sources/Backend/GTK4/Rendering/GTKRenderer.swift`
- `TransitionView: GTKRenderable` — renders content, stores transition metadata on widget via GObject data

**File:** `Sources/Backend/GTK4/Rendering/GTKViewHost.swift`

#### Problem 1: Dual-child layout conflict

The host container is a vertical `GtkBox` that assumes exactly one child. Keeping the old child alive "alongside" the new one during a removal transition would stack them vertically, visibly duplicating layout instead of transitioning in place.

**Possible solutions (needs prototyping):**
- Replace the host `GtkBox` with a `GtkOverlay` when a transition is active, so old and new children layer on top of each other
- Use a temporary `GtkFixed` or absolute-positioned container during the transition window
- Reparent the exiting child into a floating overlay widget, run the exit animation there, then destroy it

Each option has implications for expand propagation, titlebar refresh, and focus restore. This needs a host/container redesign scoped explicitly, not a small patch.

#### Problem 2: Insertion/removal identity detection

`_ConditionalView` and `Optional` render directly without descriptor conformance — they produce opaque `.composite` nodes with no children in the descriptor tree. There is no persistent wrapper-level marker to compare across rebuilds.

**What's needed:**
- `_ConditionalView` and `Optional` need `GTKDescribable` conformance that emits a descriptor node carrying the active branch tag (`.trueContent` vs `.falseContent`, `.some` vs `.none`)
- Or: store a branch/presence marker on the rendered widget via GObject data at render time, and compare before/after in rebuild
- The marker must survive same-slot branch swaps correctly (a rebuild that stays on the same branch is NOT an insertion/removal)

Without a concrete identity mechanism, insertion/removal detection will misclassify plain rebuilds as enter/exit cases.

#### Insertion (directionally correct)
After building new widget, check for stored transition. If animation is active, set initial state (opacity 0 / scale 0), then idle-callback to final state.

### B3. Transition tests

**New file:** `Tests/SwiftOpenUITests/TransitionTests.swift`
- AnyTransition construction, TransitionView wrapping

**New file:** `Tests/BackendTests/GTK4Tests/GTK4TransitionTests.swift`
- Transition metadata stored on widget
- Insertion starts at zero opacity for `.opacity` transition

---

## Batch order

**Batch A first** — rotation fix + descriptors (as prerequisite) + tests. Low risk, immediate value.

**Batch B second** — Transition API. Requires design resolution for the dual-child layout and identity detection problems before implementation begins. The core types (B1) can be built independently, but GTK4 rendering (B2) is blocked on those design decisions.

## Verification

- `swift build` (no warnings)
- `swift test` (all existing + new tests pass)
- Manual: run ParityAnimation example, verify rotation animates with `withAnimation`
- Manual (Batch B): conditional view with `.transition(.opacity)` inside `withAnimation` fades in/out
