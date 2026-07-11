# Debugging Win32 layout & clipping

Practical notes for the `BackendWin32` renderer. The headline rule, learned
the hard way:

> **When a control looks clipped or truncated, check the actual window
> geometry FIRST — not text measurement, not DPI.**

## Why this rule exists

Chasing a clipped D2D dropdown value ("Source Wins" cut off in the trigger)
cost many build/test cycles down the wrong layers:

- DirectWrite-vs-GDI text-measurement mismatch — *not it*
- DPI scaling (`GetDpiForWindow`) — *not it* (`dpi = 96`)
- Widening sizing buffers — *masked nothing*

The trigger window was correctly sized (141px). Its **parent container** was
130px — constrained by an app-side `.frame(maxWidth: 130)` left over from the
control it replaced. **Win32 always clips a child to its parent's client
rect** (independent of `WS_CLIPCHILDREN`), so the extra 11px of the trigger
simply wasn't drawn. One geometry dump made it obvious; every measurement
theory was noise.

## The first move: dump the geometry

Walk the control and its parent chain and compare widths. A child wider than
its parent is the clip — then look up the chain for the mis-sized container
(often an app `.frame(maxWidth:)`/`.frame(width:)` or a stack that sized to
the wrong intrinsic width).

```
EnumChildWindows(top, cb, 0)
  -> for each: GetClassNameW (see gotcha), GetWindowRect / GetClientRect
  -> print class + width + parent width
```

If you're driving from outside the process (PowerShell + P/Invoke), the same
`EnumChildWindows`/`GetWindowRect` works against the live window.

## Gotchas that will waste your time

- **Children clip to the parent client rect regardless of
  `WS_CLIPCHILDREN`.** Removing `WS_CLIPCHILDREN` does *not* let a child draw
  outside its parent — it only controls whether the parent paints over
  children. Fix the parent's size, not the clip style.
- **`GetClassNameW` must be UTF-16 marshaled** (`CharSet.Unicode`) or class
  names come back truncated to a single character (`"S"` for `SwiftUIStack`,
  `"E"` for `Edit`) — enough to send you looking for the wrong window.
- **D2D draws in DIPs; `GetClientRect` returns device pixels.** They're equal
  at 96 DPI, so this is a red herring there — but if you *are* on a scaled
  display, confirm the render-target DPI before "fixing" measurements. Verify
  the geometry hypothesis first either way.
- **`measureText` (GDI) and `D2DRenderer.measureText` (DirectWrite) disagree
  by a few px.** Real, but rarely the cause of a *visible* clip — a control
  sized to the widest option with a small pad tolerates it. Don't start here.

## Order of operations

1. Dump geometry (control + parents). Is any child wider than its parent?
   → fix the container / app-side frame constraint. **Usually stops here.**
2. Only if geometry is clean: check the render-target DPI vs the DPI your
   measurements assume.
3. Only then: reconcile GDI vs DirectWrite measurement.

See also: [`architecture/rendering-backends.md`](../architecture/rendering-backends.md),
and the Win32 layout code in `LayoutEngine.swift` / `Win32ViewHost.swift`.
