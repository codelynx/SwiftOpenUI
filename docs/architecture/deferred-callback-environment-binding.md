# Deferred Callback Environment Binding

## Summary

Some SwiftOpenUI backends use an ambient "current environment" while rendering. That works for
body evaluation, but it is not enough for callbacks that are registered during render and invoked
later by the platform.

The rule is:

- render-time body work must run under the correct current environment
- delayed callbacks that may read `@Environment(...)` must capture and reinstall the render-time
  environment when they are registered

This note documents the Win32 failure that exposed the issue, the fix pattern, and what other
backends should audit.

## Background

SwiftOpenUI supports two environment read styles:

- key-path values such as `.environment(\.buttonStyle, value)`
- injected reference objects such as `.environment(model)` read via `@Environment(Model.self)`

For injected objects, `@Environment(T.self)` resolves through the current environment at read time.
In practice that means:

1. an ancestor modifier temporarily installs a modified environment
2. descendant bodies read from that ambient environment while rendering
3. the modifier restores the previous environment after descendant rendering returns

On native backends this ambient environment is backend-managed state:

- Win32 uses thread-local storage
- GTK uses thread-local storage
- Web uses a single-threaded global current environment

The important constraint is the same on all three: the current environment is a render-scope value,
not a general-purpose lifetime container for later callbacks.

## The Win32 Failure

The confirmed Win32 crash came from `Win32ReviewSmoke`.

Observed shape:

1. `.environment(model)` pushed `ReviewModel` into the current environment
2. `Win32ReviewView` and `ObservableCounterView` rendered successfully
3. `@Environment(ReviewModel.self)` returned the injected object during render
4. the modifier restored the previous environment after render completed
5. a native button callback fired later and re-read `@Environment(ReviewModel.self)`
6. the lookup failed because current environment no longer contained `ReviewModel`

This was initially easy to misread as:

- a missing injection
- a broken `ReviewModel`
- or a generic Observation failure

It was none of those.

The real bug was that the callback executed outside render scope, while `@Environment(T.self)`
still depended on ambient current-environment state.

## Two Different Environment Problems

These need different fixes.

### 1. Render-time re-entry

Examples:

- initial stateful render
- rebuild
- descriptor capture

These paths are still rendering bodies, just not necessarily from the original modifier stack.
The fix here is host-owned environment reinstall, such as Win32's
`installEffectiveEnvironment()`.

### 2. Delayed callback dispatch

Examples:

- button actions
- menu item commands
- navigation pushes
- gesture handlers
- `onAppear`
- `onDisappear`

These are not body-render paths. They happen later, after the original render scope has ended.
Host reinstall alone does not help, because the callback may not go through a host rebuild entry.

The fix here is callback binding: capture the current environment at registration time, then
save/restore it around callback execution later.

## Correct Fix Pattern

Win32 now uses this pattern in `Sources/Backend/Win32/Rendering/WinRenderer.swift`:

```swift
func bindActionToCurrentEnvironment(_ action: @escaping () -> Void) -> () -> Void {
    let capturedEnvironment = getCurrentEnvironment()
    return {
        let previousEnvironment = getCurrentEnvironment()
        setCurrentEnvironment(capturedEnvironment)
        defer { setCurrentEnvironment(previousEnvironment) }
        action()
    }
}

func bindActionToCurrentEnvironment<T>(_ action: @escaping (T) -> Void) -> (T) -> Void {
    let capturedEnvironment = getCurrentEnvironment()
    return { value in
        let previousEnvironment = getCurrentEnvironment()
        setCurrentEnvironment(capturedEnvironment)
        defer { setCurrentEnvironment(previousEnvironment) }
        action(value)
    }
}
```

The important properties are:

- capture happens at render time, when the correct environment is active
- callback execution later saves the then-current environment and restores it afterwards
- nested callback execution composes correctly because each layer saves/restores independently
- the generic overload covers payload-bearing callbacks like gestures and expansion handlers

## Where to Apply the Binding

Bind at the registration boundary, not later.

Good:

- when storing a native button action
- when registering a menu command
- when creating a gesture handler object
- when boxing an `onDisappear` closure
- when scheduling deferred work with a main-thread or timer callback

Bad:

- wrapping only at dispatch time after render has already finished
- relying on whatever environment happens to be current when the platform fires the callback

This distinction mattered in Win32 `DisclosureGroup`: the first attempt rebound the callback at
dispatch time, which just captured already-empty current environment. The correct fix was to bind
the `(Bool) -> Void` callback itself when the view was rendered.

## What Win32 Had to Cover

The Win32 audit ended up covering these delayed-callback boundaries:

- `Button`
- `NavigationLink`
- `Menu` item actions
- `onAppear`
- `onDisappear`
- `DisclosureGroup`
- `onTapGesture`
- `onLongPressGesture`
- `onDrag` (`onChanged` and `onEnded`)

This is intentionally broader than a single smoke-test fix. Once one backend proves the bug class,
it is usually worth auditing every similar delayed callback on that backend.

## Guidance for Other Backends

This is not a "Win32-only" idea. It applies to any backend that satisfies both conditions:

1. `@Environment(...)` reads from an ambient current environment
2. the backend stores closures during render and invokes them later

### GTK4

Audit:

- signal handlers
- gesture controllers
- `g_idle_add` / timeout callbacks
- destroy/unmap lifecycle handlers
- menu activations

GTK also uses thread-local environment, so the same failure class can exist there.

### Web

Audit:

- DOM event listeners
- `requestAnimationFrame`
- `setTimeout`
- promise continuations
- menu / overlay dismiss handlers

Web does not use TLS, but it still has an ambient current environment. If callback execution later
depends on that ambient state, the same bug class exists.

### Android

Audit:

- any Swift callback that survives across the JSON/JNI boundary
- callbacks invoked later from host-side lifecycle or event dispatch

If Android lowers actions into identifiers and later re-enters Swift to execute closures that read
`@Environment(...)`, it should apply the same binding pattern when those callbacks are registered.
If the host mutates state directly and never re-enters Swift environment lookup, the issue may not
apply there.

### macOS

This note is about SwiftOpenUI-native backends, not Apple's SwiftUI runtime. Real SwiftUI manages
its own environment semantics internally.

## Review Checklist for Future Backend Work

When adding a new backend feature, ask:

1. Does this code store a closure during render and run it later?
2. Can that closure read `@Environment(...)` directly or indirectly?
3. Does callback execution happen outside a known host reinstall scope?
4. If the callback takes arguments, is the bound wrapper capturing environment at registration time,
   not building a new wrapper at dispatch time?
5. Is there a regression test that exercises the real delayed path, not just the helper?

If the answer to the first three is yes, the callback should almost certainly be environment-bound.

## Non-Goals

Callback binding does not solve every related issue.

For example, the original Win32 smoke crash was triggered immediately by a startup click-through
artifact on the native button. Binding the callback fixed the correctness issue, but the startup
click-through itself remained a separate UX bug.

Likewise, host reinstall is still required for render-time re-entry. Callback binding is not a
replacement for proper host-owned environment restoration during rebuild and descriptor work.
