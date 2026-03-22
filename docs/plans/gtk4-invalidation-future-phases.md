# GTK4 Invalidation: Phase Status

## Context

Tracks the phased invalidation roadmap across all backends (GTK4, Web, Win32). Phases 1–9 are complete. Phase 10 (cross-backend shared logic) is future work.

## Completed Phases

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Backend descriptor model (GTK4/Web/Win32 DescriptorTree) | Completed |
| 2 | Position-based structural identity | Completed |
| 3 | Match/plan/execute pipeline | Completed |
| 4 | Narrow text/color-only host mutation | Completed |
| 5 | Slider host integration (.sliderValue in-place mutation) | Completed |
| 6 | Host-level dependency gating (@Published read-set tracking) | Completed |
| 7 | Input-equality short-circuiting (generation counters) | Completed |
| 8 | Wrapper/layout mutation (padding, backgroundColor, foregroundColor) | Completed |
| 9 | Descriptor coverage expansion + Button/gesture assessment | Completed |
| — | Interactive update deferral (slider drag) | Completed |

## Future Phases

### Phase 5: Slider host integration (Completed)

**Goal:** Avoid full rebuild during slider drag — mutate slider value in place.

**GTK mechanism:** `gtk_range_set_value(GtkRange*, gdouble)` on existing GtkScale widget.

**Depends on:** Hosted-node tagging for slider widgets, descriptor pipeline wired for `.sliderValue` intent.

**Win32 reference:** Slider suppression during drag + `.sliderValue` vs `.sliderConfiguration` intent split.

### Phase 6: Local dependency tracking (Completed)

**Goal:** Track which @State/@Published properties a view subtree depends on, so only affected subtrees rebuild.

**Approach:**
- During body evaluation, record which storage keys are read
- On state change, identify which ViewHosts need rebuild based on dependency overlap
- Skip rebuild for ViewHosts whose dependencies weren't touched

**Cross-backend:** This should be shared infrastructure in `Sources/SwiftOpenUI/State/`, not backend-specific.

### Phase 7: Input-equality short-circuiting (Completed)

**Goal:** Skip rebuild entirely when the view's inputs haven't changed (same @State values produce same body).

**Approach:**
- Cache the last input values (via Equatable or hashing)
- On state change, compare new inputs to cached inputs
- If equal, skip body evaluation entirely

**Cross-backend:** Shared infrastructure, benefits all backends equally.

### Phase 8: Wrapper/layout mutation (Completed)

**Goal:** Update padding, frame, background, foreground color in place without rebuilding the widget subtree.

**GTK mechanism:**
- Padding: update CSS padding properties on existing wrapper
- Background: use replaceable CSS provider (from Phase 4)
- ForegroundColor: update CSS color property
- Frame: update `gtk_widget_set_size_request` + GtkFixed position

**Depends on:** Phase 4 (single-provider CSS mechanism), shared layout foundation.

### Phase 9: Live interactive updates (Completed — descriptor coverage + interactive deferral)

**Goal:** Slider drag updates dependent views (color swatch, hex text, RGB labels) in real time without flicker.

**Depends on:** Phase 5 (slider mutation) + Phase 6 (dependency tracking) or at minimum Phase 8 (wrapper mutation).

**Win32 reference:** `docs/issues/win32-colormixer-swatch-not-live-during-slider-drag.md`

### Phase 10: Cross-backend invalidation

**Goal:** Move descriptor/identity/match/plan logic into shared `Sources/SwiftOpenUI/` code so all backends use the same diffing pipeline.

**Approach:**
- Extract backend-neutral descriptor kinds and planning logic
- Backends provide measurement + mutation hooks
- Shared code drives the pipeline

**Prerequisites met:** Backend-local pipelines are stable on GTK4, Web, and Win32. Descriptor kinds, update intents, and describable coverage are aligned across all three backends. Phase 10 is the next step.

## Relationship to Win32 Plans

| Win32 Plan Doc | Equivalent Phase | Status |
|----------------|-----------------|--------|
| `win32-incremental-reconcile-spike.md` | Phase 5-8 | Completed |
| `win32-minimal-path-to-swiftui-like-invalidation.md` | Phase 5-10 | Phases 5-9 completed; Phase 10 open |
| `win32-text-color-host-integration-plan.md` | Phase 1-4 | Completed |
| `win32-catch-up-phases5-9.md` | Phase 5-9 alignment | Completed |
| `cross-backend-invalidation-notes.md` | Phase 10 | Open |
| `phase9b-button-gesture-assessment.md` | Phase 9 assessment | Completed |
