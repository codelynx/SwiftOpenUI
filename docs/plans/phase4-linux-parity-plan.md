# GTK4 Parity Roadmap: Fill the SwiftUI Matrix

## Status: COMPLETE (2026-03-19)

All 6 phases implemented. GTK4 column: ~91% views, ~94% modifiers.
118 tests, all passing. `swift build` clean.

## Context

The swiftui-parity-matrix.md showed GTK4 at ~47% view coverage and ~65% modifier coverage. All missing features had reference implementations in SwiftLinuxUI. This plan organized them into phases by dependency order and complexity, targeting GTK4 column completion.

## Phase Overview

| Phase | Theme | Items | Status |
|-------|-------|-------|--------|
| A | CSS Modifiers | 4 modifiers | **Done** |
| B | Simple Controls | 5 views | **Done** |
| C | Lifecycle & Presentation | 4 modifiers + 2 views | **Done** |
| D | Containers & Layout | 6 views | **Done** |
| E | Lazy Collections | 4 views | **Done** |
| F | Advanced | 4 views + 2 modifiers | **Done** |

---

## Phase A: CSS Modifiers — DONE

| Item | GTK Mechanism | Commit |
|------|-------------|--------|
| `.cornerRadius()` | CSS `border-radius` | `e139b1d` |
| `.shadow()` | CSS `box-shadow` + margin | `e139b1d` |
| `.rotationEffect()` | CSS `transform: rotate()`, Angle type | `e139b1d` |
| `.overlay()` | GtkOverlay with Alignment-to-GtkAlign | `e139b1d` |

---

## Phase B: Simple Controls — DONE

| Item | GTK Widget | Commit |
|------|-----------|--------|
| SecureField | GtkPasswordEntry + peek icon | `e139b1d` |
| TextEditor | GtkTextView + GtkScrolledWindow | `e139b1d` |
| ProgressView | GtkProgressBar (indeterminate pulse TODO) | `e139b1d` |
| Stepper | GtkSpinButton with label, range/step | `e139b1d` |
| Label | GtkBox(H) + GtkImage + GtkLabel | `e139b1d` |

---

## Phase C: Lifecycle & Presentation — DONE

| Item | GTK Mechanism | Commit |
|------|-------------|--------|
| `.onAppear()` | "map" signal, rebuild-suppressed | `5716c3c` |
| `.onDisappear()` | "unmap" signal, rebuild vs real | `5716c3c` |
| `.sheet()` | Modal GtkWindow, g_idle_add, DismissAction env | `5716c3c` |
| `.alert()` | Modal dialog, AlertButton array, destructive CSS | `5716c3c` |
| Link | GtkLinkButton | `5716c3c` |

**Not implemented**: ConfirmationDialog (similar to Alert, deferred to future work).

---

## Phase D: Containers & Layout — DONE

| Item | GTK Widget | Commit |
|------|-----------|--------|
| TabView | GtkStack + GtkStackSwitcher, TabBuilder | `1f3d14a` |
| Grid | GtkGrid, auto-wrap + explicit GridRow modes | `1f3d14a` |
| GridRow | MultiChildView, .gridCellColumns() span | `1f3d14a` |
| DisclosureGroup | GtkExpander, Binding<Bool>, notify::expanded | `1f3d14a` |
| Form | GtkBox with 12px spacing, 16px CSS padding | `1f3d14a` |
| Section | Bold Pango header, 11px footer, separator | `1f3d14a` |

**Review fixes**:
- Grid explicit-row mode uses MultiChildView.children instead of Mirror (`1aedbcc`)
- TupleView4-12 rendering via MultiChildView check in gtkRenderView (`1aedbcc`)
- TabBuilder conditional content (buildOptional, buildEither, buildArray) (`1aedbcc`)
- gtkFlattenChildren stops at GridRow boundaries (`cc357d9`)

---

## Phase E: Lazy Collections — DONE

| Item | GTK Widget | Commit |
|------|-----------|--------|
| LazyVStack | GtkListView (vertical), factory pattern | `b7bfde4` |
| LazyHStack | GtkListView (horizontal) | `b7bfde4` |
| LazyVGrid | GtkGridView, GridItem adaptive/fixed/flexible | `b7bfde4` |
| LazyHGrid | GtkGridView (horizontal) | `b7bfde4` |

All use GtkSignalListItemFactory + GtkStringList index model with setup/bind/unbind callbacks.

---

## Phase F: Advanced — DONE

| Item | GTK Mechanism | Commit |
|------|-------------|--------|
| Picker | GtkDropDown (auto) or GtkToggleButton group (segmented) | `f73c218` |
| DatePicker | GtkCalendar, DateComponents, day-selected signal | `f73c218` |
| GeometryReader | GtkBox + map signal + tick callback resize tracking | `f73c218`, `051d16f` |
| Menu | GMenu + GSimpleActionGroup + GtkPopoverMenu, MenuBuilder | `f73c218` |
| `.searchable()` | GtkSearchEntry, search-changed signal | `f73c218` |
| `.toolbar()` | ToolbarProvider, Mirror extraction, header bar integration | `f73c218`, `0e24245` |

**Review fixes**:
- Toolbar integrated into NavigationStack header bar with push/pop widget swap (`0e24245`)
- GeometryReader uses tick callback for live resize (GtkEventControllerResize unavailable) (`051d16f`)
- MenuDivider produces GMenu sections for visible separators (`0e24245`)

---

## Final Impact on Matrix

| Category | Before | After | Coverage |
|----------|--------|-------|----------|
| Views (Core+GTK4) | 21/45 (~47%) | 39/43 (~91%) | +18 views |
| Modifiers (Core+GTK4) | 22/34 (~65%) | 33/35 (~94%) | +11 modifiers |
| Tests | 71 | 118 | +47 tests |

**Not planned (too specialized)**:
- Map — needs external map library
- Canvas — needs full Cairo binding (~140 lines of shims)
- `.task()` — needs async runtime integration
- `.clipShape()` — needs Shape protocol system
- @AppStorage — needs GSettings or file persistence
- @Observable — **DONE** (Swift Observation framework, withObservationTracking)

## Verification

All phases verified:
1. `swift build` — clean
2. `swift test` — 118 tests, all pass
3. Construction tests for all new views/modifiers
