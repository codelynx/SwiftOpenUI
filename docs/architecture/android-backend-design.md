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

## Architecture: JSON Render Tree

The Android backend uses a **declarative JSON render tree** model. Swift maintains the application state and view tree, while Kotlin provides the rendering host using Jetpack Compose.

### Data Flow

1.  **Swift**: Walks the `View` tree and produces a hierarchy of `RenderNode` objects.
2.  **Serialization**: The `RenderNode` tree is serialized to a JSON string.
3.  **JNI Boundary**: The JSON string is passed from Swift to Kotlin via JNI.
4.  **Kotlin**: Deserializes the JSON and recursively builds a `@Composable` tree.

### JNI Surface (Kotlin → Swift)

The JNI boundary is narrow and focused on session lifecycle and user interaction. Events from Kotlin often return a new JSON string if the Swift-side state changed, allowing immediate UI updates.

```kotlin
object RenderBridge {
    // Lifecycle
    external fun nativeCreateSession(name: String): String?
    external fun nativeRenderApp(): String?

    // Events (Returns new JSON if @State changed)
    external fun nativeOnButtonClick(nodeId: Long): String?
    external fun nativeOnTextInput(nodeId: Long, text: String): String?
    external fun nativeOnToggleChange(nodeId: Long, isOn: Boolean): String?
    external fun nativeOnSliderChange(nodeId: Long, value: Double): String?
    external fun nativeOnFocusChange(nodeId: Long, hasFocus: Boolean)
}
```

### RenderNode Schema

Every node in the tree has:
- `type`: String identifying the view (e.g., "vstack", "text")
- `id`: Stable structural identity (Int64) for state and focus persistence
- `props`: Key-value dictionary for view-specific properties
- `layout` (optional): Absolute positioning coordinates `(x, y, width, height)`
- `children`: List of child `RenderNode` objects

## Layout Model

Android uses a hybrid layout strategy to balance performance and SwiftUI parity.

### 1. Precision Layout (Swift-driven)
For measurable, fixed-size stacks (e.g., stacks of Text or Buttons), Swift uses the **shared Swift layout engine** to calculate exact pixel coordinates.
- **Node**: The container node includes a `layout` dictionary.
- **Kotlin**: Applies `Modifier.absoluteOffset` and `Modifier.size`.
- **Parity**: Significantly improves layout alignment with GTK4 and Win32 backends for fixed-size components.
- **Limitation**: Currently uses intrinsic size estimations pending a real Kotlin → Swift measurement bridge.

### 2. Flexible Fallback (Compose-driven)
For stacks containing `Spacer`, `Slider`, or complex nested components, layout is offloaded to Jetpack Compose (`Column`, `Row`, `Box`).
- **Node**: The container lacks a `layout` dictionary.
- **Kotlin**: Uses Compose `Arrangement` and `Alignment` properties.
- **Rationale**: Compose is highly optimized for flexible distribution and intrinsic measurement.

**Ownership rule:** The Swift session pointer is held by a Kotlin `Application` subclass (or a retained singleton), not by any individual Activity. Activities come and go; the session survives. `nativeSessionDestroy` is best-effort only — Android may kill the process without calling it. All state must be designed to be recoverable without a clean shutdown callback.

### Serialization

The tree is serialized to a standard JSON string. While more verbose than binary, JSON allows for easy debugging and seamless integration with Kotlin's `JSONObject` and Compose's state model. For performance, large leaf data (like Canvas paths) or future incremental diffs may adopt a binary side-channel.

## Threading Rules

| Thread | Owner | Responsibilities |
|--------|-------|-----------------|
| **Main/UI thread** | Kotlin | View creation, layout, input events, JSON parsing |
| **Swift thread** | Swift | State changes, tree generation, JSON serialization |

**Rules:**
- Swift never touches Android Views directly.
- Kotlin never reads Swift state directly.
- All cross-boundary communication is via the JNI surface above.
- Re-renders are applied by updating a `mutableStateOf(jsonString)` on the Kotlin side, triggering Compose recomposition.

### JVM Thread Attachment

When Swift needs to call back into Kotlin (e.g. for future measurement queries), the calling thread must be attached to the JVM.

