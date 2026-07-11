# Proposal: GTK4 flexible HStack equal-division layout

**Status:** design for review (no code yet). GTK4 backend.
**Owner:** Linux-side agent. **Reviewers:** core/mac agent (foundational
layout path).
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

1. Classify each child: **flexible** if `hexpand != 0` and it's not a
   spacer/divider marker; else **fixed**. (Spacers/dividers keep their
   existing GtkBox-era handling — a spacer with no flexible siblings
   still expands; a divider stays natural-width.)
2. `available = W − s·(childCount − 1)`.
3. For each **fixed** child, measure its natural width
   (`gtk_widget_measure(HORIZONTAL, H)`); sum → `fixedTotal`.
4. `remainder = max(0, available − fixedTotal)`.
5. Split `remainder` **equally** among the `k` flexible children:
   `slice = remainder / k`, distributing the integer remainder to the
   first children (±1px). **Respect each flexible child's minimum**: if a
   flexible child's measured minimum exceeds its slice, it takes its
   minimum and is removed from the pool; re-divide the rest (iterative,
   matching SwiftUI's "satisfied children drop out" behavior). *v1 may
   ship a single pass with min-clamp and note iterative as a follow-up if
   the pathological narrow case matters.*
6. Position children left→right: `x` accumulates `childWidth + s`. Each
   child's vertical placement uses its measured height and the HStack
   `VerticalAlignment` (top/center/bottom) within `H`. Allocate via
   `gtk_widget_allocate(child, w, h, baseline, translate(x, y))`.

### measure callback

- Horizontal: `minimum = Σ child minima + spacing`;
  `natural = Σ child naturals + spacing`.
- Vertical: `minimum = max child minima`; `natural = max child naturals`.
- `request_mode`: `HEIGHT_FOR_WIDTH` (default), matching GtkBox.

This makes the box's *natural* still content-driven (so parents size it
correctly), while *allocation* splits flexible children equally — exactly
the SwiftUI split.

## Scope / gating

- Applies **only to the expanding fallback path** (`gtkRenderFallbackHStack`).
  The shared `GtkFixed` path (no expansion) is unchanged.
- **Gating decision to confirm in review:** apply the custom layout to
  *all* fallback HStacks (more correct everywhere, larger regression
  surface), **or** only when there are **2+ flexible children** (the
  equal-division case), leaving single-flexible-child / spacer-only
  layouts on the proven GtkBox path. *Recommendation: gate to 2+ flexible
  children for v1* — smallest blast radius, and GtkBox already handles the
  single-flexible case correctly (one child gets all the remainder).

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
- **over-constrained** width (remainder ≤ 0): flexible children clamp to
  minimum, no negative allocations, no crash
- **height-for-width** children (wrapping text) measured at the right
  width
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

## Open questions

1. **Gating:** 2+-flexible only (recommended) vs all fallback HStacks?
2. **Iterative vs single-pass min-clamp** for v1 (does the pathological
   narrow case matter for any real layout)?
3. **Baseline alignment:** current `VerticalAlignment` is top/center/
   bottom only; no `.firstTextBaseline`. Keep that scope, or is baseline
   needed?
4. Should the same custom layout eventually **replace** the GtkBox
   fallback wholesale (retire the natural-bias path entirely) once
   proven — a later consolidation?
