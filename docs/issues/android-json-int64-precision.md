# Android JSON Int64 Precision Loss

**Date:** 2026-03-18
**Status:** Resolved
**Affected:** Android backend — NavigationDemo back button, any node ID > 2^53

## Symptom

NavigationDemo push works (navigates to detail page), but the "← Back" button does nothing. Clicking it multiple times has no effect. No crash, no error — just silent failure.

Logcat shows:
```
Button clicked: nodeId=7640572344134404096
```
But `nativeOnButtonClick` returns `null` (no state change).

## Investigation Timeline

### 1. Initial crash: TupleView2 fatal error

The first deployed `.so` (BuildId: `587010fe`) was stale — built before `TupleView2: AndroidMultiChildRenderable` was added. The renderer fell through to `body` recursion on a `Body = Never` type:

```
SwiftOpenUI/TupleView.swift:19: Fatal error: TupleView2 is a primitive view
```

**Fix:** Rebuild `.so` from current source with the 6.3-snapshot toolchain.

### 2. Build environment: wrong architecture

`swift build --swift-sdk ...android` without `--triple` defaults to armv7 (armeabi-v7a), but the emulator is arm64-v8a. The `.so` loads but functions crash or behave unexpectedly.

**Fix:** Add `--triple aarch64-unknown-linux-android28`. This is now the settled build recipe used by `build-so.sh`.

### 3. Build environment: Foundation module not found for aarch64

```
error: could not find module 'Foundation' for target 'aarch64-unknown-linux-android';
found: armv7-unknown-linux-android, at: .../swift-armv7/android/Foundation.swiftmodule/...
```

The Android Swift SDK's `swiftResourcesPath` for `aarch64-unknown-linux-android28` was pointing to the armv7 resources directory.

**Fix:**
```bash
swift sdk configure \
  --swift-resources-path .../swift-resources/usr/lib/swift-aarch64 \
  swift-6.3-DEVELOPMENT-SNAPSHOT-2026-03-05-a_android \
  aarch64-unknown-linux-android28
```

Note: The triple must match exactly — configuring for `aarch64-unknown-linux-android` (no API level suffix) does not apply to `aarch64-unknown-linux-android28`.

### 4. Back button silent failure

After deploying a fresh `.so`, push worked but back did not. Added Kotlin-side logging:

```kotlin
Log.d(TAG, "Button result: ${result?.length ?: "null"} chars")
```

Result: push returns JSON, back returns `null`. The action for `backNodeId` is not found in `androidButtonActions`.

### 5. Root cause: JSON Int64 precision loss

Added JSON dump logging. The JSON from Swift contained:
```json
"backNodeId": "7640572344134403613"
```

But Kotlin's `JSONObject.optLong("backNodeId", 0L)` returned `7640572344134404096`.

**Difference:** 7640572344134404096 - 7640572344134403613 = 483

This is classic IEEE 754 double-precision loss. Java's `org.json.JSONObject` parses numbers through `Double` internally. A `Double` has 53 bits of mantissa, which can exactly represent integers up to 2^53 (9,007,199,254,740,992). Our node IDs are FNV-1a hashes that span the full Int64 range — values above 2^53 lose precision when round-tripped through `Double`.

The same issue affected the `id` field on ALL render nodes (read via `node.optLong("id", 0L)`), but was only visible for `backNodeId` because it's the only ID stored in a prop string and parsed back. Regular button node IDs were parsed from the initial JSON (also lossy) and sent back to Swift — but since both the registration and the lookup used the same lossy value, they matched. The `backNodeId` was different because it was registered on the Swift side with the exact Int64 value, but parsed on the Kotlin side with precision loss.

## Fix

### Swift side (RenderNode.swift)

Serialize `id` as a JSON string instead of a bare number:

```swift
// Before
dict["id"] = id          // produces: "id":7640572344134403613

// After
dict["id"] = String(id)  // produces: "id":"7640572344134403613"
```

### Kotlin side (ComposeRenderHost.kt)

Parse node IDs as strings, then convert with `toLongOrNull()`:

```kotlin
// Before
val nodeId = node.optLong("id", 0L)
val backNodeId = props.optLong("backNodeId", 0L)

// After
val nodeId = node.optString("id", "0").toLongOrNull() ?: 0L
val backNodeId = props.optString("backNodeId", "0").toLongOrNull() ?: 0L
```

## Why It Wasn't Caught Earlier

- **StateDemo buttons worked** because their node IDs happened to be below 2^53 (e.g., `4455897874268277082` — still below 2^53? Actually no, 4.4×10^18 > 2^53 ≈ 9×10^15). The real reason StateDemo worked is that both sides used the same lossy value — Kotlin parsed the JSON with precision loss, stored that lossy ID in the Compose tree, and sent it back to Swift via JNI. Swift's `androidButtonActions` was populated during the same render pass that produced the JSON, so the registration used the exact ID. The JNI `nativeOnButtonClick` received the lossy ID from Kotlin, but the action was registered under the exact ID — **these only matched by luck** when the hash happened to be below 2^53 or when the precision loss was zero.

- **backNodeId was different** because it was stored as a prop string in the JSON (`"backNodeId":"7640572344134403613"`), parsed by Kotlin with `optLong` (lossy), and sent back to Swift via JNI. But on the Swift side, the action was registered under the **exact** Int64 value. The mismatch caused the lookup to fail.

## Lessons

1. **Never use bare JSON numbers for Int64 values** when the consumer is Java/Kotlin. JSON numbers are IEEE 754 doubles (53-bit mantissa). Always serialize as strings.

2. **Silent failures are harder to debug than crashes.** The back button returned `null` with no error — it took JSON dump logging to spot the ID mismatch.

3. **Test with values > 2^53.** FNV-1a hashes span the full Int64 range. Any test using small synthetic IDs would not catch this.

4. **The Android SDK triple must include the API level.** `aarch64-unknown-linux-android` ≠ `aarch64-unknown-linux-android28` for SDK configuration purposes.

## Files Changed

| File | Change |
|------|--------|
| `Sources/Backend/Android/Rendering/RenderNode.swift` | Serialize `id` as string |
| `android/.../ComposeRenderHost.kt` | Parse IDs with `optString().toLongOrNull()` |
