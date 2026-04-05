# GTK4 Animation Pipeline — Technical Notes

## How animation works on GTK4

GTK4 animation uses CSS transitions. The pipeline has two paths:

1. **Initial render** �� `AnimatedView.gtkCreateWidget()` applies `transition: all <duration>s <timing>;` to the widget via inline CSS. This primes the widget so that any subsequent property change (opacity, transform) is interpolated by GTK's CSS engine.

2. **Rebuild with `withAnimation`** — `GTKViewHost.rebuild()` captures old animatable state before teardown, builds the new widget tree, sets old values on the new widget, adds the CSS transition property, then schedules an idle callback (`g_idle_add`) to apply the new values on the next frame. GTK's CSS engine interpolates between old and new.

```
withAnimation(.easeInOut) { someState.toggle() }
        │
        ▼
setPendingAnimation(.easeInOut)
scheduleRebuild() → g_idle_add(rebuild)
        │
        ▼
rebuild():
  1. animation = consumePendingAnimation()
  2. capture old: opacity, offsetX/Y, scaleX/Y, rotation
  3. remove old children
  4. build new widget tree
  5. read new: opacity, offsetX/Y, scaleX/Y, rotation
  6. apply old values to new widget
  7. apply CSS transition property
  8. g_idle_add → apply new values (triggers CSS interpolation)
```

## Transform composition model

Offset, scale, and rotation share a single CSS `transform` property. The `buildTransformCSS()` function composes them in a fixed order:

```
transform: translate(Xpx, Ypx) rotate(Ndeg) scale(sx, sy);
```

Order matters — CSS transforms apply right-to-left, so the effective order is: scale first, then rotate, then translate. This matches SwiftUI's behavior where offset moves the already-rotated-and-scaled view.

Each animatable value is stored on the widget via GObject data keys:
- `gtk-swift-offset-x`, `gtk-swift-offset-y`
- `gtk-swift-scale-x`, `gtk-swift-scale-y`
- `gtk-swift-rotation`

This storage is necessary because:
- Multiple modifier views compose onto the same inner widget (e.g. `Text("Hi").offset(x: 10).scaleEffect(2).rotationEffect(45)`)
- Each modifier reads the others' stored values to build the combined transform
- The ViewHost needs to read these values from the old widget before teardown

Opacity is separate — it uses `gtk_widget_set_opacity()` directly, not CSS transform.

## Why RotationView no longer wraps in a GtkBox

Previously, `RotationView` created a wrapper `GtkBox`, appended the content, and applied `transform: rotate()` to the wrapper. This broke transform composition: offset and scale were stored on the inner widget, but rotation lived on the outer wrapper. The ViewHost could not capture rotation from the same widget as offset/scale.

Now `RotationView` applies the rotation directly to the content widget (same as `OffsetView` and `ScaleEffectView`), stores the angle via GObject data, and calls `buildTransformCSS` with all three transforms combined.

## Descriptor conformance and the narrow-mutation path

All five animation views (`OpacityView`, `OffsetView`, `ScaleEffectView`, `RotationView`, `AnimatedView`) now conform to `GTKDescribable`. This has two effects:

1. **Subtree reuse** — When the animation wrapper's props haven't changed, the descriptor plan marks it as `reuse`. Child nodes (e.g. a `Text` underneath) can then take the narrow-mutation path for supported updates (text content, color fill, slider value, canvas redraw, padding layout) without triggering a full rebuild of the host.

2. **Change detection** — When props do change (e.g. opacity goes from 0.5 to 1.0, or animation curve changes from linear to easeIn), the plan marks it as `update` with the appropriate intent. These intents are currently descriptive-only — the mutation gate does not handle them, so the host falls through to a full rebuild. Extending the gate to handle these intents in-place is future work.

`AnimatedView` records the animation's curve (as a string) and duration in its descriptor. `.animation(nil)` emits `.none` props, distinguishing it from any non-nil animation.

## Timing curve mapping

| SwiftUI curve | CSS timing function |
|---------------|-------------------|
| `.linear` | `linear` |
| `.easeIn` | `ease-in` |
| `.easeOut` | `ease-out` |
| `.easeInOut` | `ease-in-out` |
| `.spring` | `cubic-bezier(0.5, 1.8, 0.3, 0.8)` |

The spring approximation is a single cubic-bezier that overshoots. It does not model damping or mass — it is a visual approximation only.

## Known limitations

- **No transition API** — Views appearing/disappearing (via conditionals) cannot animate their entry/exit. This requires identity tracking and a host container redesign (see `docs/plans/animation-gtk4-plan.md` Batch B).
- **No in-place mutation for animation properties** — Changing opacity, offset, scale, or rotation still triggers a full rebuild. The descriptor infrastructure is in place but the mutation gate needs extension.
- **Single CSS transition property** — `transition: all` animates every CSS property change. There is no per-property transition control.
- **Spring is approximate** — The cubic-bezier spring does not support configurable damping, stiffness, or mass.
- **No `Animatable` protocol** — Custom view properties cannot opt into animation interpolation.
