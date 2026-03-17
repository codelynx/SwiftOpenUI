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
    case create(nodeId: Int64, type: NodeType, parentId: Int64, index: Int)
    case remove(nodeId: Int64)
    case move(nodeId: Int64, newParentId: Int64, newIndex: Int)

    // Properties
    case setText(nodeId: Int64, text: String)
    case setPadding(nodeId: Int64, top: Int, bottom: Int, leading: Int, trailing: Int)
    case setFrame(nodeId: Int64, width: Double?, height: Double?)
    case setColor(nodeId: Int64, property: ColorProperty, r: Double, g: Double, b: Double, a: Double)
    case setFont(nodeId: Int64, size: Double, weight: Int)
    case setEnabled(nodeId: Int64, enabled: Bool)
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
// --- Session lifecycle (Application-scoped, survives Activity recreation) ---
// Called once when the process starts. Returns an opaque pointer to the
// Swift app session. Kotlin's Application subclass owns this pointer.
external fun nativeSessionCreate(): Long

// Best-effort teardown for explicit shutdown or testing.
// NOT called on Activity destruction. NOT guaranteed by Android —
// the system may kill the process without running any app code.
// Do not rely on this for persistence or cleanup; design all state
// to be recoverable without it.
external fun nativeSessionDestroy(session: Long)

// --- Activity lifecycle (Activity-scoped, may be destroyed/recreated) ---
// Called from Activity.onCreate(). Swift re-sends full render tree.
external fun nativeActivityCreated(session: Long)

// Called from Activity.onDestroy(). Swift does NOT tear down state.
external fun nativeActivityDestroyed(session: Long)

// --- Events (Kotlin → Swift) ---
external fun nativeOnButtonClick(session: Long, nodeId: Long)
external fun nativeOnTextInput(session: Long, nodeId: Long, text: String)

// --- Render host (Swift → Kotlin) ---
class RenderHost {
    // Swift calls this with a serialized diff batch
    fun applyBatch(operations: ByteArray)

