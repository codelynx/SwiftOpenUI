# Proposal: GTK4 flexible HStack equal-division layout

**Status:** ✅ landed (SwiftOpenUI `a684384`; Synca workaround removed
`280b2ed`). GTK4 backend. **Owner:** Linux-side agent. **Reviewers:**
core/mac agent (foundational layout path) — signed off, with the
vertical-measure + over-constrained-shrink corrections and the review's
spacer/width-budget/integer-residual/visible-gate fixes all folded in.
Full GTK4 suite green (278 tests) incl. `GTK4FlexibleHStackTests`;
runtime-verified (equal drop zones, no resize on selection, symmetric
under window resize).
**Issue:** [`gtk4-hstack-maxwidth-infinity-not-equal.md`](../issues/gtk4-hstack-maxwidth-infinity-not-equal.md)

## Problem

SwiftUI gives equally-flexible HStack children **equal** width — it
splits the remaining width (after inflexible children take their ideal)
equally among flexible children, then proposes each slice to its content.
GTK4's `HStack` fallback uses a plain `GtkBox`, which allocates each
child its **natural** width first and distributes only the leftover
equally — so a flexible child with wider content ends up wider. Two
`.frame(maxWidth:.infinity)` drop zones become unequal when one holds a
long path (Synca's `DualFolderView`). Confirmed no GtkBox knob fixes it:
`set_size_request(0)` sets the *minimum* (GtkBox allocates from natural);
`homogeneous` equalizes *all* children (wrong — the swap button between
the zones must keep its natural size).

## Approach: `GtkCustomLayout` on the flexible HStack path

GTK 4.14 provides `gtk_custom_layout_new(request_mode, measure,
allocate)` — a `GtkLayoutManager` driven by **plain C callbacks**, no
GObject subclassing. We attach it to the fallback HStack box and
implement SwiftUI's distribution in the `allocate` callback. Callbacks
receive the container widget (not user_data), so per-stack config
(spacing, vertical alignment) is stashed on the box via
`g_object_set_data` and read back in the callbacks. Precedent for
`@convention(c)` callbacks + widget-stored context already exists
(`gtk_swift_drawing_area_set_draw_func`), as does `gtk_widget_measure`
usage in Swift.

### The distribution algorithm (allocate callback)

Given box width `W`, height `H`, spacing `s`, and children
`c₀…cₙ₋₁` (iterated via `gtk_widget_get_first_child` /
`get_next_sibling`):

Only **visible** children participate: skip `!gtk_widget_get_visible`
children entirely (no width, no spacing) — matching GtkBox. (`.hidden()`
stays visible-with-opacity-0, so it *does* still take space; a test
asserts both.) Let `n` = visible child count; spacing applies between
visible children only.

1. Classify each visible child: **flexible** if `hexpand != 0` and not a
   spacer/divider marker; else **fixed**. Same marker-aware classification
   the 2+-gate uses (see Scope), so a spacer-only box never opts in.
2. `available = W − s·(n − 1)`.
3. Measure each **fixed** child's `(min, natural)` width; `fixedNatTotal`
   = Σ naturals, `fixedMinTotal` = Σ minima.
4. **Over-constrained fixed case (GtkBox parity).** If
   `available < fixedNatTotal`, fixed children cannot all take natural.
   Shrink them proportionally between their `min` and `natural` toward
   `available` (GtkBox-like), floor at min; `remainder = 0` for flexible.
   Otherwise each fixed child takes natural and
   `remainder = available − fixedNatTotal`.
5. Split `remainder` among the `k` flexible children with an **iterative
   waterfall** (≤ k passes, ~10 lines — do NOT single-pass): `slice =
   pool / kRemaining`; any flexible child whose measured **minimum >
   slice** is clamped to its minimum and removed from the pool; re-divide
   the rest. Repeat until no child is over its slice. Distribute the
   integer rounding remainder ±1px across the first children. *Terminal
   case:* if even `Σ flexible minima > remainder`, clamp all to minimum,
   let GTK clip — **never emit a negative width.**
6. Position visible children in **reading order** (see RTL note in the
   matrix): accumulate `x += childWidth + s`. Vertical placement uses the
   child's height measured **at its assigned width** and the HStack
   `VerticalAlignment` (top/center/bottom) within `H`. Allocate via a
   **fresh** `gsk_transform_translate(x, y)` per child (see gotchas —
   `gtk_widget_allocate` takes the transform transfer-full). **Allocate
   every visible child every pass**, even at clamped/zero width (an
   unallocated child keeps a stale render node).

`layoutPriority` and SwiftUI's full ideal-vs-min flexibility ranges are
**explicitly out of scope** for v1 — flexible = "splits the remainder",
fixed = "natural (shrinkable under pressure)".

### measure callback

- **`request_mode`: pass an explicit func returning `HEIGHT_FOR_WIDTH`.**
  `gtk_custom_layout_new`'s first argument is the request-mode func; a
  `NULL` there defaults to `CONSTANT_SIZE`, silently breaking wrapping.
  (This is a trap — "default" here means *explicit func*, not NULL.)
- Horizontal: `minimum = Σ child minima + spacing`;
  `natural = Σ child naturals + spacing`.
- **Vertical is height-for-width — measure heights at *assigned* widths,
  not natural widths.** When GTK calls `measure(VERTICAL, for_size = W)`
  it must first run the horizontal distribution (step above) for `W`,
  then measure each child's height **at its assigned width** and take the
  max. Measuring at natural width under-reports a flexible Text that will
  be squeezed and wrap to 2 lines → clipped label. Only `for_size == -1`
  uses `max(natural heights)`. **Factor the distribution into a function
  shared by `allocate` and `measure(VERTICAL, for_size ≥ 0)`** so the two
  can't diverge.

This makes the box's *natural* still content-driven (so parents size it
correctly), while *allocation* splits flexible children equally — exactly
the SwiftUI split.