1. **Kotlin → Swift → Kotlin callbacks**: the thread is already JVM-attached (it came from Kotlin). Safe to call back immediately.
2. **Swift-originated threads**: must call `JavaVM.AttachCurrentThread()` before any JNI call, and `DetachCurrentThread()` when done.
3. **Phase 1 simplification**: all Swift work currently happens on the Kotlin callback thread (event → rebuild → return JSON), avoiding the need for explicit attach/detach.

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

## Phase 1 Scope (Implemented)

Swift renders the entire view tree to a `RenderNode` graph, serializes to JSON, and sends it across JNI. Kotlin's `ComposeRenderHost` builds a `@Composable` tree using a global post-dispatch pass for modal overlays.

#### Views (JSON → Compose)
- `Text` → `Text()`
- `Button` → `Button()` (Material3)
- `TextField`, `SecureField`, `TextEditor` → `BasicTextField`
- `Toggle` → `Switch()`
- `Slider` → `Slider()`
- `ProgressView` → `LinearProgressIndicator()`
- `Shapes` → `Circle`, `Rectangle`, `RoundedRectangle`, `Capsule`, `Ellipse`
- `VStack`, `HStack`, `ZStack`
- `List` → `LazyColumn`
- `ScrollView` → `Modifier.verticalScroll / horizontalScroll`
- `Spacer`, `Divider`, `Group`, `EmptyView`

#### Modifiers
- `.padding()`, `.frame()`, `.border()`
- `.foregroundColor()`, `.backgroundColor()`, `.font()`
- `.opacity()`, `.offset()`, `.scaleEffect()`, `.animation()`
- `.clipShape()`, `.onTapGesture()`, `.onLongPressGesture()`, `.onDrag()`
- `.sheet()`, `.alert()` (Layout-neutral global pass)
- `.navigationTitle()`, `.navigationDestination()`, `.focused()`

#### State & Interaction
- **Precision Layout**: Gated absolute positioning for fixed-size stacks.
- **Stable Identity**: Structural path hashes ensure @State and Focus survive rebuilds.
- **JNI Interaction**: Immediate binding updates for Text, Toggle, and Slider.
- **Navigation**: Swift-driven path-based navigation with system back button support.

### Rebuild Model vs Host Boundary

All backends (GTK4, Win32, Web, Android) use the same **coalesced full-rebuild** model: state mutation → schedule → tear down children → rebuild from scratch. The rebuild granularity is aligned across platforms.

However, Android differs at the **host boundary**: GTK4/Win32/Web render directly from Swift into the platform tree (GTK widgets, HWNDs, DOM nodes). Android renders in Swift, serializes to JSON, crosses the JNI boundary, and rebuilds in Kotlin. This extra serialization + cross-runtime step is the architectural cost unique to Android.

### Incremental Diffs (Future — Cross-Platform)

Batched diff operations (the design above) are deferred. When implemented, they should be built as a **cross-platform diff engine** in `Sources/SwiftOpenUI/` core, with each backend consuming diff ops. This avoids architectural divergence from doing Android-only diffs. Trigger: TextField input performance, IME jank, or visible rebuild flicker.

### Not in Phase 1 (Cross-Platform Future Work)
- TabView, Grid, Canvas
- Presentations beyond Sheet/Alert (.confirmationDialog)
- Images (Image(systemName:), Image(material:))
- Advanced Animations (Custom transitions)

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
│   └── app/                     ← Kotlin Android project
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

## Resolved Design Questions

1. **JNI bindings** — hand-written `@_cdecl` functions. The JNI surface is ~8 entry points (`nativeCreateSession`, `nativeOnButtonClick`, `nativeOnTextInput`, `nativeOnFocusChange`, `nativeOnDragEvent`, `nativeRenderApp`). `swift-java`/`jextract` are not needed at this scale.
2. **Testing** — Android render logic is unit-tested on macOS (93 tests) via `@testable import BackendAndroid`. No Android emulator needed for Swift-side tests.
3. **Compose integration** — Resolved as JSON render tree model. Swift produces a full JSON tree each render; Kotlin's `ComposeRenderHost` maps it to `@Composable` calls. This is effectively a virtual DOM that Compose reads declaratively.
