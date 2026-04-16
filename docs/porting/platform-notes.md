# Platform Notes

## macOS

- Uses **real SwiftUI** — examples `import SwiftUI` and call `App.main()`
- SwiftOpenUI core library compiles on macOS (for tests) but is not used for rendering
- **Namespace conflict**: `ObservableObject` and `Published` clash with Foundation/Combine — tests use `SwiftOpenUI.ObservableObject` and `@SwiftOpenUI.Published` prefixes (see `docs/issues/observable-namespace-conflict.md`)
- Package minimum: macOS 13 (required by JavaScriptKit dependency)

### Launch and frontmost behavior

SwiftUI example apps launched via `swift run` can start in the background or create their first
window slightly after `App.main()` enters the Cocoa lifecycle. The working rule on macOS is:
front the app only after the app has finished launching and a real `NSWindow` exists.

Mechanism used by `MacExampleSupport`:

1. Call `NSApplication.shared.setActivationPolicy(.regular)` before `App.main()`
2. Do **not** replace `NSApplication.shared.delegate`
3. Install passive observers for app and window notifications
4. Wait for `NSApplication.didFinishLaunchingNotification`
5. Retry briefly on the main queue because SwiftUI may create the first window a moment later
6. When a usable `NSWindow` exists, call:
   - `NSApplication.shared.activate(ignoringOtherApps: true)`
   - `window.makeKeyAndOrderFront(nil)`
   - `window.orderFrontRegardless()`

What we learned:

- Setting focus policy too early is ineffective; there is no real window to front yet
- Owning the global app delegate is too invasive; SwiftUI needs to control its own lifecycle
- A small retry loop is acceptable for example apps because window creation is asynchronous
- Logging app and window notifications is much more informative than guessing from launch timing

### Window sizing semantics

macOS window sizing has a few separate concerns that should not be collapsed into one flag:

- **Default size**: the initial size when the window is first created
- **Minimum size**: the smallest user-resizable size
- **Maximum size**: the largest user-resizable size
- **Resizable or fixed**: whether the user can drag-resize at all
- **Content-driven size**: whether the window should follow its content's ideal size

Practical guidance:

- Treat default size as an initial suggestion, not as a permanent clamp
- Treat min and max as persistent constraints
- For fixed-content examples such as Calculator, content-sized behavior is often the cleanest fit
- If a window should not resize, express that explicitly instead of faking it with `min == max`
- Keep launch/fronting logic separate from sizing logic; they are different responsibilities

On native macOS implementations, typical knobs are:

- SwiftUI: `WindowGroup`, `.windowResizability(...)`, and scene/window sizing modifiers
- AppKit: `setContentSize`, `minSize`, `maxSize`, and the `resizable` style mask

### Example-app quit behavior

For `swift run` showcase apps, "quit when the last window closes" is reasonable and feels native.
That policy belongs in the example-launch helper, not in shared view code. It should remain a thin
example-runner behavior, not a global framework rule.

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
- Delayed callback environment binding for actions, menus, lifecycle hooks, and gestures that may
  read `@Environment(...)` after render scope has ended. See
  [Deferred Callback Environment Binding](../architecture/deferred-callback-environment-binding.md)
- Gesture routing via recursive subclassing (same proc on root + all descendants, not WM_PARENTNOTIFY)
- Navigation via Win32Navigation.swift — show/hide HWND stack with header bar, thread-local context sharing
- Animation: Timer-driven (SetTimer 60fps + easing) for `OpacityView`/`ScaleEffectView` on fully D2D-renderable subtrees (Text, Color, Divider, simple wrappers). Easing: linear, easeIn, easeOut, easeInOut, spring. `consumePendingAnimation()` reads animation set by `withAnimation()` after deferred rebuild
- Cursor/selection preservation for all Edit controls via `EM_GETSEL`/`EM_SETSEL` (not just focused control)
- Canvas: D2D-backed `DrawingContext` with path accumulation, deferred stroke/fill, transform state in save/restore, alpha support. Partial arcs via line-segment approximation (stroke-only). See `docs/architecture/canvas-parity.md` for detailed gap analysis
- Visual effects: `.cornerRadius()` via `SetWindowRgn` + `CreateRoundRectRgn`; `.shadow()` via layered GDI rects with alpha blending against system background; `.rotationEffect()` via D2D `SetTransform` (D2D-renderable content only)

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

- Backend: `BackendAndroid` → Swift renders view tree to JSON → Kotlin `RenderHost` builds Android Views
- Requires Swift 6.3 dev snapshot toolchain (opt-in, not the repo default)
- Architecture design: Swift owns state/diff, Kotlin host owns UI (see [Android Backend Design](../architecture/android-backend-design.md))
- Setup: see [Android Setup Guide](../guides/android-setup.md)
- SwiftOpenUI core compiles for `aarch64-unknown-linux-android28` via the official Swift Android SDK
- `pthread` TLS works on Android via `canImport(Glibc)`

