# Win32 Catch-Up: Phases 5–9 Alignment (Completed)

## Context

GTK4 and Web backends completed Phases 4–9 of the invalidation roadmap. This document provided instructions to bring Win32 to parity. All steps have been implemented.

## Current Win32 State

**Already done:**
- Descriptor pipeline: describe → identify → retain → match → plan → execute → hook
- 12 descriptor kinds: text, color, vStack, hStack, zStack, padding, frame, background, foregroundColor, border, slider, composite
- Describable views: Text, Color, Slider, VStack, HStack, ZStack, PaddedView, FrameView, BackgroundView, ForegroundColorView, BorderView
- Real mutation hooks: textContent, colorFill
- Interactive deferral: `beginInteractiveUpdate` / `endInteractiveUpdate` in Win32ViewHost
- Slider interactive deferral: already wired via D2DSliderState drag handling

**Gaps to fill:**

| Gap | Reference (GTK4/Web) | Win32 File |
|-----|----------------------|------------|
| `.sliderValue` in eligibility gate | GTK4DescriptorTree.swift:574 | Win32DescriptorTree.swift:408 |
| `.paddingLayout` in eligibility gate | Same | Same |
| `.sliderValue` in slot validation | GTK4DescriptorTree.swift:900 | Win32DescriptorTree.swift (equivalent) |
| `.paddingLayout` in slot validation | Same | Same |
| `.font` descriptor kind | GTK4DescriptorTree.swift:10 | Win32DescriptorTree.swift |
| `.divider` descriptor kind | GTK4DescriptorTree.swift:9 | Win32DescriptorTree.swift |
| `.spacer` descriptor kind | GTK4DescriptorTree.swift:18 | Win32DescriptorTree.swift |
| `Win32FontDescriptor` | GTK4DescriptorTree.swift:96 | Win32DescriptorTree.swift |
| `.fontStyle` update intent | GTK4DescriptorTree.swift:240 | Win32DescriptorTree.swift |
| FontModifiedView describable | GTKRenderer.swift:835 | WinRenderer.swift |
| Divider describable | GTKRenderer.swift:131 | WinRenderer.swift |
| Spacer describable | GTKRenderer.swift:121 | WinRenderer.swift |
| Phase 6: dependency tracking | DependencyTracking.swift (shared) | Win32ViewHost.swift |
| Phase 7: input-equality | DependencyTracking.swift (shared) | Win32ViewHost.swift |

## Step-by-Step Instructions

### Step 1: Add missing descriptor kinds

**File:** `Sources/Backend/Win32/Rendering/Win32DescriptorTree.swift`

Add to `Win32DescriptorKind` enum:
```swift
case divider
case font
case spacer
```

Add `Win32FontDescriptor`:
```swift
public struct Win32FontDescriptor: Equatable {
    public let font: Font
}
```

Add `.font(Win32FontDescriptor)` to `Win32DescriptorProps` enum.

Add `case fontStyle` to `Win32DescriptorUpdateIntent` enum.

In `winUpdateIntent()` switch, add:
```swift
case .divider: return .none
case .font:    return .fontStyle
case .spacer:  return .none
```

In the hook dispatch switch (`winUpdateHook`), add `.fontStyle` to the descriptive-only fallthrough case.

### Step 2: Expand eligibility gate

**File:** `Sources/Backend/Win32/Rendering/Win32DescriptorTree.swift`

In `winCanApplyTextColorHostMutation` (or equivalent function), expand the `.update` case guard:
```swift
guard plan.updateIntent == .textContent
   || plan.updateIntent == .colorFill
   || plan.updateIntent == .sliderValue
   || plan.updateIntent == .paddingLayout
else { return false }
```

In `winAllSlotsValid` (or equivalent), expand the `.update` case to validate `.sliderValue` and `.paddingLayout` slots alongside `.textContent` and `.colorFill`.

### Step 3: Add WinDescribable to remaining views

**File:** `Sources/Backend/Win32/Rendering/WinRenderer.swift`

Add `WinDescribable` conformance to:

