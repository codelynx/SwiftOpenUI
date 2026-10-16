#!/bin/bash
# Capture GTK4 examples at a given display scale, including fractional ones.
#
# Starts a private headless GNOME Shell with a 1920x1080 virtual monitor on
# its own D-Bus session, sets the monitor scale, and has each example render
# its own window to PNG (SWIFTOPENUI_GTK_CAPTURE; see GTKCapture.swift). The
# desktop you are logged into is not touched.
#
# Requires: gnome-shell (GNOME 45+), dbus-run-session, a GTK 4.12+ build.
#
# Usage:
#   ./screenshots/capture-linux-scaled.sh 1.5                  # all examples
#   ./screenshots/capture-linux-scaled.sh 1.5 HelloWorld        # one example
#   OUTDIR=/tmp/out ./screenshots/capture-linux-scaled.sh 2.0
#
# Scales the virtual monitor supports: 1.0 1.25 1.333 1.5 1.666 2.0.
# The monitor is 1280x720 logical points at 1.5 and 960x540 at 2.0, so
# windows larger than that are shrunk to fit.

set -e
cd "$(dirname "$0")/.."

if [ -z "$SOU_INNER" ]; then
    [ -n "$1" ] || { echo "usage: $0 <scale> [target...]" >&2; exit 2; }
    # Re-run inside a private session bus; unset the parent's display. The
    # session's own services are noisy on stderr; SOU_VERBOSE=1 keeps it.
    if [ -n "$SOU_VERBOSE" ]; then
        exec env -u WAYLAND_DISPLAY -u DISPLAY SOU_INNER=1 dbus-run-session -- "$0" "$@"
    fi
    exec env -u WAYLAND_DISPLAY -u DISPLAY SOU_INNER=1 dbus-run-session -- "$0" "$@" 2>/dev/null
fi

SCALE="$1"; shift
OUTDIR="${OUTDIR:-screenshots/linux-scale-$SCALE}"
mkdir -p "$OUTDIR"
OUTDIR="$(cd "$OUTDIR" && pwd)"

TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
    TARGETS=(
        HelloWorld Stopwatch ColorMixer Calculator SimplePaint
        ParityViewsBasic ParityViewsLayout ParityViewsContainers
        ParityModifiers ParityStateData ParityNavigation
        ParityEnvironment ParityGestures ParityAnimation
        ParityFocus ParityAppStructure
    )
fi

# Wayland socket paths are limited to 108 bytes, so keep the runtime dir short.
RUNTIME="$(mktemp -d /tmp/sou-XXXXXX)"
CONFIG="$RUNTIME/config"
mkdir -p "$CONFIG"
SOCKET=sou-wl
export XDG_RUNTIME_DIR="$RUNTIME"

XDG_CONFIG_HOME="$CONFIG" gnome-shell --headless --wayland --no-x11 \
    --wayland-display="$SOCKET" --virtual-monitor 1920x1080 \
    > "$RUNTIME/shell.log" 2>&1 &
SHELL_PID=$!
trap 'kill $SHELL_PID 2>/dev/null; wait $SHELL_PID 2>/dev/null; rm -rf "$RUNTIME"' EXIT

display_config() {
    gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
        --object-path /org/gnome/Mutter/DisplayConfig \
        --method "org.gnome.Mutter.DisplayConfig.$1" "${@:2}"
}

for _ in $(seq 30); do
    [ -S "$RUNTIME/$SOCKET" ] && display_config GetCurrentState >/dev/null 2>&1 && break
    sleep 1
done
[ -S "$RUNTIME/$SOCKET" ] || { echo "gnome-shell did not start:"; cat "$RUNTIME/shell.log"; exit 1; }

# Apply the scale temporarily (method 1) to the single virtual monitor.
STATE="$(display_config GetCurrentState)"
SERIAL="$(sed -E 's/^\(uint32 ([0-9]+),.*/\1/' <<< "$STATE")"
CONNECTOR="$(grep -o -E "\(\('[^']+'" <<< "$STATE" | head -1 | cut -d"'" -f2)"
MODE="$(grep -o -E "'[0-9]+x[0-9]+@[0-9.]+'" <<< "$STATE" | head -1 | tr -d "'")"
display_config ApplyMonitorsConfig "$SERIAL" 1 \
    "[(0, 0, $SCALE, 0, true, [('$CONNECTOR', '$MODE', @a{sv} {})])]" "@a{sv} {}" >/dev/null
echo "==> $CONNECTOR $MODE at scale $SCALE → $OUTDIR"

BINDIR="$(swift build --show-bin-path)"
for target in "${TARGETS[@]}"; do
    swift build --product "$target" 2>&1 | grep -E "error:" || true
    WAYLAND_DISPLAY="$SOCKET" SWIFTOPENUI_GTK_CAPTURE="$OUTDIR/$target.png" \
        timeout 30 "$BINDIR/$target" 2>&1 | grep '^swiftopenui-capture:' || \
        echo "    WARNING: no capture for $target"
done
