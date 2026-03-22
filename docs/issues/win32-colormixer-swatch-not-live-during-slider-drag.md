# Win32 ColorMixer Swatch Does Not Live-Update During Slider Drag

## Summary

The Win32 incremental reconcile spike improved slider survival during drag and enabled some dependent text updates, but the main ColorMixer swatch still does not reliably live-update while the slider is being dragged.

Observed runtime result:

- slider thumb remains responsive during drag
- RGB / hex labels can update during drag
- main color swatch still appears stale until release
- no obvious flicker or subtree destruction during drag
- overall interaction remains slower than desired

This is the point where the current HWND-first reconcile spike should stop. Further patching on top of the same model is likely to produce churn rather than a robust solution.

## What The Spike Proved

The spike did produce useful information.

Confirmed:

- preserving the live slider `HWND` during pointer capture is necessary
- broad reuse based on raw Win32 class names is unsafe
- Win32-local backend node kinds are a better identity layer than raw class names
- some in-place updates are straightforward:
  - `Text` via `SetWindowTextW`
  - D2D-backed leaf state via callback transfer
- safe fallback to full rebuild is still required for mismatches

Not proven:

- reliable live swatch updates through the current create-then-adopt `HWND` path
- efficient drag-time updates without building a full temp subtree every time
- a clean layout contract for nested wrappers using temp-tree state as an update source

## Why The Current Approach Stalls Out

The current spike still works like this:

1. build a fresh temp `HWND` subtree
2. compare old vs new Win32-local node kinds
3. transfer some state from temp to preserved `HWND`s
4. destroy the temp subtree

That model is enough to prove some reuse, but it has hard limits.

### 1. Temp subtree creation remains on the critical drag path

Even on the "safe reconcile" path, drag-time updates still create and destroy a full temp subtree. That is expensive and keeps interactive performance tied to full subtree construction cost.

### 2. The temp tree is not a clean source of truth for preserved layout

The preserved tree owns real parent-assigned geometry. The temp tree only reflects a parallel rebuild inside a temporary parent. Trying to use temp-tree wrapper state while preserving old parent geometry creates an awkward split:

- preserved parents own actual layout allocation
- temp children hold freshly rebuilt semantic state
- reconcile has to decide which fields are authoritative case by case

This is manageable for a few leaf updates, but fragile for nested wrappers.

### 3. Live D2D leaf repaint is still not enough to guarantee the visible swatch updates

The main ColorMixer swatch path is:

- `current.color`
- `.frame(width: 120, height: 80)`
- `.border(...)`

The border is not a separate retained wrapper; it mutates the returned `HWND` style in place. The remaining failure therefore is not just "class matching is wrong." It is deeper in how the preserved wrapper chain and D2D repaint interact under the current temp-tree reconcile model.

### 4. The host still rebuilds the whole body

Even with better Win32-local identity, `Win32ViewHost` still fundamentally thinks in terms of rebuilding the full hosted body. That prevents this spike from becoming true small-scope interactive invalidation.

## Conclusion

This issue should be treated as a spike limit, not as a small remaining bug.

The current HWND-first create-then-adopt reconcile path is good enough to prove:

- platform-node reuse can help
- backend node identity matters
- some live dependent updates are possible

But it is not a solid foundation for reliable live Color swatch updates in ColorMixer.

## Recommended Next Step

Move to the descriptor-first / backend-node-first path described in:

- `docs/plans/win32-minimal-path-to-swiftui-like-invalidation.md`

Specifically:

1. build a backend descriptor tree before creating `HWND`s
2. reconcile descriptors against retained backend nodes
3. create, update, or replace `HWND`s only after the reconcile decision
4. add subtree-local rebuildability before chasing more drag-time polish

That is the path that can eventually support:

- safe structural identity
- dirty-subtree rebuilds
- reliable live dependent updates during drag
- lower steady-state interactive cost

## Practical Recommendation For This Branch

Keep the safe results from the spike:

- slider drag no longer destroys the control mid-capture
- Win32-local backend node identity exists
- reconcile safety is better than the original class-name experiment

Do not continue extending the current temp-`HWND` reconcile path in hopes of making the swatch fully reliable.

The remaining work should be architectural, not another local patch round.
