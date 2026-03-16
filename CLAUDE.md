# SwiftOpenUI

Cross-platform SwiftUI framework — write SwiftUI, run anywhere.

## Project Structure

- `Sources/SwiftOpenUI/` — Core platform-independent library (Views, State, Layout, Modifiers, Environment, Backend protocol)
- `Sources/Backend/GTK4/` — Linux backend (GTK4): CGTK system module, CGTKBridge interop, Rendering
- `Sources/Backend/Win32/` — Windows backend (Win32/Direct2D) — placeholder, not yet implemented
- `Examples/` — Executable examples (`swift run HelloWorld`, `swift run Showcase1`, etc.)
- `Tests/SwiftOpenUITests/` — Core tests (platform-independent, 60 tests)
- `Tests/BackendTests/` — Platform-specific backend tests
- `docs/` — Architecture, API reference, porting guides, mission

## Branches

- `main` — clean until v1.0, do not merge to main without explicit instruction
- `develop` — active development, all work happens here

## Build & Test

```bash
swift build              # builds core + GTK4 backend + examples (Linux)
swift test               # runs 60 platform-independent tests
swift run HelloWorld     # launches GTK window on Linux, SwiftUI on macOS
swift run Counter        # reactive counter with @State
swift run Showcase1      # text, buttons, state, font, color
swift run Showcase2      # layout with HStack, ForEach, ZStack, frame
```

## Key Design Decisions

- **Core is platform-independent**: `Sources/SwiftOpenUI/` has zero platform imports. All GTK/Win32 code lives in `Sources/Backend/`.
- **Protocol-based rendering**: Backends extend core views with `GTKRenderable` (or `Win32Renderable`). The renderer checks `if let renderable = view as? GTKRenderable` before falling back to body recursion.
- **On macOS, examples use real SwiftUI**: `#if os(macOS) import SwiftUI` — validates API compatibility.
- **Namespace conflicts**: On macOS, `ObservableObject` and `Published` clash with Combine. Tests qualify as `SwiftOpenUI.ObservableObject` / `SwiftOpenUI.Published`. See `docs/issues/observable-namespace-conflict.md`.
- **State management** (@State, @Binding, @ObservedObject, @Published, @StateObject, @EnvironmentObject, @FocusState) is fully platform-independent with thread-safe storage.
- **CSS provider lifecycle**: GTK CSS providers are attached to widgets and auto-removed on destroy. Uses a single fixed GObject data key per widget to avoid quark leaks.
- **Scene rendering is recursive**: `gtkRenderScene` walks `Scene.body` until it hits a terminal `WindowGroup`, so custom Scene wrappers work.

## Architecture Layers

```
┌─────────────────────────────────────────┐
│  Examples (import SwiftOpenUI)          │
├─────────────────────────────────────────┤
│  SwiftOpenUI Core                       │
│  View, State, Layout, Modifiers, Env    │
├──────────────┬──────────────────────────┤
│  BackendGTK4 │  BackendWin32 (planned)  │
│  GTKRenderer │  Win32Renderer           │
│  GTKViewHost │  Win32ViewHost           │
├──────────────┼──────────────────────────┤
│  CGTK + CGTKBridge │  CWin32 (planned)  │
└──────────────┴──────────────────────────┘
```

## Adding a New View

1. Define the view struct in `Sources/SwiftOpenUI/Views/` — pure data, `Body = Never`
2. Add GTK rendering in `Sources/Backend/GTK4/Rendering/GTKRenderer.swift` as an `extension MyView: GTKRenderable`
3. Add tests in `Tests/SwiftOpenUITests/`

## Adding a New Modifier

1. Define the modifier view struct in `Sources/SwiftOpenUI/Modifiers/` with `Body = Never`
2. Add the `extension View` convenience method
3. Add GTK rendering extension in `GTKRenderer.swift`
4. Add tests

## Reference Projects

- `~/Projects/SwiftLinuxUI` — POC for Linux (GTK4), 150 commits, v0.28.0
- `~/Projects/SwiftWindowsUI` — POC for Windows (Win32/D2D), 81 source files
- These are references only — SwiftOpenUI has its own architecture
