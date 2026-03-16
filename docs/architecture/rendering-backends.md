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

## macOS

On macOS, examples use real SwiftUI directly (`import SwiftUI` + `App.main()`). No SwiftOpenUI backend is needed — the framework compiles for testing but rendering uses Apple's native implementation.