    // Kotlin-side: decodes and applies ops on UI thread
    private fun applyOnUiThread(ops: List<RenderOp>) { ... }
}
```

**Ownership rule:** The Swift session pointer is held by a Kotlin `Application` subclass (or a retained singleton), not by any individual Activity. Activities come and go; the session survives. `nativeSessionDestroy` is best-effort only — Android may kill the process without calling it. All state must be designed to be recoverable without a clean shutdown callback.

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

### JVM Thread Attachment

When Swift needs to call back into Kotlin (e.g. `applyBatch`), the calling thread must be attached to the JVM. Rules:

1. **Kotlin → Swift → Kotlin callbacks** (e.g. button tap handler that triggers re-render): the thread is already JVM-attached (it came from Kotlin). Safe to call back immediately.
2. **Swift-originated threads** (e.g. background work, timers): must call `JavaVM.AttachCurrentThread()` before any JNI call, and `DetachCurrentThread()` when done. The `CAndroidBridge` layer handles this.
3. **Cached references**: `JavaVM*` is stored once at `JNI_OnLoad`. `JNIEnv*` is per-thread and must not be shared. The `RenderHost` jobject is stored as a JNI global reference (not local).
4. **Phase 1 simplification**: all Swift work happens on the Kotlin callback thread (event → rebuild → applyBatch), avoiding the need for explicit attach/detach. Background threads are a Phase 2 concern.

## Identity Model

Swift maintains a **retained render node graph** that persists across rebuilds. Node identity is based on **structural position** in the view tree, not monotonically increasing counters.

### How IDs Are Assigned

Each node's identity is its **structural path** — the sequence of (view type, child index) pairs from root to that node. For example:

```
Root → VStack[0] → Text[0]         path: "V0.T0"   nodeId: stable hash
Root → VStack[0] → Button[1]       path: "V0.B1"   nodeId: stable hash
Root → VStack[0] → HStack[2]       path: "V0.H2"
Root → VStack[0] → HStack[2] → Text[0]  path: "V0.H2.T0"
```

- The same structural position always produces the same ID across rebuilds
- `ForEach` items use their data `Identifiable.id` as the child key instead of index, so reordering emits `move` ops (not remove/create churn)
- Conditional views (`if/else`) use the branch tag as part of the path

### Retained Node Graph

```swift
class RenderNode {
    let nodeId: Int64            // stable hash of structural path (Int64/Long on wire)
    let type: NodeType
    var properties: [String: Any]
    var children: [RenderNode]
    weak var parent: RenderNode?
}
```

**Wire type:** Node IDs are `Int64` (Swift) / `Long` (Kotlin) on the JNI boundary. Swift `Int` is 64-bit on ARM64 but Kotlin `Int` is 32-bit — using `Int64`/`Long` explicitly avoids width ambiguity. Structural path hashing uses a 64-bit hash (e.g. FNV-1a or SipHash); collision probability is negligible for realistic tree sizes but if a collision is detected during diff, the node is treated as remove + create (safe, not silent corruption).

On rebuild:
1. Swift walks the new view tree, producing a new `RenderNode` graph
2. Swift diffs old graph vs new graph by `nodeId` (structural path hash)
3. **Same nodeId, same properties** → no ops emitted
4. **Same nodeId, changed properties** → `set*` ops
5. **New nodeId** → `create` op
6. **Missing nodeId** → `remove` op
7. **Same nodeId, different parent/index** → `move` op

The Kotlin host maintains a `Map<Long, View>` for O(1) lookup by nodeId.

## Lifecycle

### Session vs Activity

Two distinct lifetimes:

| Scope | Kotlin owner | Swift side | Survives rotation? |
|-------|-------------|------------|-------------------|
| **Session** | `Application` subclass | App instance, state, render tree | Yes |
| **Activity** | `Activity` instance | Current render batch target | No |

### Process Start

```
1. Kotlin Application.onCreate()
2. System.loadLibrary("SwiftOpenUI")
3. JNI: nativeSessionCreate() → Swift creates App instance, builds initial tree
4. Session pointer stored in Application singleton
```

### Activity Start

```
1. Kotlin Activity.onCreate()
2. Activity retrieves session pointer from Application
3. JNI: nativeActivityCreated(session) → Swift re-sends full tree as create batch
4. Kotlin builds View tree from batch
5. Activity.setContentView(rootView)
```

### Activity Recreation (rotation, theme change, etc.)

```
1. Android calls Activity.onDestroy()
2. JNI: nativeActivityDestroyed(session) — Swift does NOT tear down state
3. Android creates new Activity
4. New Activity.onCreate() → nativeActivityCreated(session)
5. Swift re-sends full render tree (state is intact in session)
6. Kotlin rebuilds View tree from scratch
```

### Configuration Changes

Option: declare `android:configChanges` in manifest to handle in-place (avoids recreation for common cases like rotation).

### Process Death

Android may kill the process at any time without notification. `nativeSessionDestroy` is **not guaranteed** to run — `Application.onTerminate()` is never called on production devices, and `ProcessLifecycleOwner` never dispatches `ON_DESTROY`.

Swift in-memory state is lost. All persistent state must be saved proactively (e.g. on Activity pause), not on teardown. Future work: `@AppStorage` backed by SharedPreferences via JNI, saved in `nativeActivityDestroyed` or `onPause`.

## Error Boundary

If Kotlin host rejects or fails to apply a batch:

1. Kotlin catches the exception, logs it
2. Kotlin sends error back to Swift via JNI callback
3. Swift marks the tree as dirty, re-sends a full rebuild on next frame
4. If full rebuild also fails → log and show a fallback error view on Kotlin side

No crash propagation across the JNI boundary.

## Phase 1 Scope

### Phase 1a: JSON Bridge + Jetpack Compose (Implemented)

Swift renders the entire view tree to a `RenderNode` graph, serializes to JSON, and sends it across JNI in one call. Kotlin's `ComposeRenderHost` deserializes the JSON and builds a `@Composable` tree via Jetpack Compose.

State changes from Swift produce new JSON, which updates a `mutableStateOf(json)` — Compose recomposes only the changed subtrees.

#### Views (JSON → Compose)
- `Text` → `Text()`
- `Button` → `Button()` (Material3)
- `TextField` → `BasicTextField` with `TextFieldValue` (preserves cursor/selection/IME)
- `VStack` → `Column`
- `HStack` → `Row`
- `ZStack` → `Box`
- `Spacer` → `Spacer` with `Modifier.weight(1f)` in Row/Column scope
- `Divider` → `Divider()`
- `Color` → `Box` with `Modifier.background`
- `Group` → `Column`
- `EmptyView` → no-op

#### Modifiers
- `.padding()` → `Modifier.padding`
- `.frame()` → `Modifier.width/height`
- `.foregroundColor()` → `CompositionLocalProvider(LocalContentColor)`
- `.backgroundColor()` → `Modifier.background`
- `.font()` → `CompositionLocalProvider(LocalTextStyle)`
- `.border()` → `Modifier.border`
- `.focused()` → `FocusRequester` + `onFocusChanged` + `clearFocus`

#### State
- Interactive `@State`: button tap → JNI `nativeOnButtonClick` → action closure → `@State` mutation → `scheduleRebuild` → new JSON → Compose recomposition
- `@Binding`: child views receive `Binding<Value>` from parent's projected `$state`
- `TextField`: `nativeOnTextInput` JNI → immediate `Binding<String>` update → recomposition. `TextFieldValue` preserves cursor/selection across external updates
- `.focused()`: bidirectional — `nativeOnFocusChange` JNI for platform events (no rebuild), `"focused"` prop for programmatic focus/unfocus
- Session persistence: `AndroidSession` at module scope survives Activity recreation
- `ComponentActivity` with `setContent { }`, `MaterialTheme`, scrollable `Box`

#### Examples (defined in JNIBridge.swift)
- HelloWorld, TextStyles, Buttons, StateDemo (interactive, 5 sections), Layout, TextFieldDemo
- Launched via intent extra: `--es example "TextFieldDemo"`

### Rebuild Model vs Host Boundary

All backends (GTK4, Win32, Web, Android) use the same **coalesced full-rebuild** model: state mutation → schedule → tear down children → rebuild from scratch. The rebuild granularity is aligned across platforms.

However, Android differs at the **host boundary**: GTK4/Win32/Web render directly from Swift into the platform tree (GTK widgets, HWNDs, DOM nodes). Android renders in Swift, serializes to JSON, crosses the JNI boundary, and rebuilds in Kotlin. This extra serialization + cross-runtime step is the architectural cost unique to Android.

### Incremental Diffs (Future — Cross-Platform)

Batched diff operations (the design above) are deferred. When implemented, they should be built as a **cross-platform diff engine** in `Sources/SwiftOpenUI/` core, with each backend consuming diff ops. This avoids architectural divergence from doing Android-only diffs. Trigger: TextField input performance, IME jank, or visible rebuild flicker.

### Not in Phase 1 (Cross-Platform Future Work)
- Navigation (`NavigationStack`, `NavigationLink`)
- Gestures beyond button tap (`onTapGesture`, `onLongPressGesture`, `DragGesture`)
- Animations (`withAnimation`, `.animation()` modifier)

## Project Structure

```
Sources/Backend/Android/
└── Rendering/
    ├── AndroidBackend.swift     ← RenderBackend protocol, entry points
    ├── AndroidRenderer.swift    ← View → RenderNode extensions (AndroidRenderable)
    ├── RenderNode.swift         ← RenderNode class + JSON serialization (no Foundation)
    └── JNIBridge.swift          ← JNI entry point, example renderers, JNI string helpers

