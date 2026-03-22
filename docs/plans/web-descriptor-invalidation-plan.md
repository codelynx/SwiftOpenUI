# Web Backend: Descriptor-First Invalidation Pipeline (Completed)

## Context

The GTK4 and Win32 backends now have descriptor-first invalidation pipelines that enable in-place DOM mutations (text content, color fill) without full widget rebuilds. The Web backend currently does `innerHTML = ""` + full re-render on every state change. This plan aligns the Web backend with the same architecture.

## Key Differences from GTK4/Win32

| Concern | GTK4/Win32 | Web |
|---------|-----------|-----|
| Threading | Multi-threaded (pthread TLS / NSLock) | Single-threaded (Wasm) — no locks needed |
| Native slots | `Int` (pointer bitpattern) | `JSValue` (reference type) — see Design Decision 1 |
| Node tagging | `g_object_set_data` / `SetPropW` | `data-hosted-kind` HTML attribute |
| Slot validation | `gtk_swift_is_widget` / HWND alive check | `element.parentNode` != null/undefined |
| Text mutation | `gtk_label_set_text` | `element.textContent = ...` |
| Color mutation | CSS provider reload | `element.style.backgroundColor = "rgba(...)"` |
| Closure lifetime | GTK signal handlers / Win32 subclass procs | `_webRetainedClosures` — preserved automatically when narrow path returns early |
| Rebuild coalescing | `g_idle_add` | `requestAnimationFrame` |

## Design Decisions

### 1. Native Slot Storage — `nativeSlotID: Int` (not `Any?`)

GTK4/Win32 store native widget pointers as `Int` bitpatterns in `RetainedExecutorNode.nativeSlotID`. This keeps the node fully `Equatable` via synthesis, which the pipeline relies on in tests and retained-tree comparisons.

Storing `Any?` or `JSValue` would break synthesized `Equatable` — requiring either custom equality (fragile, hides bugs) or splitting runtime state out of the tree (architectural divergence from GTK4/Win32).

**Decision:** Use `nativeSlotID: Int` like GTK4/Win32. Store JSValue references in a side table keyed by slot ID:

```swift
/// Maps integer slot IDs to live DOM elements. Cleared on full rebuild.
var _webSlotTable: [Int: JSValue] = [:]
var _webNextSlotID: Int = 1

func webRegisterSlot(_ element: JSValue) -> Int {
    let id = _webNextSlotID
    _webNextSlotID += 1
    _webSlotTable[id] = element
    return id
}

func webResolveSlot(_ slotID: Int) -> JSValue? {
    _webSlotTable[slotID]
}
```

This preserves full `Equatable` synthesis, keeps the pure pipeline identical to GTK4/Win32, and isolates JSValue references in the mutation layer only.

### 2. Descriptor Coverage vs DOM Coverage

**Problem:** Many `Body = Never` modifier views (FontModifiedView, OpacityView, CornerRadiusView, etc.) are `WebRenderable` but not `WebDescribable`. When `webDescribeView` hits these, the GTK4-style fallback produces an opaque `.composite` node with no children. But the DOM tree *does* contain tagged Text/Color descendants inside these wrappers. This causes `webCaptureSupportedNativeSlots` to see more hosted elements than descriptor leaves → slot capture fails → narrow path disabled for common trees.

**This is the same limitation GTK4 has today.** GTK4 only has `GTKDescribable` on Text, Color, and VStack. The narrow path only activates for simple trees without non-described wrappers.

**Decision for Phase 1:** The Web backend defines broader `WebDescribable` coverage than GTK4 today (11 views vs 3), but the same mutation scope (textContent + colorFill only). The extra describable views (HStack, ZStack, PaddedView, FrameView, BackgroundView, ForegroundColorView, BorderView, Slider) make the narrow path activate for more tree shapes — they act as transparent structural wrappers in the descriptor tree, letting the pipeline see through to Text/Color leaves.

