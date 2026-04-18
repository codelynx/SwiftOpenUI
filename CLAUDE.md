# SwiftOpenUI

Cross-platform SwiftUI framework — write SwiftUI, run anywhere.

## Project Structure

- `Sources/SwiftOpenUI/` — Core platform-independent library (Views, State, Layout, Modifiers, Environment, Backend protocol)
- `Sources/Backend/GTK4/` — Linux backend (GTK4): CGTK system module, CGTKBridge interop, Rendering
- `Sources/Backend/Win32/` — Windows backend (Win32): CWin32, CWin32Bridge, Rendering + LayoutEngine
- `Sources/Backend/Web/` — Web/Wasm backend (experimental): DOM rendering via JavaScriptKit
- `Examples/Showcase/` — Polished demo apps (HelloWorld, Stopwatch, ColorMixer, Calculator, SimplePaint, LayoutStress)
- `Examples/Parity/` — Matrix-backed coverage examples (11 parity targets)
- `Tests/SwiftOpenUITests/` — Core tests (platform-independent)
- `Tests/BackendTests/` — Platform-specific backend tests
- `docs/` — Architecture, API reference, porting guides, mission
- `configure` — Setup script: installs swiftly, open-source Swift toolchain, Wasm SDK

## Branches

- `main` — clean until v1.0, do not merge to main without explicit instruction
- `develop` — active development, all work happens here
- `experimental/*` — experimental features (e.g. `experimental/web-wasm-poc`)

## Multi-Platform Branch Protocol

- Coordinator creates one pushed core/base branch per batch and declares the exact base commit hash.
- After pushing a core/base branch, coordinator must verify the remote ref explicitly with:
  - `git ls-remote --heads origin <branch>`
  - only send handoff after the remote hash matches the intended local commit
- Every platform handoff must include:
  - branch
  - commit
  - base commit
  - changed files
  - tests run
- Worker first step must be:
  - `git fetch origin`
  - `git switch -C <worker-branch> origin/<base-branch>`
  - `git rev-parse HEAD`
- If the worker sees a different commit hash than the handoff hash, stop and report a stale base immediately.
- Platform branches may edit only backend-owned files and backend tests.
- Platform branches must not update shared truth docs:
  - `docs/api/implementation-tracker/**`
  - `docs/architecture/swiftui-parity-matrix.md`
  - repo status docs such as `CLAUDE.md`
- Once any platform branch from a batch is merged into `develop`, sibling platform branches are stale by default.
- After that point, further platform work must be:
  - rebased onto current `develop`, or
  - delivered as focused cherry-pickable commits
- Use this decision rule:
  - `batch/*` branch: created from the coordinator’s batch base, intended for one merge
  - `fix/*` branch: created from current `develop`, intended for quick merge or cherry-pick
- Coordinator owns:
  - core API design
  - merge conflict resolution
  - tracker regeneration
  - parity/doc truth
- If a platform report arrives after the batch is already integrated, coordinator should prefer cherry-picking the focused fix commit instead of merging the stale platform branch head.

## Build & Test

```bash
# macOS (uses real SwiftUI for examples)
swift build
swift test                   # ~628 macOS / ~707 Linux

# WebAssembly (requires open-source Swift toolchain, not Xcode's)
source ~/.swiftly/env.sh     # activate swiftly-managed toolchain
swift build --swift-sdk swift-6.2.4-RELEASE_wasm

# Run examples on macOS
swift run HelloWorld
swift run Stopwatch
swift run ColorMixer
swift run SimplePaint
swift run LayoutStress
swift run ParityViewsBasic

# Run in browser (Wasm)
swift package --swift-sdk swift-6.2.4-RELEASE_wasm js --product HelloWorld
npx serve .build/plugins/PackageToJS/outputs/Package

# Package an app as a .app bundle
swift package create-bundle HelloWorld --allow-writing-to-package-directory
# Output: .build/bundles/HelloWorld.app

# Full setup from scratch (macOS only)
./configure
```

## Key Design Decisions

