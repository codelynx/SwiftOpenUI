# Getting Started

Complete setup guide for SwiftOpenUI on each platform.

## macOS

macOS is the primary development platform. Examples compile against real SwiftUI on macOS, validating API compatibility.

### Prerequisites

- **Xcode** (or Xcode Command Line Tools): `xcode-select --install`

### Build and Run

```bash
git clone https://github.com/codelynx/SwiftOpenUI.git
cd SwiftOpenUI

swift build
swift test
swift run HelloWorld
swift run ColorMixer

# Package as a .app bundle
swift package create-bundle HelloWorld --allow-writing-to-package-directory
# Output: .build/bundles/HelloWorld.app
```

See [App Bundle Packaging](app-bundle-packaging.md) for full bundle structure and platform details.

### Xcode Project

For running examples in Xcode with scheme selection and debugging:

```bash
brew install xcodegen
cd apple/Examples && xcodegen generate
open Examples.xcodeproj
```

Select any scheme (HelloWorld, Stopwatch, ColorMixer, SimplePaint, ParityViewsBasic, etc.) and press Cmd+R.

The generated `.xcodeproj` is not committed — each developer generates it locally. If you add or rename an example, update `apple/Examples/project.yml` and re-run `xcodegen generate`.

---

## Linux (GTK4)

SwiftOpenUI uses GTK4 for native Linux rendering. Tested on Ubuntu 22.04+ and Debian 12+.

### Prerequisites

