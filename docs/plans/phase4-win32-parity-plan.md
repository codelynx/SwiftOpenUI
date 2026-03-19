# Phase 4: SwiftUI Parity Implementation Plan

Phased plan to fill the [SwiftUI parity matrix](../architecture/swiftui-parity-matrix.md) for Win32 (and other backends where applicable). Ordered by dependency, complexity, and impact.

## Phase 4A — Easy Wins (native controls) — COMPLETE

Direct mappings to Win32 controls. No new architecture needed.

| # | View/Modifier | Win32 mapping | Status |
|---|--------------|---------------|--------|
| 1 | SecureField | EDIT + `ES_PASSWORD` | Done |
| 2 | TextEditor | EDIT + `ES_MULTILINE \| ES_WANTRETURN` | Done |
| 3 | Stepper | Label + buttons (Binding<Double>) | Done |
| 4 | ProgressView | `msctls_progress32` | Done |
| 5 | Picker | `WC_COMBOBOX` (automatic) / radio buttons (segmented) | Done |
| 6 | Alert | `MessageBoxW` | Done |
| 7 | ConfirmationDialog | `MessageBoxW` Yes/No | Done |
| 8 | Label | STATIC icon + text | Done |
| 9 | Link | Button → `ShellExecuteW` | Done |

## Phase 4B — Lifecycle & Container Modifiers — COMPLETE

| # | Feature | Win32 approach | Status |
|---|---------|---------------|--------|
| 1 | .onAppear() | Deferred via PostMessage | Done |
| 2 | .onDisappear() | WM_NCDESTROY | Done (~) |
| 3 | .overlay() | GtkOverlay-style container | Done |
| 4 | .sheet() | Modal child window + per-presenter SetPropW | Done |
| 5 | Section | VStack with header + divider | Done |
| 6 | Form | VStack + padding | Done |
| 7 | TabView | Button bar + show/hide pages | Done |

## Phase 4C — D2D Visual Effects — COMPLETE

| # | Feature | Win32 approach | Status |
|---|---------|---------------|--------|
| 1 | .cornerRadius() | `SetWindowRgn` + `CreateRoundRectRgn` | Done |
| 2 | .shadow() | Layered GDI shadow with alpha blending | Done |
| 3 | .rotationEffect() | D2D `SetTransform` (D2D-renderable content) | Done |
| 4 | Canvas | D2D DrawingContext (paths, transforms, alpha) | Done (~) |
| 5 | .clipShape() | D2D geometry clip (PushLayer with geometry) | Not implemented |

## Phase 4D — Advanced Layout & Data — MOSTLY COMPLETE

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1 | GeometryReader | Done | Parent rect measurement |
| 2 | LazyVStack / LazyHStack | Done | Non-virtualized (renders all items) |
| 3 | Grid / GridRow / LazyVGrid / LazyHGrid | Done | Column spans via .gridCellColumns() |
| 4 | Menu | Done | Win32 popup menu (TrackPopupMenu) |
| 5 | DisclosureGroup | Done | Toggle + show/hide |
| 6 | .searchable() | Done | GTK: SearchEntry; Win32: EDIT |
| 7 | .toolbar() | Done | Navigation header bar integration |
| 8 | DatePicker | Done | SysDateTimePick32 + binding |
| 9 | .pickerStyle() | Done | .automatic (ComboBox), .segmented (radio buttons) |
| 10 | .task() | Not implemented | Needs Swift async runtime |
| 11 | @AppStorage | Not implemented | Needs persistence layer |

## Final Parity (as of 2026-03-19)

See [swiftui-parity-matrix.md](../architecture/swiftui-parity-matrix.md) for current per-backend counts and detailed feature status.

Remaining Win32 gaps: .clipShape() (needs D2D path geometry), .task() (needs async runtime), @AppStorage (needs persistence).

## Cross-Platform Notes

- **Phase 4A** items are Win32-specific (native controls). GTK4 has its own equivalents. Web/Android would need separate implementations.
- **Phase 4B** lifecycle modifiers (.onAppear/.onDisappear) use core framework types with per-backend hooks.
- **Phase 4C** D2D effects are Win32-specific. GTK4 uses CSS equivalents. Web and Android backends do not yet implement these effects.
- **Phase 4D** features like GeometryReader and Layout protocol need core framework design before any backend work.

## Execution Rules

- Core types (`Sources/SwiftOpenUI/`) defined first, then backend rendering
- Examples in `Examples/` are shared — use `#if os()` only for platform labels, not behavior
- Each view/modifier needs: core type, Win32 extension, at least one test
- Follow existing patterns (see `docs/guides/adding-a-backend.md`)
