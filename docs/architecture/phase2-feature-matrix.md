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
| **onDrag** | ✅ | ✅ gtk_gesture_drag | ✅ WM_MOUSEMOVE | ✅ pointer events | ✅ detectDragGestures + JNI |
| **opacity()** | ✅ | ✅ gtk_widget_set_opacity | ⚠️ D2D surface only | ✅ CSS opacity | ✅ Modifier.alpha |
| **offset()** | ✅ | ✅ CSS transform | ✅ SetWindowPos | ✅ CSS translate | ✅ Modifier.offset |
| **scaleEffect()** | ✅ | ✅ CSS transform | ⚠️ D2D surface only | ✅ CSS scale | ✅ Modifier.graphicsLayer |
| **.animation()** | ✅ | ✅ CSS transition | ⚠️ D2D opacity/scale only | ✅ CSS transition | ❌ pass-through |
| **withAnimation()** | ✅ TLS context | ✅ | ✅ | ✅ | ✅ partial |
| **TextField binding** | ✅ | ✅ GtkEntry notify::text | ✅ SubclassHandler EN_CHANGE | ✅ addEventListener input | ✅ BasicTextField (verified) |
| **Toggle** | ✅ | ✅ | ✅ | ✅ | ✅ Switch (verified) |
| **Slider** | ✅ | ✅ | ✅ | ✅ | ✅ Slider (verified) |
| **ScrollView** | ✅ | ✅ | ✅ | ✅ | ✅ vertical/horizontal (verified) |
| **@FocusState binding** | ✅ | ✅ GtkEventControllerFocus | ✅ WM_SETFOCUS/KILLFOCUS | ⚠️ stub | ✅ FocusRequester + onFocusChanged |
| **@FocusState programmatic** | ✅ | ✅ gtk_grab_focus | ✅ SetFocus | ❌ | ✅ requestFocus / clearFocus (verified) |
| **@State (flat/root)** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **@State (nested/composed)** | ✅ | ✅ per-view host | ✅ per-view host | ✅ per-view host | ✅ structural state cache |
| **Display cutout** | N/A | N/A | N/A | N/A | ✅ statusBarsPadding |
| **HStack centering** | ✅ | ✅ | ✅ | ✅ | ✅ (no-Spacer only) |
| **Cursor/selection restore** | ✅ SwiftUI | ✅ DFS-indexed save/restore | ✅ EM_GETSEL/SETSEL all Edits | ❌ | ⚠️ TextFieldValue preserves cursor |
| **.sheet()** | ✅ | ✅ | ✅ | ✅ | ✅ ModalBottomSheet |
| **.alert()** | ✅ | ✅ | ✅ | ✅ | ✅ AlertDialog |
| **Circle** | ✅ | ✅ | ✅ | ✅ | ✅ TrueCircleShape |
| **Rectangle** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **RoundedRectangle** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Capsule / Ellipse** | ✅ | ✅ | ✅ | ✅ | ✅ |

## Legend

- ✅ Fully implemented
- ⚠️ Partially implemented (noted limitation)
- ❌ Missing or stub
- N/A Not applicable

## Platform Notes

### GTK4 (Linux)
Most complete Phase 2 implementation. Navigation uses `GtkStack` with slide transitions. Gestures use GTK gesture controllers. Animations use CSS `transition` property. Focus is bidirectional with programmatic grab/clear.

### Win32 (Windows)
Navigation and gestures fully working. Navigation uses show/hide HWND stack with header bar (back button + title). NavigationLink supports value-based init with destination registry. NavigationSplitView with 2/3-column layout, draggable divider, column width constraints, and visibility control. Gestures use recursive subclassing (same proc on root + all descendants). Animation: `OpacityView` and `ScaleEffectView` have timer-driven animation (SetTimer at 60fps with easing curves) when their content is fully D2D-renderable. `RotationView` uses D2D SetTransform. Native HWND controls inside `withAnimation` rebuild instantly without interpolation. Foundation Timer integration via hybrid RunLoop pump. Image rendering uses WIC (PNG/JPEG/BMP/GIF) + Win32 stock icons. D2D custom slider with accent track, white thumb, and inherited background. Cursor/selection preserved for all Edit controls across rebuilds via `EM_GETSEL`/`EM_SETSEL`. ComCtl32 v6 visual styles enabled at runtime for TextField placeholders.

