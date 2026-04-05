# Web Animation Batch A — Implementation Plan

**Status: Implemented**

## Goal

Make `.animation()` and `withAnimation()` work on Web for rebuild-driven state changes. Previously, Web applied CSS `transition` on initial render only. On rebuild, the host nukes the DOM (`innerHTML = ""`), so new elements had no prior state for CSS to interpolate from.

## Approach: Constrained Hybrid

Three coordinated changes:

1. **TLS scoping + host capture** — necessary plumbing for animation context
2. **Marker attributes on animatable wrappers** — identity signal for old↔new pairing
3. **Pre/post scan in rebuild with strict matching** — two-phase CSS transition

---

## Step 1: TLS Scoping + Host Capture

### 1a. `AnimatedView.webCreateElement()` — scope TLS for subtree

**File:** `Sources/Backend/Web/Rendering/WebRenderer.swift` (line 330)

Current code just applies `transition` to the content element. Change to also scope `currentAnimation` into TLS so descendant modifier renderers can see it:

```swift
extension AnimatedView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let previous = getCurrentAnimation()
        setCurrentAnimation(animation)
        defer { setCurrentAnimation(previous) }

        let element = webRenderView(content)
        if let anim = animation ?? previous {
            let timing = webCSSTimingFunction(anim.curve)
            _ = element.style.setProperty("transition", "all \(anim.duration)s \(timing)")
        }
        return element
    }
}
```

### 1b. `WebViewHost` — add animation fields

**File:** `Sources/Backend/Web/Rendering/WebViewHost.swift`

Add two fields (same pattern as Win32ViewHost):

```swift
/// Animation from wrapping .animation() modifier — persistent across rebuilds.
private var capturedAnimation: Animation?

/// Animation from withAnimation() — one-shot, consumed during next rebuild.
private var pendingAnimation: Animation?
```

### 1c. Capture at `scheduleRebuild()` time

In `scheduleRebuild()`, before the early returns, snapshot `getCurrentAnimation()`:

```swift
public func scheduleRebuild() {
    let currentAnim = getCurrentAnimation()
    if let currentAnim {
        pendingAnimation = currentAnim
    }
    // ... existing guard/scheduled logic ...
}
```

Also capture in `endInteractiveUpdate()` the same way.

### 1d. Capture scoped `.animation()` during initial render

In `webRenderStatefulView()`, after `host.capturedEnvironment = previousEnv`, add:

```swift
host.captureAnimation()
```

Add the method to `WebViewHost`:

```swift
public func captureAnimation() {
    capturedAnimation = getCurrentAnimation()
}
```

### 1e. Restore animation context in `rebuild()`

In `rebuild()`, before `buildBodyWithTracking()`:

```swift
let previousAnim = getCurrentAnimation()
let rebuildAnim = pendingAnimation ?? capturedAnimation
pendingAnimation = nil
if let rebuildAnim {
    setCurrentAnimation(rebuildAnim)
}
defer { setCurrentAnimation(previousAnim) }
```

---

## Step 2: Marker Attributes on Animatable Wrappers

### 2a. Mark wrapper divs with `data-anim-role`

Each animatable modifier renderer stamps its wrapper div with a data attribute identifying what it animates. This gives the rebuild scanner a stable identity signal.

**File:** `Sources/Backend/Web/Rendering/WebRenderer.swift`

**OpacityView** (line 299):
```swift
extension OpacityView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let wrapper = document.createElement("div")
        wrapper.style = .string("display: inline-block; opacity: \(opacity);")
        wrapper.dataset.animRole = .string("opacity")
        _ = wrapper.appendChild(child)
        return wrapper
    }
}
```

**OffsetView** (line 309):
```swift
wrapper.dataset.animRole = .string("offset")
```

**ScaleEffectView** (line 319):
```swift
wrapper.dataset.animRole = .string("scale")
```

**RotationView** (line 1541):
```swift
wrapper.dataset.animRole = .string("rotation")
```

Note: `dataset` access may need to go through `setAttribute` depending on JavaScriptKit API:
```swift
_ = wrapper.setAttribute("data-anim-role", "opacity")
```

---

## Step 3: Pre/Post Scan in Rebuild with Strict Matching

### 3a. Helper: collect animatable wrappers from a DOM subtree

