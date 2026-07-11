# Proposal: Restorable Widget State Across Rebuilds

> **Status: Draft — core + Win32 sections by the macOS-side agent.**
> GTK4 section owned by the Linux-side agent (to be appended). macOS is
> the reference platform (SwiftUI preserves this state natively; no work).

## Goal

When the view-host rebuilds a subtree, native widgets that hold
**UI-only state** — tree expansion, scroll position, and by extension
selection — should keep that state, keyed by view identity. One
backend-agnostic contract in the shared view-host, so no app carries
`#if os()` to work around lost expansion or scroll.

This generalizes the already-shipped **input-state-preservation**
(focus / cursor / text-selection), which solved exactly this shape of
problem for text controls only. See
[`docs/plans/input-state-preservation.md`](../plans/input-state-preservation.md).

## Problem

A rebuild is the *correct* response to an ancestor `@State`/`@Observable`
change — the framework re-runs `body` and re-materializes the subtree.
The bug is that a native widget holding UI-only state is torn down and
recreated fresh, so state the user established by interacting (which
folders are expanded, where they scrolled) is silently lost.

This is **backend-independent**, and the reference platform proves it is
a bug, not acceptable behavior:

| Backend | Symptom | Evidence |
|---------|---------|----------|
| **macOS (SwiftUI)** | **None — state preserved** | Reference; verified: picking a merge resolution keeps all tree expansion. |
| **GTK4** | OutlineGroup expansion **and** scroll reset to top on any ancestor rebuild | Confirmed end-to-end (`GTKViewHost.rebuild()` builds a fresh `GtkTreeListModel` + `GtkScrolledWindow`). |
| **Win32** | OutlineGroup expansion resets on ancestor rebuild | [`win32-outlinegroup-dropdown-followups.md` §1](../issues/win32-outlinegroup-dropdown-followups.md) |

In Synca's Compare Result window the trigger is routine: typing in the
filter, flipping Update↔Mirror↔Merge, or picking a merge resolution — all
mutate state the enclosing view reads, all rebuild the tree, all collapse
it on GTK4/Win32 while macOS holds steady.

### What is NOT in scope

Win32 additionally has a *separate* gap —
[`win32-conditional-view-rebuild.md`](../issues/win32-conditional-view-rebuild.md):
structural branch swaps (`if/else`) don't rebuild at all. GTK4 and macOS
already handle that correctly. That is Win32 catch-up and it is out of
scope here — but, **corrected on review, it is NOT a prerequisite for this
contract.** Synca's actual expansion-reset triggers (filter typing,
sync-mode flip) are *value-change* rebuilds of an always-present
`OutlineGroup` — `displayTree` is `@State`, `applyFilter()` reassigns it,
and the tree is not behind an `if/else` — so the rebuild boundary the token
rides already fires on Win32 today (that is precisely *why* expansion
resets there). Branch-swap catch-up would only extend the contract to a
reset trigger that is itself an `if/else` swap — which none of Synca's
are. Keep the two separate, but do not gate this work on it.

## Core design questions

Three decisions shape the shared API. #3 is load-bearing — it fixes the
token's type and cannot be retrofitted, so it must be settled first.

### Q1 — Scope: preserve-across-rebuild, or skip-the-rebuild?

Two levels solve the symptom:

- **(a) State-preservation** — accept the rebuild; save identified
  UI-state before teardown, restore after. Generalizes the shipped
  input-state pattern.
- **(b) True reconciliation** — make the host *skip* rebuilding subtrees
  whose inputs are unchanged (reuse the widget → nothing to restore).
  This is the descriptor-pipeline investment.

**Decision (recommended): (a) now, (b) deferred.** (a) is the shipped
pattern, closes both platforms' user-visible bugs, and is a strictly
smaller surface. (b) was triple-checked for GTK4's OutlineGroup and found
mispriced — it needs a Canvas-scale payload channel, a hosted-boundary
rule for slot capture, and List describability before it even engages —
so it stays the long-term optimization, probe-gated, exactly the
sequencing used for Menu §5. Rebuild-on-change remains the correctness
mechanism.

