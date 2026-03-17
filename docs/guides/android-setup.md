# Android Build Setup

This documents how to cross-compile SwiftOpenUI core for Android from macOS. This is an experimental capability — the Android backend does not exist yet. This setup only proves the core library compiles for the Android target.

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| Swift toolchain | 6.3 dev snapshot | Stable 6.2.x does not ship an Android SDK. Opt-in — do not change `.swift-version`. |
| Swift Android SDK | 6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a | Must match the toolchain version exactly. |
| Android NDK | r27 or later (tested with r29) | Install via Android Studio SDK Manager → SDK Tools → NDK. |
| Android Studio | Any recent version | For NDK installation and future Kotlin host development. |

## Step-by-Step Setup

### 1. Install Swift 6.3 dev snapshot (opt-in, do not change .swift-version)

```bash
source ~/.swiftly/env.sh
swiftly install 6.3-snapshot
swiftly use 6.3-snapshot
swift --version
# Expected: Apple Swift version 6.3-dev (...)
```

### 2. Install Android NDK

Via Android Studio: Settings → Languages & Frameworks → Android SDK → SDK Tools → check "NDK (Side by side)" → Apply.

Or via command line:
```bash
~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager "ndk;29.0.14206865"
```

### 3. Install Swift Android SDK

```bash
swift sdk install https://download.swift.org/swift-6.3-branch/android-sdk/swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a/swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android.artifactbundle.tar.gz --checksum 6d3e851c46490cb64bcfb3e4eb5c5f3b7385e4f3f8b6bb89f8b9dc8c461a6c61
```

### 4. Link NDK sysroot into the Swift Android SDK

This step is required — the SDK needs to find NDK headers and libraries:

```bash
ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/29.0.14206865 \
  ~/Library/org.swift.swiftpm/swift-sdks/swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android.artifactbundle/swift-android/scripts/setup-android-sdk.sh
```

Expected output: `setup-android-sdk.sh: success: ndk-sysroot linked to Android NDK at ...`

### 5. Verify: build SwiftOpenUI core for Android

```bash
swift build --swift-sdk swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android --target SwiftOpenUI
```

Expected output: `Build of target: 'SwiftOpenUI' complete!`

## What This Builds

- **SwiftOpenUI core only** — the platform-independent library (Views, State, Layout, Modifiers, Environment)
- **Not examples** — they depend on BackendWeb/JavaScriptKit which doesn't compile for Android
- **Not a runnable Android app** — there is no Android backend yet, only the design doc at `docs/architecture/android-backend-design.md`

## Scope: What "Compiles for Android" Means

The SwiftOpenUI core library has zero platform-specific imports in its source. It uses:
- `Foundation` (available on Android via the Swift Android SDK)
- `pthread` for thread-local storage on Linux/Android (via `#if canImport(Glibc)`)

This is the same core that compiles for macOS, Linux, Windows, and WebAssembly.

## Known Issues

- `--triple aarch64-unknown-linux-android28` flag causes module resolution errors (SPM bug with the SDK). Omit `--triple` and let the SDK select the default target.
- Building the full package (not just `--target SwiftOpenUI`) fails because JavaScriptKit doesn't compile for Android. The Web backend needs to be made conditional before full-package Android builds work.
- The "multiple Swift SDKs match" warning is harmless — the SDK bundles multiple arch variants.

## Switching Back to Stable

After Android work, switch back to the stable toolchain:

```bash
swiftly use 6.2.4
```

The repo's `.swift-version` is pinned to `6.2.4` (stable). The 6.3 snapshot is opt-in for Android development only.