- **Core is platform-independent**: `Sources/SwiftOpenUI/` has zero platform imports. All GTK/Win32/Web code lives in `Sources/Backend/`.
- **Protocol-based rendering**: Backends extend core views with `GTKRenderable` / `WebRenderable` / etc. The renderer checks `if let renderable = view as? Renderable` before falling back to body recursion.
- **On macOS, examples use real SwiftUI**: `#if os(macOS) import SwiftUI` — validates API compatibility.
- **Manifest conditionals check HOST, not target**: `#if os()` and `#if arch()` in Package.swift evaluate the build machine. Example deps always include SwiftOpenUI. Web backend + JavaScriptKit are gated to `#if os(macOS)` (Wasm cross-compilation always happens from macOS). GTK4 and Win32 backends are gated to their native OS.
- **Namespace conflicts**: On macOS, `ObservableObject` and `Published` clash with Combine. Tests qualify as `SwiftOpenUI.ObservableObject` and `@SwiftOpenUI.Published`. See `docs/issues/observable-namespace-conflict.md`.
- **State management** (@State, @Binding, @ObservedObject, @Published, @StateObject, @EnvironmentObject, @FocusState, @Observable) is fully platform-independent with thread-safe storage.
- **Environment TLS**: pthread on Linux/macOS, TlsAlloc on Windows, simple global on Wasm (single-threaded).
- **Scene rendering is recursive**: `renderScene` walks `Scene.body` until it hits a terminal `WindowGroup` or `Window`.
- **App bundle dev mode**: When running via `swift run`, `AppBundle.main` walks up from the executable looking for `Package.swift` + `Resources/`. Place resources in `Resources/` at the package root for development-time resource lookup without a `.app` bundle.

## Architecture Layers

```
┌─────────────────────────────────────────────────────┐
│  Examples (import SwiftUI on macOS, SwiftOpenUI else)│
├─────────────────────────────────────────────────────┤
│  SwiftOpenUI Core                                   │
│  View, State, Layout, Modifiers, Environment        │
├──────────────┬───────────────┬──────────────────────┤
│  BackendGTK4 │  BackendWin32 │  BackendWeb          │
│  GTKRenderer │  WinRenderer  │  WebRenderer         │
│  GTKViewHost │  Win32ViewHost│  WebViewHost         │
├──────────────┼───────────────┼──────────────────────┤
│  CGTK        │  CWin32       │  JavaScriptKit       │
│  CGTKBridge  │  CWin32Bridge │  (DOM API)           │
└──────────────┴───────────────┴──────────────────────┘
```

## Current Views & Modifiers

### Views (Sources/SwiftOpenUI/Views/)
Text, Button, TextField, SecureField, TextEditor, Toggle, Slider, Stepper, Picker, DatePicker, ProgressView, Label, Link, ScrollView, List, Image, VStack, HStack, ZStack, Spacer, Divider, Color, Group, ForEach, AnyView, EmptyView, TabView, Grid, GridRow, Form, Section, DisclosureGroup, OutlineGroup, LazyVStack, LazyHStack, LazyVGrid, LazyHGrid, Menu, Canvas, GeometryReader, ViewThatFits, NavigationSplitView, ConfirmationDialog, Path (with StrokeStyle, Shading), Circle, Rectangle, RoundedRectangle, Capsule, Ellipse (Shape protocol with .fill()/.stroke()), ScrollViewReader, LinearGradient, RadialGradient

### Scenes (Sources/SwiftOpenUI/App/)
WindowGroup, Window (GTK/Win32: functional with OpenWindowAction; Web: core type only), Commands (CommandGroup, CommandMenuItem — GTK/Win32: native menu bar with observation-driven enable/disable; Web: not yet)

### Navigation (Sources/SwiftOpenUI/Navigation/)
NavigationStack, NavigationLink, NavigationSplitView, NavigationPath, .navigationTitle(), .navigationDestination(for:), NavigateAction (environment)

### Modifiers (Sources/SwiftOpenUI/Modifiers/)
.padding(), .frame(), .foregroundColor(), .foregroundStyle(), .background(), .font(), .border(), .opacity(), .offset(), .scaleEffect(), .animation(), .imageScale(), .onTapGesture(), .onLongPressGesture(), .onDrag(), .disabled(), .environmentObject(), .environment(), withAnimation(), .cornerRadius(), .shadow(), .rotationEffect(), .overlay(), .sheet(), .alert(), .confirmationDialog(), .onAppear(), .onDisappear(), .searchable(), .toolbar(), .gridCellColumns(), .pickerStyle(), .navigationSplitViewColumnWidth(), .ignoresSafeArea(), .safeAreaInset(), .lineLimit(), .truncationMode(), .lineSpacing(), .multilineTextAlignment(), .clipShape(), .clipped(), .hidden(), .blur(), .buttonStyle(), .toggleStyle(), .textFieldStyle(), .onChange(), .contextMenu(), .position(), .layoutPriority(), .fixedSize(), .popover(), .id(), .bold(), .italic(), .fontWeight(), .underline(), .strikethrough(), .textCase(), .aspectRatio(), .scaledToFit(), .scaledToFill(), .fullScreenCover(), .tag(), .onSubmit(), .keyboardShortcut(), .focusedValue(), custom ViewModifier