### Architecture

- **JSON bridge**: Swift `AndroidRenderer` walks the SwiftOpenUI view tree, produces `RenderNode` graph, serializes to JSON (hand-written, no Foundation JSONSerialization)
- **JNI entry point**: `@_cdecl("Java_com_example_swiftopenui_RenderBridge_nativeRenderApp")` — single JNI call returns full JSON render tree
- **Kotlin host**: `RenderHost.renderFromJSON()` recursively maps JSON nodes to Android Views (TextView, Button, LinearLayout, FrameLayout, etc.)
- **Manual JNI**: no swift-java bindings — JNI function table navigated manually (NewStringUTF at index 167, GetStringUTFChars at 169)

### Supported Views and Mapping

| SwiftOpenUI | Android View | Notes |
|-------------|-------------|-------|
| Text | TextView | setTextColor(BLACK), SP units |
| Button | Button | isAllCaps=false |
| VStack | LinearLayout (VERTICAL) | alignment → Gravity, spacing → topMargin |
| HStack | LinearLayout (HORIZONTAL) | alignment → Gravity, spacing → leftMargin |
| ZStack | FrameLayout | Color children → MATCH_PARENT, others → CENTER |
| Spacer | Space | layout weight=1 in HStack/VStack |
| Divider | View (1dp, gray) | |
| Color | View (MATCH_PARENT) | rgba from props |
| .padding() | wrapper LinearLayout | setPadding in dp |
| .frame() | FrameLayout | explicit width/height in dp |
| .font() | setTextSize + setTypeface | recursive into child views |
| .foregroundColor() | setTextColor | recursive into child TextViews |
| .backgroundColor() | setBackgroundColor | |

### Key Quirks

- Debug APK is ~77MB due to unstripped Swift runtime `.so` files
- Theme: `Theme.Material.Light.NoActionBar` for clean rendering
- `fitsSystemWindows=true` on ScrollView to avoid status bar overlap
- Intent extra `--es example "name"` selects which example to render
- Must force-stop app between intent launches (Android reuses existing Activity otherwise)

## Cross-Compilation Notes

- `ViewBuilder` no longer has a fixed child-count ceiling. It now uses incremental `buildPartialBlock` accumulation into a flat `ViewList` (`MultiChildView`) instead of relying only on fixed-arity `buildBlock` overloads.
- This was a **core framework issue, not a Win32-only issue**. Any backend using SwiftOpenUI's custom `ViewBuilder` could hit the old limit when examples or apps exceeded the supported tuple arity. macOS with real SwiftUI is unaffected because it does not use SwiftOpenUI rendering.
- Backend note: renderers that recurse directly through `body` for primitive multi-child results must handle `MultiChildView` / `ViewList` explicitly. GTK4 and Android already do this in their main dispatch; Win32 and Web needed explicit top-level fallbacks.
- `#if os()` in `Package.swift` checks the **host** platform, not the cross-compile target
- Example dependencies always include `SwiftOpenUI` — source-level `#if os(macOS)` selects the import
- Backend targets (GTK4, Win32) are still gated by `#if os()` since they require platform-specific system libraries
- Web backend and JavaScriptKit are always declared in the manifest to support cross-compilation from macOS to Wasm

## Cross-Platform Guidance From macOS

The macOS launch fix is mostly about lifecycle discipline, and that lesson carries well to GTK4,
Win32, and other native backends:

- Do not try to front a window before the platform has created and shown a real top-level window
- Keep the "bring app frontmost" helper passive; avoid taking ownership of the platform's primary app lifecycle if the toolkit already has one
- Separate these concerns in backend design:
  - app activation / focus
  - initial window show timing
  - window sizing policy
  - process termination on last-window-close
- Model size policy as independent fields:
  - default width/height
  - min width/height
  - max width/height
  - resizable enabled/disabled
  - content-sized behavior where the platform supports it
- Expect platform policy limits:
  - macOS may refuse focus changes until the app is eligible
  - Linux window managers may ignore or reinterpret aggressive activation requests
  - Windows generally allows more explicit foreground control, but only after a real HWND exists
- Add platform-native lifecycle logging before changing behavior; notification traces are usually more useful than speculation

Suggestion for Linux and Windows agents:

- Reuse the macOS mental model, not the exact API sequence
- Front only after the first mapped GTK window or shown HWND exists
- Prefer a small, local example-runner helper over embedding launch hacks in core rendering code
- Keep fixed-size and content-sized example windows as explicit backend policy, not accidental side effects
