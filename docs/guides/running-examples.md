# Running Examples

How to build and run SwiftOpenUI examples on each platform.

All examples share the same view definitions (`Sources/Examples/`). Each platform has its own entry point and build system.

## macOS (SwiftUI)

Examples use real SwiftUI on macOS to validate API compatibility.

```bash
swift run HelloWorld
swift run Counter
swift run StateDemo
swift run BasicInteractive
```

Requires Xcode command-line tools. The process launches a native SwiftUI window.

## iOS / iPadOS (SwiftUI)

Open the Xcode workspace and select an example scheme:

```bash
open apple/Examples/Examples.xcodeproj
```

Select the target (e.g. HelloWorld-iOS), pick a simulator or device, and press ⌘R.

> **Note:** The Xcode project is not yet created. This is a planned step. See [issue #2](https://github.com/codelynx/SwiftOpenUI/issues/2).

## Linux (GTK4)

Requires GTK4 development libraries and the Swift toolchain.

```bash
# Install GTK4 (Ubuntu/Debian)
sudo apt install libgtk-4-dev

# Build and run
swift run HelloWorld
swift run BasicInteractive
```

The process launches a native GTK4 window.

## Windows (Win32)

Requires the Swift toolchain for Windows.

```bash
swift run HelloWorld
swift run BasicInteractive
```

The process launches a native Win32 window.

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

Cross-compiles Swift to a `.so` from macOS. Kotlin hosts the UI via Jetpack Compose.

```bash
# Build the Swift shared library
./android/renderer/build-so.sh

# Build the APK
cd android/renderer/app && gradle assembleDebug

# Install and run on emulator
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.example.swiftopenui/.MainActivity --es example "HelloWorld"
```

Available examples via intent extra: `HelloWorld`, `TextStyles`, `Buttons`, `StateDemo`, `Layout`, `TextFieldDemo`.

## Example List

| Example | What it demonstrates |
|---------|---------------------|
| HelloWorld | Text with padding |
| Counter | @State with Int |
| Showcase1 | Text, Button, Spacer, Divider, Color |
| Showcase2 | VStack, HStack, ZStack, ForEach, Frame |
| TextStyles | All font presets and named colors |
| Buttons | Button variants, custom labels, actions |
| StateDemo | @State, @Binding, conditional rendering, multiple state |
| Layout | VStack/HStack alignment, Spacer, ZStack, Frame, nested stacks |
| FocusTest | TextField with focus preservation across rebuilds |
| BasicInteractive | NavigationStack, gestures, animations |
| TextFieldDemo | TextField with live Binding (Android only) |

## Platform Support Matrix

| Feature | macOS | iOS | Linux | Windows | Web | Android |
|---------|-------|-----|-------|---------|-----|---------|
| Build system | SPM / Xcode | Xcode | SPM | SPM | SPM + Wasm SDK | SPM + Gradle |
| UI framework | SwiftUI | SwiftUI | GTK4 | Win32 | DOM | Compose |
| `swift run` | Yes | No (use Xcode) | Yes | Yes | No (use build script) | No (use build script) |
