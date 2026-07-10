# Win32: conditional view (`if/else`) does not rebuild when condition changes

## Summary

When a SwiftOpenUI `@Observable` property changes and a conditional view
(`if condition { ViewA } else { ViewB }`) should switch branches, the Win32
backend does not replace the old view subtree with the new one. The old
branch remains visible even though the condition has changed and the binding
has been updated.

Property changes within the *same* view (e.g., updating text, toggling
colors) work correctly — observation fires and the HWND content updates.
The issue is specifically with **structural changes** that require destroying
one set of HWNDs and creating a different set.

## Impact (found in Synca)

Synca's `ContentView` switches between `SingleFolderView` and
`DualFolderView` based on `appState.requiresSecondaryFolder`:

```swift
Group {
    if appState.requiresSecondaryFolder {
        DualFolderView(...)
    } else {
        SingleFolderView(...)
    }
}
```

When the user switches the segmented picker from Snapshot → Compare:
- The picker's binding fires (`appState.selectedAction = .compare`)
- The segmented control visually updates (bold text on "Compare")
- But the view tree does **not** rebuild: title stays "Snapshot", button
  stays "Save", and only one drop zone is shown instead of two

This blocks testing of Compare and Sync modes on Windows.

## Root cause (hypothesis)

The Win32 backend uses an eager HWND-creation model: views create child
HWNDs at init time via `winCreateWidget(in:)`. When observation triggers
a rebuild, the backend needs to:

1. Detect which view subtrees have structurally changed
2. Destroy the old HWNDs for the removed branch
3. Create new HWNDs for the new branch
4. Re-layout the parent container

GTK4 handles this via its lazy size-allocate model and the
`GTK4DescriptorTree` reconciliation pass. The Win32 backend may not have
an equivalent structural-diff mechanism — property updates work because
they modify existing HWNDs in-place, but branch swaps require HWND
creation/destruction that isn't implemented.

## Reproduction

1. Launch Synca on Windows (`swift run Synca`)
2. App shows Snapshot mode (single drop zone, "Save" button)
3. Click "Compare" in the segmented picker
4. Expected: two drop zones, "Compare" button, title says "Compare"
5. Actual: single drop zone, "Save" button, title says "Snapshot"

## Severity

**High** — blocks all multi-mode UI on Win32. Any app using conditional
views (`if/else`, `switch`, optional binding) for structural changes will
show stale content. This is the primary blocker for Synca's Windows
runtime validation.

## Files

- `Sources/Backend/Win32/Rendering/Win32Backend.swift` — rebuild scheduling
- `Sources/Backend/Win32/Rendering/Win32ViewHost.swift` — view tree hosting
- `Sources/Backend/Win32/Rendering/WinRenderer.swift` — widget creation

## Comparison

- **GTK4**: works correctly — `GTK4DescriptorTree` diffs the view tree
  and replaces changed subtrees during the reconciliation pass.
- **macOS (SwiftUI)**: works correctly — native SwiftUI handles
  conditional views natively.
