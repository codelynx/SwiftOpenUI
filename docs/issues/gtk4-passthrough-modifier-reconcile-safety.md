# GTK4: value-carrying passthrough modifiers can go stale on fast-path reconcile

**Status: RESOLVED** (descriptor-integration, option 1) — see Resolution.

## Summary

A class of GTK4 modifiers apply their effect as a **side effect in
`gtkCreateWidget`** and are **body-transparent** (`Body != Never`, so
they recurse into `content` in the descriptor tree and are not
represented as descriptor props). This is correct on the **create path**
but not guaranteed on **reconcile**: when the reconciler takes the narrow
in-place mutation path (`gtkCanApplyTextColorHostMutation`) it reuses the
existing widget without re-running `gtkCreateWidget`, so a **changed
value never gets re-applied** — the widget keeps its old value.

Known members of the class:

- **`AccessibilityLabelView`** (`.accessibilityLabel`) — a dynamic label
  (`Text(v).accessibilityLabel(changingString)`) can leave the AT layer
  announcing the old label. (Issue [[gtk4-win32-accessibilitylabel]].)
- **`TextSelectionView`** (`.textSelection`) — a dynamic selectability
  (`.textSelection(dynamicFlag)`) can leave the label selectable/not
  against the old value. (Issue [[gtk4-win32-textselection-modifier]].)

Contrast with **registration** side effects behind a `Body = Never`
shield (e.g. the hidden `.keyboardShortcut` Button, or `FocusedValueView`):
those register a value that *doesn't change identity*, so reuse
preserving the old registration is correct. The problem here is
specifically **value-carrying** modifiers whose value can change.

## Severity / scope

Narrow but real:
- Only bites when the **fast** mutation path runs (currently gated to
  text-color host mutations) **and** the modifier's value changed. Any
  structural change falls to full rebuild → create path → value
  re-applied correctly.
- Impact is low for the current members (a11y label / text
  selectability, not correctness of data). But the **public modifiers
  are marked Implemented and should be reconcile-safe** regardless of any
  one app's usage.

Synca's `ActionBadge` is the live example: `action.accessibilityLabel`
changes on Update↔Mirror mode flips. Whether it goes stale depends on
whether that flip is reconciled via the fast path or a rebuild.

## Fix options

1. **Descriptor integration (thorough).** Give these modifiers a
   descriptor representation (a prop on `GTK4DescriptorNode`) and a
   mutation handler in `gtkExecuteDescriptorPlan`, so a value change is
   detected in the plan and re-applied to the reused widget. Generalizes
   to future value-carrying passthrough modifiers.
2. **`Body = Never` opaque + explicit update (narrower).** Make the
   wrapper a `Body = Never` primitive with a backend renderer that
   re-applies on both create and the reuse path — requires a per-backend
   renderer (incl. Win32 pass-through) and a reuse hook.

Option 1 is preferred — it's the general mechanism and reuses the
existing plan/execute pipeline.

## Acceptance

- A dynamic `.accessibilityLabel` / `.textSelection` value updates the
  GTK4 widget after a fast-path reconcile (not just on rebuild).
- Regression test in the GTK4 reconcile suite covering a value change
  under the fast mutation path.

## Resolution (option 1 — descriptor integration)

Implemented the generalized mechanism (one path, both modifiers):

- New descriptor **kind `.widgetProperty`** + **prop `GTK4WidgetPropertyDescriptor`**
  carrying a `GTK4WidgetPropertyValue` (`.textSelectable(Bool)` /
  `.accessibilityLabel(String)`).
- `TextSelectionView` / `AccessibilityLabelView` are now `GTKDescribable`
  and emit a `.widgetProperty` node carrying their value, with the content
  as the single child (mirrors `OpacityView`). Create path unchanged
  (`gtkCreateWidget` still applies the effect).
- New update intent **`.widgetPropertyUpdate`**, derived from the kind,
  added to both fast-path gates (`gtkCanApplyTextColorHostMutation` and
  `gtkAllSlotsValid`).
- New hook **`gtkWidgetPropertyHook`** → **`gtkSetWidgetProperty(slotID:descriptor:)`**,
  which resolves the slot to the widget and re-applies the effect
  (`gtk_swift_label_set_selectable` on subtree labels / `gtk_swift_accessible_set_label`).
  Mirrors `gtkSetPadding` (the existing wrapper-with-in-place-effect on
  the fast path).

So a value change now plans a `.widgetPropertyUpdate` that stays on the
narrow path and re-applies — verified by 7 tests in `GTK4DescriptorTests`
(plan intent, fast-path eligibility, no-change reuse, hook dispatch,
describe-integration from the real modifiers, and a badge-like mixed
text+color+label change staying on the fast path). Suite 758 pass / 3
skip / 0 fail.

**Not addressed here:** actual screen-reader double-announce (a11y-tree
shape, see [[gtk4-win32-accessibilitylabel]]) and Win32 pass-through —
both out of scope for reconcile-safety.
