# Phase 2 Feature Matrix

Cross-platform alignment as of 2026-03-18. Tracked in [issue #2](https://github.com/codelynx/SwiftOpenUI/issues/2).

## Feature Status

| Feature | Core | GTK4 | Win32 | Web | Android |
|---------|------|------|-------|-----|---------|
| **NavigationStack** | ✅ | ✅ GtkStack | ✅ Win32 | ✅ DOM stack | ✅ Compose (flat only) |
| **NavigationLink** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **NavigationPath binding** | ✅ | ✅ bidirectional | ✅ bidirectional | ✅ bidirectional | ✅ Swift-driven (push/back/pop/popToRoot verified) |
| **NavigateAction (@Environment)** | ✅ | ✅ | ✅ | ✅ push/pop/popToRoot | ✅ path-only |
| **Destination registry (.navigationDestination)** | ✅ | ✅ | ✅ | ✅ type-based | ✅ type-based |
| **navigationTitle** | ✅ | ✅ header bar | ✅ header bar | ✅ header bar | ✅ header bar |
| **onTapGesture** | ✅ | ✅ gtk_gesture_click | ✅ WM_LBUTTONDOWN/UP | ✅ click event | ✅ combinedClickable |
| **onTapGesture(count: 2)** | ✅ | ✅ nPress | ✅ GetDoubleClickTime | ✅ click count + timeout | ✅ onDoubleTap |
| **onLongPressGesture** | ✅ | ✅ gtk_gesture_long_press | ✅ SetTimer | ✅ pointerdown + setTimeout | ✅ onLongClick |
| **onDrag** | ✅ | ✅ gtk_gesture_drag | ✅ WM_MOUSEMOVE | ✅ pointer events | ⚠️ props only (no callback) |
| **opacity()** | ✅ | ✅ gtk_widget_set_opacity | ⚠️ D2D surface only | ✅ CSS opacity | ✅ Modifier.alpha |
| **offset()** | ✅ | ✅ CSS transform | ✅ SetWindowPos | ✅ CSS translate | ✅ Modifier.offset |
| **scaleEffect()** | ✅ | ✅ CSS transform | ⚠️ D2D surface only | ✅ CSS scale | ✅ Modifier.graphicsLayer |
| **.animation()** | ✅ | ✅ CSS transition | ❌ stub (instant) | ✅ CSS transition | ❌ pass-through |
| **withAnimation()** | ✅ TLS context | ✅ | ✅ | ✅ | ✅ partial |
| **TextField binding** | ✅ | ✅ GtkEntry notify::text | ✅ SubclassHandler EN_CHANGE | ✅ addEventListener input | ✅ BasicTextField (verified) |
| **@FocusState binding** | ✅ | ✅ GtkEventControllerFocus | ✅ WM_SETFOCUS/KILLFOCUS | ⚠️ stub | ✅ FocusRequester + onFocusChanged |
| **@FocusState programmatic** | ✅ | ✅ gtk_grab_focus | ✅ SetFocus | ❌ | ✅ requestFocus / clearFocus |
| **@State (flat/root)** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **@State (nested/composed)** | ✅ | ✅ per-view host | ✅ per-view host | ✅ per-view host | ✅ structural state cache |
| **Display cutout** | N/A | N/A | N/A | N/A | ✅ statusBarsPadding |
| **HStack centering** | ✅ | ✅ | ✅ | ✅ | ✅ (no-Spacer only) |
| **Cursor/selection restore** | ✅ SwiftUI | ❌ | ❌ | ❌ | ⚠️ TextFieldValue preserves cursor |

## Legend

- ✅ Fully implemented
- ⚠️ Partially implemented (noted limitation)
- ❌ Missing or stub
- N/A Not applicable

## Platform Notes

### GTK4 (Linux)
Most complete Phase 2 implementation. Navigation uses `GtkStack` with slide transitions. Gestures use GTK gesture controllers. Animations use CSS `transition` property. Focus is bidirectional with programmatic grab/clear.

### Win32 (Windows)
Navigation and gestures fully working. Gesture installation is recursive (root + all children). Animation timing is stub — `withAnimation()` state changes trigger rebuilds but transitions are instant. Opacity and scale only work on D2D-rendered content (custom surface); native HWND controls cannot be alpha-blended or scaled.

### Web (Wasm)
Full Phase 2 coverage. Navigation uses a JS-side stack with header bar and back button. NavigationPath binding is bidirectional with re-entrancy guard (matching GTK4/Win32 pattern). Destination registry supports type-based path navigation via `.navigationDestination(for:)`. `NavigateAction` is wired into the environment for programmatic push/pop/popToRoot — including inside pushed destinations. Gestures use pointer events (tap, double-tap via click count, long press via setTimeout, drag via pointermove). Animations use CSS transitions with timing curves. Known issue: animation demo shows double-rendered text due to a rendering bug.

### Android (Compose)
Phase 2 renderers implemented for navigation, gestures, and animation modifiers. Compose handlers (`ComposeRenderHost.kt`) dispatch all Phase 2 node types: `opacity` → `Modifier.alpha`, `offset` → `Modifier.offset`, `scaleEffect` → `Modifier.graphicsLayer`, `navigationStack` → header bar + content Column, `navigationLink` → Button. NavigationPath binding is Swift-driven: path changes trigger full re-render, Swift resolves destinations via registry, Kotlin renders the JSON. NavigationDemo is verified working — push (NavigationLink + programmatic), back button, pop, and pop-to-root all function correctly. This is one-way rebuild navigation, not bidirectional UI/path sync like GTK4/Win32/Web. No platform back-stack integration (system back button not wired). Destination titles fall back to path value description, not `.navigationTitle`. State works for flat root views (`AndroidStateDemoView`, `AndroidNavigationDemo`). Nested composed views with their own `@State` don't persist across renders — needs structural state store. Display cutout and HStack centering fixed.

**Build note:** Node IDs are serialized as JSON strings to avoid Int64 precision loss in Java's `JSONObject`. See [android-json-int64-precision.md](../issues/android-json-int64-precision.md) for details.

**Build note:** BackendAndroid must be built from the root `Package.swift`, not a separate package. See [android-package-split-regression.md](../issues/android-package-split-regression.md) for details. The aarch64 build requires `swift sdk configure` to point at the correct resources path — see [android-json-int64-precision.md](../issues/android-json-int64-precision.md) §3.

## Build & Run

| Platform | Command |
|----------|---------|
| macOS | `swift run StateDemo` or Xcode (`xcodegen generate`) |
| Linux | `swift run StateDemo` |
| Windows | `swift run StateDemo` |
| Web | `./web/run.sh StateDemo` |
| Android | `./android/renderer/build-so.sh` + `gradle assembleDebug` + `adb install` |

See [running-examples.md](../guides/running-examples.md) for full instructions.

## Known Limitations

1. **Android nested @State**: Resolved. Structural state cache keyed by node ID persists `@State` values across rebuilds for nested child views.
2. **Win32 animation**: Transitions are instant (no smooth animation). `withAnimation()` triggers state change but no interpolation.
3. **Win32 opacity/scale**: Only works on D2D-rendered content, not native HWND controls.
4. **Web animation**: Double-rendered text in animation demo due to modifier wrapping bug.
5. **Cursor/selection restore**: Lost on rebuild across all platforms except macOS (which uses real SwiftUI).
6. **Android JSON Int64 precision**: Node IDs must be serialized as strings, not bare numbers. Java's `JSONObject` parses numbers through `Double`, losing precision for values > 2^53. See [android-json-int64-precision.md](../issues/android-json-int64-precision.md).

## Key Files

| Area | Core | GTK4 | Win32 | Web | Android |
|------|------|------|-------|-----|---------|
| Navigation | `Navigation/` | `GTKNavigation.swift` | `Win32Navigation.swift` | `WebRenderer.swift` | `AndroidRenderer.swift` + `ComposeRenderHost.kt` |
| Gestures | `Modifiers/GestureModifier.swift` | `GTKRenderer.swift` | `WinRenderer.swift` | `WebRenderer.swift` | `AndroidRenderer.swift` + `ComposeRenderHost.kt` |
| Animation | `Modifiers/AnimationModifier.swift` | `GTKRenderer.swift` | `WinRenderer.swift` | `WebRenderer.swift` | `AndroidRenderer.swift` + `ComposeRenderHost.kt` |
| Focus | `State/FocusState.swift` + `Modifiers/FocusModifier.swift` | `GTKRenderer.swift` | `WinRenderer.swift` | `WebRenderer.swift` | `AndroidRenderer.swift` + `ComposeRenderHost.kt` |
| TextField | `Views/TextField.swift` | `GTKRenderer.swift` | `WinRenderer.swift` | `WebRenderer.swift` | `AndroidRenderer.swift` + `ComposeRenderHost.kt` |
