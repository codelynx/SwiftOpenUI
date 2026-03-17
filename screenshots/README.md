# Screenshots

Cross-platform screenshot comparison for SwiftOpenUI examples.

## Structure

```
screenshots/
├── android/    ← Android Views (captured via adb screencap)
├── linux/      ← GTK4 (captured via gnome-screenshot)
├── macos/      ← Native SwiftUI (captured via CGWindowID + screencapture)
├── windows/    ← Win32/D2D (captured via GDI+ CopyFromScreen)
└── web/        ← Browser/Wasm
```

## Capturing

### macOS

```bash
# Capture all examples
./screenshots/capture-macos.sh

# Capture one example
./screenshots/capture-macos.sh HelloWorld
```

Uses a compiled Swift helper (`window-capture.swift`) to find the CGWindowID by PID, then `screencapture -l` for the window, then `sips` to scale to 50% (Retina 2x → 1x). Requires Screen Recording permission for VS Code or Terminal.

### Linux

```bash
# Capture all examples
./screenshots/capture-linux.sh

# Capture one example
./screenshots/capture-linux.sh HelloWorld
```

Requires `gnome-screenshot` and a running display server (X11 or Wayland).

### Android

```bash
# Capture all examples (requires running emulator with APK installed)
./screenshots/capture-android.sh

# Capture one example
./screenshots/capture-android.sh HelloWorld
```

Auto-detects the emulator with the app installed (scans all `adb devices`). Force-stops between captures to ensure fresh intent extras. Scales to 50% if device density > 320dpi (Retina Mac emulators produce high-density screenshots). Requires `adb` in PATH and `sips` (macOS) for scaling.

### Windows

```powershell
# Capture all examples
.\screenshots\capture-windows.ps1

# Capture one example
.\screenshots\capture-windows.ps1 HelloWorld
```

Uses Win32 `FindWindow` + GDI+ `CopyFromScreen` to capture by window title. Saves as PNG. No external tools needed.

## Naming Convention

Screenshots are named to match example numbers:

| File | Example | Command |
|------|---------|---------|
| `01-HelloWorld.png` | HelloWorld | `swift run HelloWorld` |
| `02-TextStyles.png` | TextStyles | `swift run TextStyles` |
| `03-Buttons.png` | Buttons | `swift run Buttons` |
| `04-State.png` | State | `swift run StateDemo` |
| `05-Layout.png` | Layout | `swift run Layout` |
| `06-TextField.png` | TextFieldDemo | Android only (JNIBridge.swift) |

## Cross-Platform Comparison

All examples use the same Swift source (`main.swift`) with `#if os(macOS)` to select SwiftUI vs SwiftOpenUI. The view code is identical — only the platform's native rendering differs.

### 01-HelloWorld

| macOS (SwiftUI) | Linux (GTK4) | Windows (Win32) |
|-----------------|-------------|-----------------|
| ![macOS](macos/01-HelloWorld.png) | ![Linux](linux/01-HelloWorld.png) | ![Windows](windows/01-HelloWorld.png) |

- macOS: centered text, native SwiftUI window chrome
- Linux: left-aligned text, GTK4 header bar
- Windows: left-aligned text, Win32 title bar

### 02-TextStyles

| macOS (SwiftUI) | Linux (GTK4) | Windows (Win32) |
|-----------------|-------------|-----------------|
| ![macOS](macos/02-TextStyles.png) | ![Linux](linux/02-TextStyles.png) | ![Windows](windows/02-TextStyles.png) |

- All font sizes render correctly across platforms
- Named colors match well (red, blue, green, orange, purple, pink, teal, indigo)
- Opacity gradient visible on all platforms
- Font metrics differ slightly (platform-native typefaces)

### 03-Buttons

| macOS (SwiftUI) | Linux (GTK4) | Windows (Win32) |
|-----------------|-------------|-----------------|
| ![macOS](macos/03-Buttons.png) | ![Linux](linux/03-Buttons.png) | ![Windows](windows/03-Buttons.png) |

- Button styling is platform-native (rounded on macOS, GTK theme on Linux, flat on Windows)
- Custom label buttons (star emoji) render on all platforms
- Multiple buttons in HStack layout correctly

### 04-State

| macOS (SwiftUI) | Linux (GTK4) | Windows (Win32) |
|-----------------|-------------|-----------------|
| ![macOS](macos/04-State.png) | ![Linux](linux/04-State.png) | ![Windows](windows/04-State.png) |