android/
├── hello/                       ← Minimal PoC: Swift .so + Kotlin JNI "Hello from Swift"
│   ├── app/                     ← Kotlin Android project
│   └── swift-lib/               ← Swift shared library (Package.swift)
└── renderer/                    ← Full renderer: Swift view tree → JSON → Compose
    ├── app/
    │   └── app/src/main/java/com/example/swiftopenui/
    │       ├── MainActivity.kt       ← ComponentActivity with setContent, loads .so
    │       ├── RenderBridge.kt       ← JNI bridge class
    │       └── ComposeRenderHost.kt  ← JSON → @Composable tree
    └── build-so.sh                   ← Build script for Swift .so

screenshots/
├── capture-android.sh           ← Automated screenshot capture via adb
└── android/                     ← Captured screenshots (6 examples)
```

## Open Questions

1. **swift-java generated bindings** — should we use `jextract` for the JNI surface, or hand-write the small API? Given Phase 1 is ~10 JNI functions, hand-writing may be simpler.
2. **Testing** — the Swift diff/batch layer can be unit-tested on macOS without Android, since it produces serialized `[RenderOp]` with no platform dependency.
3. **Compose (Phase 2)** — Compose expects declarative recomposition, not imperative view manipulation. The host API would need to become a "virtual DOM" that Compose reads, rather than a command stream. This is a different contract and should be designed separately.
