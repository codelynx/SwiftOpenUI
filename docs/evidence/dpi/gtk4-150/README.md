# GTK4 at 150% — D8 evidence (issue #21)

Captured 2026-10-16 on `develop` at 0db9622, plus the capture hook.
Environment: GNOME Shell 50.1, headless, one 1920×1080 virtual monitor
(Wayland); GTK 4.22.4, Vulkan renderer; aarch64 Linux.

Each window renders itself at its surface's real scale
(`SWIFTOPENUI_GTK_CAPTURE`), so these are the buffers GTK hands the
compositor. GTK 4.12+ uses the Wayland fractional-scale protocol, so the
compositor shows them without resampling.

| File | What it shows |
| --- | --- |
| `probe-1.0.png`, `probe-1.5.png`, `probe-2.0.png` | `ScaleProbe.swift.txt`: fixed frames, borders, shapes, a `Canvas` and text |
| `simplepaint-1.0.png`, `simplepaint-1.5.png` | SimplePaint: a full example at 100% and 150% |
| `zoom-canvas-1.0-1.5-2.0.png` | The Canvas diagonal and circle in device pixels, ×6, at each scale |
| `zoom-hairlines-1.0-1.5-2.0.png` | SimplePaint tool buttons: 1pt borders and bitmap icons at each scale |

At 2.0 the virtual monitor is 960×540 logical points, so windows larger
than that are shrunk to fit; ignore window size in `probe-2.0.png`.

## Measurements

| | 100% | 150% | 200% |
| --- | --- | --- | --- |
| `gdk_surface_get_scale` | 1.0 | 1.5 | 2.0 |
| `gtk_widget_get_scale_factor` | 1 | 2 | 2 |
| Default window (800×600pt) | 800×600px | 1200×900px | n/a (clamped) |
| `Color.red.frame(width: 100, height: 40)` | 100×40px | 150×59px | 200×80px |
| Canvas 1pt diagonal, one row across it | 3px of ink, darkest 23 | 4px, darkest 14 | 5px, darkest 0 |

The 59px height at 150% is the 40pt frame landing on a fractional device
origin: one edge row is antialiased, so it isn't pure red.

## Results

- Layout is unchanged in points; every element is at 1.5× its 100%
  position. No clipping or overflow is introduced by the scale.
- Text and Canvas are rendered at device resolution and are crisp.
- 1pt hairlines (`.border`, native button outlines) are soft at 150%.
  This is expected GTK behavior, not a SwiftOpenUI bug.
- `GDK_SCALE=2` and `GDK_DPI_SCALE=1.5` at 100% produce byte-identical
  output to an unset run.

Seen at every scale, so not part of D8: `Circle().stroke(lineWidth: 1)` is
clipped flat at its left and right edges, and ParityModifiers' "Mixed"
padding label and `.offset()` label are clipped.

## Reproduce

```bash
./screenshots/capture-linux-scaled.sh 1.5 SimplePaint
```

To capture the probe, build `ScaleProbe.swift.txt` as `main.swift` in a
scratch package that depends on this repo's `SwiftOpenUI` and
`BackendGTK4` products. Then run it with
`SWIFTOPENUI_GTK_CAPTURE=<file.png>` against the script's compositor.
