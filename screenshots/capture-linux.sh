#!/bin/bash
# Capture screenshots of all examples on Linux (GTK4).
# Requires: gnome-screenshot, a running display server.
#
# Usage:
#   ./screenshots/capture-linux.sh
#   ./screenshots/capture-linux.sh HelloWorld    # capture one example

set -e
cd "$(dirname "$0")/.."

OUTDIR="screenshots/linux"
mkdir -p "$OUTDIR"

DELAY=3  # seconds to wait for window to appear

# Map of target name → screenshot filename
declare -A FILENAMES=(
    # Showcase
    [HelloWorld]="showcase-HelloWorld"
    [Stopwatch]="showcase-Stopwatch"
    [ColorMixer]="showcase-ColorMixer"
    [Calculator]="showcase-Calculator"
    # Parity
    [ParityViewsBasic]="parity-ViewsBasic"
    [ParityViewsLayout]="parity-ViewsLayout"
    [ParityViewsContainers]="parity-ViewsContainers"
    [ParityModifiers]="parity-Modifiers"
    [ParityStateData]="parity-StateData"
    [ParityNavigation]="parity-Navigation"
    [ParityEnvironment]="parity-Environment"
    [ParityGestures]="parity-Gestures"
    [ParityAnimation]="parity-Animation"
    [ParityFocus]="parity-Focus"
    [ParityAppStructure]="parity-AppStructure"
)

TARGETS=(
    HelloWorld Stopwatch ColorMixer Calculator
    ParityViewsBasic ParityViewsLayout ParityViewsContainers
    ParityModifiers ParityStateData ParityNavigation
    ParityEnvironment ParityGestures ParityAnimation
    ParityFocus ParityAppStructure
)

capture_one() {
    local target="$1"
    local filename="${FILENAMES[$target]:-$target}"
    local outfile="$OUTDIR/${filename}.png"

    echo "==> Capturing $target → $outfile"

    # Build first
    swift build --product "$target" 2>/dev/null

    # Launch in background
    local bindir
    bindir=$(swift build --product "$target" --show-bin-path 2>/dev/null)
    "$bindir/$target" &>/dev/null &
    local pid=$!

    # Wait for window to appear and settle
    sleep "$DELAY"

    # Capture the most recent window
    gnome-screenshot --window --file="$outfile" 2>/dev/null || \
        gnome-screenshot --file="$outfile" 2>/dev/null || \
        echo "    WARNING: gnome-screenshot failed for $target"

    # Kill the example
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null || true

    if [ -f "$outfile" ]; then
        echo "    Saved: $outfile ($(du -h "$outfile" | cut -f1))"
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
    echo "Done. Screenshots saved to $OUTDIR/"
    ls -la "$OUTDIR/"
fi
