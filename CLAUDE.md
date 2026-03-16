# SwiftOpenUI

Cross-platform SwiftUI framework — write SwiftUI, run anywhere.

## Project Structure

- `Sources/SwiftOpenUI/` — Core platform-independent library (Views, State, Layout, Modifiers, Environment, Backend protocol)
- `Sources/Backend/GTK4/` — Linux backend (GTK4)
- `Sources/Backend/Win32/` — Windows backend (Win32/Direct2D)
- `Examples/` — Executable examples (`swift run HelloWorld`, `swift run Showcase1`, etc.)
- `Tests/SwiftOpenUITests/` — Core tests (platform-independent)
- `Tests/BackendTests/` — Platform-specific backend tests
- `docs/` — Architecture, API reference, porting guides, mission

## Branches

- `main` — clean until v1.0
- `develop` — active development

## Key Design Decisions

- Examples only `import SwiftOpenUI` — Package.swift conditionally links the right backend per platform
- State management is fully platform-independent
- `RenderBackend` protocol in `Sources/SwiftOpenUI/Backend/` defines the abstraction layer
- Platform backends implement this protocol with native toolkit calls

## Reference Projects

- `~/Projects/SwiftLinuxUI` — POC for Linux (GTK4), 150 commits, v0.28.0
- `~/Projects/SwiftWindowsUI` — POC for Windows (Win32/D2D), 81 source files
- These are references only — SwiftOpenUI has its own architecture
