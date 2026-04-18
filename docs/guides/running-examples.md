# Running Examples

How to build and run SwiftOpenUI examples on each platform.

Examples are organized into two tracks:
- **Showcase** (`Examples/Showcase/`) — polished mini-apps for demos and screenshots
- **Parity** (`Examples/Parity/`) — matrix-backed coverage screens, one per feature section

Each example is a single `main.swift` using `#if os(macOS) import SwiftUI` for real SwiftUI validation on macOS, and `import SwiftOpenUI` with platform backends elsewhere.

## macOS — Terminal (SwiftUI)

```bash
# Showcase
swift run HelloWorld
swift run Stopwatch
swift run ColorMixer
swift run SimplePaint
swift run LayoutStress

# Parity
swift run ParityViewsBasic
swift run ParityViewsLayout
swift run ParityViewsContainers
swift run ParityModifiers
swift run ParityStateData
swift run ParityNavigation
swift run ParityEnvironment
swift run ParityGestures
swift run ParityAnimation
swift run ParityFocus
swift run ParityAppStructure
```

Requires Xcode command-line tools. The window appears as a native SwiftUI app with Dock icon and ⌘Tab support.

## macOS — Xcode (SwiftUI)

The Xcode project is generated from `project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen). Each target references the same `Examples/*/main.swift` source — no copies.

### First-time setup

```bash
# Install XcodeGen (one time)
brew install xcodegen

# Generate the Xcode project
cd apple/Examples
xcodegen generate
```

### Run

```bash
open apple/Examples/Examples.xcodeproj
```

Select any scheme and press ⌘R.

### Regenerating after changes

If you add or rename an example, update `apple/Examples/project.yml` and re-run:

```bash
cd apple/Examples && xcodegen generate
```

The generated `Examples.xcodeproj` is not committed to git — each developer generates it locally.

## iOS / iPadOS (SwiftUI)

The same Xcode project can be extended with iOS targets. Add a new target in `project.yml` with `platform: iOS` and run `xcodegen generate`.

> **Status:** Not yet configured. macOS targets only for now.

## Linux (GTK4)

```bash
# Install GTK4 (Ubuntu/Debian)
sudo apt install libgtk-4-dev

# Showcase
swift run HelloWorld
swift run Stopwatch
swift run ColorMixer
swift run SimplePaint
swift run LayoutStress

# Parity
swift run ParityViewsBasic
swift run ParityModifiers
# ... all Parity targets work on Linux
```

Launches a native GTK4 window. All examples are supported on Linux.

## Windows (Win32)

```bash
swift run HelloWorld
swift run Stopwatch
swift run ParityViewsBasic
# ... all targets work on Windows
```

Launches a native Win32 window.

## Web (Wasm)

Cross-compiles from macOS using the Swift Wasm SDK.

```bash
# One-time setup
source ~/.swiftly/env.sh

# Build a single example
swift package --swift-sdk swift-6.2.4-RELEASE_wasm js --product HelloWorld

# Serve in browser
npx serve .build/plugins/PackageToJS/outputs/Package

# Or build all examples
cd web && ./build-wasm.sh
```

Opens in any modern browser.

## Android (Compose)

Cross-compiles Swift to a `.so` from macOS using the root `Package.swift`. Kotlin hosts the UI via Jetpack Compose.

```bash
# Build the Swift shared library (from repo root)
./android/renderer/build-so.sh

# Build the APK
cd android/renderer/app && gradle assembleDebug

# Install and run on emulator
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.example.swiftopenui/.MainActivity --es example "StateDemo"
```

See [android-setup.md](android-setup.md) for full setup instructions.

## Example List

### Showcase

| Example | Target | What it demonstrates |
|---------|--------|---------------------|
| HelloWorld | `HelloWorld` | Text with padding — minimal app |
| Stopwatch | `Stopwatch` | Timer, ObservableObject, start/stop/lap |
| ColorMixer | `ColorMixer` | Sliders, color swatches, harmony, dark theme |
| Calculator | `Calculator` | Grid/GridRow, .gridCellColumns, ZStack, @State |
| SimplePaint | `SimplePaint` | Canvas, Path, .onDrag(), tools, color palette, undo/redo |
| LayoutStress | `LayoutStress` | Settings rows, dashboard cards, sidebar/detail split, nested alignment, status bar |

### Parity

| Example | Target | Matrix section covered |
|---------|--------|----------------------|
| ViewsBasic | `ParityViewsBasic` | Text, Button, TextField, Color, Spacer, Divider |
| ViewsLayout | `ParityViewsLayout` | VStack, HStack, ZStack, Group, ForEach, AnyView, EmptyView |
| ViewsContainers | `ParityViewsContainers` | Toggle, Slider, Image, ScrollView, List |
| Modifiers | `ParityModifiers` | padding, frame, colors, font, border, opacity, offset, scale |
| StateData | `ParityStateData` | @State, @Binding, @ObservedObject, @StateObject, @Published |
| Navigation | `ParityNavigation` | NavigationStack, NavigationLink, NavigationPath, destinations |
| Environment | `ParityEnvironment` | @Environment, @EnvironmentObject, custom keys |
| Gestures | `ParityGestures` | onTapGesture, onLongPressGesture, onDrag |
| Animation | `ParityAnimation` | .animation(), withAnimation() |
| Focus | `ParityFocus` | @FocusState (bool + enum), .focused() |
| AppStructure | `ParityAppStructure` | App, Scene, WindowGroup, @ViewBuilder, window sizing APIs |


## Platform Support Matrix

| Feature | macOS | iOS | Linux | Windows | Web | Android |
|---------|-------|-----|-------|---------|-----|---------|
| Build system | SPM / Xcode | Xcode | SPM | SPM | SPM + Wasm SDK | SPM + Gradle |
| UI framework | SwiftUI | SwiftUI | GTK4 | Win32 | DOM | Compose |
| `swift run` | Yes | Planned | Yes | Yes | No (build script) | No (build script) |
| Xcode | Yes (xcodegen) | Planned | N/A | N/A | N/A | N/A |

## Build Environment Notes

- **macOS `swift run`**: Uses `NSApplication.setActivationPolicy(.regular)` to ensure the window appears in the Dock and ⌘Tab. Without this, SPM executables run as background processes.
- **Xcode project**: Generated by XcodeGen from `apple/Examples/project.yml`. Not committed to git. Each target compiles `Examples/*/main.swift` directly — same source as `swift run`.
- **Android build**: Uses the root `Package.swift` with `--triple aarch64-unknown-linux-android28`. Run `./android/renderer/build-so.sh` to build and copy the `.so`. See [android-setup.md](android-setup.md) for SDK configuration.
- **Build cache**: If you switch between the stable toolchain and the 6.3 snapshot for Android, clear the target-specific cache (`rm -rf .build/aarch64-unknown-linux-android28`) rather than the entire `.build` directory.
