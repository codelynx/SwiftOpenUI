import WinSDK
import CWin32
import SwiftOpenUI

// MARK: - Win32 Incremental Reconcile (Phase 1)
//
// Instead of always destroying and recreating the HWND subtree on rebuild,
// attempt to update existing HWNDs in place when the tree structure matches.
//
// Strategy: "create-then-adopt"
// 1. Build the new HWND subtree as usual (buildBody creates fresh HWNDs)
// 2. Compare old vs new trees by HWND class name + child count
// 3. If structure matches: transfer content from new to old, destroy new
// 4. If structure mismatches: destroy old, adopt new (current behavior)
//
// This avoids needing a "describe without creating" path while still
// proving the reconciliation concept for ColorMixer.

/// Safe-to-reconcile class names. Only truly self-describing leaf
/// nodes where we know how to transfer all relevant state.
/// SwiftUIStack is NOT safe — it's shared by FrameView, BackgroundView,
/// ForegroundColorView, PaddingView, etc. which all hang stateful info
/// off the same HWND class. Reconciling them preserves stale wrapper state.
/// SwiftUIContainer is NOT safe — it's the ViewHost container.
/// Wrapper preservation requires backend node identity (retained tree),
/// not raw HWND class names.
private let reconcilableClasses: Set<String> = [
    "Static",              // Text labels — SetWindowTextW
    "SwiftUID2DView",      // Color/Divider — drawCallback transfer
    "SwiftUID2DSurface",   // Slider D2D surfaces
]

/// Compare two HWND subtrees structurally (class name + child count).
/// Returns true only if the structure matches AND every node is a
/// type we know how to safely reconcile in place.
func canReconcile(oldHwnd: HWND, newHwnd: HWND) -> Bool {
    let oldClass = className(of: oldHwnd)
    let newClass = className(of: newHwnd)
    guard oldClass == newClass else { return false }

    // Only reconcile node types we explicitly handle
    guard reconcilableClasses.contains(oldClass) else { return false }

    // Compare child count
    let oldChildren = collectDirectChildren(of: oldHwnd)
    let newChildren = collectDirectChildren(of: newHwnd)
    guard oldChildren.count == newChildren.count else { return false }

    // Recursively check children
    for (oldChild, newChild) in zip(oldChildren, newChildren) {
        if !canReconcile(oldHwnd: oldChild, newHwnd: newChild) {
            return false
        }
    }

    return true
}

/// Transfer content from new HWNDs to old HWNDs in place.
/// Updates text and visual state ONLY — does NOT change position/size.
/// The old HWNDs already have correct layout from the WM_SIZE cascade.
/// The new HWNDs were created in a temp 0x0 container so their sizes
/// are wrong — copying them would break the existing layout.
func reconcileInPlace(oldHwnd: HWND, newHwnd: HWND) {
    let cls = className(of: oldHwnd)

    // Update text content (Text labels only — not Button or Edit which
    // have stateful closures/bindings that we can't safely retarget)
    if cls == "Static" {
        let textLen = GetWindowTextLengthW(newHwnd)
        if textLen >= 0 {
            let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(textLen) + 1)
            defer { buf.deallocate() }
            GetWindowTextW(newHwnd, buf, textLen + 1)

            // Only update if text actually changed
            let oldLen = GetWindowTextLengthW(oldHwnd)
            var textChanged = oldLen != textLen
            if !textChanged {
                let oldBuf = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(oldLen) + 1)
                defer { oldBuf.deallocate() }
                GetWindowTextW(oldHwnd, oldBuf, oldLen + 1)
                textChanged = wcscmp(buf, oldBuf) != 0
            }

            if textChanged {
                SetWindowTextW(oldHwnd, buf)
                // Trigger repaint after text change
                InvalidateRect(oldHwnd, nil, false)
            }
        }
    }

    // Transfer D2D draw callback from new to old so the surface
    // paints with updated values (e.g. new color from slider change).
    if cls == "SwiftUID2DSurface" || cls == "SwiftUID2DView" {
        transferD2DViewState(from: newHwnd, to: oldHwnd)
        InvalidateRect(oldHwnd, nil, false)
    }

    // Recurse into children — content only, no layout changes
    let oldChildren = collectDirectChildren(of: oldHwnd)
    let newChildren = collectDirectChildren(of: newHwnd)
    for (oldChild, newChild) in zip(oldChildren, newChildren) {
        reconcileInPlace(oldHwnd: oldChild, newHwnd: newChild)
    }
}

/// Property name for storing a reconcile-update closure on D2D HWNDs.
let d2dReconcilePropName: UnsafePointer<WCHAR> = {
    "SwiftUID2DReconcile".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

/// Box for storing a reconcile closure as a window property.
class D2DReconcileBox {
    let update: (HWND) -> Void
    init(_ update: @escaping (HWND) -> Void) { self.update = update }
}

/// Transfer D2D draw state from a new HWND to an old HWND.
/// The new HWND has a reconcile closure stored as a window property
/// that knows how to update the old HWND's draw callback.
func transferD2DViewState(from newHwnd: HWND, to oldHwnd: HWND) {
    let ptr = GetPropW(newHwnd, d2dReconcilePropName)
    guard let ptr = ptr else { return }
    let box = Unmanaged<D2DReconcileBox>.fromOpaque(ptr).takeUnretainedValue()
    box.update(oldHwnd)
}

/// Get the Win32 class name of an HWND.
private func className(of hwnd: HWND) -> String {
    let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: 256)
    defer { buf.deallocate() }
    let len = GetClassNameW(hwnd, buf, 256)
    guard len > 0 else { return "" }
    return String(decodingCString: buf, as: UTF16.self)
}

/// Collect direct child HWNDs in creation order.
private func collectDirectChildren(of parent: HWND) -> [HWND] {
    var children: [HWND] = []
    var child = GetWindow(parent, UINT(GW_CHILD))
    while let c = child {
        children.append(c)
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
    return children
}
