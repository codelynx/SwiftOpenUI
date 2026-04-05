# Modifiers

All modifier view structs live in `Sources/SwiftOpenUI/Modifiers/`. Each wraps content with `Body = Never` and is rendered by backend extensions.

## Layout & Appearance

| Modifier | Description |
|----------|-------------|
| `.padding(_:)` | Adds padding around the view. |
| `.frame(width:height:alignment:)` | Sets explicit dimensions. |
| `.foregroundColor(_:)` | Sets text/icon color. |
| `.foregroundStyle(_:)` | Sets foreground style (ShapeStyle). |
| `.background(_:)` | Sets background color. |
| `.font(_:)` | Sets text font (.title, .headline, .body, etc.). |
| `.border(_:width:)` | Adds a border around the view. |

## Gestures

| Modifier | Description |
|----------|-------------|
| `.onTapGesture(count:perform:)` | Fires action after `count` taps (default 1). |
| `.onLongPressGesture(minimumDuration:perform:)` | Fires action after a long press (default 0.5s). |
| `.onDrag(minimumDistance:onChanged:onEnded:)` | Tracks drag gestures. Suppresses callbacks until pointer moves beyond `minimumDistance` (default 10pt). Provides `DragGestureValue` with `startLocation`, `location`, and `translation`. |

### Backend support

- **GTK4**: GtkGestureClick, GtkGestureLongPress, GtkGestureDrag event controllers.
- **Win32**: Recursive subclassing on all HWNDs. TapGesture uses armed down→up tracking. LongPress via SetTimer. Drag with minimumDistance filtering and WM_MOUSEMOVE capture.
- **macOS**: Uses real SwiftUI gesture modifiers.
- **Web**: Pointer events. Tap via `click` (with multi-tap counter + 400ms timeout). LongPress via `setTimeout` + `pointerdown`/`pointerup`. Drag via `pointerdown`/`pointermove`/`pointerup` with document-level listeners and distance threshold.

## Image

| Modifier | Description |
|----------|-------------|
| `.imageScale(_:)` | Sets icon size: `.small` (14pt), `.medium` (20pt), `.large` (24pt). Applies to both system icons and file-backed images. |

## Animation & Transform

| Modifier / Function | Description |
|---------------------|-------------|
| `.opacity(_:)` | Sets view opacity (0.0–1.0). |
| `.offset(x:y:)` | Translates the view by the given amounts. |
| `.scaleEffect(_:)` | Uniform scale. Also `.scaleEffect(x:y:)` for independent axes. |
| `.animation(_:value:)` | Associates an animation curve with the view. |
| `withAnimation(_:_:)` | Wraps a state change so the resulting rebuild animates. |

### Animation curves

`Animation.linear()`, `.easeIn()`, `.easeOut()`, `.easeInOut()`, `.spring` — each with configurable `duration` (default 0.35s).

### Backend support

- **GTK4**: CSS `transition` property. On rebuild, old values are set first, then new values are applied on the next frame via `g_idle_add` so GTK interpolates.
- **Win32**: D2D surface rendering with `SetTimer` at 60fps for `OpacityView`/`ScaleEffectView` on D2D-renderable subtrees (Text, Color, Divider). Easing curves: linear, easeIn, easeOut, easeInOut, spring. `consumePendingAnimation()` captures animation across deferred PostMessage rebuilds.
- **macOS**: Uses real SwiftUI animation.
- **Web**: CSS `transition` property. On rebuild, old computed values are captured from `data-anim-role` marked wrappers, applied to new DOM nodes, then new values are set on the next `requestAnimationFrame` so the browser interpolates. Strict key-based pairing (role + depth) with uniqueness guard.

## Environment

| Modifier | Description |
|----------|-------------|
| `.environmentObject(_:)` | Injects an `ObservableObject` into the environment. |
| `.environment(_:_:)` | Sets a custom `EnvironmentKey` value. |
| `ViewModifier` protocol | Custom reusable modifier via `func body(content:) -> some View`. |