1. **Swift toolchain** (6.0+)

   Install via [swiftly](https://github.com/swiftlang/swiftly) (recommended):
   ```bash
   curl -L https://swift.org/install.sh | bash
   ```

   Or download from [swift.org/download](https://www.swift.org/download/).

2. **GTK4 development libraries**

   Ubuntu / Debian:
   ```bash
   sudo apt update
   sudo apt install libgtk-4-dev pkg-config
   ```

   Fedora:
   ```bash
   sudo dnf install gtk4-devel pkg-config
   ```

   Arch Linux:
   ```bash
   sudo pacman -S gtk4 pkg-config
   ```

3. **Verify GTK4 is installed**
   ```bash
   pkg-config --modversion gtk4
   # Should print 4.x.x
   ```

### Build and Run

```bash
swift build
swift test
swift run HelloWorld
swift run ColorMixer
swift run ParityViewsBasic
```

All 17 examples (6 Showcase + 11 Parity) work on Linux.

### Notes

- Font rendering uses the system sans-serif font (not SF Pro).
- Image (systemName) renders GTK icon theme names (e.g., `"starred"`, `"emblem-favorite"`), not SF Symbols.
- Timer-based apps (Stopwatch) work via Foundation RunLoop pumped from a GLib timeout source.

---

## Windows (Win32)

SwiftOpenUI uses Win32 and Direct2D for native Windows rendering.

### Prerequisites

1. **Swift toolchain for Windows** (6.0+)

   Download from [swift.org/download](https://www.swift.org/download/) — choose the Windows installer.

2. **Visual Studio** (2022 recommended)

   Install with these workloads:
   - **Desktop development with C++** (includes Windows SDK)
   - **Individual components**: Windows 10/11 SDK

   Or install just the Build Tools:
   ```powershell
   winget install Microsoft.VisualStudio.2022.BuildTools
   ```

3. **Verify Swift is on PATH**
   ```powershell
   swift --version
   # Should print Swift 6.x.x
   ```

### Build and Run

Open **Developer Command Prompt for VS 2022** (or any shell with the Visual Studio environment loaded):

```powershell
swift build
swift test
swift run HelloWorld
swift run ColorMixer
swift run ParityViewsBasic
```

All 14 examples work on Windows.

### Notes

- Rendering uses native Win32 controls (HWND) for text fields, toggles, etc.
- Buttons use D2D flat rendering with rounded corners, hover/press states.
- Borders use flat 1px GDI rendering (no 3D bezel).
- Direct2D is used for Canvas, Slider, opacity, scale, and rotation effects.
- Image rendering uses Windows Imaging Component (WIC) — supports PNG, JPEG, BMP, GIF.
- Timer-based apps (Stopwatch) work via a hybrid RunLoop + Win32 message pump.

---

## Web (Wasm)

SwiftOpenUI compiles to WebAssembly and renders into the browser DOM via [JavaScriptKit](https://github.com/nicklama/JavaScriptKit).

### Prerequisites

1. **Open-source Swift toolchain** (not Xcode's — Xcode's Swift lacks the Wasm backend)

   Install via [swiftly](https://github.com/swiftlang/swiftly):
   ```bash
   # macOS
   curl -L https://swift.org/install.sh | bash
   source ~/.swiftly/env.sh
   ```

   Or run the configure script (macOS only):
   ```bash
   ./configure
   ```

   This installs swiftly, Swift 6.2.4, and the Wasm SDK automatically.

2. **Wasm SDK**

   If not installed by `./configure`:
   ```bash
   swift sdk install https://download.swift.org/swift-6.2.4-release/wasm-sdk/swift-6.2.4-RELEASE/swift-6.2.4-RELEASE_wasm.artifactbundle.tar.gz
   ```

   Verify:
   ```bash
   swift sdk list
   # Should include: swift-6.2.4-RELEASE_wasm
   ```

3. **Node.js** (18+) — for the Vite dev server

   ```bash
   # macOS
   brew install node

   # Ubuntu/Debian
   sudo apt install nodejs npm

   # Or use nvm
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
   nvm install 18
   ```

4. **Install Node dependencies**
   ```bash
   cd web && npm install
   ```

### Build and Run (Quick)

The `run.sh` script builds a single example and serves it:

```bash
./web/run.sh HelloWorld
# Open http://localhost:3000
```

```bash
./web/run.sh ColorMixer
./web/run.sh Stopwatch
./web/run.sh ParityViewsBasic
```

### Build and Run (All Examples)

Build all 14 examples at once, then serve via Vite:

```bash
source ~/.swiftly/env.sh
./web/build-wasm.sh        # builds all examples
cd web && npx vite         # serves at http://localhost:3000
```

Navigate to `http://localhost:3000/examples/HelloWorld.html`, `ColorMixer.html`, etc.

### Vite Dev Server

[Vite](https://vite.dev/) is used as the development server. It handles:
- Correct MIME types for `.wasm` files
- Module resolution for JavaScriptKit imports
- Hot reload for HTML changes (not Swift — Wasm requires rebuild)

The Vite config is at `web/vite.config.js`. No customization needed for basic usage.

### How It Works

```
Swift source  -->  SwiftWasm compiler  -->  .wasm binary
                                               |
              PackageToJS plugin generates:     |
              - index.js (loader)               |
              - index.html                      v
                                           Browser loads .wasm
                                           JavaScriptKit bridges
                                           Swift <-> DOM API
```

SwiftOpenUI's `WebBackend` creates DOM elements (`<div>`, `<input>`, `<button>`, etc.) via JavaScriptKit. Each SwiftOpenUI view maps to one or more DOM elements. CSS handles styling. No virtual DOM or React — direct DOM manipulation.

### Notes

- `Foundation.Timer` is not available on Wasm (no CFRunLoop). Use `JSObject.global.setInterval` via JavaScriptKit instead. The Stopwatch example demonstrates this pattern.
- Image (systemName) renders as text placeholders — there is no browser icon theme equivalent to GTK or SF Symbols.
- The Puppeteer screenshot tool (`web/screenshot.mjs`) requires Google Chrome installed locally.

---

## Android (Compose)

SwiftOpenUI uses Jetpack Compose for Android rendering, bridged via JNI. Tested on macOS with ARM64 Android emulator (Pixel 9, API 36).

### Prerequisites

1. **Swift toolchain (6.3 snapshot)**

   Install the specific version needed for Android SDK support via [swiftly](https://github.com/swiftlang/swiftly):
   ```bash
   swiftly install 6.3-snapshot-2026-03-05
   ```

2. **Swift Android SDK**

   Install the SDK artifact bundle:
   ```bash
   swift sdk install https://download.swift.org/swift-6.3-branch/android-sdk/swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a/swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android.artifactbundle.tar.gz
   ```

3. **Android Studio and NDK**
   - Install **Android Studio** (Hedgehog or later)
   - Via SDK Manager: Install **NDK (Side by side)** version 28 or 29.
   - Run the setup script to link the NDK sysroot:
     ```bash
     ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/<version> \
     ~/Library/org.swift.swiftpm/swift-sdks/<sdk-name>/swift-android/scripts/setup-android-sdk.sh
     ```

### Build and Run

1. **Build the Swift shared library**
   ```bash
   ./android/renderer/build-so.sh
   ```
   This compiles the Swift backend and copies `.so` files to the Android project.

2. **Run in Emulator**
   - Open `android/renderer/app/` in Android Studio.
   - Launch an ARM64 emulator (Pixel 8/9 recommended).
   - Press **Run** (Triangle icon) or use `./gradlew installDebug`.

### Notes

- **Precision Layout**: Fixed-size stacks (Text, Button, Divider) use Swift-side measurement for absolute positioning.
- **Flexible Layout**: Stacks with Spacers or Sliders fall back to native Compose `Column`/`Row` distribution.
- **Interactions**: Toggles, Sliders, and Text input are synchronized to Swift via JNI bindings.

---

## Toolchain Switching

If you develop for both macOS (Xcode) and Web (Wasm), you'll switch between toolchains:

```bash
# Use Xcode's Swift (default for macOS)
swift build
swift run HelloWorld

# Switch to open-source Swift for Wasm builds
source ~/.swiftly/env.sh
swift package --swift-sdk swift-6.2.4-RELEASE_wasm js --product HelloWorld
```

After switching, you may need to clean the build cache:

```bash
swift package clean
# Or for a specific target:
rm -rf .build/wasm32-unknown-wasip1
```

---

## Your First App

Create a new file `Examples/Showcase/MyApp/main.swift`:

```swift
#if os(macOS)
import SwiftUI
import AppKit
#else
import SwiftOpenUI
#if canImport(BackendGTK4)
import BackendGTK4
#endif
#if canImport(BackendWin32)
import BackendWin32
#endif
#if canImport(BackendWeb)
import BackendWeb
#endif
#endif

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("Count: \(count)")
                .font(.title)
            Button("Increment") { count += 1 }
        }
        .padding()
    }
}

struct MyApp: App {
    var body: some Scene {
        WindowGroup("My App") {
            ContentView()
        }
    }
}

#if os(macOS)
NSApplication.shared.setActivationPolicy(.regular)
NSApplication.shared.activate(ignoringOtherApps: true)
MyApp.main()
#elseif canImport(BackendGTK4)
GTK4Backend().run(MyApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(MyApp.self)
#elseif canImport(BackendWeb)
WebBackend().run(MyApp.self)
#else
print("No backend available on this platform.")
#endif
```

Add the target to `Package.swift`:

```swift
.executableTarget(
    name: "MyApp",
    dependencies: exampleDeps,
    path: "Examples/Showcase/MyApp"
),
```

Then run:

```bash
swift run MyApp
```

The view code is identical across platforms — only the imports and entry point differ via `#if`.

---

## Next Steps

- [Running Examples](running-examples.md) — all 14 examples with commands per platform
- [Feature Parity Matrix](../architecture/swiftui-parity-matrix.md) — what's implemented on each backend
- [Adding a Backend](adding-a-backend.md) — how to implement a new backend
- [Web Setup Details](web-setup.md) — Wasm build pipeline, DOM mapping, Puppeteer screenshots
