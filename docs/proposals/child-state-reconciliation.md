# RFC: Preserve child `@State` across parent rebuilds

> **Status: Request for Comment (draft, 2026-10-15).** Comments wanted from
> the Win32, GTK4, Web and Android owners before any backend work starts.
> The specific questions are at the end.

## Summary

When a stateful parent view rebuilds its body, a child view that owns its
own `@State` keeps that state on GTK4 and Android but **resets to its
initial value on Win32 and Web**. This RFC proposes one shared,
identity-first child-state store in core, adopted by every backend, to
replace GTK4's and Android's private positional caches and close the gap on
Win32 and Web.

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
  nested child's state, because it goes through this same gap. A
  third-party review of D4 raised exactly this concern.
- Apps hit it in ordinary use. Any parent state change that is not a pure
  text or colour update triggers a structural rebuild on Win32. Every
  stateful child below it then resets: text typed into a child view's
  `@State`, a child counter, a child's local toggle.

## How each backend behaves today

`@State` is a struct holding a `StateStorage` reference
(`Sources/SwiftOpenUI/State/State.swift`). A parent's `body` creates a new
child struct on every evaluation, and with it a new `StateStorage`. A child
keeps its state only if the backend copies the old value into the new
storage (`AnyStateStorage.restoreValue(from:)`).

| Backend | Child `@State` survives parent rebuild? | Mechanism | Identity key |
| --- | --- | --- | --- |
| macOS (SwiftUI) | Yes | Native SwiftUI | Structural + explicit identity |
| GTK4 | Yes | Per-parent-host `childStateCache` (`GTKViewHost.swift:57-66`); restore in `gtkRenderStatefulView` (`GTKRenderer.swift:7134-7145`) | `"<index>:<TypeName>"`; index counts stateful children in render order |
| Android | Yes | Global `androidStateCache` (`AndroidBackend.swift:54-56`); `androidRestoreState` (`AndroidRenderer.swift:116-137`) | Hash of parent hash + type tag + child index |
| Win32 | **No** | `winRenderStatefulView` always creates a fresh `Win32ViewHost` (`WinRenderer.swift:73-113`); full rebuild destroys all child hosts (`Win32ViewHost.swift:348-359`). No "current rebuilding host" exists | — |
| Web | **No** | `webRenderStatefulView` creates a fresh `WebViewHost` (`WebViewHost.swift:561-579`); rebuild clears `innerHTML` | — |

Details worth knowing:

- **Win32's narrow path hides the gap sometimes.** When a rebuild is only
  a text or colour change, `tryTextColorMutationRebuild()` updates windows
  in place and child hosts survive by accident. Anything structural falls
  through to `DestroyWindow` + full rebuild.
- **GTK4 copies values; it does not reuse hosts.** Each rebuild still
  creates new child `GTKViewHost`s and widgets; only the values move.
- **GTK4's key is positional, with a known flaw.** Same-typed stateful
  siblings that swap order swap state. This is pinned by
  `testSameTypedSiblingReorderMigratesStateByPosition`. `ForEach` ids and
  `.id()` are not used, and the cache is never pruned.
- **Web leaks.** `_webRetainedHosts` only grows, because orphaned child
  hosts are never released.
- **No shared code.** The Mirror → providers → `restoreValue` loop is
  duplicated in GTK4 and Android. Core has `installState` and
  `hasReactiveProperties`, nothing for restore.

## Goals and non-goals

**Goals**

1. A child's `@State`, `@StateObject` and `@FocusState` survive a parent
   rebuild on every backend, matching SwiftUI for the common cases.
2. One implementation in core; backends call it from their existing
   "render stateful view" function.
3. Identity follows SwiftUI rules where we can see them: explicit `.id()`
   and `ForEach` element ids first, structural position otherwise.
4. State for views that disappear is released (no unbounded caches).

**Non-goals**

- Reusing child hosts or native widgets across a rebuild (true
  reconciliation). That is a larger change to each backend's rebuild
  model; see Alternative C.
- UI-only native state that never enters `StateStorage` (tree expansion,
  scroll offset). That is `docs/proposals/restorable-widget-state.md`. The
  two proposals should share identity rules (see below).

## Proposed design

### 1. A core `ChildStateStore`

A small type in `Sources/SwiftOpenUI/State/`, owned by each `ViewHost`:

```swift
/// Carries child views' state across one parent body evaluation.
public final class ChildStateStore {
    /// Begin a body pass: children rendered in this pass are matched
    /// against the previous pass's entries, then the previous pass is dropped.
    public func beginPass()
    public func endPass()   // releases entries not seen in this pass

    /// Called by a backend when it renders a stateful child. Restores
    /// values from the matching previous entry, then records the child's
    /// storages for the next pass.
    public func adopt<V>(_ child: V, identity: ChildStateIdentity)
}
```

`adopt` holds the loop that GTK4 and Android duplicate today: reflect the
child's `AnyStateStorageProvider`s, and if a previous entry matches by
identity, type and storage count, call `restoreValue(from:)` on each.

`endPass()` drops entries that were not adopted in the pass. That fixes
GTK4's unbounded cache and gives "state is discarded when the view
disappears", which is SwiftUI's behaviour.

