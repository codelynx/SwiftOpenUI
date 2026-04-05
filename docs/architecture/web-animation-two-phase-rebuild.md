# Web Animation: Two-Phase Rebuild

## The Problem

CSS transitions interpolate between old and new property values on the same DOM element. But `WebViewHost.rebuild()` destroys the entire DOM subtree (`innerHTML = ""`) and rebuilds from scratch. New elements have no prior computed state, so CSS transitions have nothing to interpolate from.

This is fundamentally different from GTK4 and Win32:
- **GTK4** flattens offset/scale/rotation onto a single widget and can read old values from one child before teardown.
- **Win32** uses a persistent D2D surface with frame-based animation — the surface survives across rebuilds.
- **Web** creates fresh DOM nodes every rebuild.

## The Solution

A two-phase approach: capture old state before teardown, stamp it onto new nodes, then let CSS transitions animate to the new values.

### Phase 1: Capture and Apply Old Values

Before `innerHTML = ""`:
1. Walk the old DOM tree depth-first
2. Find elements marked with `data-anim-role` (only these — never infer from generic `div` structure)
3. Read `getComputedStyle()` for their opacity/transform values
4. Record each as a `WebAnimatableSnapshot` with a composite key (`"role@depth"`)

After rebuilding the new DOM:
1. Walk the new tree the same way
2. Collect `WebAnimatableWrapper` references with the same key format
3. **Strict guard**: key sequences must match exactly AND all keys must be unique
4. Save new computed values from each wrapper
5. Overwrite with old values + set CSS `transition` property

### Phase 2: Trigger Interpolation

On the next `requestAnimationFrame`:
1. Apply the saved new values explicitly to each wrapper
2. The browser's CSS engine interpolates from old → new

```
State change → scheduleRebuild() [captures animation token]
                    ↓
              requestAnimationFrame
                    ↓
              rebuild():
                1. Consume pending animation token
                2. Pre-scan: snapshot old wrappers
                3. innerHTML = ""
                4. Build new DOM with animation TLS active
                5. Post-scan: collect new wrappers
                6. Strict match guard
                7. Phase 1: apply old values + transition
                    ↓
              requestAnimationFrame
                    ↓
                8. Phase 2: apply new values → CSS interpolates
```

## Why Not Morph the DOM?

Keeping the old DOM and updating it in-place (DOM morphing) would avoid the capture/restore cycle entirely. But it requires:
- A descriptor-driven narrow mutation path that works for all view types
- View identity tracking for conditionals and ForEach
- Both are partially built but not complete for Web

The two-phase approach works with the existing full-rebuild architecture.

## The Identity Problem

The hardest part was reliably pairing old↔new wrapper nodes after a full DOM rebuild. Without persistent identity, we use:

- **`data-anim-role` attribute**: Only animatable modifier renderers (`OpacityView`, `OffsetView`, `ScaleEffectView`, `RotationView`) stamp their wrapper divs. No generic divs are considered.
- **Composite key**: `"role@depth"` combines the modifier type with DOM depth from the host root.
- **Uniqueness guard**: If any two wrappers produce the same key (e.g., two `opacity` wrappers at the same depth — sibling reorders), we bail out entirely. This is conservative: some valid cases skip animation, but no wrong-node transitions occur.

This is a structural identity scheme, not a view identity scheme. It works for the common case (one modifier per type per depth level) and safely bails for ambiguous cases.

## Animation Token Lifecycle

Two channels propagate animation context to the rebuild:

| Channel | Set by | Lifetime | Priority |
|---------|--------|----------|----------|
| `capturedAnimation` | `.animation()` wrapper at initial render | Persistent | Fallback |
| `pendingAnimation` | `withAnimation()` at `scheduleRebuild()` time | One-shot, consumed at rebuild entry | Primary |

Critical: `pendingAnimation` is consumed **before** the Phase 7 early return (`inputsUnchanged`). If the rebuild is skipped, the token is still cleared — it cannot leak to a later unrelated rebuild.

During rebuild, the active animation is restored into TLS so subtree renderers (via `getCurrentAnimation()`) see it and can apply CSS `transition` to their own wrappers.

## Known Limitations

- **Same-role siblings at the same depth**: Cannot be reliably paired. Animation is skipped (conservative, correct).
- **Structural changes**: If the wrapper sequence changes between old and new (conditional branches, view insertion/removal), animation is skipped.
- **No per-property control**: Uses `transition: all` — all CSS properties animate together.
- **No appearance/disappearance**: Requires view identity tracking, not yet available.