Views that remain non-describable (FontModifiedView, OpacityView, etc.) still block the narrow path. Expanding those is a future cross-backend concern tracked in `docs/plans/gtk4-invalidation-future-phases.md` Phase 8.

### 3. Describe Fallback Behavior

`webDescribeView` follows the **identical** fallback behavior as `gtkDescribeView` (GTK4DescriptorTree.swift:347):

```swift
public func webDescribeView<V: View>(_ view: V) -> WebDescriptorNode {
    if let describable = view as? WebDescribable { return describable.webDescribeNode() }
    if let multi = view as? MultiChildView {
        return WebDescriptorNode(kind: .composite, typeName: ..., children: multi.children.map(webDescribeAnyView))
    }
    if V.Body.self != Never.self { return webDescribeAnyView(view.body) }
    return WebDescriptorNode(kind: .composite, typeName: ...)  // opaque
}
```

Non-describable `Body = Never` views become opaque `.composite` nodes. `webCanApplyTextColorHostMutation` rejects trees containing opaque composites. This is correct and safe — it forces a full rebuild when the descriptor tree can't prove what changed.

## Phase 1 Narrow Slice

Three things are distinct and should not be conflated:

### 1. Descriptor kinds defined by the backend

All 12 kinds, matching the GTK4/Win32 enum surface. Types are cheap; defining them now avoids churn when future phases wire more mutation hooks.

```
text, color, vStack, hStack, zStack, padding, frame,
background, foregroundColor, border, slider, composite
```

### 2. Views that get `WebDescribable` in Phase 1

Broader than GTK4's current 3 (Text, Color, VStack), but same mutation scope:

| View | Kind | Status |
|------|------|--------|
| Text | .text | **Mutation target** |
| Color | .color | **Mutation target** |
| VStack | .vStack | Structural (recurses children) |
| HStack | .hStack | Structural (recurses children) |
| ZStack | .zStack | Structural (recurses children) |
| PaddedView | .padding | Structural (wraps child) |
| FrameView | .frame | Structural (wraps child) |
| BackgroundView | .background | Structural (wraps child) |
| ForegroundColorView | .foregroundColor | Structural (wraps child) |
| BorderView | .border | Structural (wraps child) |
| Slider | .slider | Descriptive only (no mutation hook yet) |

Broader `WebDescribable` coverage means the narrow path activates for more tree shapes than GTK4 today. For example, `VStack { BackgroundView(Text("x"), color: .blue) }` — GTK4 would produce an opaque composite for BackgroundView and reject; Web can describe through it.

**Not described (opaque composites):** FontModifiedView, OpacityView, OffsetView, ScaleEffectView, AnimatedView, CornerRadiusView, ShadowView, RotationView, Button, Toggle, TextField, NavigationStack, and all other `Body = Never` views without explicit conformance. These cause `webCanApplyTextColorHostMutation` to reject the narrow path, forcing full rebuild.

### 3. Updates actually mutated in place in Phase 1

Only two update intents are wired to real DOM mutations:

- **`textContent`** — `element.textContent = newText`
- **`colorFill`** — `element.style.backgroundColor = "rgba(...)"`

All other update intents (`frameLayout`, `vStackLayout`, `paddingLayout`, etc.) are descriptive only — they appear in the plan tree but have no mutation hook. If the eligibility check (`webCanApplyTextColorHostMutation`) encounters them, it rejects the narrow path and falls back to full rebuild.

This matches GTK4/Win32's Phase 1 mutation scope.

## Implementation Plan

### Step 1: Descriptor Types & Pure Pipeline

**New file:** `Sources/Backend/Web/Rendering/WebDescriptorTree.swift`

Imports only `SwiftOpenUI` (no JavaScriptKit) — fully testable without browser/Wasm.

