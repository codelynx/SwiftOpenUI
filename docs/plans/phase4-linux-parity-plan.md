# GTK4 Parity Roadmap: Fill the SwiftUI Matrix

## Context

The swiftui-parity-matrix.md shows GTK4 at ~47% view coverage and ~65% modifier coverage. All missing features have reference implementations in SwiftLinuxUI. This plan organizes them into phases by dependency order and complexity, targeting GTK4 column completion.

## Phase Overview

| Phase | Theme | Items | Complexity | Unlocks |
|-------|-------|-------|-----------|---------|
| A | CSS Modifiers | 4 modifiers | Simple | Visual polish for all views |
| B | Simple Controls | 5 views | Simple | Form-building capability |
| C | Lifecycle & Presentation | 4 modifiers + 2 views | Medium | Sheet/Alert, onAppear/onDisappear |
| D | Containers & Layout | 4 views | Medium | Grid, TabView, Form, DisclosureGroup |
| E | Lazy Collections | 4 views | Medium | LazyVStack, LazyHStack, LazyVGrid, LazyHGrid |
| F | Advanced | 4 views + 2 modifiers | Complex | Menu, GeometryReader, Canvas, searchable, toolbar |

---

## Phase A: CSS Modifiers (simple, no dependencies)

All pure CSS — no new GTK widgets, no signals. Just `applyCSSToWidget()`.

| Item | GTK Mechanism | Reference | Est. Lines |
|------|-------------|-----------|-----------|
| `.cornerRadius()` | `border-radius: Npx` | CornerRadiusModifier.swift | ~25 |
| `.shadow()` | `box-shadow` + margin fallback | ShadowModifier.swift | ~40 |
| `.rotationEffect()` | CSS `transform: rotate(Ndeg)` | RotationModifier.swift | ~30 |
| `.overlay()` | `GtkOverlay` widget | OverlayModifier.swift | ~55 |

**Core types needed**: `Angle` struct (degrees/radians) for rotation. `Shape` enum (circle, capsule, roundedRectangle) if adding `.clipShape()`.

**Files**:
- New: `Modifiers/CornerRadiusModifier.swift`, `Modifiers/ShadowModifier.swift`, `Modifiers/RotationModifier.swift`, `Modifiers/OverlayModifier.swift`
- Edit: `GTKRenderer.swift` (4 extensions)

---

## Phase B: Simple Controls (1 GTK widget each)

All have SwiftLinuxUI reference. Each is a single GTK widget + signal.

| Item | GTK Widget | Signal | Reference | Est. Lines |
|------|-----------|--------|-----------|-----------|
| SecureField | GtkPasswordEntry | "changed" | SecureField.swift | ~40 |
| TextEditor | GtkTextView + GtkScrolledWindow | "changed" on buffer | TextEditor.swift | ~50 |
| ProgressView | GtkProgressBar | none | ProgressBar.swift | ~20 |
| Stepper | GtkSpinButton | "value-changed" | Stepper.swift | ~40 |
| Label | GtkBox(H) + GtkImage + GtkLabel | none | Label.swift | ~30 |

**Depends on**: Image view (done in Phase 3)

**Shims needed**: `gtk_swift_password_entry_set_show_peek_icon`, spin button helpers

**Files**:
- New: `Views/SecureField.swift`, `Views/TextEditor.swift`, `Views/ProgressView.swift`, `Views/Stepper.swift`, `Views/Label.swift`
- Edit: `GTKRenderer.swift` (5 extensions), `shim.h`

---

## Phase C: Lifecycle & Presentation (medium, needs ViewHost awareness)

These interact with the rebuild cycle and window management.

| Item | GTK Mechanism | Key Challenge | Reference | Est. Lines |
|------|-------------|---------------|-----------|-----------|
| `.onAppear()` | "map" signal | Suppress on rebuild (check ViewHost mapped) | LifecycleModifier.swift | ~60 |
| `.onDisappear()` | "unmap" signal | Distinguish rebuild vs real disappear | LifecycleModifier.swift | ~60 |
| `.sheet()` | Modal GtkWindow | Deferred via g_idle_add, DismissAction env | SheetModifier.swift | ~100 |
| `.alert()` | Modal GtkWindow + buttons | Deferred, prevent duplicates | Alert.swift | ~80 |
| Link | GtkLinkButton | none | Link.swift | ~15 |
| ConfirmationDialog | Modal GtkWindow + multiple buttons | Similar to Alert | AlertModifier.swift | ~80 |

**Depends on**: Environment system (done), DismissAction (done)

**Files**:
- New: `Modifiers/LifecycleModifier.swift`, `Modifiers/SheetModifier.swift`, `Modifiers/AlertModifier.swift`, `Views/Link.swift`
- Edit: `GTKRenderer.swift`

