#!/usr/bin/env zsh
# Build the BackendAndroid .so and copy it + Swift runtime to the Android project.
set -e
cd "$(dirname "$0")/../.."

echo "Building BackendAndroid for Android ARM64..."
source ~/.swiftly/env.sh
swiftly use 6.3-snapshot 2>&1 | tail -1

swift build \
    --swift-sdk swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android \
    --triple aarch64-unknown-linux-android28 \
    --product BackendAndroid \
    -c release 2>&1 | tail -1

SO_PATH=$(find .build/aarch64-unknown-linux-android28/release -name "libBackendAndroid.so" | head -1)
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
