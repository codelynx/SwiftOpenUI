# Phase 4: SwiftUI Parity Implementation Plan

Phased plan to fill the [SwiftUI parity matrix](../architecture/swiftui-parity-matrix.md) for Win32 (and other backends where applicable). Ordered by dependency, complexity, and impact.

## Phase 4A — Easy Wins (native controls)

Direct mappings to Win32 controls. No new architecture needed. Follow existing TextField/Slider/Toggle patterns.

| # | View/Modifier | Win32 mapping | Complexity | Dependencies |
|---|--------------|---------------|------------|-------------|
| 1 | SecureField | EDIT + `ES_PASSWORD` | Easy | TextField pattern |
| 2 | TextEditor | EDIT + `ES_MULTILINE \| ES_WANTRETURN` | Easy | TextField pattern |
| 3 | Stepper | Up-Down control (`UPDOWN_CLASS`) + buddy EDIT | Easy | Binding pattern |
| 4 | ProgressView | `PROGRESS_CLASS` | Easy | No binding |
| 5 | Picker | `WC_COMBOBOX` | Medium | Selection binding |
| 6 | Alert | `MessageBoxW` | Easy | Callback/dismiss |
| 7 | ConfirmationDialog | `MessageBoxW` Yes/No | Easy | Same as Alert |
| 8 | Label | STATIC icon + text (HStack pattern) | Easy | Image + Text |
| 9 | Link | Button → `ShellExecuteW` to open URL | Easy | URL string |

**Estimated effort:** 1–2 weeks
**Parity impact:** Views 21→30 (47%→67%), Modifiers +2

## Phase 4B — Lifecycle & Container Modifiers

Core framework types + per-backend hooks.

| # | Feature | Win32 approach | Complexity | Dependencies |
|---|---------|---------------|------------|-------------|
| 1 | .onAppear() | Fire on first WM_SHOWWINDOW or ViewHost add | Medium | Core modifier type |
| 2 | .onDisappear() | Fire on WM_NCDESTROY or ViewHost remove | Medium | Core modifier type |
| 3 | .overlay() | ZStack-like container, child on top | Medium | ZStack pattern |
| 4 | .sheet() | Modal child window or DialogBox | Medium | Core modifier + dismiss |
| 5 | Section | VStack with header Text + Divider | Easy | Core type |
| 6 | Form | VStack with Section styling | Easy | Section |
| 7 | TabView | Show/hide page HWNDs + tab bar buttons | Medium | Navigation pattern |

**Estimated effort:** 1 week
**Parity impact:** Views +3, Modifiers +5

## Phase 4C — D2D Visual Effects

D2D surface rendering (infrastructure already exists from opacity/scale work).

| # | Feature | D2D approach | Complexity | Dependencies |
|---|---------|-------------|------------|-------------|
| 1 | .cornerRadius() | `FillRoundedRectangle` clipping | Medium | D2DSurface |
| 2 | .shadow() | Offset filled rect with Gaussian blur (or solid approximation) | Medium | D2DSurface |
| 3 | .rotationEffect() | `SetTransform` rotation matrix | Medium | d2d1_shim.h addition |
| 4 | Canvas | D2D drawing area with user draw callback | Medium | D2DSurface |
| 5 | .clipShape() | D2D geometry clip (PushLayer with geometry) | Hard | D2D path geometry shim |

**Estimated effort:** 1 week
**Parity impact:** Modifiers +4, Views +1

## Phase 4D — Advanced Layout & Data

Architecturally complex or depend on features not yet designed.

| # | Feature | Complexity | Notes |
|---|---------|------------|-------|
| 1 | GeometryReader | Hard | Layout introspection callback |
| 2 | LazyVStack / LazyHStack | Hard | Virtualized scrolling, view recycling |
| 3 | Grid / LazyVGrid / LazyHGrid | Hard | Grid layout engine |
| 4 | Menu | Medium | Win32 popup menu (`TrackPopupMenu`) |
| 5 | DisclosureGroup | Medium | Collapsible container with animation |
| 6 | .searchable() | Hard | Search bar + content filtering |
| 7 | .toolbar() | Medium | Win32 toolbar/rebar control |
| 8 | .task() | Hard | Swift concurrency / async integration |
| 9 | @AppStorage | Medium | Win32 Registry or file-based UserDefaults |
| 10 | @Observable | Hard | Swift 5.9 macro-based observation |

**Estimated effort:** Ongoing
**Parity impact:** Remaining views + advanced modifiers

## Cumulative Parity Projection

| After Phase | Views | Modifiers | Total Features |
|-------------|-------|-----------|---------------|
| Current (Phase 3) | 21/45 (47%) | 22/34 (65%) | 43/79 (54%) |
| After 4A | 30/45 (67%) | 24/34 (71%) | 54/79 (68%) |
| After 4B | 33/45 (73%) | 29/34 (85%) | 62/79 (78%) |
| After 4C | 34/45 (76%) | 33/34 (97%) | 67/79 (85%) |
| After 4D | 45/45 (100%) | 34/34 (100%) | 79/79 (100%) |

## Cross-Platform Notes

- **Phase 4A** items are mostly Win32-specific (native controls). GTK4 equivalents exist for most. Web/Android would need separate implementations.
- **Phase 4B** lifecycle modifiers (.onAppear/.onDisappear) need core framework types that all backends implement.
- **Phase 4C** D2D effects are Win32-specific. GTK4 uses CSS equivalents. Web uses CSS. Android uses Compose Modifier.
- **Phase 4D** features like GeometryReader and Layout protocol need core framework design before any backend work.

## Execution Rules

- Core types (`Sources/SwiftOpenUI/`) defined first, then backend rendering
- Examples in `Examples/` are shared — use `#if os()` only for platform labels, not behavior
- Each view/modifier needs: core type, Win32 extension, at least one test
- Follow existing patterns (see `docs/guides/adding-a-backend.md`)
