# Android Build Setup

This documents how to cross-compile Swift for Android and run it on a device/emulator. Verified on macOS with ARM64 Android emulator (Pixel 8/9, API 36).

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| Swift toolchain | 6.3 dev snapshot | Stable 6.2.x does not ship an Android SDK. Opt-in — do not change `.swift-version`. |
| Swift Android SDK | 6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a | Must match the toolchain version exactly. |
| Android NDK | r27 or later (tested with r29) | Install via Android Studio SDK Manager → SDK Tools → NDK. |
| Android Studio | Any recent version | For NDK, emulator, and Kotlin host app. |
| JDK | 17+ | Android Studio bundles one, or install via Homebrew. |

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

**This step is required** — without it, the SDK cannot find C headers (`semaphore.h`, etc.) and Foundation modules:

```bash
ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/29.0.14206865 \
  ~/Library/org.swift.swiftpm/swift-sdks/swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android.artifactbundle/swift-android/scripts/setup-android-sdk.sh
```

Expected output: `setup-android-sdk.sh: success: ndk-sysroot linked to Android NDK at ...`

### 4.1 Troubleshooting: aarch64 Swift module resolution
In some development environments (macOS arm64), the Swift SDK may incorrectly default to `x86_64` resource paths, causing `error: could not find module 'Foundation'` during cross-compilation.

To fix this, manually configure the resource path to point at the `aarch64` directory:

```bash
SDK_PATH=~/Library/org.swift.swiftpm/swift-sdks/swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android.artifactbundle
swift sdk configure \
  --swift-resources-path "$SDK_PATH/swift-android/swift-resources/usr/lib/swift-aarch64" \
  swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android \
  aarch64-unknown-linux-android28
```

### 5. Verify: build SwiftOpenUI core for Android

```bash
swift build --swift-sdk swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android --target SwiftOpenUI
```

Expected output: `Build of target: 'SwiftOpenUI' complete!`

## Running the Hello World POC on Android

The `android/hello/` directory contains a minimal proof-of-concept: Swift function called from Kotlin via JNI, displayed in a `TextView`.

### Build the Swift shared library

```bash
cd android/hello/swift-lib
swiftly use 6.3-snapshot
swift build --swift-sdk swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android \
  --triple aarch64-unknown-linux-android28 -c release
```

Output: `android/hello/swift-lib/.build/aarch64-unknown-linux-android28/release/libSwiftHello.so` (22KB)

### Copy .so files to the Android project

The Swift `.so` needs the Swift runtime libraries and `libc++_shared.so` from the NDK:

```bash
SWIFT_LIBS=~/Library/org.swift.swiftpm/swift-sdks/swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android.artifactbundle/swift-android/swift-resources/usr/lib/swift-aarch64/android
NDK_LIBS=~/Library/Android/sdk/ndk/29.0.14206865/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android
JNILIBS=android/hello/app/app/src/main/jniLibs/arm64-v8a

# Swift library
cp android/hello/swift-lib/.build/aarch64-unknown-linux-android28/release/libSwiftHello.so "$JNILIBS/"

# Swift runtime (all .so files)
cp "$SWIFT_LIBS"/*.so "$JNILIBS/"

# NDK C++ runtime
cp "$NDK_LIBS/libc++_shared.so" "$JNILIBS/"
```

### Run in Android Studio

1. Open `android/hello/app/` in Android Studio
2. Sync Gradle (should succeed with no errors)
3. Device Manager → launch Pixel_8 or Pixel_9 emulator
4. Wait for emulator to boot to home screen
5. Click Run → the app displays "Hello from SwiftOpenUI on Android!"

## Lessons Learned (Trial and Error)

### NDK sysroot must be linked first

Without running `setup-android-sdk.sh`, the SDK fails with `'semaphore.h' file not found` or `could not find module 'Foundation'`. The script creates symlinks from the SDK's `ndk-sysroot/` to the NDK's headers and libraries.

### SDK resource path configuration

The Android Swift SDK may default to armv7 resources for aarch64 targets. If you see `could not find module 'Foundation' for target 'aarch64-unknown-linux-android'`, reconfigure:

```bash
swift sdk configure \
    --swift-resources-path .../swift-resources/usr/lib/swift-aarch64 \
    swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android \
    aarch64-unknown-linux-android28
```