### State (Sources/SwiftOpenUI/State/)
@State, @Binding, @ObservedObject, @StateObject, @EnvironmentObject, @Published, @FocusState, @FocusedValue (active-window scoped; true focus-chain semantics deferred)

## Adding a New View

1. Define the view struct in `Sources/SwiftOpenUI/Views/` — pure data, `Body = Never`
2. Add backend rendering in each backend's Renderer as `extension MyView: PlatformRenderable`
3. Add tests in `Tests/SwiftOpenUITests/`
4. See `docs/guides/adding-a-backend.md` for the full pattern

## Adding a New Modifier

1. Define the modifier view struct in `Sources/SwiftOpenUI/Modifiers/` with `Body = Never`
2. Add the `extension View` convenience method
3. Add backend rendering extensions in each Renderer
4. Add tests

## Examples

- Showcase: HelloWorld, Stopwatch, ColorMixer, Calculator, SimplePaint, LayoutStress (in `Examples/Showcase/`)
- Parity: ParityViewsBasic, ParityViewsLayout, ParityViewsContainers, ParityModifiers, ParityStateData, ParityNavigation, ParityEnvironment, ParityGestures, ParityAnimation, ParityFocus, ParityAppStructure (in `Examples/Parity/`)
- Plan: `docs/guides/examples-plan.md` — two-track Showcase + Parity design
- **Rules**: single `main.swift` per example, compiles and runs on all platforms (Android exception: uses flat views in JNIBridge.swift due to import conflict — see `docs/guides/examples-plan.md`), platform limitations labeled inline with fallback text (never build errors)
- Import boilerplate: `#if os(macOS) import SwiftUI #else import SwiftOpenUI + backend imports #endif`
- Entry point: `#if os(macOS) App.main() #elseif canImport(BackendGTK4) GTK4Backend().run() ...`

## Key Documentation

| Doc | Purpose |
|-----|---------|
| `docs/guides/getting-started.md` | Setup, build, run on all platforms |
| `docs/guides/adding-a-backend.md` | How to implement a new backend |
| `docs/guides/examples-plan.md` | Examples reorganization plan |
| `docs/guides/web-setup.md` | Web/Wasm build, Vite, screenshots, DOM mapping |
| `docs/guides/android-setup.md` | Android cross-compilation setup |
| `docs/architecture/rendering-backends.md` | Backend architecture, ViewHost patterns |
| `docs/architecture/gtk4-animation-pipeline.md` | GTK4 animation: CSS transitions, transform composition, descriptors |
| `docs/architecture/web-animation-two-phase-rebuild.md` | Web animation: two-phase DOM rebuild, marker-based pairing, token lifecycle |
| `docs/architecture/android-backend-design.md` | Android backend design (batched JNI diffs) |
| `docs/porting/platform-notes.md` | Platform quirks: macOS, Linux, Windows, Web, Android |
| `docs/issues/observable-namespace-conflict.md` | ObservableObject/Published clash on macOS |
| `docs/plans/simplepaint-example.md` | SimplePaint example design and scope |
| `docs/proposals/unified-canvas-api.md` | Unified Canvas API proposal (Path, Shading, StrokeStyle) |
| `docs/architecture/app-bundle-format.md` | Cross-platform .app bundle format spec |
| `docs/guides/app-bundle-packaging.md` | App bundle packaging guide + SPM plugin usage |

## Reference Projects

- `~/Projects/SwiftLinuxUI` — POC for Linux (GTK4), 150 commits, v0.28.0
- `~/Projects/SwiftWindowsUI` — POC for Windows (Win32/D2D), 81 source files
- These are references only — SwiftOpenUI has its own architecture
