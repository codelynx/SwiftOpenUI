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

- Backend: `BackendWin32` → renders to HWNDs with Win32 API + Direct2D
- Requires: Visual Studio with Windows SDK

### Architecture

Three-layer design mirroring the GTK4 backend:

| Layer | Target | Purpose |
|-------|--------|---------|
| `CWin32` | C/C++ shim | Win32 macro expansions + D2D/DirectWrite COM wrappers |
| `CWin32Bridge` | Swift bridge | HWNDRef, SubclassHandler, ClosureBox, MainThread |
| `BackendWin32` | Rendering | Win32Backend, WinRenderer, Win32ViewHost, LayoutEngine, D2DRenderer |

### Rendering Strategy

- **HWND-based controls**: Text→STATIC, Button→BUTTON — native Win32 controls for standard widgets
- **Direct2D**: Color fills, Divider lines, and any custom visual rendering (anti-aliased, alpha-aware)
- **DirectWrite**: Text measurement via `DWriteTextLayout.GetMetrics()` — more accurate than GDI's `GetTextExtentPoint32W`
- **Layout**: Custom flexbox-like engine using `SetWindowPos()` for VStack/HStack/ZStack

### Why the D2D C++ Shim?

Swift's C++ interop (as of Swift 6.2) has a [known bug](https://github.com/apple/swift/issues/62354) where **virtual method calls dispatch statically** instead of through the vtable. COM interfaces like `ID2D1RenderTarget` are pure-virtual — every method must go through vtable dispatch. Calling them directly from Swift invokes the wrong function.

The workaround is `d2d1_shim.cpp`: a C++ file that wraps each COM call in a `extern "C"` function. Swift calls the C function, the C++ compiler dispatches through the vtable correctly. The header (`d2d1_shim.h`) exposes COM objects as opaque struct pointers so Swift gets type-safe distinct types.

**When can the shim be removed?** When [swiftlang/swift#62354](https://github.com/apple/swift/issues/62354) is resolved and Swift can dispatch virtual C++ calls through vtables correctly. At that point, the D2D COM interfaces can be imported directly with `import CxxD2D1` or similar.

### Key Implementation Details

- Coalesced rebuilds via `PostMessage(WM_SWIFTUI_REBUILD)` — Win32 equivalent of GTK's `g_idle_add()`
- Focus save/restore across rebuilds with `suppressNextFocusRestore()` for `@FocusState`
- Owner-draw buttons (`BS_OWNERDRAW` + `WM_DRAWITEM`) for `.foregroundColor()` on Button controls
- Recursive font application via `applyFontRecursively()` to reach controls inside modifier wrappers
- HFONT leak prevention via cleanup subclass on `WM_NCDESTROY`
- Thread-local environment via `TlsAlloc` / `TlsGetValue`

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
