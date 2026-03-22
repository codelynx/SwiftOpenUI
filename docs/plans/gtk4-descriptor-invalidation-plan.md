# GTK4 Descriptor-First Invalidation Plan (Completed)

## Context

Win32 landed a descriptor/executor/hook pipeline for narrow in-place mutation (text + color only), avoiding full widget tree rebuild for simple state changes. We need the same on GTK4 to:
- Avoid destroying/recreating GtkLabel for text-only changes (use `gtk_label_set_text`)
- Avoid destroying/recreating GtkBox for color-only changes (use `applyCSSToWidget`)
- Keep full rebuild as fallback for anything else

## Branch

Create `feature/gtk4-descriptor-invalidation` from `develop` before starting.

## Architecture (mirrors Win32)

```
describe → identify → retain → match → plan → execute → hook → mutate-or-fallback
```

All layers are pure data until the final hook mutation step.

## Deliverables

### 1. GTK4DescriptorTree.swift (new file)

**Location:** `Sources/Backend/GTK4/Rendering/GTK4DescriptorTree.swift`

Types (mirror Win32 naming with GTK4 prefix):
- `GTK4DescriptorKind` — text, color, vStack, hStack, zStack, frame, padding, background, foregroundColor, border, slider, composite
- `GTK4TextDescriptor`, `GTK4ColorDescriptor`, etc. — property structs
- `GTK4DescriptorProps` — enum wrapping property structs
- `GTK4DescriptorNode` — kind + typeName + props + children
- `GTK4DescriptorIdentity` — position-based path `[Int]`
- `GTK4IdentifiedDescriptorNode` — identity + descriptor + children
- `GTK4RetainedDescriptorNode` — for matching old vs new
- `GTK4RetainedExecutorNode` — identity + kind + lastDescriptor + nativeSlotID + children
- `GTK4DescriptorMatch`, `GTK4DescriptorPlan`, `GTK4ExecutorAction`, `GTK4HookResult`
- `GTK4DescriptorUpdateIntent` — textContent, colorFill, + others as descriptive-only

Functions:
- `gtkDescribeView(_:)` — walks view tree, produces descriptor (like `winDescribeView`)
- `gtkIdentifyDescriptorTree(_:)` — assigns position paths
- `gtkRetainDescriptorTree(_:)` — freezes for comparison
- `gtkMakeExecutorTree(from:)` — initial executor state
- `gtkMatchDescriptorTree(old:new:)` — structural match
- `gtkPlanDescriptorTree(old:new:)` — create/reuse/update/replace decisions
- `gtkExecuteDescriptorPlan(old:plan:)` — executor actions
- `gtkApplyHook(action:)` — descriptive dispatch
- `gtkApplyHookMutation(action:)` — real mutation for text/color only
- `gtkCanApplyTextColorHostMutation(plan:)` — eligibility check
- `gtkCaptureSupportedNativeSlots(from:descriptorRoot:executorRoot:)` — walk GTK widget tree, capture GtkLabel/Color GtkBox pointers

**Protocol:** `GTKDescribable` with `func gtkDescribeNode() -> GTK4DescriptorNode`

**GTK-specific mutation functions:**
- `gtkSetTextContent(widget:text:)` — calls `gtk_label_set_text(GTK_LABEL(widget), text)`
- `gtkSetColorFill(widget:color:)` — uses a dedicated single-provider mechanism:
  store one `GtkCssProvider` per hosted Color widget via `g_object_set_data`.
  On mutation, reload the existing provider with the new `background-color` CSS
  instead of calling `applyCSSToWidget` (which stacks new providers indefinitely).
  Helper: `gtkReplaceCSSBackground(widget, r, g, b, a)` that creates or reuses
  the provider stored under key `"gtk-swift-color-provider"`.

### 2. GTKRenderer.swift extensions

Add `GTKDescribable` conformance to existing GTKRenderable extensions:
- `Text` — returns `.text` with `GTK4TextDescriptor(content:)`
- `Color` — returns `.color` with `GTK4ColorDescriptor(r:g:b:a:)`
- `VStack` — returns `.vStack` with spacing/alignment, recurse children
- `HStack` — returns `.hStack`
- `ZStack` — returns `.zStack`
- `PaddedView` — returns `.padding`
- `FrameView` — returns `.frame`
- `BackgroundView` — returns `.background`
- `ForegroundColorView` — returns `.foregroundColor`
- `BorderView` — returns `.border`

### 3. Shim additions (shim.h)

- `gtk_swift_label_set_text(widget, text)` — wraps `gtk_label_set_text(GTK_LABEL(widget), text)`

### 4. GTKViewHost.swift changes

Add to GTKViewHost:
- `var retainedExecutorTree: GTK4RetainedExecutorNode?` — persists across rebuilds
- `var lastDescriptorTree: GTK4RetainedDescriptorNode?` — for matching