### 2. Identity: explicit first, structural otherwise

```swift
public struct ChildStateIdentity: Hashable {
    var explicitID: AnyHashable?   // .id(x), ForEach element id
    var structuralPath: [Int]      // position among stateful children
    var typeName: String
}
```

- If the child (or its nearest `ForEach` / `.id()` wrapper) has an
  explicit id, match on `explicitID + typeName`. Reordered rows keep
  their state.
- Otherwise match on `structuralPath + typeName`, as GTK4 does today.
- A type change at the same identity never restores. This is GTK4's
  current `testTypeChangeAtSamePositionSkipsRestore` behaviour.
- Collisions (two children claim the same identity in one pass) restore
  neither and log once in debug builds.

This needs the renderers to carry the nearest explicit id down to the
stateful child. `ForEach` and `IDView` already know their ids, so this is a
renderer-side context value, not a core API change.

### 3. Backend adoption

Each backend's stateful-render function gets a "current parent host"
during body evaluation (GTK4 already has `setCurrentRebuilding`), and calls
`parentHost.childStates.adopt(child, identity:)` before installing state.

| Backend | Change |
| --- | --- |
| GTK4 | Replace `childStateCache` + `nextChildStateKey` with `ChildStateStore`. Behaviour is identical for unkeyed children; keyed rows stop swapping state. |
| Android | Replace `androidStateCache` with per-host `ChildStateStore`. |
| Win32 | Add a current-rebuilding-host context in `Win32ViewHost.buildBodyWithTracking`, and call `adopt` in `winRenderStatefulView`. The window root (and D4's re-render) needs a store too: give `MainWindowState` its own `ChildStateStore`, treated as the root's parent. |
| Web | Same as Win32 in `webRenderStatefulView` / `WebViewHost.rebuild`. Also release orphaned child hosts so `_webRetainedHosts` stops growing. |

### 4. Relationship to restorable widget state

`restorable-widget-state.md` already decided "key by identity from
`.id()`/`idKeyPath`, never position, skip on collision" for UI-only native
state. This RFC uses the same explicit-id rule and adds a structural
fallback, because most `@State` children have no explicit id. If that
fallback is accepted, the restorable-widget-state proposal could use the
same `ChildStateIdentity` type.

## Alternatives considered

**A. Port GTK4's positional cache to Win32 and Web as-is.** Smallest
change: about 20 lines per backend. But it copies the reorder bug and the
unbounded cache into two more backends, and leaves four private copies of
the same logic. Rejected as the end state; acceptable as a stopgap if the
core store slips.

**B. This proposal: a shared, identity-first store with a positional
fallback.** One implementation, fixes the reorder and leak problems, and
matches SwiftUI for keyed collections.

**C. True reconciliation: reuse child hosts and native widgets.** Diff the
new body against the old tree and keep unchanged child hosts alive, so
state never needs copying. This is what SwiftUI does, and it would also
remove flicker and save work. But it requires a keyed descriptor diff and
in-place native updates on every backend. Win32's descriptor tree is
positional and only supports text/colour updates today. Deferred; B does
not block it, because a host that survives needs no restore.

## Testing

- **Core:** unit tests for `ChildStateStore`: restore by structural path,
  restore by explicit id across reorder, no restore on type change, no
  restore on collision, release of entries not seen in a pass.
- **Per backend:** the scenario at the top of this RFC as a shared test
  shape (a child counter survives a parent toggle), plus keyed reorder.
  GTK4's existing three tests move to the shared shape; the reorder test's
  expectation flips for keyed children.
- **Win32 D4:** a nested child counter survives a synthetic
  `WM_DPICHANGED`.

## Migration

1. Land `ChildStateStore` in core with its unit tests. No backend uses it
   yet.
2. Win32 adopts it (closes the user-visible gap, including D4).
3. GTK4 and Android switch from their private caches (behaviour-preserving
   for unkeyed children).
4. Web adopts it and fixes the host leak.
5. Update `docs/issues/win32-conditional-view-rebuild.md` and the
   changelog to close the 2026-07-10 item.

## Questions for commenters

1. **Structural fallback or identity only?** Restorable-widget-state chose
   identity only. Is a positional fallback acceptable for `@State`, given
   most children have no explicit id?
2. **Which explicit ids count?** `.id()` and `ForEach` element ids are
   proposed. Should `List`/`OutlineGroup` row ids and `TabView` tags count
   too?
3. **When should state be released?** This RFC drops entries not seen in
   one pass. SwiftUI keeps state for views hidden by `if` only while they
   exist, so this matches; does any backend need state to survive a
   branch that is hidden and later re-shown?
4. **`@StateObject` lifetime.** Restoring copies the reference, so the old
   object lives on. Is that the semantics we want, or should `@StateObject`
   be held by the store directly?
5. **Thread safety.** `StateStorage.restoreValue` copies without taking
   its lock ("called only during render pass"). Is that guarantee true on
   every backend, including Web's single thread and Win32's message loop?
6. **Order of work.** Win32 first because it closes a user-visible gap and
   D4 depends on it, or core + GTK4 first because GTK4 already has the
   tests?

Please reply on the PR or open an issue referencing this file.
