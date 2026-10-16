# RFC: Preserve child `@State` across parent rebuilds

> **Status: Request for Comment (draft, revised 2026-10-16).** Comments
> wanted from the Win32, GTK4, Web and Android owners before any backend
> work starts. The remaining open questions are at the end.
>
> **Revision 2** (after the first review on #37): corrects the `@StateObject`
> claim, defines structural identity as a view-tree path rather than a
> counter, defines which rebuilds may release state, and moves the API
> sketch to an appendix.

## Summary

When a stateful parent view rebuilds its body, a child view that owns its
own `@State` keeps that state on GTK4 and Android but **resets to its
initial value on Win32 and Web**. A child's `@StateObject` is recreated
on **every** backend. This RFC proposes one shared, identity-first child-state
store in core, adopted by every backend. It replaces GTK4's and Android's
private positional caches and closes the gap on Win32 and Web.

```swift
struct Parent: View {
    @State var showDetails = false
    var body: some View {
        VStack {
            Toggle("Details", isOn: $showDetails)
            Counter()          // owns @State var n
        }
    }
}
```

Toggling `showDetails` rebuilds `Parent`. On Win32 and Web, `Counter`'s
`n` is reset to 0. On macOS SwiftUI, GTK4 and Android, it keeps its value.

## Why now

- The 2026-07-10 entry in `docs/cross-platform-changelog.md` already
  flagged this as "a **shared view-host problem** … likely **one fix at the
  shared view-host layer** (ID-keyed child-state persistence) … Reconcile
  the two designs before either backend invests further." Nobody has done
  that reconciliation yet.
- RFC #16's D4 (`WM_DPICHANGED`) re-renders a window's root on a DPI
  change. That keeps state held by the root view, but resets every
  nested child's state, because it goes through this same gap.
- Apps hit it in ordinary use. Any parent state change that is not a pure
  text or colour update triggers a structural rebuild on Win32. Every
  stateful child below it then resets: text typed into a child view's
  `@State`, a child counter, a child's local toggle.

## How each backend behaves today

`@State` is a struct holding a `StateStorage` reference. A parent's `body`
creates a new child struct on every evaluation, and with it a new storage.
A child keeps its state only if the backend copies the old value into the
new storage (`AnyStateStorage.restoreValue(from:)`).

| Backend | Child `@State` / `@FocusState` survive? | Child `@StateObject` survives? | Mechanism | Identity key |
| --- | --- | --- | --- | --- |
| macOS (SwiftUI) | Yes | Yes | Native SwiftUI | Structural + explicit identity |
| GTK4 | Yes | **No** | Per-parent-host `childStateCache`; restore in `gtkRenderStatefulView` | `"<index>:<TypeName>"`; index counts stateful children in render order |
| Android | Yes | **No** | Global `androidStateCache`; `androidRestoreState` | Hash of parent hash + type tag + child index |
| Win32 | **No** | **No** | `winRenderStatefulView` always creates a fresh `Win32ViewHost`; a full rebuild destroys all child hosts | — |
| Web | **No** | **No** | `webRenderStatefulView` creates a fresh `WebViewHost`; rebuild clears `innerHTML` | — |

Details worth knowing:

- **`@StateObject` is never restored.** `StateObjectStorage.restoreValue`
  is a no-op ("StateObject owns its object — no value to restore"). The new
  storage's factory runs again during the rebuild: setting `host` wires
  `@Published` properties, which reads `object`. The old object is dropped.
- **Win32's narrow path hides the gap sometimes.** When a rebuild is only
  a text or colour change, `tryTextColorMutationRebuild()` updates windows
  in place and child hosts survive by accident. Anything structural falls
  through to `DestroyWindow` + full rebuild.
- **GTK4 copies values; it does not reuse hosts.** Each rebuild still
  creates new child `GTKViewHost`s and widgets; only the values move.
- **GTK4's key is a counter, not a position.** The index counts stateful
  children in render order. So a stateful child that appears *earlier* in
  the body (`if showBanner { Banner() }` above `Counter()`) shifts every
  later key, and `Counter` loses its state. Same-typed siblings that swap
  order also swap state (pinned by
  `testSameTypedSiblingReorderMigratesStateByPosition`). `ForEach` ids and
  `.id()` are not used, and the cache is never pruned.
- **Web leaks.** `_webRetainedHosts` only grows, because orphaned child
  hosts are never released.
- **No shared code.** The reflect → providers → `restoreValue` loop is
  duplicated in GTK4 and Android. Core has `installState` and
  `hasReactiveProperties`, nothing for restore.

## Goals and non-goals

**Goals**

1. A child's `@State` and `@FocusState` values survive a parent rebuild on
   every backend.
2. A child's `@StateObject` keeps **the same object** across parent
   rebuilds, and its factory does not run again when the child is matched.
   This is new behaviour on every backend.
3. Identity follows SwiftUI rules: explicit `.id()` and `ForEach` element
   ids first, position in the view tree otherwise.
4. State for views that go away is released. No unbounded caches.
5. One implementation in core; backends call it from their existing
   "render stateful view" function.

**Non-goals**

- Reusing child hosts or native widgets across a rebuild (true
  reconciliation). That is a larger change to each backend's rebuild
  model; see Alternative C.
- UI-only native state that never enters `StateStorage` (tree expansion,
  scroll offset). That is `docs/proposals/restorable-widget-state.md`. The
  two proposals should share identity rules (see below).

## Proposed behaviour

### 1. Identity

A stateful child's identity is the first of these that applies:

1. **Explicit id**: the id from the nearest `.id(x)` or `ForEach` element
   above the child, plus the child's type. Reordered rows keep their state.
2. **Structural path**: the child's position in the parent's view tree,
   plus its type. The path records each container index, **which branch
   of an `if`/`else` (or `switch`) was taken**, and the `ForEach` element.
   It is not a count of stateful children. A sibling that appears or
   disappears does not change the identity of the views around it.

Rules:

- A type change at the same identity never restores (GTK4's current
  `testTypeChangeAtSamePositionSkipsRestore` behaviour).
- If two children claim the same identity in one pass, neither is
  restored, and debug builds log it once.

### 2. What is restored

- `@State` and `@FocusState`: the value is copied into the new storage.
- `@StateObject`: the child takes over the **matched storage's object**.
  The new storage's factory is not called. One object per identity, released
  together with the entry.

### 3. When state is released

Only a **full structural rebuild** of the parent's body is a pass. After a
pass, entries for children that did not appear are released. This matches
SwiftUI: a view hidden by an `if` loses its state.

Not a pass, so nothing is released:

- A narrow in-place update (Win32 and GTK4 text/colour path), which runs
  the body without rendering stateful children.
- Partial re-renders that don't reach every child.

Pinned, so kept across passes even though not rendered:

- Children that are alive but not on screen: unselected `TabView` tabs
  (SwiftUI keeps their state), pushed `NavigationStack` destinations, and
  rows of lazy containers outside the visible range.

### 4. Backend adoption

Each backend's stateful-render function gets the "current parent host"
during body evaluation (GTK4 already has `setCurrentRebuilding`) and hands
the child to that host's store before installing state.

| Backend | Change |
| --- | --- |
| GTK4 | Replace `childStateCache` + `nextChildStateKey` with the shared store. Unkeyed children keep their state. Keyed rows stop swapping, and inserted siblings stop shifting. |
| Android | Replace `androidStateCache` with a per-host store. |
| Win32 | Add a current-rebuilding-host context in `Win32ViewHost.buildBodyWithTracking`, and use the store in `winRenderStatefulView`. The window root (and D4's re-render) needs a store too: `MainWindowState` owns one, treated as the root's parent. |
| Web | Same as Win32 in `webRenderStatefulView` / `WebViewHost.rebuild`. Also release orphaned child hosts so `_webRetainedHosts` stops growing. |

### 5. Relationship to restorable widget state

`restorable-widget-state.md` already decided "key by identity from
`.id()`/`idKeyPath`, never position, skip on collision" for UI-only native
state. This RFC uses the same explicit-id rule and adds the view-tree path
as a fallback, because most `@State` children have no explicit id. If
accepted, restorable-widget-state could use the same identity type.

## Alternatives considered

**A. Port GTK4's counter cache to Win32 and Web as-is.** Smallest
change: about 20 lines per backend. But it copies the insertion and reorder
bugs and the unbounded cache into two more backends, leaves `@StateObject`
broken, and leaves four private copies of the same logic. Rejected as the
end state; acceptable as a stopgap if the core store slips.

**B. This proposal: a shared, identity-first store with a view-tree path
fallback.** One implementation. Fixes insertion, reorder, leak and
`@StateObject` lifetime. Matches SwiftUI for keyed collections.

**C. True reconciliation: reuse child hosts and native widgets.** Diff the
new body against the old tree and keep unchanged child hosts alive, so
state never needs copying. This is what SwiftUI does, and it would also
remove flicker and save work. But it requires a keyed descriptor diff and
in-place native updates on every backend. Win32's descriptor tree is
positional and only supports text/colour updates today. Deferred; B does
not block it, because a host that survives needs no restore.

## Testing

- **Core:** unit tests for the store: restore by structural path, a
  sibling inserted by `if` does not shift identity, restore by explicit id
  across reorder, `@StateObject` keeps its object and its factory runs
  once, no restore on type change, no restore on collision, release after
  a full pass, no release after a narrow update.
- **Per backend:** the scenario at the top of this RFC as a shared test
  shape (a child counter survives a parent toggle), plus keyed reorder and
  an unselected tab keeping its state. GTK4's existing three tests move to
  the shared shape; the reorder test's expectation flips for keyed children.
- **Win32 D4:** a nested child counter survives a real or synthetic
  `WM_DPICHANGED`.

## Migration

1. Land the store in core with its unit tests. No backend uses it yet.
2. Win32 adopts it (closes the user-visible gap, including D4).
3. GTK4 switches from its private cache, guarded by its existing tests;
   then Android.
4. Web adopts it and fixes the host leak.
5. Update `docs/issues/win32-conditional-view-rebuild.md` and the
   changelog to close the 2026-07-10 item.

## Decisions from review (revision 2)

- **Structural fallback: yes**, as the view-tree path above, not a counter.
  Identity-only would leave most `@State` children with no identity.
- **Explicit ids for v1:** `.id()` and `ForEach` element ids. `List` and
  `OutlineGroup` rows built on `ForEach` get those ids anyway.
- **Hidden `if` branches release state** (matches SwiftUI). Children that
  are alive but not rendered are pinned instead (section 3).
- **`@StateObject`:** the store carries the object; the factory runs once
  per identity.
- **Order of work:** core, then Win32, then GTK4 and Android, then Web.

## Open questions

1. **Thread safety.** `StateStorage.restoreValue` copies without taking
   its lock ("called only during render pass"). Is that guarantee true on
   every backend (GTK main loop, Win32 message loop, Web's single thread)?
   Proposal: assert in debug builds that the restore runs on the render
   thread.
2. **Pinning in practice.** Which containers in each backend render only
   part of their children today (TabView, NavigationStack, lazy stacks and
   grids)? Each needs to pin its unrendered children's entries.
3. **`TabView` tags** as explicit ids: needed, or does pinning cover it?

Please reply on the PR or open an issue referencing this file.

## Appendix: API sketch

Illustrative only; names may change during implementation.

```swift
/// Carries child views' state across a parent's body evaluations.
public final class ChildStateStore {
    public func beginPass()
    /// Releases entries not adopted since `beginPass()`, except pinned ones.
    /// Call only after a full structural rebuild.
    public func endPass()
    /// Restores the matching previous entry into `child`'s storages
    /// (or hands over its `@StateObject` object), then records them.
    public func adopt<V>(_ child: V, identity: ChildStateIdentity)
    public func pin(_ identity: ChildStateIdentity)
}

public struct ChildStateIdentity: Hashable {
    var explicitID: AnyHashable?   // .id(x), ForEach element id
    var structuralPath: [PathComponent]  // container index, branch, element
    var typeName: String
}
```
