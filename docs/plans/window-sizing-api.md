# Window Sizing API

## Goal

Provide a sample-code-controlled window sizing API for showcase apps such as Calculator.

Implemented on GTK4, Win32, and Web. Each backend does the best native mapping it can. On Web, `defaultWindowSize` and `windowSizing` are applied as CSS dimensions on the app container div (browsers don't allow content to resize the window).

Related limitation:
- GTK4 `.windowResizability(.contentSize)` currently provides compatibility spelling, not full SwiftUI-equivalent content-sized window behavior. See `docs/issues/gtk-window-resizability-content-size-gap.md`.

## Desired behaviors

- Size window from content when appropriate
- Support fixed-size windows for showcase apps
- Support explicit default window size
- Support min/max constraints where the backend can enforce them
- Keep configuration in sample code, not hardcoded in backend logic

## Proposed API

```swift
WindowGroup("Calculator") {
    CalculatorView()
}
.windowSizing(.contentFixed)
```

```swift
WindowGroup("Calculator") {
    CalculatorView()
}
.defaultWindowSize(width: 320, height: 480)
.windowResizeBehavior(.fixed)
```

```swift
WindowGroup("Calculator") {
    CalculatorView()
}
.defaultWindowSize(width: 320, height: 480)
.windowSizeConstraints(
    minWidth: 320, minHeight: 480,
    maxWidth: 480, maxHeight: 720
)
```

## Core types

- `WindowSizing`
  - `.automatic`
  - `.content`
  - `.contentFixed`
  - `.size(width:height:)`
- `WindowResizeBehavior`
  - `.automatic`
  - `.fixed`
  - `.resizable`

## Backend mapping

### GTK4

- `.content` / `.automatic`
  - rely on GTK's natural content sizing
- `.contentFixed`
  - natural content sizing + non-resizable window
- `.size(width:height:)`
  - `gtk_window_set_default_size`
- min size
  - apply via root content size request
- max size
  - not strictly enforced in the first pass

### Win32

- `.content` / `.automatic`
  - use content natural size path already present in backend
- `.contentFixed`
  - natural content size + non-resizable window style
- `.size(width:height:)`
  - explicit client size, adjusted to window frame
- min/max size
  - enforce via `WM_GETMINMAXINFO`

### macOS

- same public API can map to AppKit/SwiftUI-native window sizing behavior
- exact implementation remains platform-specific

## First-pass implementation scope

- Add scene-level configuration on `WindowGroup`
- Implement GTK4:
  - `.windowSizing(.contentFixed)`
  - `.defaultWindowSize(width:height:)`
  - `.windowResizeBehavior(.fixed/.resizable)`
  - min size constraints
- Implement Win32:
  - same API surface
  - fixed/resizable style handling
  - min/max enforcement

## Non-goals for first pass

- Generic scene wrappers beyond `WindowGroup`
- Perfect macOS parity
- Strict max-size enforcement on GTK4
