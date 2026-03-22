# Win32 Incremental Reconcile Spike

## Goal

Improve interactive Win32 behavior without changing shared state APIs yet.

The immediate target is to replace full hosted-subtree teardown on every state change with a Win32-local retained render tree that can preserve wrapper and leaf nodes, update them in place when safe, and fall back to subtree rebuild when structure no longer matches.

## Current problem

Today a state change reaches Win32 through `scheduleRebuild()`, and the host responds by destroying and recreating the hosted subtree.

That is acceptable for coarse structural changes, but it is the wrong default for interactive flows such as:

- slider scrubbing
- live color previews
- paint-style updates
- text editing
- splitter dragging
- scroll-preserving interactions

The recent slider suppression work confirms the gap: the control can stay alive during drag, but dependent views still lag because the backend has no path to update only the affected native nodes in place.

## Direction

The right direction on `win32-incremental-reconcile-spike` is:

- add a Win32-local retained render tree
- preserve wrapper and leaf nodes, not just primitive HWNDs
- give retained nodes explicit update hooks
- keep full rebuild as fallback
- leave `AnyViewHost` and shared invalidation APIs unchanged for now

This spike should not try to solve cross-backend diffing or shared invalidation categories yet.

## Design rules

### Reconcile against backend nodes, not raw HWND trees

Matching should be based on Win32-local node kinds and subtree shape, not naked HWND class names.

Examples of backend node kinds:

- hostContainer
- stack
- frame
- padding
- background
- foregroundColor
- text
- color
- slider

This keeps reconciliation aligned with where Win32 behavior actually lives: layout containers, message-routing wrappers, and native leaf controls.

### Keep the shared contract stable

`scheduleRebuild()` should continue to mean only that something changed.

Win32 changes how it fulfills invalidation:

- build a lightweight desired node description
- reconcile against the retained node tree
- reuse and update matching nodes
- replace only mismatched subtrees

### Prefer explicit local outcomes over a broad invalidation redesign

For the spike, node update hooks should return a small local result such as:

- `noChange`
- `needsRepaint`
- `needsRelayout`
- `replaceSubtree`

That is enough to prove the architecture without forcing a shared visual/layout/structural invalidation model yet.

## Phase plan

### Phase 0: scaffolding

- Define Win32 retained node types.
- Teach `Win32ViewHost` to retain the previous node tree.
- Add a lightweight desired-node description path for the initial slice.
- Keep the current full rebuild path available as fallback.

### Phase 1: ColorMixer proof

Initial scope:

- `FrameView`
- `BackgroundView`
- `Text`
- `Color`
- `Slider`

What this proves:

- wrapper and leaf nodes can both survive ordinary state changes
- slider movement can update dependent text/color views without subtree teardown
- layout is only touched when the updated node says it is necessary

Expected behavior:

- `Text`
  - update text in place via `SetWindowTextW`
  - request relayout only if size-relevant content changed
- `Color`
  - repaint existing surface or background wrapper in place
- `Slider`
  - keep HWND and drag state alive
  - continue local repaint during drag
  - propagate dependent updates without full rebuild

### Phase 2: layout invalidation split

- Refine node update outcomes so text or wrapper changes can trigger relayout locally.
- Keep purely visual changes on repaint paths.
- Continue using subtree replacement when the node kind or child structure no longer matches.

### Phase 3: harder controls

Defer until the retained-tree shape is proven:

- `TextField`
- `Canvas`
- split-view divider and other drag-driven controls

These need extra rules for closure retargeting, reentrancy, caret preservation, and redraw semantics.

## First slice boundaries

Do not start with `TextField` or `Canvas`.

The first useful slice is the wrapper-plus-leaf chain needed for `ColorMixer`:

- `FrameView`
- `BackgroundView`
- `Text`
- `Color`
- `Slider`

This gives enough value to test the architecture without pulling in the hardest native-state cases first.

## Proposed implementation shape

### Retained node model

Each retained node should represent either a wrapper/container or a native leaf.

Each node should carry:

- backend kind
- owned HWND, if any
- child nodes
- local update hook
- enough cached data to decide repaint vs relayout vs replace

### Desired node description

The desired tree should be built from render-time view expansion into backend-local descriptors.

It should not be inferred from the live HWND tree.

### Matching

Matching should require:

- same backend node kind
- same reconcile boundary under the same parent
- compatible child structure for the scoped slice

If matching is ambiguous or structure diverges, replace that subtree.

## Files likely in scope

- `Sources/Backend/Win32/Rendering/Win32ViewHost.swift`
- `Sources/Backend/Win32/Rendering/WinRenderer.swift`

Possible follow-on extraction if the spike grows:

- a new Win32-local node/reconcile file under `Sources/Backend/Win32/Rendering/`

## Success criteria

The spike is successful if `ColorMixer` on Win32 demonstrates:

- slider drag does not destroy and recreate the hosted subtree on ordinary value changes
- dependent text/color updates happen during drag, not only on release
- slider drag state remains smooth and local
- full rebuild still occurs for unhandled structural changes

## Non-goals

- redesign `AnyViewHost`
- introduce shared cross-backend diffing
- generalize invalidation across all backends
- rely on positional patching without a retained node model
- claim primitive-only preservation while wrappers are still recreated

## Stop conditions

Stop or narrow the spike if any of these become true:

- the retained-tree scaffolding requires a broad shared renderer rewrite
- the first slice cannot be implemented without immediately solving `TextField` or `Canvas`
- matching same-kind siblings safely requires more identity machinery than this branch can carry
- fallback rebuild paths become harder to reason about than the existing host behavior

If that happens, keep the branch focused on proving retained wrapper-and-leaf reconciliation for the narrow `ColorMixer` path only.
