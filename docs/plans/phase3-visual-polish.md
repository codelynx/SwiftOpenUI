# Phase 3 — Visual Polish & App Readiness

**Status: Complete.**

## Goal

Close the highest-impact view and modifier gaps so SwiftOpenUI can build real-looking apps, not just functional demos.

## Existing Foundation

Not starting from zero — these already exist:
- `Path` view with drawing commands (`Sources/SwiftOpenUI/Views/Path.swift`)
- `.cornerRadius()`, `.shadow()`, `.border()`, `.opacity()`, `.overlay()` modifiers
- Win32 D2D drawing infrastructure
- GTK4 CSS styling + Cairo rendering
- Web CSS properties

## Batches

### Batch A: Text Formatting

lineLimit, truncationMode, lineSpacing, multilineTextAlignment.

**Why first:** Lowest risk, highest app-visible gain. Text view exists, these are additive modifiers with clear backend mappings.

**Core:** Modifier structs + View extensions in `Sources/SwiftOpenUI/Modifiers/`.

**Backends:** Pango properties (GTK4), CSS text properties (Web), DrawText flags (Win32).

---

### Batch B: Shape Views

Circle, Rectangle, RoundedRectangle, Capsule, Ellipse as `View` types.

**Why:** The single biggest API gap. These are standalone shape views that render as filled/stroked geometry.

**Core:** `Shape` protocol + 5 concrete types in `Sources/SwiftOpenUI/Views/`. Reuse existing `Path` infrastructure where possible.

**Backends:** Each backend chooses its own rendering strategy — the plan specifies the outcome (a filled/stroked geometric shape), not the mechanism. GTK4 may use Cairo drawing, Web may use SVG or CSS, Win32 may use D2D geometry.

**Not in this batch:** `.clipShape()` — view clipping is a different problem (masking the render output of an arbitrary view) and needs its own design.

---

### Batch C: Shape Styling + clipShape

`.fill()`, `.stroke()`, `.clipShape()`.

**Why separate:** `.fill()`/`.stroke()` define how shape views render. `.clipShape()` applies a shape as a clipping mask to any view — different rendering problem, different backend integration points.

**Prerequisites:** Batch B (shape types must exist).

**Core:** Modifiers that take a `Shape` parameter.

**Backends:** Each backend's clipping mechanism (CSS `clip-path`/`overflow`, Cairo clip, D2D clip geometry).

---

### Batch D: Appearance Modifiers (bounded)

Split by effort:

**D1 — `.hidden()`:** Trivial. Sets visibility to false. One modifier, one backend property each.

**D2 — `.clipped()`:** Medium. Clips view to its bounds. Backend-specific (CSS `overflow: hidden`, GTK widget clip, Win32 clip region). Partially overlaps with existing `.cornerRadius()` which already clips on Web.

**D3 — `.blur(radius:)`:** Higher effort. CSS `filter: blur()` on GTK4/Web. Win32/D2D Gaussian blur effect. Defer if backend cost is too high.

---

### Batch E: Style Protocols (core design)

ButtonStyle, TextFieldStyle, ToggleStyle + `makeBody(configuration:)`.

**Why separate:** This is an architectural feature, not just a modifier. Requires:
- Core style resolution model (environment-driven)
- Configuration types per control
- `makeBody(configuration:)` protocol pattern
- Backend rendering changes to defer to style body

**Scope:** Core API design first. Backend integration is a follow-on. This is Phase 3's largest single item and should not be mixed with bounded modifier work.

---

## Phase 4 (future)

- contextMenu
- ScrollViewReader
- AsyncImage
- fullScreenCover / popover
- onChange
- Complete frame overloads, layoutPriority, position

---

## Execution Order

A → B → C → D1 → D2 → D3 → E

Text formatting first (low risk, immediate value). Shapes next (biggest gap). clipShape after shapes exist. Appearance modifiers individually by effort. Style protocols last (largest design surface).
