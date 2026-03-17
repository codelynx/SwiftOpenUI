#!/usr/bin/env zsh
# Capture screenshots of all examples on Android (emulator or device).
# Scales to 50% if running on a high-density display (Retina Mac emulator).
#
# Requires:
#   - adb in PATH (Android SDK platform-tools)
#   - emulator running or device connected
#   - APK already installed (com.example.swiftopenui)
#   - sips (macOS) for scaling, or falls back to no scaling
#
# Usage:
#   ./screenshots/capture-android.sh
#   ./screenshots/capture-android.sh HelloWorld    # capture one example

set -e
cd "$(dirname "$0")/.."

OUTDIR="screenshots/android"
mkdir -p "$OUTDIR"

PACKAGE="com.example.swiftopenui"
ACTIVITY="$PACKAGE/.MainActivity"
DELAY=3  # seconds to wait for render

# Density threshold: scale if device density > this value
SCALE_THRESHOLD=320

TARGETS=(HelloWorld TextStyles Buttons StateDemo Layout TextFieldDemo)
typeset -A FILENAMES
FILENAMES=(
    HelloWorld     "01-HelloWorld"
    TextStyles     "02-TextStyles"
    Buttons        "03-Buttons"
    StateDemo      "04-State"
    Layout         "05-Layout"
    TextFieldDemo  "06-TextField"
)

# Check adb
if ! command -v adb &>/dev/null; then
    echo "Error: adb not found. Add Android SDK platform-tools to PATH."
    exit 1
fi

# Pick device: use ANDROID_SERIAL env var, or auto-detect the one with our app
DEVICE=""
if [ -n "$ANDROID_SERIAL" ]; then
    DEVICE="$ANDROID_SERIAL"
elif ! adb shell pm list packages 2>/dev/null | grep -q "$PACKAGE"; then
    # App not on default device — scan all devices
    for dev in $(adb devices | awk 'NR>1 && $2=="device" {print $1}'); do
        if adb -s "$dev" shell pm list packages 2>/dev/null | grep -q "$PACKAGE"; then
            DEVICE="$dev"
            echo "Found app on $dev"
            break
        fi
    done
fi

ADB_ARGS=()
if [ -n "$DEVICE" ]; then
    ADB_ARGS=(-s "$DEVICE")
fi

# Check device/emulator is connected
if ! adb "${ADB_ARGS[@]}" get-state &>/dev/null; then
    echo "Error: No device/emulator connected. Start an emulator first."
    exit 1
fi

# Verify app is installed
if ! adb "${ADB_ARGS[@]}" shell pm list packages 2>/dev/null | grep -q "$PACKAGE"; then
    echo "Error: $PACKAGE not installed. Run the app from Android Studio first."
    exit 1
fi

# Get device density to decide whether to scale
DENSITY=$(adb "${ADB_ARGS[@]}" shell wm density 2>/dev/null | grep -oE '[0-9]+$' || echo "0")
SHOULD_SCALE=false
if [ "$DENSITY" -gt "$SCALE_THRESHOLD" ]; then
    SHOULD_SCALE=true
    echo "Device density: ${DENSITY}dpi (> ${SCALE_THRESHOLD}dpi) — will scale to 50%"
else
    echo "Device density: ${DENSITY}dpi — no scaling needed"
fi

scale_image() {
    local file="$1"
    if [ "$SHOULD_SCALE" = true ] && command -v sips &>/dev/null; then
        local width height new_width new_height
        width=$(sips -g pixelWidth "$file" | tail -1 | awk '{print $2}')
        height=$(sips -g pixelHeight "$file" | tail -1 | awk '{print $2}')
        new_width=$((width / 2))
        new_height=$((height / 2))
        sips --resampleHeightWidth "$new_height" "$new_width" "$file" --out "$file" >/dev/null 2>&1
        echo "  Scaled: ${new_width}x${new_height}"
    fi
}

capture_one() {
    local target="$1"
    local filename="${FILENAMES[$target]}"
    if [ -z "$filename" ]; then
        echo "Unknown example: $target"
        return 1
    fi

    local outfile="$OUTDIR/${filename}.png"
    echo "Capturing $target..."

    # Force-stop then launch with example name as intent extra
    adb "${ADB_ARGS[@]}" shell am force-stop "$PACKAGE" >/dev/null 2>&1
    adb "${ADB_ARGS[@]}" shell am start -n "$ACTIVITY" --es example "$target" >/dev/null 2>&1
    sleep "$DELAY"

    # Scroll to top to ensure content is visible
    adb "${ADB_ARGS[@]}" shell input swipe 540 400 540 1200 300 >/dev/null 2>&1
    sleep 1

    # Capture screenshot
    adb "${ADB_ARGS[@]}" exec-out screencap -p > "$outfile"

    if [ -f "$outfile" ] && [ -s "$outfile" ]; then
        scale_image "$outfile"
        echo "  Saved: $outfile ($(du -h "$outfile" | cut -f1))"
    else
        echo "  Warning: screencap failed for $target"
        rm -f "$outfile"
    fi
}

if [ -n "$1" ]; then
    capture_one "$1"
else
    for target in "${TARGETS[@]}"; do
        capture_one "$target"
        sleep 1
    done
    echo ""
    echo "All screenshots saved to $OUTDIR/"
fi
