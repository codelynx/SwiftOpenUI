# Examples Reorganization Plan

## Two-Track Design

Examples serve two distinct purposes that require different design trade-offs:

| | **Showcase** | **Parity** |
|---|---|---|
| **Purpose** | "Look what you can build" | "Verify matrix rows visually (GTK4, Win32, Web)" |
| **Audience** | New users, README screenshots | Developers, CI, parity tracking |
| **Style** | Polished, realistic, minimal | Systematic, labeled blocks, exhaustive |
| **Naming** | Short friendly names | `Parity` prefix, CamelCase |

Trying to serve both in one example creates muddled demos that are too scattered to validate coverage and too messy to showcase.

## Directory Layout

```
Examples/
├── Showcase/                    # Polished mini-apps
│   ├── HelloWorld/main.swift    # target: HelloWorld
│   ├── Stopwatch/main.swift     # target: Stopwatch (replaces Counter)
│   ├── ColorMixer/main.swift    # target: ColorMixer
│   ├── Calculator/main.swift    # target: Calculator (future)
│   └── PaintApp/main.swift      # target: PaintApp (future, needs Canvas)
│
├── Parity/                      # Maps to parity matrix sections
│   ├── ViewsBasic/main.swift    # target: ParityViewsBasic
│   ├── ViewsLayout/main.swift   # target: ParityViewsLayout
│   ├── ViewsContainers/main.swift # target: ParityViewsContainers
│   ├── Modifiers/main.swift     # target: ParityModifiers
│   ├── StateData/main.swift     # target: ParityStateData
│   ├── Navigation/main.swift    # target: ParityNavigation
│   ├── Environment/main.swift   # target: ParityEnvironment
│   ├── AppStructure/main.swift  # target: ParityAppStructure
│   ├── Gestures/main.swift      # target: ParityGestures
│   ├── Animation/main.swift     # target: ParityAnimation
│   └── Focus/main.swift         # target: ParityFocus
```

Filesystem path expresses organization. Target name expresses run ergonomics.

```bash
# Showcase — friendly names
swift run HelloWorld
swift run Stopwatch
swift run ColorMixer

# Parity — Parity prefix, tab-completable as a group
swift run ParityViewsBasic
swift run ParityModifiers
swift run ParityStateData
swift run ParityNavigation
```

## Principles

1. **Single source, all platforms (with exceptions)** — every example is one `main.swift` with `#if` import/entry-point boilerplate. **Android exception:** Android uses a flat view defined in `JNIBridge.swift` due to conditional-import conflicts (see `docs/issues/android-package-split-regression.md`). Parity examples target GTK4, Win32, and Web directly; Android parity is verified via its own `AndroidStateDemoView` pattern until the import conflict is resolved.
2. **Always compiles, always runs** — platform-unavailable features show fallback text, never build errors
3. **Showcase tells a story** — each is a small realistic app worth screenshotting
4. **Parity maps to the matrix** — each parity file has a primary owner for its matrix rows
5. **Deterministic screens** — parity examples use fixed data, no randomness, stable for future screenshot diffing
6. **Contract rule** — a matrix row marked Y or ~ must have a corresponding `// MARK:` block in its primary parity owner
7. **Flat @State on root for Android compatibility** — interactive parity examples keep all `@State` on the root view struct. Child section structs are pure (no local @State) so the pattern works if Android support is added later. Showcase examples are exempt — they can use composed child views freely.

## Parity File Structure

Each parity file has a header comment listing the matrix rows it covers, with a link to the matrix rather than duplicating per-backend status:

```swift
// Parity: Views — Basic
// Owner: Text, Button, TextField, Color, Spacer, Divider
// See: docs/architecture/swiftui-parity-matrix.md § Views

// MARK: - Text

struct TextSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Plain text")
            Text("Styled text")
                .font(.headline)
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Button

struct ButtonSection: View {
    // Note: @State lives on the root view, passed down via @Binding
    // to maintain Android compatibility.
    var body: some View { ... }
}

// MARK: - TextField
// ...
```

Per-backend status (Core Y, GTK4 Y, etc.) is **not** duplicated in source comments — the matrix is the single source of truth for backend status. Parity files only reference the matrix section and list owned rows.

Design each screen as a fixed-height, stable layout covering a coherent feature cluster — suitable for screenshot diffing without scrolling.

### Non-Visual Rows

Some matrix rows are not directly visible (e.g., `ProposedViewSize`, `@SceneBuilder`, `@Published`, `ObservableObject`). These are validated indirectly — the parity block uses the feature to produce a visible result, with a comment explaining the dependency:

```swift
// MARK: - @Published / ObservableObject
// Validated by: class drives Text update on button tap

class ItemStore: ObservableObject {
    @Published var count = 0
}

// Root view uses @ObservedObject to observe ItemStore.
// If @Published or ObservableObject is broken, the count Text won't update.
```

