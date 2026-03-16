# SwiftOpenUI

Cross-platform SwiftUI framework — write SwiftUI, run anywhere.

## Project Structure

- `Sources/SwiftOpenUI/` — Core platform-independent library (Views, State, Layout, Modifiers, Environment, Backend protocol)
- `Sources/Backend/GTK4/` — Linux backend (GTK4): CGTK system module, CGTKBridge interop, Rendering
- `Sources/Backend/Win32/` — Windows backend (Win32): CWin32, CWin32Bridge, Rendering + LayoutEngine
- `Sources/Backend/Web/` — Web/Wasm backend (experimental): DOM rendering via JavaScriptKit
- `Examples/` — Executable examples (`swift run HelloWorld`, `swift run Counter`, etc.)
- `Tests/SwiftOpenUITests/` — Core tests (platform-independent, 60 tests)
- `Tests/BackendTests/` — Platform-specific backend tests
- `docs/` — Architecture, API reference, porting guides, mission
- `configure` — Setup script: installs swiftly, open-source Swift toolchain, Wasm SDK

## Branches

- `main` — clean until v1.0, do not merge to main without explicit instruction
- `develop` — active development, all work happens here
- `experimental/*` — experimental features (e.g. `experimental/web-wasm-poc`)

## Build & Test

```bash
# macOS (uses real SwiftUI for examples)
swift build
swift test                   # 60 tests

# WebAssembly (requires open-source Swift toolchain, not Xcode's)
source ~/.swiftly/env.sh     # activate swiftly-managed toolchain
swift build --swift-sdk swift-6.2.4-RELEASE_wasm

# Run examples on macOS
swift run HelloWorld
swift run Counter
swift run Showcase1
swift run Showcase2

# Run in browser (Wasm)
swift package --swift-sdk swift-6.2.4-RELEASE_wasm js --product HelloWorld
npx serve .build/plugins/PackageToJS/outputs/Package

# Full setup from scratch (macOS only)
./configure
```

## Key Design Decisions

- **Core is platform-independent**: `Sources/SwiftOpenUI/` has zero platform imports. All GTK/Win32/Web code lives in `Sources/Backend/`.
- **Protocol-based rendering**: Backends extend core views with `GTKRenderable` / `WebRenderable` / etc. The renderer checks `if let renderable = view as? Renderable` before falling back to body recursion.
- **On macOS, examples use real SwiftUI**: `#if os(macOS) import SwiftUI` — validates API compatibility.
- **Manifest conditionals check HOST, not target**: `#if os()` and `#if arch()` in Package.swift evaluate the build machine. Example deps always include SwiftOpenUI; Web backend + JavaScriptKit are declared unconditionally to support cross-compilation from macOS to Wasm.
- **Namespace conflicts**: On macOS, `ObservableObject` and `Published` clash with Combine. Tests qualify as `SwiftOpenUI.ObservableObject` and `@SwiftOpenUI.Published`. See `docs/issues/observable-namespace-conflict.md`.
- **State management** (@State, @Binding, @ObservedObject, @Published, @StateObject, @EnvironmentObject, @FocusState) is fully platform-independent with thread-safe storage.
- **Environment TLS**: pthread on Linux/macOS, TlsAlloc on Windows, simple global on Wasm (single-threaded).
- **Scene rendering is recursive**: `renderScene` walks `Scene.body` until it hits a terminal `WindowGroup`.

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

## Adding a New View

1. Define the view struct in `Sources/SwiftOpenUI/Views/` — pure data, `Body = Never`
2. Add backend rendering in each backend's Renderer as `extension MyView: PlatformRenderable`
3. Add tests in `Tests/SwiftOpenUITests/`

## Adding a New Modifier

1. Define the modifier view struct in `Sources/SwiftOpenUI/Modifiers/` with `Body = Never`
2. Add the `extension View` convenience method
3. Add backend rendering extensions in each Renderer
4. Add tests

## Reference Projects

- `~/Projects/SwiftLinuxUI` — POC for Linux (GTK4), 150 commits, v0.28.0
- `~/Projects/SwiftWindowsUI` — POC for Windows (Win32/D2D), 81 source files
- These are references only — SwiftOpenUI has its own architecture