- Counter, text toggle, conditional rendering, @Binding, multiple @State all present
- Linux closely matches macOS layout
- Windows layout is slightly looser but functionally correct

### 05-Layout

| macOS (SwiftUI) | Linux (GTK4) | Windows (Win32) |
|-----------------|-------------|-----------------|
| ![macOS](macos/05-Layout.png) | ![Linux](linux/05-Layout.png) | ![Windows](windows/05-Layout.png) |

- VStack alignment (.leading, .center, .trailing) works on all platforms
- HStack alignment (.top, .center, .bottom) works on macOS and Linux; Windows has some alignment differences
- Spacer pushes content correctly on all platforms
- ZStack layering with blue background renders on all platforms
- Frame sizing (100x50, 150x50) correct on macOS and Linux; Windows frame rendering needs refinement
- Nested stacks render on all platforms with minor spacing differences

### Summary

| Aspect | macOS | Linux | Windows |
|--------|-------|-------|---------|
| Text rendering | Native SF | Native GTK font | Direct2D |
| Font sizes | All correct | All correct | All correct |
| Colors | All correct | All correct | All correct |
| Button styling | Rounded, native | GTK theme | Flat, Win32 |
| VStack/HStack | Precise | Close match | Some alignment gaps |
| ZStack | Correct | Correct | Correct |
| Spacer | Correct | Correct | Correct |
| Frame | Correct | Correct | Needs refinement |
| @State reactivity | Works | Works | Works |
| @Binding | Works | Works | Works |

### Web (Wasm + DOM)

| 01-HelloWorld | 02-TextStyles | 03-Buttons |
|---------------|--------------|------------|
| ![Web](web/01-HelloWorld.png) | ![Web](web/02-TextStyles.png) | ![Web](web/03-Buttons.png) |

| 04-State | 05-Layout |
|----------|----------|
| ![Web](web/04-State.png) | ![Web](web/05-Layout.png) |

- Clean DOM rendering via CSS flexbox/grid
- Font sizes and colors render correctly
- Spacer layout needs refinement (not expanding as expected)
- ZStack, Frame, and nested stacks all render correctly
- Buttons use native HTML `<button>` elements

### Android (Swift .so + Jetpack Compose via JSON)

| 01-HelloWorld | 02-TextStyles | 03-Buttons |
|---------------|--------------|------------|
| ![Android](android/01-HelloWorld.png) | ![Android](android/02-TextStyles.png) | ![Android](android/03-Buttons.png) |

| 04-State | 05-Layout | 06-TextField |
|----------|----------|-------------|
| ![Android](android/04-State.png) | ![Android](android/05-Layout.png) | ![Android](android/06-TextField.png) |

- Swift renders view tree to JSON, Kotlin `ComposeRenderHost` builds Compose UI
- Jetpack Compose: Column/Row/Box, Material3 buttons, BasicTextField with TextFieldValue
- Font hierarchy (Large Title → Caption) renders with correct sizes and weights
- TextField with live Binding, cursor/selection preservation, placeholder support
- Spacer works in VStack and HStack via `Modifier.weight(1f)`
- ZStack with Color background constrained by `.frame(width:200, height:100)`
- `.focused()` wired bidirectionally via FocusRequester + onFocusChanged
- No action bar — uses `Theme.Material.Light.NoActionBar` for clean display

### Updated Summary

| Aspect | macOS | Linux | Windows | Web | Android |
|--------|-------|-------|---------|-----|---------|
| Text rendering | Native SF | Native GTK font | Direct2D | Browser CSS | Android TextView |
| Font sizes | All correct | All correct | All correct | All correct | All correct |
| Colors | All correct | All correct | All correct | All correct | All correct |
| Button styling | Rounded, native | GTK theme | Flat, Win32 | HTML button | Material button |
| VStack/HStack | Precise | Close match | Some alignment gaps | CSS flexbox | LinearLayout |
| ZStack | Correct | Correct | Correct | CSS grid | FrameLayout |
| Spacer | Correct | Correct | Correct | Needs work | VStack only |
| Frame | Correct | Correct | Needs refinement | Correct | Correct |
| @State reactivity | Works | Works | Works | Works | Works (full re-render) |
| @Binding | Works | Works | Works | Works | Works |

**Overall:** The same Swift source renders functionally correct on all 5 platforms. Each platform uses its native rendering: SwiftUI on macOS, GTK4 on Linux, Win32/D2D on Windows, DOM/CSS on Web, and Android Views via JSON bridge on Android.
