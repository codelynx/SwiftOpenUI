# Win32 Minimal Path Toward SwiftUI-Like Invalidation

Related:

- `docs/architecture/cross-backend-invalidation-notes.md`

## Goal

Improve Win32 interactive responsiveness step by step without trying to build full SwiftUI internals all at once.

The immediate practical target is:

- keep slider drag smooth
- define a safe path to live dependent ColorMixer updates during drag
- avoid broad unsafe reuse based on raw HWND class names

## Core idea

SwiftUI does not primarily diff raw platform widgets.

It combines:

- dependency-based invalidation
- structural identity
- platform-node reuse and update

Our Win32 path should move toward that in small local steps:

1. backend node tree
2. identity rules
3. subtree buildability
4. interaction policy during drag
5. ColorMixer proof
6. local dependency tracking
7. input-equality short-circuiting

## Step 1: Backend Node / Descriptor Model

Stop treating raw HWND class names as view identity.

Build a Win32-local node or descriptor tree first. Each node should represent backend meaning, for example:

- `stack`
- `frame`
- `padding`
- `background`
- `foregroundColor`
- `text`
- `color`
- `slider`

Each node should carry:

- backend kind
- children
- owned `HWND`, if any
- cached props needed for update decisions
- local update hook returning:
  - `noChange`
  - `needsRepaint`
  - `needsRelayout`
  - `replaceSubtree`

### Required design choice

This step must explicitly choose between two build models:

### 1a. HWND-first wrapper path

- build HWNDs first using the existing render path
- wrap the resulting backend structure in retained nodes
- use this to prove safe reuse rules

Pros:

- smallest change from the current renderer
- useful for proving retained-node matching and update hooks

Cons:

- still pays full temp-HWND construction cost
- does not by itself enable efficient dirty-subtree rebuilds

### 1b. Descriptor-first path

- build backend descriptors without creating HWNDs first
- reconcile descriptors against retained nodes
- create, update, or replace HWNDs only after the reconcile decision

Pros:

- enables real dirty-subtree rebuilds
- removes temp-HWND churn from steady-state updates

Cons:

- larger change
- requires a new backend-local build path

The recommended near-term approach is:

- use `1a` only if needed to prove safe reuse for a narrow slice
- treat `1b` as the target model required for subtree rebuilds

### Review checkpoint

- verify ColorMixer wrappers become distinct backend nodes
- verify `background` and `frame` are no longer conflated because both render to `SwiftUIStack`

## Step 2: Identity Rules

Define structural identity before broad reuse.

Rules:

- identity must be based on backend node kind plus structural position and keyed identity where available
- same node kind alone is not enough
- repeated sibling nodes of the same kind must not be matched ambiguously

Reuse rules should be:

- same identity => candidate for reuse
- same identity + changed props => call update hook
- mismatched kind or structure => replace subtree

Examples:

- `text` => `SetWindowTextW`
- `color` => swap D2D draw callback and invalidate
- `slider` => preserve HWND and drag state
- `background` => update brush/color state in place
- `frame` => relayout child without recreating wrapper

### Review checkpoint

- verify repeated `text`, `frame`, or `background` siblings match correctly
- verify wrapper identity is no longer inferred from raw Win32 class names

## Step 3: Subtree Buildability Boundary

Before narrowing rebuild scope, make a subtree buildable on its own.

Today `Win32ViewHost` owns one full-subtree `buildBody` closure. That is not enough for dirty-subtree rebuilds by itself.

This step must define how a retained node or descriptor subtree can be rebuilt independently.

Possible forms:

- subtree-local builder closures
- cached backend descriptors with local rebuild functions
- another backend-local mechanism that can materialize only the affected slice

### Review checkpoint

- verify a subtree can be rebuilt without rerendering the whole host body
- verify fallback to full-host rebuild remains simple and correct

## Step 4: Interaction Policy During Drag

Decide explicitly how interaction-time invalidation behaves.

The current host defers rebuilds while the slider owns pointer capture. That preserves drag state, but it also means dependent views only update on release.

To achieve live dependent updates during drag, choose one of these:

- allow safe rebuild/reconcile during drag for the ColorMixer slice only
- provide a separate live-update path for the slider-dependent slice
- another equally explicit interaction-time policy

This decision must come before claiming live-drag proof.

### Review checkpoint

- slider HWND remains stable during capture
- dependent views update during drag, not only on release

## Step 5: ColorMixer Proof

Now prove the architecture on the narrow target slice.

Suggested scope:

- `text`
- `color`
- `slider`
- `frame`
- `background`

### Review checkpoint

- prove live ColorMixer swatch and label updates during drag
- prove full rebuild still occurs for structural changes
- prove the branch has not become a renderer-wide rewrite

## Step 6: Add Local Dependency Tracking

After the above correctness path is working, add a simple local dependency map inside the Win32 host.

During backend-node build:

- record which state source each node reads

On state change:

- mark only dependent nodes dirty
- rerender those nodes
- reconcile them into the retained tree

This should capture most of the practical benefit without redesigning shared APIs.

### Review checkpoint

- changing `red` only rerenders red-dependent nodes
- unrelated controls do not rebuild

## Step 7: Input-Based Short-Circuiting

Later, if a node's inputs are unchanged, skip rerender and platform update entirely.

Examples:

- unchanged `Text`
- unchanged `Color`
- unchanged `FrameView` constraints

This is the last optimization, not the first.

## Recommended Implementation Order

1. Choose and document the build model (`1a` vs `1b`).
2. Define backend-node identity rules.
3. Make the ColorMixer slice subtree-buildable.
4. Define drag-time interaction policy for that slice.
5. Reconcile/update the ColorMixer slice safely.
6. Add local dependency tracking.

## Helper Review Passes

Use these review passes after each step.

### 1. Identity Review

- are we matching backend node kinds, not HWND classes?
- are position and keyed identity rules explicit?

### 2. State Ownership Review

- for each wrapper, what state lives on the node?
- can that state be updated in place safely?

### 3. Fallback Review

- on mismatch, do we fall back to full rebuild cleanly?

### 4. Interaction Review

- during pointer capture, is slider preserved?
- do dependent views update live?

### 5. Scope Review

- did the step stay ColorMixer-only?
- did it accidentally become a renderer-wide rewrite?

## Stop Conditions

Stop or narrow the work if any of these become true:

- backend-node identity requires a broad shared renderer redesign
- ColorMixer live updates cannot be achieved without immediately solving TextField or Canvas
- fallback paths become harder to reason about than the current rebuild behavior
- the branch stops being a narrow Win32-local proof

## Immediate Next Slice

The next practical slice should be limited to:

- `text`
- `color`
- `slider`
- `frame`
- `background`

This is enough to prove the architecture for ColorMixer without reopening unsafe generic reconciliation.

The main precondition is that this slice must be:

- backend-node identifiable
- subtree-buildable
- allowed to update safely during drag