### Q2 — Where the contract lives

**Decision (recommended): shared orchestration + a minimal backend
protocol.** The view-host already owns the save-before-teardown /
restore-after-rebuild lifecycle (GTK4's `saveFocusInfo`, Web's rebuild).
Extend that one lifecycle to also drive a small per-backend hook —
"capture your restorable state → opaque token" / "restore from token" —
which each backend implements for its native tree/scroll widgets. One
save/restore lifecycle, N backends implementing only the capture/restore
primitives. This is precisely how input-state-preservation already
divides labor (shared semantics, per-backend mechanism).

### Q3 — ⭐ The key: identity or position?

What identifies "the same row/subtree" across a rebuild, so restored
state lands on the right node?

- **Positional** (DFS index `"0","1",…`) renumbers on any shape change:
  filter apply/clear, mode flip, re-compare. The GTK4 triple-check
  flagged this as the fatal flaw; the Win32 followup's hope that
  "positional keys are stable across rebuilds" holds *only* when shape is
  unchanged — false for exactly Synca's filter and mode-flip paths.
- **Identity** uses the view's own id. `OutlineGroup` already carries an
  `idKeyPath` (Synca uses `\.fullPath`). Survives shape changes; restored
  state lands on the surviving node or is cleanly dropped.

**Decision (recommended): identity-based, threaded from the view's
existing `id`/`idKeyPath`**, with an input-state-preservation-style
bail-out guard — if identity can't be matched, skip (conservative,
never an error). Positional only as a last-resort fallback for views
with no identity. This is #3 because it dictates the token carries
stable IDs, not indices: decided up front, or not at all.

## Shared contract (the "what")

At the level of *what*, not *how*:

- The view-host, around the rebuild it already performs, asks the outgoing
  subtree for a **restorable-state token** and offers it to the incoming
  subtree.
- A widget that holds UI-only state (tree, scroll view) opts in by
  implementing capture/restore. Everything else is unaffected.
- The token is a set of **(identity → state)** entries — e.g. expanded
  node IDs; scroll offset — never indices.
- Restore is **best-effort with a bail-out guard**: unmatched identities
  are dropped, a wholesale mismatch skips restoration. A failed restore
  is never an error (same principle as input-state and the animation
  batch).
- Scroll restore may need to be **deferred to the next frame** (right
  after rebuild the content isn't realized, so an immediate offset clamps
  to zero).

## Contract sketch (for backend review)

Interface-level, not implementation — this is the shape the three
backend adapters build against, so it needs cross-backend sign-off
**before** core code lands. Signatures are illustrative; names open.

### Shared core (SwiftOpenUI)

```swift
/// A backend widget wrapper that holds UI-only state which should
/// survive a host rebuild. Backends conform their tree / scroll
/// wrappers (GtkTreeList…, Win32OutlineModel host, Web tree element).
protocol RestorableStateHost {
    /// Stable identity for matching the outgoing widget to its
    /// incoming replacement. Derived from the owning view's id — equal
    /// iff "the same logical widget" across the rebuild. (Q3: identity,
    /// never positional.)
    var restorationIdentity: RestorationIdentity { get }

    /// Snapshot current UI-only state, or nil if there's nothing to
    /// save. Entries inside are keyed by *node* identity, never index.
    func captureRestorableState() -> RestorableStateToken?

    /// Re-apply a snapshot. Best-effort: silently drop entries whose
    /// node no longer exists; never throw. May defer (e.g. scroll
    /// offset to the next frame, once rows are realized).
    func restoreState(_ token: RestorableStateToken)
}

/// Backend-opaque payload. The shared layer stores and routes it by
/// identity and never inspects the contents.
struct RestorableStateToken { /* backend-defined */ }

struct RestorationIdentity: Hashable { /* from view id / idKeyPath */ }
```

