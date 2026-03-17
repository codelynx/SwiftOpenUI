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
- **macOS**: Uses real SwiftUI gesture modifiers.
- **Win32 / Web**: Core types compile; backend rendering not yet implemented.

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
- **macOS**: Uses real SwiftUI animation.
- **Win32 / Web**: Core types compile; backend rendering not yet implemented.

## Environment

| Modifier | Description |
|----------|-------------|
| `.environmentObject(_:)` | Injects an `ObservableObject` into the environment. |
| `.environment(_:_:)` | Sets a custom `EnvironmentKey` value. |
| `ViewModifier` protocol | Custom reusable modifier via `func body(content:) -> some View`. |
