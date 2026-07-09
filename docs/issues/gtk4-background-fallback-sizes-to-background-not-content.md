# GTK4: `.background(nonNativeView)` sizes to the background, not the content

## Summary

On GTK4, `.background(someView)` with a **non-native** background (not a
`Color` or `FilledShape`) lowers to the `ZStack`-overlay fallback, which
makes the **background** the overlay's *main (sizing)* child and demotes
the real content to an `add_overlay` child. This inverts SwiftUI's
`.background` semantics — where **content** drives the size and the
background merely stretches behind it — and, critically, **loses the
content's expand flags**: the container inherits the *background's*
`hexpand`/`vexpand`, not the content's.

## Impact (real, found in Synca)

Synca's Compare Result view wrapped its whole `VStack` in
`.background(findShortcutHook)`, where `findShortcutHook` is a zero-size
hidden Button (it hosts the ⌘F/Ctrl+F shortcut). Result: the hidden
button became the sizing child, the real content was trapped at the
button's ~0 natural size, the overlay inherited `vexpand = 0`, and the
whole UI collapsed to natural size and **centered** instead of filling
the window — even though the content correctly set `.frame(maxHeight:
.infinity)`. The content's vexpand propagated up to the `VStack` but
dead-ended at the background overlay.

Workaround in Synca: use `.overlay(hook)` instead of `.background(hook)`
(`OverlayView` makes *content* the sizing child). But any app that uses
`.background(someView)` for its intended purpose (a real view behind
content) will hit this.

## Where

- Non-native background fallback builds the overlay with the background
  first: `Sources/Backend/GTK4/Rendering/GTKRenderer.swift` (~`gtkRenderFallbackZStack` /
  `BackgroundView` fallback, around L1640).
- The fallback propagates expand flags from the **first** child only:
  `Sources/Backend/GTK4/Rendering/GTKRenderer.swift` (~L1063).

For `.background`, the first child is the background → its expand flags
win. For `.overlay`, the first child is the content → correct.

## Proposed fix

Render `BackgroundView`'s non-native fallback as an overlay whose **main
child is the content** and whose background is added *behind* it
(`gtk_overlay_set_child(overlay, content)` + `gtk_overlay_add_overlay`
for the background, with the background positioned/allocated to match).
Then `.background(anyView)` sizes to content and propagates the content's
expand flags — matching SwiftUI and `OverlayView`. Effectively:
`.background(bg)` ≈ `overlay { main: content, behind: bg }`.

## Acceptance

- `content.background(expandingView)` fills its parent when `content`
  wants to expand (content's `hexpand`/`vexpand` reach the container).
- A `Examples/Parity` / layout test: a `VStack` with `.frame(maxHeight:
  .infinity).background(Color-less view)` fills its window on GTK4.
- macOS/other backends unchanged (already content-sized).