### Lifecycle (extends the existing `rebuild()`)

The host already has one save-before-teardown / restore-after point
(GTK4 `saveFocusInfo`, Web innerHTML swap). Generalize it:

1. **Before teardown** — walk the outgoing subtree; for each
   `RestorableStateHost`, stash `captureRestorableState()` under its
   `restorationIdentity`.
2. **Teardown + rebuild body** — unchanged.
3. **After rebuild** — walk the incoming subtree; for each
   `RestorableStateHost`, if a token matches its `restorationIdentity`,
   `restoreState(it)`. No match → skip (bail-out guard, never an error).

This *is* input-state-preservation generalized: today's focus/cursor
save/restore is the same lifecycle for text controls, keyed by
tag+type+index. Text controls can migrate onto this protocol later (not
required by this proposal).

### Open questions for backend sign-off

1. **Identity source / uniqueness.** A single OutlineGroup per view
   (Synca today) can key off a type+structural signature. Multiple
   restorable widgets in one view need real disambiguation — an explicit
   `.id()` on the view, threaded into `RestorationIdentity`. Is
   "type-signature default, explicit `.id()` override" enough for all
   backends?
2. **Walk boundary.** Each backend needs one cheap point to walk
   outgoing/incoming. GTK4 `rebuild()` ✓; Web innerHTML swap ✓; Win32 ✓
   on the structural-rebuild path (no longer a hard prerequisite per the
   Win32-section correction).
3. **Token: opaque vs. shared-typed.** Recommend **opaque** (shared
   layer stays out of modeling expansion/scroll; extensible). An optional
   shared convenience struct (`expanded: [ID]`, `scrollOffset: Double`)
   backends *may* use would enable cross-backend tests — worth it, or
   premature?

## Win32 section

**No hard prerequisite** (corrected on review). The
[`win32-conditional-view-rebuild.md`](../issues/win32-conditional-view-rebuild.md)
branch-swap gap is *not* a blocker here: Synca's expansion-reset triggers
(filter typing, sync-mode flip) are value-change rebuilds of an
always-present `OutlineGroup`, so `Win32ViewHost.rebuild()` already
DestroyWindows + re-renders the tree subtree today — the very reason
expansion resets. The token rides *that* existing rebuild lifecycle, which
is the same seam GTK4 uses. (The branch-swap fix stays worthwhile on its
own, and would gate this contract only for a future reset trigger that is
itself an `if/else` swap.)

**Mechanism:** `Win32OutlineTree` keeps expansion in a retained
`Win32OutlineModel`, but `OutlineGroup.winCreateWidget` allocates a fresh
model with an empty `expanded` set on every call, and the model dies with
the hosting view on structural rebuild
([followups §1](../issues/win32-outlinegroup-dropdown-followups.md)).
Under this contract Win32 implements: capture the `expanded` set keyed by
**node identity — the ancestor-ID path (root→row), per Q3** — not the
current positional `"0","1"` keys, plus the scroll offset, into the shared
token; restore both after the new model is built, dropping identities that
no longer exist. (Synca's `\.fullPath` id is already root-anchored, so for
this app the path form collapses to the id itself; the path framing is what
keeps the contract correct for trees whose leaf ids recur across subtrees —
the same reason the GTK4 section keys on the ID path.) The existing
retained-model design is a head start — it only needs to be re-seeded from
the token instead of from empty.

## GTK4 section

**No prerequisite** (unlike Win32): GTK4 already rebuilds branch swaps
correctly, so the rebuild boundary the token rides already exists. This
section implements the shared contract directly once the core hook lands.

