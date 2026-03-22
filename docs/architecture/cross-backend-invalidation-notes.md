# Cross-Backend Invalidation Notes

## Summary

The Win32 incremental reconcile spike explored one way to improve interactive responsiveness, but only part of that work is portable to other backends.

The portable part is the architecture:

- backend-local node / descriptor identity
- structural matching rules
- safe in-place update vs subtree replacement
- dirty-subtree rebuild
- later, dependency-based invalidation

The non-portable part is the exact Win32 mechanism used by the spike:

- `HWND` property tagging
- subclass proc state transfer
- D2D callback swapping
- building a temp native subtree and copying state out of it

## What Transfers Across Backends

These ideas should apply to Win32, GTK/Linux, Web/WASM, and future backends:

### 1. Backend Node Identity

Do not treat raw native widget class names as view identity.

Instead, build a backend-local node or descriptor model with semantic kinds such as:

- `text`
- `color`
- `slider`
- `frame`
- `background`
- `padding`
- `stack`

This is the key abstraction that allows safe reconciliation.

### 2. Structural Matching

Old and new trees should be matched by:

- backend node kind
- structural position
- keyed identity where available

Same native class alone is not enough.

### 3. In-Place Update Hooks

Each backend node kind should know how to update itself safely:

- text content update
- color / paint update
- layout / spacing update
- style / foreground / background update

If a node cannot be safely updated in place, the backend should replace that subtree.

### 4. Dirty-Subtree Rebuild

A good long-term target for all backends is:

- rebuild only the affected backend subtree
- reconcile it against retained backend nodes
- leave unrelated siblings untouched

### 5. Dependency-Based Invalidation

Later, backends can benefit from tracking which subtrees depend on which state values so that only the minimum affected subtree is rebuilt.

That is closer to SwiftUI's real model than raw native tree diffing.

## What Is Win32-Specific

The current spike used several Win32-only expedients:

- storing backend node metadata on `HWND`s
- pulling state out of subclass `dwRefData`
- transferring D2D draw callbacks between old and new windows
- building a full temp `HWND` subtree during rebuild and destroying it after reconcile

Those techniques were useful for a local spike, but they should not be treated as a shared backend design.

## Linux / GTK

The architecture transfers well to GTK.

Likely mapping:

- backend node identity stays the same conceptually
- retained native nodes become GTK widgets
- in-place updates become GTK property changes, relayout requests, and style updates
- subtree replacement means destroying and recreating only the affected GTK subtree

GTK should not copy the Win32 temp-`HWND` approach directly unless it is needed for a narrow spike. A descriptor-first or backend-node-first model is cleaner.

## Web / WASM

The architecture transfers well to Web/WASM too.

Likely mapping:

- backend nodes map naturally to retained DOM-oriented nodes
- in-place updates become text, attribute, style, and canvas updates
- subtree replacement becomes DOM subtree replacement
- dependency-based invalidation is especially valuable because DOM churn is user-visible

Again, the transferable part is the backend-node / invalidation model, not the Win32-specific state-transfer mechanics.

## Recommendation

If SwiftOpenUI moves toward a shared invalidation architecture, the shared layer should be:

1. backend-local descriptor / node tree
2. identity rules
3. update-vs-replace decisions
4. dirty-subtree rebuild hooks

Each backend should then provide its own concrete native update logic.

The Win32 create-then-adopt spike should be treated as a local experiment, not as the reusable template for Linux or WASM implementations.
