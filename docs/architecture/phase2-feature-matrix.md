# Phase 2 Feature Matrix

Cross-platform alignment as of 2026-03-18. Tracked in [issue #2](https://github.com/codelynx/SwiftOpenUI/issues/2).

## Feature Status

| Feature | Core | GTK4 | Win32 | Web | Android |
|---------|------|------|-------|-----|---------|
| **NavigationStack** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **NavigationLink** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **NavigationPath binding** | ✅ | ✅ bidirectional | ✅ bidirectional | ❌ | ❌ |
| **navigationTitle** | ✅ | ✅ header bar | ✅ header bar | ❌ | ❌ |
| **onTapGesture** | ✅ | ✅ gtk_gesture_click | ✅ WM_LBUTTONDOWN/UP | ❌ | ❌ |
| **onTapGesture(count: 2)** | ✅ | ✅ nPress | ✅ GetDoubleClickTime | ❌ | ❌ |
| **onLongPressGesture** | ✅ | ✅ gtk_gesture_long_press | ✅ SetTimer | ❌ | ❌ |
| **onDrag** | ✅ | ✅ gtk_gesture_drag | ✅ WM_MOUSEMOVE | ❌ | ❌ |
| **DragGestureValue** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **opacity()** | ✅ | ✅ gtk_widget_set_opacity | ⚠️ D2D surface only | ❌ | ❌ |
| **offset()** | ✅ | ✅ CSS transform | ✅ SetWindowPos | ❌ | ❌ |
| **scaleEffect()** | ✅ | ✅ CSS transform | ⚠️ D2D surface only | ❌ | ❌ |
| **.animation()** | ✅ | ✅ CSS transition | ❌ stub (instant) | ❌ | ❌ |
| **withAnimation()** | ✅ TLS context | ✅ | ✅ | ✅ partial | ✅ partial |
| **TextField binding** | ✅ | ✅ GtkEntry notify::text | ✅ SubclassHandler EN_CHANGE | ✅ addEventListener input | ✅ BasicTextField |
| **@FocusState binding** | ✅ | ✅ GtkEventControllerFocus | ✅ WM_SETFOCUS/KILLFOCUS | ⚠️ stub | ⚠️ stub |
| **@FocusState programmatic** | ✅ | ✅ gtk_grab_focus | ✅ SetFocus | ❌ | ❌ |
| **Cursor/selection restore** | — | ❌ | ❌ | ❌ | ❌ |

## Legend

- ✅ Fully implemented
- ⚠️ Partially implemented (noted limitation)
- ❌ Missing or stub
- — Not applicable at this layer

## Platform Notes

### GTK4 (Linux)
Most complete Phase 2 implementation. Navigation uses `GtkStack` with slide transitions. Gestures use GTK gesture controllers. Animations use CSS `transition` property. Focus is bidirectional with programmatic grab/clear.

### Win32 (Windows)
Navigation and gestures fully working. Gesture installation is recursive (root + all children). Animation timing is stub — `withAnimation()` state changes trigger rebuilds but transitions are instant. Opacity and scale only work on D2D-rendered content (custom surface); native HWND controls cannot be alpha-blended or scaled.

### Web (Wasm)
Only TextField binding implemented. All Phase 2 views (`NavigationStack`, gesture modifiers, animation modifiers) have `Body = Never` in core and **no Web renderer** — using them will trap. Needs: DOM routing for navigation, DOM event listeners for gestures, CSS transitions for animations, `.focus()` API for focus management.

### Android (Compose)
Only TextField binding + Compose rendering implemented. Same gap as Web — Phase 2 views will trap. Needs: Compose `NavHost` for navigation, Compose gesture modifiers for gestures, Compose `animate*AsState` for animations, `FocusRequester` wiring for focus.

## Priority

1. **Add stubs for Web + Android** — prevent traps on `Body = Never` views
2. **Navigation** — highest value, enables multi-screen apps
3. **Gestures** — required for interactive content beyond buttons
4. **Animations** — polish, can be incremental
5. **Input-state preservation** — cross-platform cursor/selection restore during rebuilds

## Key Files

| Area | Core | GTK4 | Win32 |
|------|------|------|-------|
| Navigation | `Sources/SwiftOpenUI/Navigation/` | `GTKNavigation.swift` (420 lines) | `Win32Navigation.swift` (506 lines) |
| Gestures | `Modifiers/GestureModifier.swift` (71 lines) | `GTKRenderer.swift:530-703` | `WinRenderer.swift:1906-2207` |
| Animation | `Modifiers/AnimationModifier.swift` (266 lines) | `GTKRenderer.swift:749-802` | `WinRenderer.swift:1764-1873` |
| Focus | `State/FocusState.swift` + `Modifiers/FocusModifier.swift` | `GTKRenderer.swift:133-240` | `WinRenderer.swift:219-323` |
| TextField | `Views/TextField.swift` | `GTKRenderer.swift:91-130` | `WinRenderer.swift:160-206` |