The rule is: the `// MARK:` block must exist and must produce an observable effect that breaks if the feature is removed. For protocol/infrastructure rows like `App`, `Scene`, `@SceneBuilder` — every parity example implicitly validates these by compiling and launching. `ParityAppStructure` makes this explicit by exercising `WindowGroup(title:)` and multi-scene patterns.

## Parity ↔ Matrix Mapping

Each matrix row has exactly one **primary owner** (bold). Cross-cutting parity files may exercise the same feature in context, but the primary owner is where the contract rule is enforced.

| Parity Example | Matrix Section | Owned Rows |
|---------------|---------------|------------|
| **ParityViewsBasic** | Views | Text, Button, TextField, Color, Spacer, Divider |
| **ParityViewsLayout** | Views + Layout System | VStack, HStack, ZStack, Group, ForEach, AnyView, EmptyView, Alignment, Edge/Edge.Set, EdgeInsets, ProposedViewSize |
| **ParityViewsContainers** | Views | List, ScrollView, Toggle, Slider, Image (system), Image (file) |
| **ParityNavigation** | Navigation | NavigationStack, NavigationLink, NavigationPath, .navigationTitle(), .navigationDestination(), NavigateAction |
| **ParityModifiers** | Modifiers | .padding(), .frame(), .foregroundColor(), .foregroundStyle(), .background(), .font(), .border(), .opacity(), .offset(), .scaleEffect(), .imageScale(), .modifier() |
| **ParityStateData** | State & Data | @State, @Binding, @ObservedObject, @StateObject, @Published, ObservableObject |
| **ParityEnvironment** | State & Data + Modifiers | @Environment, @EnvironmentObject, .environmentObject(), .environment(), custom EnvironmentKey |
| **ParityAppStructure** | App Structure | App, Scene, WindowGroup, @SceneBuilder, @ViewBuilder |
| **ParityGestures** | Modifiers | .onTapGesture(), .onLongPressGesture(), .onDrag() |
| **ParityAnimation** | Modifiers | .animation(), withAnimation() |
| **ParityFocus** | State & Data + Modifiers | @FocusState, .focused() |

**Cross-cutting note:** Features like `.opacity()`, `.scaleEffect()`, `.offset()` are **owned** by `ParityModifiers`. `ParityAnimation` exercises them in animated context but does not own them. Similarly, `@FocusState` is **owned** by `ParityFocus`, not `ParityStateData`.

## Showcase Examples

### HelloWorld
**Target:** `HelloWorld` (keep as-is)
**Features:** App, WindowGroup, Text, .padding()
The first thing people run.

### Stopwatch
**Target:** `Stopwatch` (replaces Counter)
**Features:** @State, Button, Timer, VStack, HStack, .font(), .foregroundColor(), .padding(), .frame()
Stylish stopwatch with start/stop/reset, elapsed time display, lap times list. Exercises timer-driven state updates and list rendering.

### ColorMixer
**Target:** `ColorMixer` (redesign)
**Features:** Slider, @State, Color, .frame(), .background(), .foregroundColor(), .onTapGesture(), HStack, VStack, Button, Spacer, Text
Redesign as a "Color Studio" — visually presentable like a Photoshop/Figma color picker panel. Large color swatch with hex/RGB readout, RGB sliders with colored labels, preset palette grid (tap to apply), lighter/darker buttons, and color harmony row (complementary + analogous computed swatches). All using existing views — no new APIs needed.

### Calculator (future)
**Target:** `Calculator`
**Reference:** `~/Projects/SwiftLinuxUI/Examples/Calculator/main.swift` (213 lines)
**Features:** Grid/GridRow, Button (17 keys), @State (display, currentValue, pendingOperation), .font(), .foregroundColor(), .background(), .frame(), .padding()
iOS-style calculator — dark theme, orange operator keys, 5×4 grid layout, full arithmetic logic. Exercises Grid (not yet rendered on backends), precise layout, and multi-property @State.

### PaintApp (future)
**Target:** `PaintApp`
**Requires:** Canvas rendering on backends
**Reference:** `~/Projects/SwiftLinuxUI/Examples/PaintApp/main.swift`
**Features:** Canvas, .onDrag(), @State, Color palette, brush size selection
Drawing app — drag to paint strokes, pick colors and brush sizes. Borrowed from SwiftLinuxUI's PaintApp. Depends on Canvas view having backend rendering (currently core-defined, no backend renderers yet).

## Migration Plan

### Phase 1: Restructure directories
1. Create `Examples/Showcase/` and `Examples/Parity/`
2. Move `HelloWorld`, `Counter`, `ColorMixer` → `Examples/Showcase/`
3. Retire `Showcase1`, `Showcase2` (content absorbed into parity examples)

