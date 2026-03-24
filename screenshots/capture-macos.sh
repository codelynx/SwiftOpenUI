#!/usr/bin/env zsh
# Capture screenshots of all examples on macOS (SwiftUI).
# Launches each app, captures its window, scales to 50% (Retina → 1x).
#
# Requires: Screen Recording permission for VS Code / Terminal.
#
# Usage:
#   ./screenshots/capture-macos.sh
#   ./screenshots/capture-macos.sh HelloWorld    # capture one example

set -e
cd "$(dirname "$0")/.."

OUTDIR="screenshots/macos"
SCRIPTDIR="screenshots"
mkdir -p "$OUTDIR"

DELAY=3

TARGETS=(
    # Showcase
    HelloWorld Stopwatch ColorMixer Calculator SimplePaint
    # Parity
    ParityViewsBasic ParityViewsLayout ParityViewsContainers
    ParityModifiers ParityStateData ParityNavigation
    ParityEnvironment ParityGestures ParityAnimation
    ParityFocus ParityAppStructure
)
typeset -A FILENAMES
FILENAMES=(
    # Showcase
    HelloWorld          "showcase-HelloWorld"
    Stopwatch           "showcase-Stopwatch"
    ColorMixer          "showcase-ColorMixer"
    Calculator          "showcase-Calculator"
    SimplePaint         "showcase-SimplePaint"
    # Parity
    ParityViewsBasic       "parity-ViewsBasic"
    ParityViewsLayout      "parity-ViewsLayout"
    ParityViewsContainers  "parity-ViewsContainers"
    ParityModifiers        "parity-Modifiers"
    ParityStateData        "parity-StateData"
    ParityNavigation       "parity-Navigation"
    ParityEnvironment      "parity-Environment"
    ParityGestures         "parity-Gestures"
    ParityAnimation        "parity-Animation"
    ParityFocus            "parity-Focus"
    ParityAppStructure     "parity-AppStructure"
)

# Build the window-id helper if needed
if [ ! -x "$SCRIPTDIR/window-capture" ]; then
    echo "Building window-capture helper..."
    swiftc "$SCRIPTDIR/window-capture.swift" -o "$SCRIPTDIR/window-capture" -framework CoreGraphics
fi

capture_one() {
    local target="$1"
    local filename="${FILENAMES[$target]}"
    if [ -z "$filename" ]; then
        echo "Unknown example: $target"
        return 1
    fi

    local outfile="$OUTDIR/${filename}.png"
    local tmpfile="$OUTDIR/${filename}_retina.png"
    echo "Capturing $target..."

    # Build
    swift build --product "$target" 2>&1 | tail -1

    # Launch the binary directly
    local bindir
    bindir=$(swift build --product "$target" --show-bin-path 2>/dev/null)
    "$bindir/$target" &
    local pid=$!
    sleep "$DELAY"

    # Get window ID
    local wid
    wid=$("$SCRIPTDIR/window-capture" "$pid" 2>/dev/null) || true

    if [ -z "$wid" ]; then
        echo "  Warning: could not find window for $target (PID $pid)"
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
        return 1
    fi

    echo "  Window ID: $wid"

    # Capture by window ID
    screencapture -o -x -l "$wid" "$tmpfile"

    if [ -f "$tmpfile" ] && [ -s "$tmpfile" ]; then
        # Scale to 50% (Retina 2x → 1x)
        local width height new_width new_height
        width=$(sips -g pixelWidth "$tmpfile" | tail -1 | awk '{print $2}')
        height=$(sips -g pixelHeight "$tmpfile" | tail -1 | awk '{print $2}')
        new_width=$((width / 2))
        new_height=$((height / 2))
        sips --resampleHeightWidth "$new_height" "$new_width" "$tmpfile" --out "$outfile" >/dev/null 2>&1
        rm -f "$tmpfile"
        echo "  Saved: $outfile (${new_width}x${new_height})"
    else
        echo "  Warning: screencapture failed for $target"
    fi

    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
}

if [ -n "$1" ]; then
    capture_one "$1"
else
    for target in $TARGETS; do
        capture_one "$target"
        sleep 1
    done
    echo ""
    echo "All screenshots saved to $OUTDIR/"
fi
