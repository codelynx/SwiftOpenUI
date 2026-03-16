# Android Backend Design

## Overview

The Android backend differs fundamentally from GTK4, Win32, and Web. Android's UI lives in a managed Java/Kotlin runtime — Swift cannot directly create or manipulate UI widgets. Instead, the architecture is **Swift core + Kotlin host**: Swift decides *what* to render, Kotlin decides *how*.

```
┌──────────────────────────────────────┐
│  Swift (.so shared library)          │
│  SwiftOpenUI: views, state, diffing  │
│  Produces: render tree + diffs       │
├──────────────────────────────────────┤
│  JNI boundary (narrow, batched)      │
├──────────────────────────────────────┤
│  Kotlin host (Activity)              │
│  Owns: UI thread, view tree,         │
│        lifecycle, input              │
│  Consumes: diff batches              │
│  Renders: Android Views              │
└──────────────────────────────────────┘
```

## Why Not the GTK4/Win32 Pattern

GTK4 and Win32 expose C ABIs — Swift calls `gtk_label_new()` or `CreateWindowEx()` directly. Android's UI surface is Java/Kotlin-managed. Attempting to drive Android Views through raw JNI per-node calls creates:

- **Jank**: chatty JNI round-trips block the UI thread
- **Leaks**: JNI local/global reference mismanagement
- **Lifecycle bugs**: Android recreates Activities on rotation, theme change, etc.
- **Thread violations**: Android Views must be touched on the UI thread only

The correct boundary: Swift produces a **declarative render tree / diff**, Kotlin applies it in a single batched UI-thread commit.

## Host API Contract

### Approach: Batched Diff Operations

Swift maintains a retained render tree with stable node IDs. On state change, Swift diffs the tree and sends a batch of operations to Kotlin.

### Operation Types

```
enum RenderOp {
    // Tree structure
    case create(nodeId: Int, type: NodeType, parentId: Int, index: Int)
    case remove(nodeId: Int)
    case move(nodeId: Int, newParentId: Int, newIndex: Int)

    // Properties
    case setText(nodeId: Int, text: String)
    case setPadding(nodeId: Int, top: Int, bottom: Int, leading: Int, trailing: Int)
    case setFrame(nodeId: Int, width: Double?, height: Double?)
    case setColor(nodeId: Int, property: ColorProperty, r: Double, g: Double, b: Double, a: Double)
    case setFont(nodeId: Int, size: Double, weight: Int)
    case setEnabled(nodeId: Int, enabled: Bool)
}

enum NodeType {
    case text
    case button
    case vstack
    case hstack
    case zstack
    case spacer
    case divider
    case color
    case frame     // FrameLayout wrapper
    case padding   // wrapper with padding
}

enum ColorProperty {
    case foreground
    case background
    case border
}
```

### JNI Surface (Kotlin side)

The Kotlin host exposes a single entry point for applying a batch:

```kotlin
// Called from Swift via JNI
external fun nativeInit(): Long          // returns opaque Swift app pointer
external fun nativeOnCreate(ptr: Long)   // app created
external fun nativeOnDestroy(ptr: Long)  // app destroyed

// Called from Kotlin when events occur
fun onButtonClick(nodeId: Int)           // forwards to Swift
fun onTextInput(nodeId: Int, text: String)

// The batch apply — called by Swift on state change
class RenderHost {
    // Swift calls this with a serialized batch
    fun applyBatch(operations: ByteArray)

    // Kotlin-side: decodes and applies ops on UI thread
    private fun applyOnUiThread(ops: List<RenderOp>) { ... }
}
```

### Serialization

Operations are serialized to a `ByteArray` on the Swift side and deserialized on the Kotlin side. This avoids per-operation JNI calls. Format: simple binary (tag byte + fixed-width fields), not JSON/protobuf — minimal allocation.

## Threading Rules

| Thread | Owner | Responsibilities |
|--------|-------|-----------------|
| **Main/UI thread** | Kotlin | View creation, layout, input events, `applyBatch` |
| **Swift thread** | Swift | State changes, tree diffing, batch generation |

**Flow:**

1. User taps a button → Kotlin UI thread → JNI call to Swift (`onButtonClick`)
2. Swift handles action, `@State` changes, triggers rebuild
3. Swift diffs the tree, produces `[RenderOp]` batch
4. Swift calls Kotlin `applyBatch` via JNI (still on callback thread)
5. Kotlin posts batch to UI thread via `runOnUiThread` / `Handler`
6. Kotlin decodes and applies operations in one pass

