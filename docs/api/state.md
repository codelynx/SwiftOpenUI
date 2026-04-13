# State

All state property wrappers live in `Sources/SwiftOpenUI/State/`. Storage is thread-safe and platform-independent.

## Property Wrappers

| Wrapper | Description |
|---------|-------------|
| `@State` | Private value-type state owned by the view. Changes trigger a rebuild of the enclosing `ViewHost`. |
| `@Binding` | Two-way reference to a `@State` value owned elsewhere. Created via `$property` projected value. |
| `@ObservedObject` | Subscribes to an external `ObservableObject`. Rebuilds on any `@Published` change. |
| `@StateObject` | Like `@ObservedObject`, but the view owns the object's lifetime (created once, survives rebuilds). |
| `@EnvironmentObject` | Reads an `ObservableObject` injected via `.environmentObject()`. |
| `@Published` | Publishes changes from an `ObservableObject` property. Triggers subscriber rebuilds. |
| `@FocusState` | Tracks focus state for input views. |

## Environment

| Type | Description |
|------|-------------|
| `EnvironmentValues` | Key-value bag threaded through the view tree. |
| `EnvironmentKey` protocol | Define custom keys with a `defaultValue`. |
| `.environment(_:_:)` | Modifier to set a key's value for a subtree. |
| `OpenWindowAction` | Environment key for opening `Window` scenes by ID. GTK/Win32: functional via window registry. Web: resolves to no-op default. Usage: `@Environment(\.openWindow) var openWindow; openWindow(id: "settings")`. |

## Observation & Scroll

| Type / Modifier | Description |
|-----------------|-------------|
| `.onChange(of:perform:)` | Fires action when a tracked `Equatable` value changes between renders. Counter-keyed global storage. |
| `ScrollViewReader` | View that provides a `ScrollViewProxy` for programmatic scrolling. |
| `ScrollViewProxy` | `scrollTo(_:anchor:)` scrolls to a view tagged with `.id()`. |
| `UnitPoint` | Unit coordinate (0-1 range) for scroll anchor: `.top`, `.center`, `.bottom`, etc. |
| `.id(_:)` | Tags a view with a `Hashable` identity for `ScrollViewProxy` lookup. |

## Platform Notes

- **Thread-local storage**: `pthread_key_t` on Linux/macOS, `TlsAlloc` on Windows, simple global on Wasm (single-threaded).
- **Namespace conflict on macOS**: `ObservableObject` and `Published` clash with Combine. Tests qualify as `SwiftOpenUI.ObservableObject`. See `docs/issues/observable-namespace-conflict.md`.
