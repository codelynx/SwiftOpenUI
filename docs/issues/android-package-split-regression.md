# Android Package Split Regression

**Date:** 2026-03-18
**Status:** Resolved
**Issue:** [#3](https://github.com/codelynx/SwiftOpenUI/issues/3)
**Fix:** commit `a3fae6c`

## Summary

Building `BackendAndroid` from a separate Swift package (`android/renderer/swift-lib/Package.swift`) produced a `.so` binary where `@State` mutations never triggered UI rebuilds. Moving the build back to the root `Package.swift` fixed it.

## Symptom

All `nativeOnButtonClick` JNI calls returned `null`. Buttons fired (logcat showed "Button clicked"), but `pendingJSON` was never set. The counter stayed at 0 no matter how many times you tapped.

## Timeline

1. **Working state** (`experimental/android-backend` branch): `BackendAndroid` was a target in root `Package.swift`. `build-so.sh` built from repo root. StateDemo worked — tapping + incremented the counter.

2. **Package split** (`experimental/examples-shared` branch): To solve a conditional import conflict (shared example views need `import SwiftUI` on macOS but `import SwiftOpenUI` for Android), `BackendAndroid` was moved to a separate package at `android/renderer/swift-lib/Package.swift`. This package depended on the root package via `.package(path: "../../..")`.

3. **Regression appeared**: After the split, button taps stopped updating state. The `.so` compiled successfully and all views rendered, but state mutations had no effect.

4. **Long debugging session**: Multiple hypotheses tested:
   - Nested @State in composed child views → real limitation, but not the regression cause
   - `rm -rf .build` destroying module caches → real issue, but not the root cause
   - `--triple aarch64-unknown-linux-android28` flag causing Foundation module resolution failure → fixed by removing the flag, but didn't fix the state issue
   - View instance caching, storage copying, `androidCurrentHost` wiring → all attempted, none fixed it

5. **Root cause found**: Built the same code from root `Package.swift` instead of `swift-lib/Package.swift`. StateDemo immediately worked. The package split was confirmed as the cause.

## Root Cause

When `BackendAndroid` is built from a separate package that depends on `SwiftOpenUI` via `path: "../../.."`, the cross-compiled `.so` has a module identity issue. The `SwiftOpenUI` module compiled in the context of the separate package graph produces protocol witnesses that don't match at runtime on Android.

Specifically: `StateStorage.host` (typed as `AnyViewHost?`) is set via `installState()`, but the `AnyViewHost` protocol witness in the `.so` doesn't match the `AndroidViewHost` conformance. The result: `host?.scheduleRebuild()` silently does nothing because `host` appears nil or the witness table is wrong.

**This only manifests in the cross-compiled ARM64 binary.** The same code passes unit tests on macOS because macOS builds resolve the module identity correctly within a single compilation context.

## Why the Separate Package Doesn't Work

Swift module identity is determined by the build graph. When `swift-lib/Package.swift` depends on the root package, SPM may compile `SwiftOpenUI` with subtly different module metadata for the cross-compilation target. The protocol witness tables in the resulting `.so` don't align with what `BackendAndroid` expects.

This is a known fragility in Swift cross-compilation with multi-package dependency graphs. It doesn't affect native builds (macOS, Linux, Windows) because those compile everything in a single package context.

## The Fix

Keep `BackendAndroid` in the root `Package.swift`:

```swift
#if os(macOS)
targets += [
    .target(
        name: "BackendAndroid",
        dependencies: ["SwiftOpenUI"],
        path: "Sources/Backend/Android/Rendering"
    ),
]
#endif
```

Build from repo root (not from `swift-lib/`):

```bash
# build-so.sh
cd "$(dirname "$0")/../.."
swift build \
    --swift-sdk swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android \
    --triple aarch64-unknown-linux-android28 \
    --product BackendAndroid \
    -c release
```

**Note:** `--triple aarch64-unknown-linux-android28` is required — without it the SDK defaults to armv7. The earlier Foundation module resolution failure was caused by the SDK's `swiftResourcesPath` pointing to the wrong architecture; fix with `swift sdk configure --swift-resources-path .../swift-aarch64`. See [android-json-int64-precision.md](android-json-int64-precision.md) §3.

## Consequences

### Conditional Import Conflict Returns

With `BackendAndroid` back in the root package, the original problem returns: shared example views (`Sources/Examples/*.swift`) can't use `#if canImport(SwiftUI) && os(macOS)` because the Android cross-compilation also runs on macOS. The `SWIFTOPENUI_BACKEND` define from the swift-lib package is no longer available.

**Current workaround:** Android uses a flat `AndroidStateDemoView` defined privately in `JNIBridge.swift` instead of importing from shared examples. This duplicates the view definition but avoids the import conflict.

**Future fix:** Implement a structural state store (keyed by node ID) so composed child views work on Android. Then `StateDemoRootView` from shared examples would work directly.

### Flat @State Requirement

Android interactive examples must define all `@State` on a single root struct. Composed child views with their own `@State` (like `CounterSection`, `GestureDemo`) don't persist state across renders. This is a separate limitation from the package split — it's how the Android JSON bridge works without per-view hosts.

### Build Cache Fragility

`rm -rf .build` breaks Android cross-compilation because SPM loses the module resolution cache for `aarch64`. Instead of full cache clear, clear only the macro cache:

```bash
rm -rf .build/arm64-apple-macosx/debug/Modules-tool/
```

Or re-run the SDK setup after clearing:

```bash
ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/29.0.14206865 \
  ~/Library/org.swift.swiftpm/swift-sdks/...android.../scripts/setup-android-sdk.sh
```

## Lessons Learned

1. **Unit tests are necessary but not sufficient** for cross-compilation. The session rebuild test passed on macOS but the same code failed in the ARM64 `.so`.

2. **Package dependency graphs affect module identity** in Swift cross-compilation. A separate package depending on the root package can produce different protocol witnesses than building from the root directly.

3. **Use `--triple aarch64-unknown-linux-android28`** — without it the SDK defaults to armv7. The earlier Foundation module resolution failure was caused by misconfigured `swiftResourcesPath`, not by `--triple` itself. Fix with `swift sdk configure --swift-resources-path .../swift-aarch64`.

4. **Avoid `rm -rf .build`** during Android development. Use targeted cache clears instead.

5. **Debug logging in Swift doesn't reach Android logcat** — `print()` goes to stdout which isn't captured. Use Kotlin-side logging via JNI callbacks for debugging.