The settled build command uses `--triple` to target aarch64:
```bash
swift build --swift-sdk swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android \
    --triple aarch64-unknown-linux-android28 \
    --product BackendAndroid -c release
```

### All Swift runtime .so files must be bundled

The Swift `.so` depends on `libswiftCore.so`, which depends on `libc++_shared.so`, `libswift_Concurrency.so`, `libFoundation.so`, etc. Missing any one causes `dlopen failed: library "..." not found` at runtime.

The safest approach: copy **all** `.so` files from the SDK's `swift-aarch64/android/` directory plus `libc++_shared.so` from the NDK. This adds ~77MB to the APK (debug). Release builds with stripping would be smaller.

### Emulator must be authorized for ADB

If `adb devices` shows `unauthorized`, the emulator hasn't accepted the debugging prompt. Fix: restart ADB server (`adb kill-server && adb start-server`) or cold-boot the emulator.

### Gradle configuration

- `dependencyResolutionManagement` (not `dependencyResolution`) in `settings.gradle.kts`
- `android.useAndroidX=true` in `gradle.properties`
- Remove the `foojay-resolver-convention` plugin if Android Studio auto-adds it (causes `--jvm-vendor` error)
- `compileSdk` / `targetSdk` should match or exceed the emulator's API level

### JNI function naming

JNI functions must follow the naming convention `Java_<package>_<class>_<method>` with dots replaced by underscores. In Swift, use `@_cdecl` to export with the exact name:

```swift
@_cdecl("Java_com_example_swifthello_MainActivity_helloFromSwift")
public func helloFromSwift(env: UnsafeMutableRawPointer?, thisObj: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    // ...
}
```

### JNI string creation is manual

There's no Swift wrapper for JNI — you must navigate the JNI function table manually. `NewStringUTF` is at index 167 in the `JNINativeInterface` function table. The `swift-java` project aims to automate this but is pre-1.0.

## What "Compiles for Android" Means

The SwiftOpenUI core library has zero platform-specific imports. It uses:
- `Foundation` (available on Android via the Swift Android SDK)
- `pthread` for thread-local storage on Linux/Android (via `#if canImport(Glibc)`)

This is the same core that compiles for macOS, Linux, Windows, and WebAssembly.

## Known Issues

- Android's Swift build uses the **root** `Package.swift` with `--triple aarch64-unknown-linux-android28`. Building from a separate package caused a state wiring regression — see `docs/issues/android-package-split-regression.md`. The SDK's `swiftResourcesPath` may need reconfiguration for aarch64 — see above.
- The "multiple Swift SDKs match" warning is harmless — the SDK bundles multiple arch variants.
- Debug APK is large (~77MB) due to unstripped Swift runtime libraries.

## Running the Full Renderer on Android

The `android/renderer/` directory contains the full SwiftOpenUI renderer: Swift renders view trees to JSON, Kotlin `ComposeRenderHost` builds Jetpack Compose UI.

### Build the Swift shared library

```bash
cd android/renderer
./build-so.sh
```

This builds `libBackendAndroid.so` and copies it along with all Swift runtime `.so` files to the Kotlin project's `jniLibs/arm64-v8a/`.

### Run in Android Studio

1. Open `android/renderer/app/` in Android Studio (not `android/hello/app/`)
2. Sync Gradle
3. Select an ARM64 emulator (e.g. Pixel 9, API 36)
4. Click Run

The app launches with the HelloWorld example by default. To switch examples, launch via `adb`:

```bash
adb shell am start -n com.example.swiftopenui/.MainActivity --es example "TextStyles"
```

Available examples: `HelloWorld`, `TextStyles`, `Buttons`, `StateDemo`, `Layout`.

### Capturing Screenshots

```bash
./screenshots/capture-android.sh
```

The script auto-detects the emulator with the app installed, force-stops between captures, and scales to 50% on high-density displays. See `screenshots/README.md` for details.

## Switching Back to Stable

After Android work, switch back to the stable toolchain:

```bash
swiftly use 6.2.4
```

The repo's `.swift-version` is pinned to `6.2.4` (stable). The 6.3 snapshot is opt-in for Android development only.
