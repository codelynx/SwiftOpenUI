# Roadmap

_Last reviewed: 2026-10-16 against `develop` @ `9c5bbfb`._

## Completed

- Core framework: View, State, Binding, ObservedObject, StateObject, EnvironmentObject, Environment
- ViewBuilder (`buildPartialBlock` + `ViewList` accumulation, no fixed child-count ceiling), App/Scene/WindowGroup
- Views: Text, Button, TextField, VStack, HStack, ZStack, Spacer, Divider, Color, Group, ForEach, AnyView
- Modifiers: padding, frame, foregroundColor, foregroundStyle, background, font, border
- GTK4 backend (Linux) — full rendering + reactive rebuilds + focus preservation + navigation + gestures + animation (CSS transitions)
- GTK4: Navigation — NavigationStack, NavigationLink, NavigationPath, .navigationTitle(), .navigationDestination(for:)
- GTK4: Gestures — .onTapGesture(), .onLongPressGesture(), .onDrag(minimumDistance:)
- GTK4: Animation — withAnimation(), .animation(), .opacity(), .offset(), .scaleEffect()
- GTK4+Win32: Toggle, Slider, ScrollView, List, Image (+ .imageScale())
- Win32 backend (Windows) — full rendering + layout engine + reactive rebuilds
- Win32: Navigation — NavigationStack, NavigationLink, NavigationPath, .navigationTitle(), .navigationDestination(for:)
- Win32: Gestures — .onTapGesture(), .onLongPressGesture(), .onDrag() with recursive subclassing
- Win32: Animation — withAnimation(), .animation(), .opacity(), .scaleEffect() via D2D surface + SetTimer 60fps
- Win32: Phase 4 parity — SecureField, TextEditor, Stepper, ProgressView, Picker, Label, Link, TabView, Grid, GridRow, Canvas, Menu, DisclosureGroup, DatePicker, GeometryReader, LazyStacks, LazyGrids, Form, Section
- Win32: Modifiers — .cornerRadius() (SetWindowRgn), .shadow() (layered alpha), .rotationEffect() (D2D SetTransform), .pickerStyle() (segmented radio buttons), .gridCellColumns(), .searchable(), .toolbar(), .sheet(), .alert(), .overlay(), .onAppear(), .onDisappear()
- macOS support — examples use real SwiftUI via conditional compilation
- Web/Wasm backend (experimental) — DOM rendering via JavaScriptKit, verified in browser
- `./configure` script — automated toolchain + Wasm SDK setup
- GTK4+Win32: `.keyboardShortcut()` — KeyEquivalent, EventModifiers, window-scoped dispatch (M1)
- GTK4+Win32: `Commands` + `@FocusedValue` — native menu bar with observation-driven enable/disable (M2.1)
- GTK4+Win32: `.dropDestination(for: URL.self)` — drag-and-drop from OS file manager (GTK4: GtkDropTarget; Win32: OLE IDropTarget) (M3)
- GTK4: SwiftUI-parity visual polish — HStack/VStack default spacing, `Text.lineLimit(1)` hexpand in flex layouts, `.borderedProminent` filled+disabled button style, `RoundedRectangle.strokeBorder(style: StrokeStyle(dash:))` for dashed overlays (M-Visual-1)
- GTK4: bundled Material Symbols font for non-macOS icon rendering — `SwiftOpenUISymbols` target ships a ~1.7 MB static Material Symbols Rounded Regular; process-local FontConfig registration at backend startup; zero bundle weight on macOS (M-Symbols-1, packaging only; SF-to-Material name compatibility tracked as follow-up milestones — see `docs/architecture/icon-symbols.md`)
- Logical-coordinate contract — every dimension in the core API is a logical point, never a device pixel; `docs/architecture/logical-coordinates.md` is the normative doc (RFC #16 D7)
- Win32: points→pixels at a single chokepoint — API geometry scaled from logical points (D3a), hard-coded control constants scaled from points (D3b), DPI-scaled text measurement, D2D rendering, symbol glyph boxes, navigation header, window defaults, and dropdown chevron; verified by 150% captures under `docs/evidence/dpi/`
- Win32: visual-parity run after the DPI merges — Segoe UI body font for unstyled `Text` and text inputs, automatic window grows to fit content, outer `.foregroundColor()` reaches text through backgrounds, leading-aligned `List` rows, D2D views clear to the inherited background, finite `maxWidth`/`maxHeight` frames grow to their max; screenshots refreshed
- Layout parity suite — 53 scenarios comparing GTK4 and Win32 against recorded macOS SwiftUI fixtures (`Tests/LayoutParityTests/`)
- `.task()` — fires once per view identity, composed over `.onAppear()` plus nested `@State` (GTK4 pilot; see gaps below)
- Window sizing API — `.defaultWindowSize()`, `.windowSizeConstraints()`, `.windowSizing()`, `.windowResizability()`, `.windowResizeBehavior()`
- `Image` sources — `Image(resource:)` for bundle-relative files and `Image(decoded:width:height:format:)` for in-memory pixel buffers; SimplePaint ships generated PNG tool icons through the former
- Cosmetic modifiers — `.textSelection()`, `.monospacedDigit()` (per-backend behavior in the parity matrix)

## Next

### Views & Modifiers — Completed (Phase 3 & 4)
- ~~.clipShape()~~ — done
- ~~.clipped()~~ — done
- ~~.hidden(), .blur()~~ — done (blur: Win32 pass-through)
- ~~lineLimit, truncationMode, lineSpacing, multilineTextAlignment~~ — done
- ~~Circle, Rectangle, RoundedRectangle, Capsule, Ellipse~~ — done (Shape protocol + .fill()/.stroke())
- ~~.buttonStyle(), .toggleStyle(), .textFieldStyle()~~ — done (environment-based enums)
- ~~.onChange()~~ — done
- ~~.contextMenu()~~ — done
- ~~.popover()~~ — done
- ~~.position(), .layoutPriority(), .fixedSize()~~ — done (layoutPriority API only, engine deferred)
- ~~ScrollViewReader, .id(), ScrollViewProxy~~ — done

- ~~.fullScreenCover()~~ — done (GTK: fullscreen modal; Win32: WS_POPUP + WS_EX_TOPMOST; Web: fixed overlay)
- ~~.bold(), .italic(), .fontWeight(), .underline(), .strikethrough(), .textCase()~~ — done
- ~~LinearGradient, RadialGradient~~ — done (Win32: solid first-stop approximation)
- ~~.aspectRatio(), .scaledToFit(), .scaledToFill()~~ — done
- ~~.tag()~~ — done (thread-local propagation for selection controls)
- ~~.onSubmit()~~ — done (environment-based; TextField + SecureField wired on all platforms)

### Views & Modifiers — Remaining
- `.task()` gaps: does not cancel when the view disappears, and re-fires on parent rebuilds on Win32/Web (see cross-backend gaps below)
- Canvas: bezier/quadratic curves and rotate/translate transforms — `GraphicsContext` has no transform API yet. Stroke styles (line caps, joins, dash) are done on all four backends via `StrokeStyle`
- `@AppStorage`, `@SceneStorage` — not started

### Logical coordinates & DPI — in progress
- D4: Win32 re-layout on `WM_DPICHANGED` for dynamic scale changes — PR #39, issue #18
- D5: Win32 150%/200% empirical capture verification — issue #19
- D6: DPI capture tooling and reference captures under version control — issue #20; `screenshots/capture-windows.ps1` and `docs/evidence/dpi/` have landed, so this may be closeable
- D8: confirm GTK4 fractional (150%) scaling — issue #21; no GTK4 DPI work has landed yet
- RFC #16 itself (`docs/proposals/dpi-scaling.md`, `docs/plans/dpi-scaling-breakdown.md`) is still unmerged, so the links to it from `logical-coordinates.md` do not resolve on `develop`

### Cross-backend parity gaps
- Win32 and Web do not reconcile a nested view's `@State` across a parent rebuild; GTK4 does, via positional child-state reconciliation. This is what makes `.task()` re-fire on those backends. RFC in PR #37
- SimplePaint's generated tool icons are unverified on Win32 and Web; the opaque-white icon backgrounds exist because the Win32 file-image path uses `StretchBlt(SRCCOPY)` and does not alpha-blend

### State & Data
- Resolve ObservableObject/Published namespace conflict on macOS (see `docs/issues/`)

### Backends
- Web: release build optimization (reduce from 59MB debug)
- Web: `./web/run.sh <Example>` builds and serves one example (resources copied beside the JS); hot reload of a Wasm rebuild is still manual
- Android: core library cross-compiles; Phase 1 core views (`Text`, `Button`, `TextField`, `Toggle`, `Slider`, `List`, `ScrollView`, `VStack`, `HStack`, `ZStack`), **Shapes**, and **Presentations** (`.sheet`, `.alert`) implemented and verified.
  - **Alignment Backlog:**
    - **Precision Layout:** Infrastructure complete (absolute child positioning). Pending a real Kotlin → Swift measurement bridge to replace current intrinsic estimations.
    - **Iconography:** Bridge `Image(systemName:)` to Android Material Icons or the shared symbols font.
    - **Automated Parity:** Integrate with `capture-android.sh` for standard layout parity testing.

### Infrastructure
- CI: GitHub Actions for macOS + Linux + Wasm builds — nothing runs on PRs today; merges rely on the contributor's local build and test run
- CI: automated test runs on all platforms
- Release build pipeline for Wasm (wasm-opt, strip)
