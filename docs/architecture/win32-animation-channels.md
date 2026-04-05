# Win32 Animation Channels

How `.animation()` and `withAnimation()` propagate animation context to D2D surfaces on Win32.

## Two TLS Channels

Animation context flows through two separate thread-local storage slots:

| Channel | API | Lifetime | Used by |
|---------|-----|----------|---------|
| `currentAnimation` | `setCurrentAnimation()` / `getCurrentAnimation()` | Scoped — set/restored during render traversal | `.animation()` modifier |
| `pendingAnimation` | `setPendingAnimation()` / `consumePendingAnimation()` | One-shot — cleared on first consumption | `withAnimation()` |

### `.animation()` path (synchronous, scoped)

```
AnimatedView.winCreateWidget
  setCurrentAnimation(animation)
  defer { setCurrentAnimation(previous) }
  winRenderView(content, in: context)
    └── createD2DSurface checks getCurrentAnimation() ✓
    └── createD2DSurface checks getCurrentAnimation() ✓  (all siblings see it)
```

`currentAnimation` survives the full subtree render. All D2D surfaces created within the wrapper see it.

### `withAnimation()` path (deferred, single-consumer)

```
withAnimation(.easeIn) { toggle.toggle() }
  setPendingAnimation(.easeIn)
  └── state mutation triggers scheduleRebuild()
        host.pendingAnimation = getCurrentAnimation()
  └── deferred rebuild via PostMessage
        createD2DSurface checks consumePendingAnimation() ✓  (first surface only)
```

`pendingAnimation` is consumed on first use. Only the first D2D surface in the rebuild gets the animation.

## Win32ViewHost Capture

`Win32ViewHost` stores two animation sources:

- **`capturedAnimation`** — captured once at host creation from the outer `.animation()` wrapper. Persistent across all rebuilds.
- **`pendingAnimation`** — captured at `scheduleRebuild()` time from `withAnimation()`. One-shot, cleared after use.

During rebuild, priority is: `pendingAnimation ?? capturedAnimation`.

```
Initial render:
  AnimatedView sets currentAnimation(.easeIn)
    └── winRenderStatefulView creates Win32ViewHost
          host.captureAnimation()  → stores .easeIn

Later state change → rebuild:
  Win32ViewHost.rebuild()
    setCurrentAnimation(pendingAnimation ?? capturedAnimation)
    └── buildBody re-renders subtree
          └── D2D surfaces see .easeIn from capturedAnimation ✓
```

## D2D Surface Animation Engine

`D2DSurfaceState` in `D2DSurface.swift` handles the actual frame-based animation:

- 60fps timer via `SetTimer` / `WM_TIMER` (16ms intervals)
- `GetTickCount()` for elapsed time
- 5 easing curves: linear, easeIn, easeOut, easeInOut, spring
- Interpolates opacity and scale from start to target values
- Only works for D2D-rendered content (Text, Color, Canvas) — native HWND controls (Button, TextField, Toggle, Slider) cannot animate

## Known Limitations

### `.animation(nil)` cannot suppress `withAnimation()`

TLS `nil` is indistinguishable from "no scoped animation set". When `AnimatedView` sets `currentAnimation` to `nil`, `createD2DSurface` falls through to `consumePendingAnimation()`. A subtree wrapped in `.animation(nil)` will still animate if a pending `withAnimation()` token exists.

Fix requires tri-state TLS in core (`inherit` / `explicit nil` / `explicit animation`). Affects all backends.

### Multi-surface `withAnimation()` is first-surface-wins

`consumePendingAnimation()` clears the slot on first use. In a subtree with multiple D2D surfaces, only the first one gets the animation during a `withAnimation()` rebuild.

### `.animation(_, value:)` ignores the value parameter

Core drops the `value` argument entirely — `AnimatedView` stores only the `Animation?`. All rebuilds animate regardless of which value changed. This is a core-level gap affecting all backends.
