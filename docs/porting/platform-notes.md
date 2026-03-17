# Platform Notes

## macOS

- Uses **real SwiftUI** — examples `import SwiftUI` and call `App.main()`
- SwiftOpenUI core library compiles on macOS (for tests) but is not used for rendering
- **Namespace conflict**: `ObservableObject` and `Published` clash with Foundation/Combine — tests use `SwiftOpenUI.ObservableObject` and `@SwiftOpenUI.Published` prefixes (see `docs/issues/observable-namespace-conflict.md`)
- Package minimum: macOS 13 (required by JavaScriptKit dependency)

## Linux (GTK4)

- Backend: `BackendGTK4` → renders to GtkWidgets
- Requires: `libgtk-4-dev` (`sudo apt install libgtk-4-dev`)
- CSS styling via `CSSHelper` for fonts, colors, borders
- Thread-local environment via `pthread_key_t`

## Windows (Win32)

- Backend: `BackendWin32` → renders to HWNDs with Win32 API
- Requires: Visual Studio with Windows SDK
- Custom layout engine for flexbox-like positioning
- Thread-local environment via `TlsAlloc` / `TlsGetValue`
- C bridge layer (`CWin32`, `CWin32Bridge`) for Win32 API interop

## Web (WebAssembly) — Experimental

- Backend: `BackendWeb` → renders to DOM elements via JavaScriptKit
- Compiler: requires **open-source Swift toolchain** (not Xcode's — Xcode strips the Wasm backend)
- Setup (macOS): `./configure` installs swiftly + toolchain + Wasm SDK
- Build: `swift build --swift-sdk swift-6.2.4-RELEASE_wasm`
- Package for browser: `swift package --swift-sdk swift-6.2.4-RELEASE_wasm js --product HelloWorld`
- Serve: `npx serve .build/plugins/PackageToJS/outputs/Package`
- Environment: single-threaded global (no TLS needed on Wasm)
- Debug builds are ~59MB; release builds will be significantly smaller
- DOM mapping: VStack → `flex-direction: column`, HStack → `row`, ZStack → CSS grid, etc.

## Android (experimental)

- No backend yet — only the core library cross-compiles (see [Android Setup Guide](../guides/android-setup.md))
- Requires Swift 6.3 dev snapshot toolchain (opt-in, not the repo default)
- Architecture design: Swift owns state/diff, Kotlin host owns UI (see [Android Backend Design](../architecture/android-backend-design.md))
- SwiftOpenUI core compiles for `aarch64-unknown-linux-android28` via the official Swift Android SDK
- `pthread` TLS works on Android via `canImport(Glibc)`

## Cross-Compilation Notes

- `#if os()` in `Package.swift` checks the **host** platform, not the cross-compile target
- Example dependencies always include `SwiftOpenUI` — source-level `#if os(macOS)` selects the import
- Backend targets (GTK4, Win32) are still gated by `#if os()` since they require platform-specific system libraries
- Web backend and JavaScriptKit are always declared in the manifest to support cross-compilation from macOS to Wasm
