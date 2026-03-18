#!/usr/bin/env zsh
# Build the BackendAndroid .so and copy it + Swift runtime to the Android project.
# Builds from the root Package.swift (not swift-lib — see docs/issues/android-package-split-regression.md)
set -e
cd "$(dirname "$0")/../.."

echo "Building BackendAndroid for Android ARM64..."
source ~/.swiftly/env.sh

# Use the 6.3 snapshot for this build (best effort — fallback may change global selection)
SWIFT_TOOLCHAIN=$(swiftly list-available 2>/dev/null | grep 6.3-snapshot | head -1 || echo "6.3-snapshot")
TOOLCHAIN_BIN=~/.swiftly/toolchains/swift-DEVELOPMENT-SNAPSHOT-2026-03-05-a/usr/bin

if [ -d "$TOOLCHAIN_BIN" ]; then
    export PATH="$TOOLCHAIN_BIN:$PATH"
    echo "Using toolchain: $("$TOOLCHAIN_BIN/swift" --version 2>&1 | head -1)"
else
    echo "Warning: 6.3 snapshot toolchain not found at $TOOLCHAIN_BIN"
    echo "Falling back to 'swiftly run 6.3-snapshot' — this may change your global selection."
    swiftly use 6.3-snapshot 2>&1 | tail -1
fi

swift build \
    --swift-sdk swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android \
    --triple aarch64-unknown-linux-android28 \
    --product BackendAndroid \
    -c release 2>&1 | tail -1

SO_PATH=$(find .build -path "*/aarch64*/release/libBackendAndroid.so" | head -1)
JNILIBS="android/renderer/app/app/src/main/jniLibs/arm64-v8a"
mkdir -p "$JNILIBS"

echo "Copying libBackendAndroid.so..."
cp "$SO_PATH" "$JNILIBS/"

echo "Copying Swift runtime libraries..."
SWIFT_LIBS=~/Library/org.swift.swiftpm/swift-sdks/swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android.artifactbundle/swift-android/swift-resources/usr/lib/swift-aarch64/android
NDK_LIBS=~/Library/Android/sdk/ndk/29.0.14206865/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android

cp "$SWIFT_LIBS"/*.so "$JNILIBS/"
cp "$NDK_LIBS/libc++_shared.so" "$JNILIBS/"

echo "Done. $(ls "$JNILIBS" | wc -l | tr -d ' ') libraries in $JNILIBS/"
echo ""
echo "Open android/renderer/app/ in Android Studio and run."
