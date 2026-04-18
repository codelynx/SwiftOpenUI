# Proposal: GTK4 Layout Combination Tests

**Date**: 2026-04-17
**Motivation**: Three layout bugs found in a single Synca validation session, all caused by **modifier combinations** and **container nesting** — none reproducible by testing individual modifiers in isolation.

## Problem Statement

The current GTK4 test suite has 3,600 lines covering individual modifier behavior (frame centering, spacer expansion, VStack alignment). Every modifier works correctly in isolation. The bugs that shipped were all **emergent** — they only appear when modifiers compose inside nested containers:

| Bug | Root cause | Individual tests would catch? |
|-----|-----------|------|
| Status bar steals List vertical space | `.background(fill.overlay(stroke))` falls to ZStack fallback; shapes leak `vexpand` through the ZStack to the parent VStack | No |
| Header stretches vertically | `.frame(maxWidth: .infinity, alignment: .trailing)` inserts alignment spacers with `vexpand=1`; GTK auto-computes parent's vexpand from children | No |
| List doesn't fill VStack | `GtkScrolledWindow.propagate_natural_height` defaults to 1; List reports full content height as natural, starving siblings of slack | No |

All three passed through individual modifier tests. All three broke in a real app layout.

## Coverage Gaps

### Gap 1: No `.background()` modifier tests at all

Zero tests for either the native CSS path (`FilledShape<RoundedRectangle>`) or the ZStack fallback path (anything else). Both paths have different vexpand behavior — never tested.

### Gap 2: No overlay composition tests

`.background(shape.fill.overlay(shape.stroke))` is a standard SwiftUI idiom for bordered cards. SwiftOpenUI routes it through ZStack fallback because `gtkCanRenderNativeBackground` only recognizes bare `FilledShape`. The fallback leaks vexpand from shape children. Never tested.

### Gap 3: No `List` in container tests

`List` is a scrollable container that wraps content in `GtkScrolledWindow`. Its interaction with parent VStack/HStack for vertical space distribution is untested.

### Gap 4: `FrameView` alignment vexpand propagation

`FrameView` inserts vexpand spacers for `.center`/`.leading`/`.trailing` vertical alignment. GTK's `gtk_widget_compute_expand` inherits vexpand from children, so these spacers leak expansion to the parent. Only fixed-frame centering is tested; the expansion-leak path is not.

### Gap 5: Modifier ordering effects

`.frame().background()` vs `.background().frame()` produce different widget trees with different expand characteristics. No ordering tests exist.

## Proposed Test Cases

### Category A: Background + Shape Modifier Chains

```
A1. VStack { Text; Text.background(RoundedRectangle.fill) }
    Assert: background wrapper vexpand = 0 (content doesn't expand)

A2. VStack { Text; Text.background(RoundedRectangle.fill.overlay(RoundedRectangle.stroke)) }
    Assert: ZStack fallback wrapper vexpand = 0 (shapes don't leak expansion)

A3. Text.background(Color.red)
    Assert: uses CSS path (no wrapper box), no vexpand leak

A4. Text.background(RoundedRectangle.fill).overlay(RoundedRectangle.stroke)
    Assert: background uses native CSS path; overlay via GtkOverlay;
    wrapper vexpand = 0

A5. Text.frame(maxWidth: .infinity).background(RoundedRectangle.fill)
    Assert: hexpand = 1, vexpand = 0
```

### Category B: List in Container Hierarchies

```
B1. VStack { Text("header"); List { Text("row1"); Text("row2") }; Text("footer") }
    Assert: List's ScrolledWindow has vexpand=1;
    header and footer have vexpand=0;
    List gets majority of vertical allocation

B2. VStack { Text("header"); List { ... }; HStack { TextField; Text } }
    Assert: HStack (status bar analog) stays at intrinsic height;
    List fills remaining space

B3. List { ForEach(0..<100) { Text("Row \($0)") } }
    Assert: ScrolledWindow propagate_natural_height = 0;
    natural height is small (not 100 * row_height)
```

### Category C: FrameView Alignment + vexpand

```
C1. VStack { Text; Text.frame(maxWidth: .infinity, alignment: .trailing) }
    Assert: frame wrapper vexpand = 0 (alignment spacers don't leak)

C2. VStack { Text; Text.frame(maxWidth: .infinity, alignment: .center) }
    Assert: same — vexpand = 0

C3. VStack { Text; Text.frame(height: 100, alignment: .center) }
    Assert: wrapper vexpand = 0, child centered within 100px

C4. VStack { Text; Text.frame(maxHeight: .infinity, alignment: .center) }
    Assert: wrapper vexpand = 1 (intentional — maxHeight is infinite)
```

### Category D: Modifier Ordering

```
D1. Text.frame(maxWidth: .infinity).background(Color.red)
    vs Text.background(Color.red).frame(maxWidth: .infinity)
    Assert: both produce hexpand=1, vexpand=0; visual result matches

D2. Text.padding().frame(width: 200)
    vs Text.frame(width: 200).padding()
    Assert: different wrapper sizes but both vexpand=0

D3. Text.background(RoundedRectangle.fill).frame(maxWidth: .infinity)
    Assert: hexpand=1 on outer frame, vexpand=0 on background wrapper
```

### Category E: Deep Nesting (Real-App Patterns)

```
E1. "Synca CompareResultView header"
    VStack(spacing: 0) {
        HStack {
            VStack { Text; Text; Button }.frame(width: 260)
            Spacer(minLength: 24)
            VStack { HStack { Spacer; Text; Button } }
                .frame(maxWidth: .infinity, alignment: .trailing)
        }.padding()
        Divider()
        List { Text("row") }
        Divider()
        HStack { Image; TextField.background(RoundedRect.fill)
                 .overlay(RoundedRect.stroke); Spacer; Text }
            .padding()
    }
    Assert: header vexpand=0, List vexpand=1, status bar vexpand=0

E2. "FolderDropZone pattern"
    VStack { Text; Image }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(RoundedRectangle.fill)
        .overlay(RoundedRectangle.strokeBorder(style: dashed))
    Assert: vexpand=0, hexpand=1, shapes don't inflate parent
```

## Implementation Approach

1. **New test file**: `Tests/BackendTests/GTK4Tests/GTK4LayoutCombinationTests.swift`
2. **Test method**: Build view → call `gtkCreateWidget()` → inspect widget tree properties (`gtk_widget_get_vexpand`, `gtk_widget_get_hexpand`, `gtk_widget_get_halign`, `gtk_widget_set_size_request` values)
3. **Scope**: ~20 targeted tests covering all five categories
4. **Assertion style**: Property-based (expand, align, size_request) rather than pixel-based — these are structural invariants, not visual regression tests

## Priority

**High.** Every bug found in the 2026-04-17 session would have been caught by Category A-C tests. These bugs are silent (no crash, no warning) and only surface in real app layouts — exactly the kind that slip through manual testing.
