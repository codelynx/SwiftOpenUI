# Win32 Text/Color Host Integration Plan

## Goal

Integrate the descriptor-first invalidation pipeline into `Win32ViewHost` for the
narrowest safe slice:

- `Text` updates via `textContent`
- bare `Color` updates via `colorFill`

This step is intentionally limited. It does **not** attempt general incremental
reconciliation, wrapper/layout reuse, or slider-configuration updates.

## Why This Slice

The isolated descriptor/executor/hook work has now proved two real mutation
paths:

- `textContent` can update an existing Win32 text control in place
- `colorFill` can update an existing `SwiftUID2DView` color node in place

Both paths are:

- backend-local
- narrow
- covered by focused tests
- independent of `Win32ViewHost` today

The next unanswered question is not whether more isolated hooks can be added. It
is whether `Win32ViewHost` can invoke the existing pipeline on a very narrow
subset without reintroducing the old create-then-adopt reconcile complexity.

## Scope

In scope:

- descriptor/build path invocation from `Win32ViewHost`
- retained executor tree storage at the host level
- text-only and bare-color-only in-place mutation
- fallback to existing full rebuild when the narrow path is not applicable

Out of scope:

- wrapper/layout intents:
  - `frameLayout`
  - `paddingLayout`
  - `hStackLayout`
  - `vStackLayout`
  - `zStackLayout`
- slider mutation/integration:
  - `sliderValue`
  - `sliderConfiguration`
- `ForegroundColor`, `Background`, `Border`, `Frame`, `Padding`
- keyed identity
- partial subtree rebuild
- any temp-`HWND` compare/adopt path

## Proposed Boundary

Before any narrow-path mutation attempt, host integration needs two explicit
prerequisites:

1. a parallel describe capability at the stateful-view host boundary
2. a post-rebuild descendant slot-capture pass for supported identities

Without those two pieces, the plan is not implementable in the current codebase.

## Prerequisite 1: Describe Capability

`Win32ViewHost` does not currently retain any descriptor-producing closure or
body value. It only stores:

- `buildBody: (RenderContext) -> HWND?`

That is sufficient for rebuild-only behavior, but not for a describe-first host
path.

Before narrow host mutation can exist, the stateful host boundary must gain a
parallel describe capability, for example:

- `buildBody: (RenderContext) -> HWND?`
- `describeBody: () -> Win32DescriptorNode`

The exact API shape can vary, but the requirement is fixed:

- `Win32ViewHost` must be able to produce the new descriptor tree without first
  creating a new native subtree

This should be added at the stateful-view entry point rather than inferred later
inside `rebuild()`.

## Prerequisite 2: Descendant Slot Capture

The retained executor tree already carries `nativeSlotID`, but today only the
root can be seeded directly. That is not enough for text/color host integration,
because supported leaves are often nested under wrappers or stacks.

So after every successful full rebuild, the host needs a slot-capture pass that:

1. walks the hosted subtree
2. collects supported descendant native targets
3. maps them to descriptor identities by structural path
4. writes `nativeSlotID` onto retained executor nodes for those descendants

For this slice, that slot capture should stay intentionally limited to:

- `.text`
- `.color`

If a future narrow-path update requires a supported identity that does not have a
captured native slot, the host must abort the narrow path and fall back to full
rebuild.

## Proposed Boundary

The integration point should stay inside `Win32ViewHost.rebuild()` after the new
body has been described, but before destructive full rebuild happens.

High-level flow:

1. Use `describeBody` to build the new descriptor tree for the hosted body
2. Identify the new descriptor tree structurally
3. Compare against the retained descriptor/executor state from the previous build
4. Produce:
   - descriptor plan
   - executor action tree
5. Validate whether the action tree is fully supported by the narrow host path
6. If valid:
   - run mutation hooks for supported actions
   - update retained descriptor/executor state
   - skip destructive rebuild
7. If invalid:
   - fall back to the current full rebuild path
8. After any full rebuild:
   - run descendant slot capture for supported identities
   - update retained descriptor/executor state with captured native slots

This is host-triggered incremental update, not general-purpose reconcile.

## Supported Action Shape

The initial host integration should only accept action trees where every node is
one of:

- `keep`
- `update(textContent)`
- `update(colorFill)`
- `create`
- `replace`

and where `create` / `replace` only occur if the host chooses full rebuild
fallback instead of partial mutation.

Practical rule for the first slice:

- if any node requires `create`, `replace`, or an update intent other than
  `textContent` / `colorFill`, abort the narrow path and full rebuild

That keeps the first integration easy to reason about:

- mutation path only performs in-place updates
- structure changes still rebuild
- unsupported intent changes still rebuild

## Host State To Add

`Win32ViewHost` should store two new pieces of data for the hosted subtree:

- last identified descriptor tree
- last retained executor tree

And it should be constructed with:

- `buildBody`
- `describeBody`

These should be updated only when:

- initial build succeeds
- narrow mutation path succeeds
- full rebuild succeeds

They should not be updated on an aborted narrow-path attempt.

## Native Slot Strategy

The existing retained executor nodes already carry `nativeSlotID`.

For the host-integration slice, native slot assignment should be explicit:

- on full rebuild, run descendant slot capture for supported `.text` and `.color`
  identities
- on narrow text/color mutation, preserve existing slot IDs for unchanged nodes
- do not invent slot IDs for unsupported nodes

No new ownership or lifecycle abstraction should be introduced here.

## Validation Gate

Before applying mutations from `Win32ViewHost`, validate:

1. The action tree contains only supported intents
2. Every `textContent` target still has a valid native slot
3. Every `colorFill` target still has a valid native slot
4. No node requires structural create/replace under the narrow path

If any validation fails, do not partially mutate. Fall back to full rebuild.

## Why This Avoids The Old Spike Failure

This plan does **not**:

- build a temp native subtree every tick
- infer identity from raw `HWND` class names
- reuse wrappers based on native shape
- transfer renderer state between unrelated native nodes

Instead it:

- describes first
- plans structurally
- executes only already-proven local mutations
- rebuilds for everything else

That is the key architectural difference from the abandoned reconcile spike.

## Acceptance Criteria

1. Stateful host rebuild with only text changes updates text in place without
   destroying the hosted subtree
2. Stateful host rebuild with only bare color changes updates color in place
   without destroying the hosted subtree
3. Any unsupported intent or structure change still takes the existing full
   rebuild path
4. Existing focus/input preservation behavior remains unchanged
5. No temp-`HWND` compare/adopt mechanism is reintroduced

## Suggested Test Plan

Add focused host-level tests for:

1. text-only state change
   - retained text `HWND` identity stays stable
   - text content changes
2. bare-color-only state change
   - retained color `HWND` identity stays stable
   - color fill helper sees the updated color
3. unsupported wrapper change
   - host falls back to full rebuild
4. child kind change
   - host falls back to full rebuild
5. mixed text + color change
   - both mutate in place when no unsupported intents are present

## Stop Condition

Stop after text/color-only host integration works and is covered by tests.

Do **not** automatically expand next into:

- layout intents
- slider updates
- modifier chains
- generalized subtree reuse

Those should be separate follow-on decisions after this narrow integration path
is proven.