### Web (Wasm)
Full Phase 2 coverage. Navigation uses a JS-side stack with header bar and back button. NavigationPath binding is bidirectional with re-entrancy guard (matching GTK4/Win32 pattern). Destination registry supports type-based path navigation via `.navigationDestination(for:)`. `NavigateAction` is wired into the environment for programmatic push/pop/popToRoot — including inside pushed destinations. Gestures use pointer events (tap, double-tap via click count, long press via setTimeout, drag via pointermove). Animations use CSS transitions with timing curves. Known issue: animation demo shows double-rendered text due to a rendering bug.

### Android (Compose)
Phase 2 renderers implemented for navigation, gestures, and animation modifiers. Compose handlers (`ComposeRenderHost.kt`) dispatch all Phase 2 node types: `opacity` → `Modifier.alpha`, `offset` → `Modifier.offset`, `scaleEffect` → `Modifier.graphicsLayer`, `navigationStack` → header bar + content Column, `navigationLink` → Button, `onDrag` → `detectDragGestures`. Form-entry views `Toggle`, `Slider`, `SecureField`, `TextEditor`, and `ProgressView` implemented with verified JNI interaction paths. `List` implementation uses `LazyColumn` with Material3 `HorizontalDivider`. Shape primitives `Circle`, `Rectangle`, `RoundedRectangle`, `Capsule`, and `Ellipse` supported, including `.fill()` and `.stroke()` modifiers; `Circle` uses a custom `TrueCircleShape` for inscribed circular semantics. Modal presentations `.sheet()` and `.alert()` implemented using a layout-neutral global post-dispatch pass in the host. NavigationPath binding is Swift-driven: path changes trigger full re-render, Swift resolves destinations via registry, Kotlin renders the JSON. NavigationDemo verified working — push (NavigationLink + programmatic), back button, pop, pop-to-root, and system back button all function correctly. This is one-way rebuild navigation, not bidirectional UI/path sync like GTK4/Win32/Web. System back button wired via `onBackPressedDispatcher` — pops NavigationStack when path is non-empty. Destination titles fall back to path value description, not `.navigationTitle`. Nested @State works via structural state cache keyed by node ID. StateDemo uses nested child views (`NestedCounterSection`, `NestedToggleSection`, `NestedMultiSection`). TextFieldDemo demonstrates TextField binding + enum-based `@FocusState` with programmatic Focus Name / Focus Email / Clear Focus. Display cutout and HStack centering fixed.

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
2. **Win32 opacity/scale**: Only works on D2D-rendered content (Text, Color, Divider), not native HWND controls (Button, TextField). Applying `.opacity()` or `.scaleEffect()` to a container with interactive children falls through to instant application.
3. **Win32 animation on HWND controls**: Animation timing works for D2D surfaces. Native HWND controls inside `withAnimation` rebuild instantly without interpolation.
4. **Web animation**: Double-rendered text in animation demo due to modifier wrapping bug.
5. **Cursor/selection restore**: Lost on rebuild on Web. GTK4 preserves via DFS-indexed save/restore (GtkEditable, GtkTextView, GtkScale). Win32 preserves all Edit controls' cursor/selection. Android preserves via TextFieldValue.
6. **Android JSON Int64 precision**: Node IDs must be serialized as strings, not bare numbers. Java's `JSONObject` parses numbers through `Double`, losing precision for values > 2^53. See [android-json-int64-precision.md](../issues/android-json-int64-precision.md).

## Key Files

| Area | Core | GTK4 | Win32 | Web | Android |
|------|------|------|-------|-----|---------|
| Navigation | `Navigation/` | `GTKNavigation.swift` | `Win32Navigation.swift` | `WebRenderer.swift` | `AndroidRenderer.swift` + `ComposeRenderHost.kt` |
| Gestures | `Modifiers/GestureModifier.swift` | `GTKRenderer.swift` | `WinRenderer.swift` | `WebRenderer.swift` | `AndroidRenderer.swift` + `ComposeRenderHost.kt` |
| Animation | `Modifiers/AnimationModifier.swift` | `GTKRenderer.swift` | `WinRenderer.swift` | `WebRenderer.swift` | `AndroidRenderer.swift` + `ComposeRenderHost.kt` |
| Focus | `State/FocusState.swift` + `Modifiers/FocusModifier.swift` | `GTKRenderer.swift` | `WinRenderer.swift` | `WebRenderer.swift` | `AndroidRenderer.swift` + `ComposeRenderHost.kt` |
| TextField | `Views/TextField.swift` | `GTKRenderer.swift` | `WinRenderer.swift` | `WebRenderer.swift` | `AndroidRenderer.swift` + `ComposeRenderHost.kt` |
