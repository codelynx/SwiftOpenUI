# Getting Started

## Prerequisites

- **macOS**: Xcode or the open-source Swift toolchain
- **Linux**: Swift toolchain + `libgtk-4-dev`
- **Windows**: Swift toolchain + Visual Studio (Win32 SDK)
- **Web (Wasm)**: Open-source Swift toolchain (not Xcode's) + Wasm SDK

## Quick Setup (macOS)

Run the configure script to install the open-source Swift toolchain and Wasm SDK:

```bash
./configure
```

This installs:
1. **swiftly** — official Swift version manager
2. **Open-source Swift 6.2.4** — includes the Wasm compiler backend (Xcode's Swift does not)
3. **Wasm SDK** — cross-compilation SDK for WebAssembly

Note: `./configure` is macOS-only. On Linux, install Swift from swift.org and `libgtk-4-dev`. On Windows, install Swift and Visual Studio with the Windows SDK.

## Building

```bash
# macOS (uses real SwiftUI)
swift build

# WebAssembly
swift build --swift-sdk swift-6.2.4-RELEASE_wasm

# Tests
swift test
```

Note: after switching toolchains, run `swift package clean` to clear stale build cache.

## Running Examples

### macOS (native SwiftUI windows)

```bash
swift run HelloWorld
swift run Counter
swift run Showcase1
swift run Showcase2
```

### Web (browser via Wasm)

```bash
# Build + package for browser
swift package --swift-sdk swift-6.2.4-RELEASE_wasm js --product HelloWorld

# Serve locally
npx serve .build/plugins/PackageToJS/outputs/Package

# Open http://localhost:3000
```

### Linux (GTK4)

```bash
sudo apt install libgtk-4-dev
swift run HelloWorld
```

### Windows (Win32)

```bash
swift run HelloWorld
```

Requires Visual Studio with the Windows SDK installed.

## Your First App

```swift
#if os(macOS)
import SwiftUI
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

struct MyApp: App {
    var body: some Scene {
        WindowGroup("My App") {
            VStack(spacing: 8) {
                Text("Hello!")
                    .font(.title)
                Button("Tap me") {
                    print("Tapped")
                }
            }
            .padding()
        }
    }
}

#if os(macOS)
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

The view code is identical across platforms — only the imports and entry point differ via `#if`.