```swift
/// Depth-first collection of DOM nodes with data-anim-role attribute.
/// Returns [(role: String, element: JSValue)] in traversal order.
private func collectAnimatableWrappers(from root: JSValue) -> [(role: String, element: JSValue)] {
    var result: [(role: String, element: JSValue)] = []
    collectAnimatableWrappersRecursive(root, into: &result)
    return result
}

private func collectAnimatableWrappersRecursive(
    _ node: JSValue, into result: inout [(role: String, element: JSValue)]
) {
    if let role = node.getAttribute("data-anim-role").string {
        result.append((role: role, element: node))
    }
    let children = node.children
    let count = Int(children.length.number ?? 0)
    for i in 0..<count {
        collectAnimatableWrappersRecursive(children[i], into: &result)
    }
}
```

### 3b. Helper: read animatable values from a wrapper

```swift
struct AnimatableSnapshot {
    let role: String
    let opacity: String?      // "0.5"
    let transform: String?    // "translate(10px, 20px)"
}

private func snapshotWrapper(_ wrapper: JSValue, role: String) -> AnimatableSnapshot {
    let style = JSObject.global.getComputedStyle!(wrapper)
    return AnimatableSnapshot(
        role: role,
        opacity: role == "opacity" ? style.opacity.string : nil,
        transform: (role == "offset" || role == "scale" || role == "rotation")
            ? style.transform.string : nil
    )
}
```

### 3c. Modify `rebuild()` — two-phase animation

In `rebuild()`, after determining the animation is active:

```swift
func rebuild() {
    scheduled = false

    // ... existing input snapshot check ...

    // --- Animation pre-scan ---
    let rebuildAnim = pendingAnimation ?? capturedAnimation
    pendingAnimation = nil

    var oldSnapshots: [(role: String, snapshot: AnimatableSnapshot)] = []
    if rebuildAnim != nil, let oldChild = container.firstChild {
        let wrappers = collectAnimatableWrappers(from: oldChild)
        oldSnapshots = wrappers.map { (role: $0.role, snapshot: snapshotWrapper($0.element, role: $0.role)) }
    }

    // Release old state, nuke DOM
    clear()
    // ... existing sheet tracking ...
    container.innerHTML = ""

    // Restore animation TLS for this rebuild
    let previousAnim = getCurrentAnimation()
    if let rebuildAnim {
        setCurrentAnimation(rebuildAnim)
    }

    // Build new DOM
    WebViewHost.withHost(self) {
        let previousEnv = getCurrentEnvironment()
        setCurrentEnvironment(capturedEnvironment)
        beginDependencyTracking()
        let element = buildBodyWithTracking()
        if let tracking = endDependencyTracking() {
            lastReadSet = tracking.readSet
            lastInputSnapshot = tracking.snapshots
        }
        setCurrentEnvironment(previousEnv)
        _ = container.appendChild(element)
    }

    setCurrentAnimation(previousAnim)

    // --- Animation post-scan + two-phase transition ---
    if let anim = rebuildAnim, let newChild = container.firstChild {
        let newWrappers = collectAnimatableWrappers(from: newChild)

        // STRICT GUARD: only animate if wrapper sequences match exactly
        let rolesMatch = oldSnapshots.count == newWrappers.count
            && zip(oldSnapshots, newWrappers).allSatisfy { $0.role == $1.role }

        if rolesMatch && !oldSnapshots.isEmpty {
            let timing = webCSSTimingFunction(anim.curve)
            let transitionValue = "all \(anim.duration)s \(timing)"

            // Phase 1: apply old values to new wrappers + set transition
            for (i, wrapper) in newWrappers.enumerated() {
                let old = oldSnapshots[i].snapshot
                if let opacity = old.opacity {
                    _ = wrapper.element.style.setProperty("opacity", opacity)
                }
                if let transform = old.transform {
                    _ = wrapper.element.style.setProperty("transform", transform)
                }
                _ = wrapper.element.style.setProperty("transition", transitionValue)
            }

            // Phase 2: on next frame, remove overrides → CSS interpolates to new values
            let refs = newWrappers.map { $0.element }
            let callback = webMakeClosure { _ in
                for el in refs {
                    // Remove the old-value overrides; the inline style from the
                    // modifier renderer has the new values, CSS transitions kick in.
                    _ = el.style.removeProperty("opacity")
                    _ = el.style.removeProperty("transform")
                    // Note: transition property stays so the interpolation runs
                }
                return .undefined
            }
            _ = JSObject.global.requestAnimationFrame!(callback)
        }
    }

    // ... existing sheet transition detection ...
}
```

