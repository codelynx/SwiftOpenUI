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
already handle that correctly. That is Win32 catch-up, and it is a
**prerequisite** for Win32 here (you cannot preserve state across a
rebuild that never happens) — but it is not part of this shared contract.
Do not conflate the two.

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

## Win32 section

**Prerequisite:** implement structural rebuild for branch swaps first
([`win32-conditional-view-rebuild.md`](../issues/win32-conditional-view-rebuild.md)) —
until the subtree rebuilds at all, there is no rebuild boundary to
preserve state across. GTK4/macOS already clear this bar.

**Then:** `Win32OutlineTree` keeps expansion in a retained
`Win32OutlineModel`, but `OutlineGroup.winCreateWidget` allocates a fresh
model with an empty `expanded` set on every call, and the model dies with
the hosting view on structural rebuild
([followups §1](../issues/win32-outlinegroup-dropdown-followups.md)).
Under this contract Win32 implements: capture the `expanded` set keyed by
node identity (not the current positional `"0","1"` keys) plus the scroll
offset, into the shared token; restore both after the new model is built,
dropping identities that no longer exist. The existing retained-model
design is a head start — it only needs to be re-seeded from the token
instead of from empty.

## GTK4 section

_Owned by the Linux-side agent — to be appended._

<!-- Anchors already established for this work (from the GTK4 collapse
     analysis): save at the GTKViewHost.saveFocusInfo point; new shims for
     tree-list-row expanded get/set, list-model row/count, and scrolled-
     window vadjustment get/set-value; identity keyed by OutlineGroup
     idKeyPath; scroll restore idle-deferred. Linux agent to confirm and
     detail. -->

## macOS section

Reference platform. SwiftUI preserves tree expansion and scroll across
`@State` changes natively (verified). No implementation; macOS is the
parity target the other backends match.