**Rules:**
- Swift never touches Android Views directly
- Kotlin never reads Swift state directly
- All cross-boundary communication is via the JNI surface above
- Batches are applied atomically on the UI thread

## Identity Model

Each view node gets a stable `Int` ID assigned by Swift:

- IDs are monotonically increasing (simple counter)
- Parent-child relationships are explicit in `create` operations
- `ForEach` items get stable IDs derived from their data identity
- On rebuild, Swift diffs old tree vs new tree by ID
- Unchanged nodes → no ops emitted
- Changed properties → `set*` ops
- Added/removed nodes → `create`/`remove` ops
- Moved nodes → `move` ops

The Kotlin host maintains a `Map<Int, View>` for O(1) lookup.

## Lifecycle

### App Start

```
1. Kotlin Activity.onCreate()
2. System.loadLibrary("SwiftOpenUI")
3. JNI: nativeInit() → Swift creates App instance, builds initial tree
4. Swift sends initial create batch → Kotlin builds View tree
5. Activity.setContentView(rootView)
```

### Activity Recreation (rotation, theme change, etc.)

```
1. Android destroys and recreates Activity
2. Kotlin: save nodeId tree structure (lightweight)
3. New Activity.onCreate()
4. JNI: nativeOnCreate() → Swift re-sends full tree as create batch
5. Kotlin rebuilds View tree from scratch
6. State is preserved in Swift (lives in .so, survives Activity recreation)
```

### Configuration Changes

Option: declare `android:configChanges` in manifest to handle in-place (avoids recreation for common cases like rotation).

### Process Death

Swift state is lost. For persistence, future work: `@AppStorage` backed by SharedPreferences via JNI.

## Error Boundary

If Kotlin host rejects or fails to apply a batch:

1. Kotlin catches the exception, logs it
2. Kotlin sends error back to Swift via JNI callback
3. Swift marks the tree as dirty, re-sends a full rebuild on next frame
4. If full rebuild also fails → log and show a fallback error view on Kotlin side

No crash propagation across the JNI boundary.

## Phase 1 Scope

Intentionally narrow:

### Views
- `Text` → `TextView`
- `Button` → `Button`
- `VStack` → vertical `LinearLayout`
- `HStack` → horizontal `LinearLayout`
- `Spacer` → `Space` with layout weight

### Modifiers
- `.padding()` → `setPadding` on the view
- `.foregroundColor()` → `setTextColor`
- `.font()` → `setTextSize` + `setTypeface`

### State
- `@State` triggers rebuild → diff → batch apply
- One `Activity`, one root `LinearLayout`

### Not in Phase 1
- ZStack, Divider, Color, ForEach, Group
- Compose
- Fragments, navigation
- Text input / focus
- Gestures beyond button tap
- Animations

## Project Structure

```
Sources/Backend/Android/
├── CAndroid/                    ← JNI C headers (jni.h wrappers)
├── CAndroidBridge/              ← Swift JNI helpers (env, class lookup, etc.)
└── Rendering/
    ├── AndroidBackend.swift     ← RenderBackend, lifecycle
    ├── AndroidRenderer.swift    ← View → RenderNode tree
    ├── AndroidDiffer.swift      ← Diff engine, batch generation
    └── RenderOp.swift           ← Operation types, serialization

android-host/                    ← Kotlin Android project (separate from SPM)
├── app/src/main/
│   ├── java/.../
│   │   ├── MainActivity.kt     ← loads .so, wires JNI
│   │   └── RenderHost.kt       ← applies batched ops to Views
│   └── AndroidManifest.xml
└── build.gradle.kts
```

## Open Questions

1. **swift-java generated bindings** — should we use `jextract` for the JNI surface, or hand-write the small API? Given Phase 1 is ~10 JNI functions, hand-writing may be simpler.
2. **Testing** — the Swift diff/batch layer can be unit-tested on macOS without Android, since it produces serialized `[RenderOp]` with no platform dependency.
3. **Compose (Phase 2)** — Compose expects declarative recomposition, not imperative view manipulation. The host API would need to become a "virtual DOM" that Compose reads, rather than a command stream. This is a different contract and should be designed separately.