### Phase 2: Create parity examples
4. Build parity examples one section at a time, starting with the most populated matrix sections
5. Absorb existing numbered examples into parity files:
   - `02-TextStyles` → `ParityViewsBasic`
   - `03-Buttons` → `ParityViewsBasic`
   - `04-State` → `ParityStateData`
   - `05-Layout` → `ParityViewsLayout`
   - `BasicInteractive` → `ParityGestures`
   - `FocusTest` → `ParityFocus`
6. Remove absorbed examples after content is migrated

### Phase 3: Wire up
7. Update `Package.swift` targets (add new, remove old)
8. Update `apple/Examples/project.yml` (XcodeGen schemes for all new targets)
9. Update Android example registry in `JNIBridge.swift` if any parity examples are wired to Android
10. Update matrix (`docs/architecture/swiftui-parity-matrix.md`) to reference parity example paths per section
11. Update `CLAUDE.md` examples list
12. Update `docs/guides/running-examples.md`

### Priority Order
1. **ParityViewsBasic** — highest row count, absorbs 2 existing examples
2. **ParityViewsLayout** — most visual, validates backend layout engines
3. **ParityModifiers** — tests modifier stacking and rendering
4. **ParityStateData** — absorbs existing State example
5. **ParityNavigation** — complex multi-screen validation
6. **ParityGestures** — absorbs BasicInteractive
7. **ParityEnvironment** — currently untested in examples
8. **ParityAppStructure** — App/Scene/WindowGroup verification
9. **ParityAnimation** — cross-platform timing differences
10. **ParityViewsContainers** — Phase 3 views (Toggle, Slider, Image, List, ScrollView)
11. **ParityFocus** — absorbs FocusTest

## Package.swift Target Layout

```swift
// Showcase
.executableTarget(name: "HelloWorld", dependencies: [...], path: "Examples/Showcase/HelloWorld"),
.executableTarget(name: "Stopwatch", dependencies: [...], path: "Examples/Showcase/Stopwatch"),
.executableTarget(name: "ColorMixer", dependencies: [...], path: "Examples/Showcase/ColorMixer"),

// Parity
.executableTarget(name: "ParityViewsBasic", dependencies: [...], path: "Examples/Parity/ViewsBasic"),
.executableTarget(name: "ParityViewsLayout", dependencies: [...], path: "Examples/Parity/ViewsLayout"),
.executableTarget(name: "ParityViewsContainers", dependencies: [...], path: "Examples/Parity/ViewsContainers"),
.executableTarget(name: "ParityModifiers", dependencies: [...], path: "Examples/Parity/Modifiers"),
.executableTarget(name: "ParityStateData", dependencies: [...], path: "Examples/Parity/StateData"),
.executableTarget(name: "ParityNavigation", dependencies: [...], path: "Examples/Parity/Navigation"),
.executableTarget(name: "ParityEnvironment", dependencies: [...], path: "Examples/Parity/Environment"),
.executableTarget(name: "ParityAppStructure", dependencies: [...], path: "Examples/Parity/AppStructure"),
.executableTarget(name: "ParityGestures", dependencies: [...], path: "Examples/Parity/Gestures"),
.executableTarget(name: "ParityAnimation", dependencies: [...], path: "Examples/Parity/Animation"),
.executableTarget(name: "ParityFocus", dependencies: [...], path: "Examples/Parity/Focus"),
```

## Android Platform Notes

Android examples currently cannot share `main.swift` with other platforms due to a conditional-import conflict: `#if canImport(SwiftUI) && os(macOS)` evaluates true during Android cross-compilation (which runs on macOS). See `docs/issues/android-package-split-regression.md`.

**Current workaround:** Android uses flat view definitions in `JNIBridge.swift` (e.g., `AndroidStateDemoView`). These are separate from the parity examples but should cover equivalent features.

**Future fix:** When the import conflict is resolved, Android can share the same parity `main.swift` files. Until then, Android parity is tracked separately via its own view definitions and the phase 2 feature matrix (`docs/architecture/phase2-feature-matrix.md`).

## Development Workflow

Examples are developed **macOS-first** as reference implementations, then ported to each backend one at a time.

1. **macOS** — Write and validate using real SwiftUI (`swift run` or Xcode). This is the reference.
2. **Screenshot** — Capture macOS screenshots before moving to backends.
3. **GTK4 (Linux)** — Port rendering, verify visual match.
4. **Win32 (Windows)** — Port rendering, verify visual match.
5. **Web (Wasm)** — Port rendering, verify visual match.
6. **Android** — Port via JNIBridge pattern, verify.

Each step is a separate commit/PR. No long leaps — one platform at a time, one example at a time. Pause and consult on direction at any milestone.
