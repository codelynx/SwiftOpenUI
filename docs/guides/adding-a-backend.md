# Adding a Backend

## Overview

To add a new platform backend to SwiftOpenUI, you need three components:

1. **Backend** — implements `RenderBackend`, manages app lifecycle
2. **Renderer** — maps SwiftOpenUI views to native elements
3. **ViewHost** — handles reactive rebuilds when `@State` changes

## Step 1: Create the Directory

```
Sources/Backend/YourPlatform/
└── Rendering/
    ├── YourBackend.swift
    ├── YourRenderer.swift
    └── YourViewHost.swift
```

## Step 2: Implement RenderBackend

```swift
import SwiftOpenUI

public struct YourBackend: RenderBackend {
    public init() {}

    public func run<A: App>(_ appType: A.Type) {
        let instance = A()
        // Render instance.body (a Scene) into your platform's window
        // Enter your platform's event/run loop
    }
}
```

Handle `WindowGroup` by extending it with a rendering protocol:

```swift
protocol YourWindowRenderable {
    func render()
}

extension WindowGroup: YourWindowRenderable {
    func render() {
        // Create a window, render self.content into it
    }
}
```

## Step 3: Implement the Renderer

Define a protocol for native element creation, then extend each SwiftOpenUI view type:

```swift
public protocol YourRenderable {
    func createNativeElement() -> NativeElement
}

extension Text: YourRenderable {
    public func createNativeElement() -> NativeElement {
        // Create a native text/label element with self.content
    }
}

extension VStack: YourRenderable { ... }
extension HStack: YourRenderable { ... }
extension Button: YourRenderable { ... }
// ... etc
```

The dispatch function follows this pattern:

```swift
public func renderView<V: View>(_ view: V) -> NativeElement {
    if let renderable = view as? YourRenderable {
        return renderable.createNativeElement()
    }
    if hasReactiveProperties(view) {
        return renderStatefulView(view)
    }
    return renderView(view.body)
}
```

## Step 4: Implement ViewHost

The ViewHost manages a stable native container that persists across rebuilds:

```swift
public class YourViewHost: AnyViewHost {
    let container: NativeElement
    let buildBody: () -> NativeElement

    public func scheduleRebuild() {
        // Coalesce: use platform idle callback / requestAnimationFrame / PostMessage
    }

    func rebuild() {
        // 1. Remove old children from container
        // 2. Save/restore environment context
        // 3. Call buildBody() to get new element
        // 4. Add new element to container
    }

    public func suppressNextFocusRestore() {
        // Optional — suppress focus restoration if your platform needs it
    }
}
```

## Step 5: Wire into Package.swift

Add your backend target and append it to example dependencies:

```swift
// Conditionally for platform-specific backends:
#if os(YourPlatform)
targets += [
    .target(
        name: "BackendYour",
        dependencies: ["SwiftOpenUI"],
        path: "Sources/Backend/YourPlatform/Rendering"
    ),
]
exampleDeps.append("BackendYour")
#endif
```

For cross-compilable backends (like Web), declare unconditionally.

## Step 6: Update Examples

Add `canImport` checks to each example:

```swift
#if canImport(BackendYour)
import BackendYour
#endif

// ... at the bottom:
#elseif canImport(BackendYour)
YourBackend().run(MyApp.self)
```

## Views to Support

At minimum, implement rendering for these core views:

| Priority | Views |
|----------|-------|
| **Must** | Text, Button, VStack, HStack, EmptyView |
| **Should** | ZStack, Spacer, Divider, Color, Group, ForEach |
| **Modifiers** | PaddedView, FrameView, ForegroundColorView, BackgroundView, FontModifiedView, BorderView |
| **State** | AnyView, _ConditionalView, Optional, TupleView (variadic) |
| **Environment** | EnvironmentObjectModifierView, EnvironmentModifierView |

## Reference Implementations

- **GTK4**: `Sources/Backend/GTK4/Rendering/` — C interop, GObject lifecycle
- **Win32**: `Sources/Backend/Win32/Rendering/` — HWND management, custom layout engine
- **Web**: `Sources/Backend/Web/Rendering/` — simplest, good starting point