---

## Phase D: Containers & Layout (medium, new widget patterns)

| Item | GTK Widget | Key Challenge | Reference | Est. Lines |
|------|-----------|---------------|-----------|-----------|
| TabView | GtkStack + GtkStackSwitcher | Tab builder, transition types | TabView.swift | ~100 |
| Grid | GtkGrid | GridRow, column spans, auto-wrap | Grid.swift | ~120 |
| DisclosureGroup | GtkExpander | "notify::expanded" signal, Binding<Bool> | DisclosureGroup.swift | ~50 |
| Form / Section | GtkBox with CSS padding | Section headers, grouped styling | Form.swift | ~60 |

**Depends on**: Phase A (.cornerRadius for Form styling)

**Shims needed**: `gtk_swift_grid_attach`, `gtk_swift_expander_*`

**Files**:
- New: `Views/TabView.swift`, `Views/Grid.swift`, `Views/DisclosureGroup.swift`, `Views/Form.swift`
- Edit: `GTKRenderer.swift`, `shim.h`

---

## Phase E: Lazy Collections (medium, GTK factory pattern)

All use `GtkSignalListItemFactory` + `GtkStringList` as lightweight index model.

| Item | GTK Widget | Key Challenge | Reference | Est. Lines |
|------|-----------|---------------|-----------|-----------|
| LazyVStack | GtkListView (vertical) | Item factory, bind/unbind signals | LazyVStack.swift | ~80 |
| LazyHStack | GtkListView (horizontal) | Same factory, different orientation | LazyVStack.swift | ~20 (shared) |
| LazyVGrid | GtkGridView (vertical) | Column config (adaptive/fixed) | LazyGrid.swift | ~80 |
| LazyHGrid | GtkGridView (horizontal) | Row config | LazyGrid.swift | ~20 (shared) |

**Depends on**: None (standalone pattern)

**Shims needed**: ~22 shims for GtkListView, GtkGridView, GtkStringList, factory system

**Files**:
- New: `Views/LazyStacks.swift`, `Views/LazyGrids.swift`
- Edit: `GTKRenderer.swift`, `shim.h` (~80 lines of shims)

---

## Phase F: Advanced (complex, specialized GTK subsystems)

| Item | GTK Mechanism | Key Challenge | Reference | Est. Lines |
|------|-------------|---------------|-----------|-----------|
| Menu | GMenu + GSimpleActionGroup + GtkPopoverMenu | Recursive menu building, action naming | Menu.swift | ~150 |
| Picker | GtkDropDown or GtkToggleButton group | Two display styles | Picker.swift | ~100 |
| DatePicker | GtkCalendar | Custom DateComponents type | DatePicker.swift | ~60 |
| GeometryReader | GtkBox + "map" signal | Deferred rendering until dimensions known | GeometryReader.swift | ~80 |
| `.searchable()` | GtkSearchEntry above content | Binding + "search-changed" signal | SearchableModifier.swift | ~50 |
| `.toolbar()` | ToolbarProvider extraction + header bar items | Mirror-based extraction before render | ToolbarModifier.swift | ~80 |

**Depends on**: Phase C (lifecycle signals for GeometryReader), Phase B (Image for Picker icons)

**Not planned (too specialized)**:
- Map — needs external map library
- Canvas — needs full Cairo binding (~140 lines of shims)
- `.task()` — needs async runtime integration
- @AppStorage — needs GSettings or file persistence
- @Observable — needs Swift macro support

---

## Execution Order

```
Phase A (CSS modifiers)     ─────►  can start immediately
Phase B (simple controls)   ─────►  can start immediately
Phase C (lifecycle/present) ─────►  after A (overlay pattern helps sheet)
Phase D (containers)        ─────►  after A (cornerRadius for Form)
Phase E (lazy collections)  ─────►  can start independently
Phase F (advanced)          ─────►  after B + C
```

A and B can run in parallel. C depends lightly on A. D depends lightly on A. E is independent. F comes last.

## Estimated Impact on Matrix

| Phase | Views Added | Modifiers Added | New GTK4 Coverage |
|-------|-----------|----------------|-------------------|
| A | 0 | 4 | Modifiers: 65% → 76% |
| B | 5 | 0 | Views: 47% → 58% |
| C | 2 | 4 | Views: 58% → 62%, Modifiers: 76% → 88% |
| D | 4 | 0 | Views: 62% → 71% |
| E | 4 | 0 | Views: 71% → 80% |
| F | 4 | 2 | Views: 80% → 89%, Modifiers: 88% → 94% |

**Final GTK4 column: ~89% views, ~94% modifiers**

## Verification (per phase)

1. `swift build` — clean
2. `swift test` — all tests pass (add construction tests per phase)
3. Manual demo example per phase