**Types** (port from GTK4DescriptorTree.swift with `Web` prefix, same `nativeSlotID: Int?` pattern):
- `WebDescriptorKind` — enum: text, color, vStack, hStack, zStack, padding, frame, background, foregroundColor, border, slider, composite
- Property descriptors: `WebTextDescriptor`, `WebColorDescriptor`, `WebSliderDescriptor`, `WebAlignmentDescriptor`, `WebHorizontalAlignmentDescriptor`, `WebVerticalAlignmentDescriptor`, `WebPaddingDescriptor`, `WebFrameDescriptor`, `WebBorderDescriptor`, `WebVStackDescriptor`, `WebHStackDescriptor`, `WebZStackDescriptor`
- `WebDescriptorProps` — enum wrapping each descriptor type + `.none`
- `WebDescriptorNode` — kind + typeName + props + children (all `Equatable`)
- `WebDescriptorIdentity` — path: [Int] (`Equatable`, `Hashable`)
- `WebIdentifiedDescriptorNode`, `WebRetainedDescriptorNode` (all `Equatable`)
- `WebRetainedExecutorNode` — identity + kind + lastDescriptor + `nativeSlotID: Int?` + children (`Equatable`)
- `WebDescriptorPlanKind`, `WebDescriptorUpdateIntent`, `WebDescriptorPlan` (all `Equatable`)
- `WebExecutorActionKind`, `WebExecutorAction` (all `Equatable`)
- `WebHookResultKind`, `WebHookResult` (all `Equatable`)

**Pure pipeline functions** (direct port of GTK4 equivalents):
- `webDescribeView(_:)` / `webDescribeAnyView(_:)` — builds descriptor tree from views
- `webIdentifyDescriptorTree(_:)` — assigns [Int] position paths
- `webRetainDescriptorTree(_:)` — freezes for comparison
- `webMakeExecutorTree(from:)` — creates executor nodes with nil slots
- `webMatchDescriptorTree(old:new:)` / `webCanReuseNode(old:new:)` — structural matching
- `webPlanDescriptorTree(old:new:)` / `webUpdateIntent(old:new:)` — create/reuse/update/replace + intents
- `webExecuteDescriptorPlan(old:plan:)` — produces executor actions
- `webCanApplyTextColorHostMutation(plan:)` — eligibility check
- `webApplyHook(action:)` — descriptive-only dispatch (no DOM mutation)
- `webHookMutationSucceeded(_:)` — recursive success check

**WebDescribable protocol:**
```swift
public protocol WebDescribable {
    func webDescribeNode() -> WebDescriptorNode
}
```

**Alignment helpers:**
- `webAlignmentDescriptor(_:)`, `webHorizontalAlignmentDescriptor(_:)`, `webVerticalAlignmentDescriptor(_:)`
- `webColorDescriptor(_:)` — Color → WebColorDescriptor

**Reference:** `GTK4DescriptorTree.swift` (929 lines) — types and pure pipeline are a direct port. The Web version diverges only in the mutation layer (Step 4).

### Step 2: WebDescribable Conformances

**File:** `Sources/Backend/Web/Rendering/WebRenderer.swift`

Add `WebDescribable` conformance for the 11 views listed in the Phase 1 narrow slice (see above). This is broader describable coverage than GTK4's current 3 (Text, Color, VStack), but the same mutation scope — only `textContent` and `colorFill` are wired to real DOM mutations.

Container views (VStack, HStack, ZStack) and wrapper views (PaddedView, FrameView, BackgroundView, ForegroundColorView, BorderView) recurse children via `webDescribeAnyView`. This makes them transparent to the descriptor tree, so the narrow path can see through them to the Text/Color leaves underneath.

### Step 3: Hosted-Node Tagging

**File:** `Sources/Backend/Web/Rendering/WebRenderer.swift`