### GTK implementation gotchas (fold into the code)

1. **Request-mode func, not NULL** (above) — else `CONSTANT_SIZE`, no
   height-for-width.
2. **`gtk_widget_allocate` consumes the transform (transfer-full).** Build
   a fresh `gsk_transform_translate` per child per pass; do **not** unref
   it after the call.
3. **Allocate every visible child every pass**, even at clamped/zero
   width — an unallocated child renders a stale node.
4. **Honest minimum** (`Σ minima + spacing`) or GTK logs underallocation
   warnings.
5. `GtkCustomLayout` is **GTK 4.0+** — no version gate needed.

## Scope / gating

- Applies **only to the expanding fallback path** (`gtkRenderFallbackHStack`).
  The shared `GtkFixed` path (no expansion) is unchanged.
- **Gating — DECIDED (review sign-off): 2+ flexible children only.** Zero
  fidelity cost (GtkBox already gives a sole `hexpand` child all the
  remainder, which *is* SwiftUI's answer), smallest regression surface.
  Compute the gate with the **same marker-aware classification** the
  allocate callback uses (spacers/dividers excluded) so a "2 spacers" box
  doesn't opt in. The per-build static decision is fine (rebuilds recreate
  the box).
- **Fidelity — DECIDED (review sign-off): iterative waterfall from the
  start**, not single-pass min-clamp (§algorithm step 5). Single-pass
  overflows `W` under the exact narrow-window case users produce
  (overlap/clip); the iterative delta is trivial.

## Shim surface (new)

- `gtk_swift_custom_layout_new(request_mode, measure, allocate)` → wraps
  `gtk_custom_layout_new`, returns `GtkLayoutManager*`.
- `gtk_swift_widget_set_layout_manager(widget, manager)` (or call
  directly if it imports cleanly).
- `gtk_swift_allocate_child(child, x, y, w, h, baseline)` → builds a
  `gsk_transform_translate` and calls `gtk_widget_allocate` (positioning
  a child at an offset in GTK4 goes through a transform, not a
  GtkAllocation rect).
- Child iteration (`gtk_widget_get_first_child`/`get_next_sibling`) and
  `gtk_widget_measure` are already available.
- Context struct (spacing, alignment, marker awareness) stashed via
  `g_object_set_data_full` on the box; a retained Swift class like the
  lazy-list `LazyListContext` pattern.

## Regression surface + test matrix

Foundational path — must not disturb:
- **single flexible child** + fixed siblings (fills remainder; unchanged
  under the 2+ gate)
- **spacers** (`Spacer()`) — with and without a flexible sibling
- **dividers** (vertical) — stay natural width, full height
- **nested** HStacks / stacks-in-frames
- **vertical alignment** top/center/bottom
- **over-constrained** width: fixed children shrink between min/natural
  (GtkBox parity, §algorithm step 4), then flexible clamp to minimum — no
  negative allocations, no overflow/overlap, no crash
- **height-for-width** children (wrapping text) — height measured at the
  *assigned* width (the vertical-measure fix)
- **RTL** — under `GTK_TEXT_DIR_RTL`, GtkBox auto-mirrors; a custom
  allocate does not. **Decision: mirror `x` when
  `gtk_widget_get_direction() == GTK_TEXT_DIR_RTL`** (lay out right→left).
  Tested with an RTL direction override.
- **invisible children** — `!visible` skipped entirely (no width, no
  spacing); `.hidden()` (opacity-0) still takes space. Assert both.
- **min-waterfall** — a flexible child whose content minimum exceeds its
  equal slice (e.g. a fixed-size image in a flexible frame), so the
  iterative drop-out is actually exercised.
- the **two-drop-zone** case: equal width regardless of path length
  (the acceptance that lets us delete Synca's fixed-width workaround)

Add `Examples/Parity` + `GTK4RenderTests` entries: two/three equal
flexible children with unequal content; flexible + fixed mix; spacer
interaction.

## Rollout

1. Land the custom layout behind the 2+-flexible gate, with tests green.
2. Runtime-verify the drop zones are equal via `.frame(maxWidth:.infinity)`
   (not the workaround).
3. **Remove the Synca `#if !os(macOS)` fixed-width workaround** in
   `FolderDropZone.swift`, reverting to shared `.frame(maxWidth:.infinity)`.
4. Close the issue.

## Cross-backend note

The *problem* is GTK4-specific (GtkBox natural-bias); macOS does this
natively and Win32/Web have their own layout. But the **algorithm above
is the shared spec** — the SwiftUI distribution every backend should
match. Not a shared-code change; no cross-platform-changelog entry (GTK4
backend-local), but worth a heads-up so Win32/Web confirm their
flexible-HStack distribution matches.

## Resolved by review

1. **Gating:** 2+-flexible only. ✅ (see Scope)
2. **Fidelity:** iterative waterfall from the start. ✅ (see §algorithm)
3. **Baseline alignment:** keep top/center/bottom scope — nothing in
   Synca uses `.firstTextBaseline`, and baseline plumbing through
   `gtk_widget_allocate` is real work; **defer until a consumer exists.**
4. **Wholesale GtkBox-fallback replacement:** **defer** — revisit only
   after the 2+ gate has soaked; answering it requires the
   over-constrained fixed-shrink policy (§algorithm step 4) anyway.