**FontModifiedView** → `.font` kind with font prop + child:
```swift
extension FontModifiedView: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(kind: .font, typeName: "FontModifiedView",
                             props: .font(Win32FontDescriptor(font: font)),
                             children: [winDescribeView(content)])
    }
}
```

**Divider** → `.divider` kind, no props, no children:
```swift
extension Divider: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(kind: .divider, typeName: "Divider")
    }
}
```

**Spacer** → `.spacer` kind, no props, no children:
```swift
extension Spacer: WinDescribable {
    public func winDescribeNode() -> Win32DescriptorNode {
        Win32DescriptorNode(kind: .spacer, typeName: "Spacer")
    }
}
```

### Step 4: Wire Phase 6 dependency tracking

**File:** `Sources/Backend/Win32/Rendering/Win32ViewHost.swift`

The shared infrastructure (`DependencyTracking.swift`) already exists. Win32ViewHost needs to:

1. Conform to `DependencyTrackingHost`:
```swift
public class Win32ViewHost: AnyViewHost, DependencyTrackingHost {
    public var lastReadSet: Set<ObjectIdentifier>?
    public var lastInputSnapshot: [StorageSnapshot]?
    // ... existing properties
}
```

2. Wrap `buildBodyWithTracking()` in `rebuild()`:
```swift
beginDependencyTracking()
let newChild = buildBodyWithTracking(childContext)
if let tracking = endDependencyTracking() {
    lastReadSet = tracking.readSet
    lastInputSnapshot = tracking.snapshots
}
```

3. Do the same in the initial render path (equivalent of `winRenderStatefulView`).

### Step 5: Wire Phase 7 input-equality short-circuiting

**File:** `Sources/Backend/Win32/Rendering/Win32ViewHost.swift`

In `rebuild()`, after the narrow mutation path fails but before the full rebuild:
```swift
// Phase 7: skip if inputs unchanged
if let snapshot = lastInputSnapshot,
   inputsUnchanged(snapshot: snapshot) {
    return
}
```

### Step 6: Add tests

**File:** `Tests/BackendTests/Win32Tests/Win32RenderTests.swift`

Add descriptor-level tests matching GTK4/Web patterns:
- `testDescribeFontModifiedView` — produces `.font` descriptor
- `testDescribeDivider` — produces `.divider`
- `testDescribeSpacer` — produces `.spacer`
- `testCanApplySliderValueMutation` — `.sliderValue` passes eligibility
- `testFontChangeRejectsNarrowPath` — `.fontStyle` rejected

### Step 7: Update CLAUDE.md test count

## Verification

1. `swift build` on Windows — clean build
2. `swift test` on Windows — all existing + new tests pass
3. Manual: run ColorMixer on Windows, verify slider drag behavior

## Reference Files

These are the GTK4/Web implementations to follow as patterns:

| Pattern | GTK4 Reference | Web Reference |
|---------|---------------|---------------|
| Eligibility gate | `GTK4DescriptorTree.swift:562-580` | `WebDescriptorTree.swift:557-580` |
| Slot validation | `GTK4DescriptorTree.swift:897-912` | `WebDescriptorMutation.swift:92-112` |
| FontModifiedView describable | `GTKRenderer.swift:835-845` | `WebRenderer.swift:1019-1027` |
| Divider/Spacer describable | `GTKRenderer.swift:131-137` | `WebRenderer.swift:117-133` |
| Dependency tracking in rebuild | `GTKViewHost.swift:225-231` | `WebViewHost.swift:143-150` |
| Phase 7 short-circuit | `GTKViewHost.swift:194-197` | `WebViewHost.swift:130-133` |

## Notes

- `Font` already conforms to `Equatable` (added in Phase 9 commit `d002c57`)
- `GenerationTracked` protocol, `StorageSnapshot`, `inputsUnchanged()` are all in `Sources/SwiftOpenUI/State/DependencyTracking.swift` — shared across all backends
- `beginInteractiveUpdate()` / `endInteractiveUpdate()` are already on `AnyViewHost` with default no-ops — Win32ViewHost already has its own implementation
- The eligibility function name is still `*CanApplyTextColorHostMutation` on all backends — rename to `*CanApplyNarrowHostMutation` deferred until all backends are aligned (this is that moment)