- `WebHostedNodeKind` enum: `.text`, `.color`, `.unknown`
- `webMarkHostedNodeKind(_:kind:)` — sets `element.dataset.object?.hostedKind = .string(kind.rawValue)`
- `webHostedNodeKind(of:)` — reads data attribute back
- `webHostedKindForDescriptor(_:)` — maps WebDescriptorKind → WebHostedNodeKind?

Tag DOM elements during existing `webCreateElement()`:
- `Text.webCreateElement()`: add `webMarkHostedNodeKind(span, kind: .text)`
- `Color.webCreateElement()`: add `webMarkHostedNodeKind(div, kind: .color)`

### Step 4: Slot Capture & DOM Mutation Helpers

**File:** `Sources/Backend/Web/Rendering/WebDescriptorMutation.swift` (new, imports JavaScriptKit)

Separated from `WebDescriptorTree.swift` to keep the pure pipeline free of JavaScriptKit imports. This makes the split between testable-without-DOM code and DOM-dependent code explicit.

**Slot table** (module-level, mirrors GTK4's pointer-as-Int approach):
```swift
var _webSlotTable: [Int: JSValue] = [:]
var _webNextSlotID: Int = 1
```

**Slot capture functions:**
- `webCaptureSupportedNativeSlots(from:descriptorRoot:executorRoot:)` — DFS walk DOM children, collect elements with `data-hosted-kind`, pair with descriptor leaves by DFS order, register in slot table, assign IDs to executor nodes
- `webCollectSupportedLeafDescriptors(from:)` — same as GTK4
- `webCollectSupportedHostedElements(from:into:)` — DFS walk using `element.children.length` / subscript
- `webAssignNativeSlots(_:slotsByIdentity:)` — rebuild executor with slot IDs

**DOM mutation helpers:**
- `webSetTextContent(slotID:text:) -> Bool` — resolve from slot table, set `element.textContent`
- `webSetColorFill(slotID:color:) -> Bool` — resolve from slot table, set `element.style.backgroundColor`

**Hook mutation (DOM-dependent):**
- `webApplyHookMutation(action:)` — real DOM mutation via slot table lookups
- `webAllSlotsValid(action:)` — for update actions with text/color intent, resolve slot and check `element.parentNode` is not null/undefined

### Step 5: WebViewHost Integration

**File:** `Sources/Backend/Web/Rendering/WebViewHost.swift`

Add stored properties:
```swift
var describeBody: (() -> WebDescriptorNode)?
var lastRetainedDescriptor: WebRetainedDescriptorNode?
var retainedExecutor: WebRetainedExecutorNode?
```

Modify `rebuild()` — insert narrow path **before** `_webRetainedClosures.removeAll()`:
1. Check `describeBody`, `lastRetainedDescriptor`, `retainedExecutor` all non-nil
2. `describeBody()` → new descriptor
3. Identify → plan → eligibility check (`webCanApplyTextColorHostMutation`)
4. If eligible: execute → validate slots → apply hook mutation
5. If mutation succeeds: update retained state, **return early** (closures preserved, DOM untouched)
6. If any step fails: fall through to existing full rebuild

After full rebuild (at end of `rebuild()`), capture initial descriptor state:
1. `describeBody()` → descriptor → identify → retain → make executor
2. `webCaptureSupportedNativeSlots(from: container, ...)` to map DOM elements
3. Store as `lastRetainedDescriptor` and `retainedExecutor`

Modify `webRenderStatefulView()`:
- Set `host.describeBody = { webDescribeView(mutableView.body) }`
- After initial render, capture descriptor + executor state (same pattern as GTK4)

### Step 6: Tests

**New file:** `Tests/BackendTests/WebTests/WebDescriptorTests.swift`

#### Pure pipeline tests (no DOM, no JSValue):

Direct port of `GTK4DescriptorTests.swift` (231 lines):

1. `testDescribeText` — verify kind + text prop
2. `testDescribeColor` — verify kind + color RGBA
3. `testDescribeVStackWithChildren` — verify container + child structure
4. `testIdentifyAssignsPaths` — verify [Int] path assignment
5. `testMatchSameStructure` — reuse
6. `testMatchDifferentKind` — replace
7. `testPlanTextChange` — .update + .textContent
8. `testPlanColorChange` — .update + .colorFill
9. `testPlanStructuralChange` — .replace
10. `testPlanNoChange` — .reuse + .none
11. `testExecuteTextUpdate` — action kind + intent
12. `testHookTextContent` — hook result via `webApplyHook` (descriptive, no DOM)
13. `testCanApplyTextColorMutation` — eligible
14. `testCannotApplyLayoutMutation` — rejected
15. `testCanApplyMixedTextColorMutation` — mixed text+color eligible
16. `testOpaqueCompositeRejectsNarrowPath` — opaque composite rejected
17. `testOpaqueCompositeInsideVStackRejectsNarrowPath` — nested opaque rejected

#### Slot table and mutation integration tests:

These tests exercise the slot table, slot assignment, and the full pipeline including slot validation — verifying the seam between pure pipeline and DOM layer without requiring a browser:

18. `testSlotTableRegisterAndResolve` — register a JSValue, resolve by ID, verify round-trip
19. `testSlotAssignment` — build executor tree, simulate slot capture with known IDs, verify IDs propagate through plan → execute
20. `testExecutePlanWithSlots` — full pipeline from describe through execute with pre-assigned slot IDs, verify resulting executor action has correct slot for mutation
21. `testAllSlotsValidWithNilSlot` — executor action with nil slot for text update → `webAllSlotsValid` returns false
22. `testAllSlotsValidWithAssignedSlot` — executor action with valid slot ID → returns true
23. `testOpaqueWrapperBlocksNarrowPath` — `VStack { FontModifiedView(Text("x")) }` described → FontModifiedView becomes opaque composite → eligibility check rejects

**Package.swift:** Add test target (inside the existing `#if os(macOS)` gate):
```swift
.testTarget(
    name: "WebTests",
    dependencies: ["BackendWeb", "SwiftOpenUI"],
    path: "Tests/BackendTests/WebTests"
),
```

## Implementation Sequence

| Step | Files Modified/Created | Can Land Independently |
|------|----------------------|----------------------|
| 1 | `WebDescriptorTree.swift` (new) | Yes (pure types, no runtime impact) |
| 2 | `WebRenderer.swift` (add WebDescribable) | After Step 1 |
| 3 | `WebRenderer.swift` (add hosted-node tagging) | After Step 1 |
| 4 | `WebDescriptorMutation.swift` (new) | After Steps 1, 3 |
| 5 | `WebViewHost.swift` (narrow mutation path) | After Steps 1-4 |
| 6 | `WebDescriptorTests.swift` (new), `Package.swift` | After Step 1 |

## Verification

1. **Tests pass:** `swift test` — all existing tests pass + new WebDescriptorTests (pure pipeline + slot table integration)
2. **Build succeeds:** `swift build` on macOS
3. **Wasm build:** `swift build --swift-sdk swift-6.2.4-RELEASE_wasm` (if toolchain available)
4. **Runtime:** `swift run ColorMixer` on macOS still works (Web backend isn't active on macOS, but build must succeed)
5. **Web runtime:** Build and serve HelloWorld in browser, verify narrow path activates for simple `VStack { Text(...) Color(...) }` trees (manual test — log to console when narrow path succeeds vs falls back)

## Scope Limits (Same as GTK4/Win32)

- Text and color mutations only — no layout, slider, or wrapper mutations yet
- All-or-nothing — any failure falls back to full rebuild
- Position-based identity only — no keyed identity
- No partial mutation — entire tree must be eligible
- Narrow path only activates for trees composed entirely of described views — any opaque wrapper (FontModifiedView, OpacityView, etc.) forces full rebuild
- No closure updating on narrow path — closures preserved from previous render
- No dependency tracking — future phase (shared infrastructure)
