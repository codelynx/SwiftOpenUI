# Rendering Backends

## Architecture

SwiftOpenUI uses a pluggable backend architecture. The core framework defines views, state, and layout — backends render them to native platform elements.

```
SwiftOpenUI (core)
├── View protocol, @State, @Binding, @ObservedObject, ...
├── ViewBuilder, App, Scene, WindowGroup
└── RenderBackend protocol
        ├── GTK4Backend    → GtkWidget (Linux)
        ├── Win32Backend   → HWND (Windows)
        ├── WebBackend     → DOM elements (Browser/Wasm)
        └── real SwiftUI   → macOS (no backend needed)
```

## RenderBackend Protocol

```swift
public protocol RenderBackend {
    func run<A: App>(_ appType: A.Type)
}
```

Each backend implements `run()` to:
1. Create the platform's application/event loop
2. Instantiate the `App`
3. Walk the scene tree, rendering `WindowGroup` content to native widgets
4. Enter the run loop

## Backend Components

Each backend has three key parts:

| Component | Role | GTK4 | Win32 | Web |
|-----------|------|------|-------|-----|
| **Backend** | App lifecycle, window creation | `GTK4Backend` | `Win32Backend` | `WebBackend` |
| **Renderer** | View → native element mapping | `GTKRenderer` | `WinRenderer` | `WebRenderer` |
| **ViewHost** | Reactive rebuilds on state change | `GTKViewHost` | `Win32ViewHost` | `WebViewHost` |

## Rendering Dispatch

Each renderer follows the same pattern:

1. **Primitive views** (Text, Button, etc.) — direct native element creation via a `Renderable` protocol extension
2. **Stateful composite views** — wrapped in a `ViewHost` for reactive rebuilds
3. **Stateless composite views** — recurse through `.body`

```swift
// Pseudocode — same pattern in all backends
func renderView<V: View>(_ view: V) -> NativeElement {
    if let renderable = view as? PlatformRenderable {
        return renderable.createNativeElement()
    }
    if hasReactiveProperties(view) {
        return renderStatefulView(view)  // ViewHost wrapper
    }
    return renderView(view.body)  // recurse
}
```

## ViewHost Rebuild Strategy

Each ViewHost coalesces state changes into a single rebuild per frame:

| Platform | Coalescing mechanism |
|----------|---------------------|
| GTK4 | `g_idle_add` (next main loop iteration) |
| Win32 | `PostMessage` + custom message ID |
| Web | `requestAnimationFrame` |

## Window Scene Lifecycle

The `Window` scene type provides single-instance windows opened via `OpenWindowAction` (an environment key). Each backend manages window lifecycle differently:

| Platform | Window Management |
|----------|-------------------|
| GTK4 | `GTK4WindowRegistry` — tracks live `GtkWindow*` pointers per scene ID. `open(id:)` refocuses existing windows or creates via factory. `destroy` signal clears pointers to prevent use-after-free. All Window scenes register factories at render time. |
| Win32 | `Win32WindowRegistry` — tracks `HWND` per scene ID. `open(id:)` calls `SetForegroundWindow` on existing handle or invokes factory. `WM_DESTROY` clears handle. Separate `windowSceneWndProc` with message forwarding (WM_HSCROLL, WM_VSCROLL, WM_NOTIFY). `hasMainWindow` flag for app termination when no windows remain. |
| Web | Not yet implemented. |

## App Bundle Resource Discovery

`AppBundle` provides platform-independent resource lookup for packaged apps:

| Mode | Discovery | Resources path |
|------|-----------|---------------|
| Production (.app bundle) | macOS: `Foundation.Bundle`; Linux: `/proc/self/exe` + `Info.json` walk-up; Windows: `GetModuleFileNameW` + `Info.json` walk-up | macOS: `Contents/Resources/`; Linux/Windows: `Resources/` |
| Development (`swift run`) | Walk up from executable, find `Package.swift` + `Resources/` | `<packageRoot>/Resources/` |

The `create-bundle` SPM plugin (`swift package create-bundle <product>`) automates packaging into `.build/bundles/<Product>.app` with platform-appropriate layout and generated metadata.

## Icon Resources

Icons / `Image(systemName:)` are resolved backend-specifically:

- macOS uses SF Symbols natively via SwiftUI.
- Non-macOS backends bundle a Material Symbols font in a dedicated SwiftPM target (`SwiftOpenUISymbols`), gated per-platform in `Package.swift`. Each backend registers the font process-locally at startup (FontConfig on Linux, `AddFontResourceExW` + `FR_PRIVATE` on Win32, `document.fonts.add` on Web, `Typeface.createFromAsset` on Android).
- macOS builds never pull the symbols target — zero icon-font weight in macOS app bundles.

See `icon-symbols.md` for the full design: bundling, license compliance, process-local loading, and the phased `Image(systemName:)` compatibility roadmap.

## macOS

On macOS, examples use real SwiftUI directly (`import SwiftUI` + `App.main()`). No SwiftOpenUI backend is needed — the framework compiles for testing but rendering uses Apple's native implementation.