### 3d. Extract CSS timing function helper

Used by both `AnimatedView` and the rebuild path:

```swift
func webCSSTimingFunction(_ curve: Animation.Curve) -> String {
    switch curve {
    case .linear: return "linear"
    case .easeIn: return "ease-in"
    case .easeOut: return "ease-out"
    case .easeInOut: return "ease-in-out"
    case .spring: return "cubic-bezier(0.5, 1.8, 0.3, 0.8)"
    }
}
```

---

## Important Details

### Phase 2 "remove overrides" mechanism

The modifier renderers set values via inline `style` attribute (e.g. `opacity: 0.5`). The rebuild animation overrides these with old values via `style.setProperty()`. On the next frame, we remove those overrides. But the original inline style string (set by the renderer) already has the new values — so after removing the override, the element returns to the renderer-set values, and CSS transition interpolates.

**Caveat**: This depends on `style.setProperty("opacity", oldValue)` overriding the inline attribute's opacity, and `style.removeProperty("opacity")` reverting to the inline attribute value. Need to verify this works correctly in the browser — the inline `style` attribute and the `style` object are the same thing. If `setProperty` overwrites the renderer's value, we need to save and restore the renderer's value explicitly instead of using `removeProperty`.

**Safer alternative**: Save the new value from the renderer's inline style, then:
1. Set old value
2. Set transition
3. RAF → set new value (saved) explicitly

This is more robust:

```swift
// Phase 1: save new values, apply old values
for (i, wrapper) in newWrappers.enumerated() {
    let old = oldSnapshots[i].snapshot
    let el = wrapper.element

    // Save new computed values before overwriting
    let newStyle = JSObject.global.getComputedStyle!(el)
    let newOpacity = newStyle.opacity.string
    let newTransform = newStyle.transform.string

    // Apply old values
    if let opacity = old.opacity { _ = el.style.setProperty("opacity", opacity) }
    if let transform = old.transform { _ = el.style.setProperty("transform", transform) }
    _ = el.style.setProperty("transition", transitionValue)

    // Store new values for phase 2
    // (use data attributes or closure capture)
}

// Phase 2: RAF → apply new values
// (triggers CSS interpolation from old → new)
```

---

## Scope / Not In Scope

**In scope:**
- `.animation(.easeIn)` + state change → animates opacity/offset/scale/rotation
- `withAnimation(.easeIn) { flag.toggle() }` → animates opacity/offset/scale/rotation
- Strict match guard: if tree shape changes, skip animation silently (no glitches)

**Not in scope:**
- `.animation(_, value:)` dependency tracking (core gap, affects all backends)
- `.animation(nil)` suppression (needs tri-state TLS in core)
- Transition API (appearance/disappearance)
- Animating native HTML controls (button, input, etc.)
- Multi-property transitions (per-property control)

---

## Files Changed

| File | Change |
|------|--------|
| `Sources/Backend/Web/Rendering/WebRenderer.swift` | AnimatedView TLS scoping, modifier data-anim-role attributes, webCSSTimingFunction helper |
| `Sources/Backend/Web/Rendering/WebViewHost.swift` | capturedAnimation/pendingAnimation fields, capture in scheduleRebuild/initial render, two-phase rebuild animation |
| `Tests/BackendTests/WebTests/WebAnimationTests.swift` | New test file (TLS scoping, timing function, marker attributes) |

---

## Test Plan

1. `webCSSTimingFunction` returns correct strings for all 5 curves
2. `AnimatedView.webCreateElement` sets/restores `currentAnimation` TLS
3. `OpacityView` wrapper has `data-anim-role="opacity"` attribute
4. `OffsetView` wrapper has `data-anim-role="offset"` attribute
5. `ScaleEffectView` wrapper has `data-anim-role="scale"` attribute
6. `RotationView` wrapper has `data-anim-role="rotation"` attribute
7. `WebViewHost.captureAnimation()` stores current animation
8. `WebViewHost.scheduleRebuild()` captures pending animation
9. Strict match guard: mismatched wrapper counts → no animation (no crash)
10. Manual: run ParityAnimation in browser, verify opacity/scale/offset animate on button tap

## Verification

- `swift build --swift-sdk swift-6.2.4-RELEASE_wasm` (compiles)
- `swift test` on macOS (core tests pass)
- Manual browser test with ParityAnimation example
