# Phase 9b: Assessment — Button and Gesture View Describability

## Conclusion

Button and gesture views should remain opaque composites. Describing them introduces two unsound behaviors:

1. **Stale closures:** Button's `action` and gesture views' handler closures are wired once during render. The narrow path skips closure rebinding. A `.reuse` descriptor hides closure changes, leaving stale handlers that reference old captured state.

2. **GTK4 slot capture mismatch:** Simple `Button("text")` uses `gtk_button_new_with_label` with an inaccessible internal GtkLabel. Describing the Text child creates a descriptor leaf with no matching tagged widget.

## Impact on ColorMixer

With Button and TapGestureView remaining opaque, the narrow path **cannot activate** for ColorMixer's host tree — these views exist in the same host alongside the slider-dependent subtree.

The descriptor coverage work from Phase 9 (FontModifiedView, HStack, ZStack, Divider, Spacer, etc.) is still valuable infrastructure — it removes most blockers. The remaining blockers are views with closures and external behavior that the descriptor model cannot safely represent without modeling closure identity.

## What's Needed for True Live-Drag

The narrow path is fundamentally a **host-level** optimization. For it to work on ColorMixer, one of:

1. **Closure identity modeling** — capture enough about closures in descriptors to detect changes. Complex, not obviously better than full rebuild for the closure-heavy parts.

2. **Subtree-level invalidation** — rebuild only the changed subtree within a host, not the whole host. This is the "dirty-subtree" approach described in Phase 10 / cross-backend invalidation notes. It would let the slider rows rebuild independently of the button rows.

3. **Interactive update deferral** — suppress full rebuilds during slider drag (like Win32's `interactiveUpdateDepth`), queue them until drag ends. This doesn't use the narrow path at all — it's a different optimization.

Option 3 is the simplest and most pragmatic path to live-drag. Win32 already has it.

## Recommendation

Do not describe Button or gesture views. Instead, pursue option 3: add interactive update deferral to GTK4 and Web ViewHosts, similar to Win32's `beginInteractiveUpdate` / `endInteractiveUpdate` pattern. This defers full rebuilds during drag and commits one rebuild when the drag ends.

This is a smaller, safer change that achieves the user-visible goal (no flicker during slider drag) without the soundness risks of expanding the narrow path to closure-carrying views.
