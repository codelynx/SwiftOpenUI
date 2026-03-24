# GTK4 `.windowResizability(.contentSize)` Gap

## Summary

SwiftOpenUI exposes a SwiftUI-compatible `.windowResizability(...)` API, but GTK4 does not yet implement the full semantic meaning of:

```swift
.windowResizability(.contentSize)
```

On GTK4 today, this implements only the "non-resizable window" part.
It does **not** yet implement "measure content and size the window to fit it."

## Current GTK4 Behavior

```swift
.windowResizability(.contentSize)
```

Currently maps to:

- `gtk_window_set_resizable(winPtr, 0)`

That means:

- the window becomes non-resizable
- the actual initial window size still comes from existing sizing inputs such as:
  - `.defaultWindowSize(...)`
  - `.windowSizing(...)`
  - GTK's default content/window behavior

## What SwiftUI Engineers May Expect

In SwiftUI on macOS, `.windowResizability(.contentSize)` is closer to:

1. measure the content's natural size
2. size the window to fit that content
3. disable user resizing

GTK4 SwiftOpenUI currently implements step 3 only.

## Practical Impact

This means `.windowResizability(.contentSize)` is currently a **compatibility spelling**, not full behavioral parity.

For showcase apps such as `SimplePaint`, Linux still needs explicit sizing, for example:

```swift
WindowGroup("SimplePaint") {
    SimplePaintView()
}
.defaultWindowSize(width: 900, height: 540)
.windowSizing(.contentFixed)
```

while macOS can rely on native content-sized window behavior.

This is why a platform split may still exist in examples even after adopting the unified `.windowResizability(...)` API spelling.

## Why This Is Not Done Yet

Closing this gap likely requires backend work, not just modifier plumbing.

GTK4 needs a clearer sizing pipeline that can:

- measure final root content natural size reliably
- decide precedence between:
  - `.defaultWindowSize(...)`
  - `.windowSizing(...)`
  - `.windowResizeBehavior(...)`
  - `.windowResizability(...)`
  - min/max constraints
- apply the resolved initial window size before presenting the window
- then disable resizing when `.contentSize` is requested

## Recommendation

Treat the current GTK4 implementation as acceptable for now for showcase apps, but document it honestly:

- `.contentSize` on GTK4 currently means "fixed-size window using existing sizing inputs"
- `.contentMinSize` currently behaves the same as `.automatic`

If true SwiftUI source portability is the goal, this should be addressed as a GTK4 backend sizing-policy refactor later.
