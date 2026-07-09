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

- A dynamic `.accessibilityLabel` / `.textSelection` value change is no
  longer silently reused: it is visible in the descriptor tree and the
  GTK4 widget ends up with the new value (via full rebuild — see
  Resolution for why the narrow path can't apply here).
- Regression tests in the GTK4 reconcile suite: a value change plans an
  `.update` that is *not* narrow-path-eligible (forces rebuild), and an
  unchanged value still `.reuse`s (no needless rebuild).

## Resolution (option 1 — descriptor visibility, rebuild-backed)

The fix makes the value **visible in the descriptor tree** so a change is
no longer silently reused; correctness comes from the resulting **full
rebuild** re-applying the value, not a narrow in-place mutation. (An
earlier revision added narrow-path machinery, but `.widgetProperty` has no
native slot of its own — it applies in-place to the content's, often
already-hosted, widget — so the narrow path could never engage. That dead
machinery was removed; see review below.)

- New descriptor **kind `.widgetProperty`** + **prop `GTK4WidgetPropertyDescriptor`**
  carrying a `GTK4WidgetPropertyValue` (`.textSelectable(Bool)` /
  `.accessibilityLabel(String)`).
- `TextSelectionView` / `AccessibilityLabelView` are now `GTKDescribable`
  and emit a `.widgetProperty` node carrying their value, content as the
  single child (mirrors `OpacityView`). Create path unchanged —
  `gtkCreateWidget` still applies the effect, and is what re-applies on
  rebuild.
- A value change now plans a `.widgetPropertyUpdate` (kind→intent
  derivation). This intent is **deliberately not** narrow-path-eligible:
  `gtkCanApplyTextColorHostMutation` rejects it, forcing a full rebuild.

So: changed value → `.update` (not silent reuse) → narrow path rejected →
full rebuild → create path re-applies. Unchanged value → `.reuse` (no
needless rebuild). Verified by 6 tests in `GTK4DescriptorTests` (update +
not-eligible for both modifiers, no-change reuse, describe-integration
from the real modifiers, and the badge-like mixed change forcing rebuild).
Suite 751 → 757, 0 failures.

### Why not the narrow path (marker collision)

`.widgetProperty` can't get a `nativeSlotID` the way `padding` does:
`PaddingView` creates and marks its *own* wrapper widget
(`gtkMarkHostedNodeKind(_, .padding)`), whereas `.widgetProperty` has no
widget of its own and applies to the content's top widget — which is
frequently already a hosted node (e.g. a `.text` label). A widget holds a
single hosted-kind marker, so it can't be marked `.widgetProperty` without
clobbering its `.text` marking. Making the narrow path work (option 2)
would need a secondary marker or child-slot inheritance in
`gtkAssignNativeSlots` — deferred until there's a broader need for
fast-path passthroughs; the rebuild is cheap for these infrequent effects.

**Not addressed here:** actual screen-reader double-announce (a11y-tree
shape, see [[gtk4-win32-accessibilitylabel]]) and Win32 pass-through.