**Where the state is lost.** `OutlineGroup` renders via
`GTKRenderable.gtkCreateWidget` → `gtkCreateLazyTreeWidget`, which builds
a **fresh** `GtkTreeListModel` + `GtkListView` + `GtkScrolledWindow` on
every `GTKViewHost.rebuild()` — all-collapsed (`autoexpand=FALSE`), scroll
adjustment back to 0. Expansion lives in `GtkTreeListRow` GObjects and
**never enters `@State`/StateStorage**, so it's exactly the renderer-owned
UI state this token is for.

**Lifecycle seam (the token generalizes what already exists).** Focus/
cursor survival already brackets `rebuild()` at the right points:
`saveFocusInfo(in: container)` (`GTKViewHost.swift:300`) *before* the
teardown loop (`gtk_box_remove`, `:320`), and `restoreFocusInfo(…, in:
newChild)` (`:436`) *after* `gtk_box_append` (`:357`). The generic
capture/restore should **generalize this bracket** — focus becomes one
token channel, expansion+scroll another — not a parallel path.

**Capture (outgoing subtree → token).** From the OutlineGroup's top widget
(a `GtkScrolledWindow`) reach its `GtkListView` → `GtkTreeListModel`; walk
`0..<n_items` via `get_row(i)`, and for each row with `get_expanded == true`
record its **identity** (see keying below); read the scrolled-window
vadjustment value. Cost is O(**materialized** rows) = O(roots + expanded
descendants), not O(total) — preserves the virtualization win.
- *Access gap to close:* the model/context is currently stored only on the
  factory (`GTKRenderer.swift:5383,5415`), not reachable from the scrolled
  widget. Stash the tree model (+context) on the scrolled widget via
  `g_object_set_data_full` at build time (cleanest), or add widget→model
  traversal shims.

**Restore (token → incoming subtree).** After the new model is built,
re-expand **top-down** — setting `expanded` on a row lazily materializes
its child model via the create-func, which is what makes deeper rows
addressable; a deep set cannot be restored in one flat pass. Match by
identity, drop identities that no longer exist (bail-out). Then restore the
vadjustment **idle-deferred** (`g_idle_add` — already the pattern at
`GTKViewHost.swift:139,419`); an immediate offset clamps to 0 before rows
realize.

**Keying — identity as an ancestor-ID path (refines Q3 for trees).** Per
Q3, key by the view's `idKeyPath` (Synca's `\.fullPath`) — **but for a
tree the token key must be the ancestor-ID *path* (root→row), not the bare
leaf ID**: the same leaf ID can recur in different subtrees, which is why
`LazyTreeContext` uses globally-unique positional keys today
(`GTKRenderer.swift:5231`). A bare leaf ID would misrestore; the ID path is
unique and stable across a filter/mode-flip rebuild.

**Plumbing change (explicit).** `LazyTreeContext.init` takes only `items`,
`childrenKeyPath`, `rowContent` (`GTKRenderer.swift:5222`), and
`OutlineGroup.gtkCreateWidget` does not pass `idKeyPath` (`:5428`). Thread
`idKeyPath` through and build a **positional-key → ancestor-ID-path** map
alongside `childKeysByKey`, so capture/restore translates between the
model's positional rows and the stable identity the token carries.

**New GTK shims (Linux agent owns; all absent today — only the
`GtkExpander` `expanded` accessor exists; all thin GIR wrappers):**
`gtk_tree_list_row_get_expanded` / `set_expanded`,
`gtk_tree_list_model_get_row`, `g_list_model_get_n_items`,
`gtk_scrolled_window_get_vadjustment`, `gtk_adjustment_get_value` /
`set_value`.

**Scroll robustness (v1 → follow-up).** v1 restores the raw vadjustment
value (best-effort, deferred). A raw pixel offset is brittle when content
height changed (filter apply/clear); the robust **follow-up is a
node-anchored scroll** — record the top-visible row's ancestor-ID path and
scroll to it after re-expansion.

## macOS section

Reference platform. SwiftUI preserves tree expansion and scroll across
`@State` changes natively (verified). No implementation; macOS is the
parity target the other backends match.