Modify `rebuild()`:
```
1. Describe new body → GTK4DescriptorNode
2. Identify → GTK4IdentifiedDescriptorNode
3. If lastDescriptorTree exists:
   a. Plan against retained state
   b. If plan is only reuse + textContent/colorFill updates
      AND all native slots valid:
      - Execute plan
      - Apply hook mutation (real gtk_label_set_text / CSS update)
      - If all mutations succeeded:
        - Update retained state
        - RETURN (skip full rebuild)
4. Fall through to existing full rebuild
5. After full rebuild:
   - Capture native slots for text/color widgets
   - Store descriptor tree and executor tree for next cycle
```

### 5. Hosted-node tagging + native slot capture on GTK4

**Tagging (during render):**
During `gtkCreateWidget()` for Text and Color, tag the native widget with its hosted kind using `g_object_set_data`:
- `g_object_set_data(gobject, "gtk-swift-hosted-kind", "text")` on GtkLabel
- `g_object_set_data(gobject, "gtk-swift-hosted-kind", "color")` on Color's GtkBox

Add `gtkMarkHostedNodeKind(widget, kind)` and `gtkHostedNodeKind(widget)` helpers mirroring Win32's `markHostedNodeKind` / `hostedNodeKind(of:)`.

**Slot capture (after rebuild):**
Walk the rebuilt widget tree (DFS), check each widget for hosted-kind tag:
- If tagged "text" → store GtkLabel pointer as slot
- If tagged "color" → store GtkBox pointer as slot
- Skip untagged wrapper widgets (padding boxes, frame containers, etc.)

Match captured slots against descriptor tree by validating descriptor kind == hosted kind, not just subtree order. This prevents misalignment when wrappers sit around supported leaves.

Use `gtkNativeSlotID(for:)` → `Int(bitPattern: OpaquePointer(widget))`

### 6. Tests

**Pure descriptor tests:** `Tests/BackendTests/GTK4Tests/GTK4DescriptorTests.swift` (new file)
No GTK runtime needed — tests describe/identify/match/plan/execute/hook as pure data.

**Runtime render tests:** `Tests/BackendTests/GTK4Tests/GTK4RenderTests.swift` (extend existing)
Requires GTK init — tests native slot capture, in-place mutation, fallback behavior.

Tests mirroring Win32:
- Describe Text → correct kind/props
- Describe Color → correct kind/props
- Describe VStack with children → correct tree structure
- Identify assigns position paths
- Match same structure → reuse
- Match different structure → replace
- Plan text change → update with textContent intent
- Plan color change → update with colorFill intent
- Plan structural change → replace
- Execute plan → correct executor actions
- Hook dispatch → correct hook results
- `gtkCanApplyTextColorHostMutation` → true for text/color only plans

### 7. Optional: TextColorMutationProbe example

Small example app that changes text and color on button tap — useful for manual validation.

## Scope Limits (from Win32 handoff)

- NO slider host integration
- NO layout-intent mutation
- NO generic wrapper mutation
- NO keyed identity
- NO partial mutation (all-or-nothing)
- Full rebuild fallback preserved

## Implementation Order

1. GTK4DescriptorTree.swift — descriptor types + pure functions (no GTK calls)
2. Tests for descriptor/identify/match/plan/execute/hook layers
3. GTKDescribable conformances in GTKRenderer.swift
4. Shim for gtk_label_set_text
5. Real mutation functions (gtkSetTextContent, gtkSetColorFill)
6. GTKViewHost integration (describeBody + narrow mutation path)
7. Native slot capture
8. End-to-end tests

## Verification

1. `swift build` — clean
2. `swift test` — all existing + new tests pass
3. Manual: run TextColorMutationProbe, change text via button tap → verify no widget tree rebuild (no flicker, focus preserved)
4. Manual: run Calculator → verify full rebuild still works for structural changes

## Files to create/modify

| File | Action |
|------|--------|
| `Sources/Backend/GTK4/Rendering/GTK4DescriptorTree.swift` | New — all descriptor types + pure functions |
| `Sources/Backend/GTK4/Rendering/GTKRenderer.swift` | Add GTKDescribable conformances |
| `Sources/Backend/GTK4/Rendering/GTKViewHost.swift` | Add retained state + narrow mutation path |
| `Sources/Backend/GTK4/CGTK/shim.h` | Add gtk_swift_label_set_text |
| `Tests/BackendTests/GTK4Tests/GTK4DescriptorTests.swift` | New — pure descriptor pipeline tests |
| `Tests/BackendTests/GTK4Tests/GTK4RenderTests.swift` | Extend with runtime mutation tests |
| `Examples/Showcase/TextColorMutationProbe/main.swift` | Optional probe example |

## Reference Implementation

- `Sources/Backend/Win32/Rendering/Win32DescriptorTree.swift`
- `Sources/Backend/Win32/Rendering/Win32RetainedTree.swift`
- `Sources/Backend/Win32/Rendering/Win32ViewHost.swift`
- `Tests/BackendTests/Win32Tests/Win32RenderTests.swift`
