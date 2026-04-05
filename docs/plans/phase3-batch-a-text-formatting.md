# Phase 3 Batch A — Text Formatting

## Core Design (coordinator delivers)

Four new modifiers in `Sources/SwiftOpenUI/Modifiers/TextModifiers.swift`:

```swift
// MARK: - Text Alignment

public enum TextAlignment {
    case leading
    case center
    case trailing
}

// MARK: - Truncation Mode

public enum TruncationMode {
    case head
    case tail
    case middle
}

// MARK: - Modifier Views

public struct LineLimitView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let lineLimit: Int?
}

public struct TruncationModeView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let mode: TruncationMode
}

public struct LineSpacingView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let spacing: Double
}

public struct MultilineTextAlignmentView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let alignment: TextAlignment
}

// MARK: - View Extensions

extension View {
    public func lineLimit(_ number: Int?) -> LineLimitView<Self>
    public func truncationMode(_ mode: TruncationMode) -> TruncationModeView<Self>
    public func lineSpacing(_ lineSpacing: Double) -> LineSpacingView<Self>
    public func multilineTextAlignment(_ alignment: TextAlignment) -> MultilineTextAlignmentView<Self>
}
```

### Core tests (`Tests/SwiftOpenUITests/ModifierTests/TextModifierTests.swift`)

- Modifier wrapping (each modifier stores correct values)
- TextAlignment/TruncationMode enum equality
- lineLimit nil means unlimited

---

## Base commit

Coordinator pushes core types to a branch. All platform workers start from this commit.

---

## GTK4 Worker Instructions

### Context

Text is rendered as `GtkLabel` via `gtk_label_new()` in `GTKRenderer.swift` (line 98). Currently fixed at left-align, single-line, no wrapping.

### What to implement

Add `GTKRenderable` extensions for all four modifier views in `GTKRenderer.swift`.

### LineLimitView

- Render child content
- Find the GtkLabel in the rendered widget (may be wrapped by font/color modifiers)
- If `lineLimit == nil`: `gtk_label_set_wrap(label, 1)` + `gtk_label_set_wrap_mode(label, PANGO_WRAP_WORD_CHAR)` — unlimited wrapping
- If `lineLimit == 1`: `gtk_label_set_wrap(label, 0)` — single line (default behavior)
- If `lineLimit > 1`: `gtk_label_set_wrap(label, 1)` + `gtk_label_set_lines(label, lineLimit)` + `gtk_label_set_ellipsize(label, PANGO_ELLIPSIZE_END)`
- If child is not a GtkLabel, pass through unchanged (modifier only affects text)

### TruncationModeView

- Render child content
- Find the GtkLabel
- Map mode:
  - `.head` → `gtk_label_set_ellipsize(label, PANGO_ELLIPSIZE_START)`
  - `.tail` → `gtk_label_set_ellipsize(label, PANGO_ELLIPSIZE_END)`
  - `.middle` → `gtk_label_set_ellipsize(label, PANGO_ELLIPSIZE_MIDDLE)`

### LineSpacingView

- Render child content
- Find the GtkLabel
- Use Pango attributes: get/create `PangoAttrList`, add `pango_attr_line_spacing_new()` or set spacing via CSS `line-height`
- Alternative: apply CSS `line-height: {calculated}px;` to the label widget

### MultilineTextAlignmentView

- Render child content
- Find the GtkLabel
- Map alignment:
  - `.leading` → `gtk_label_set_justify(label, GTK_JUSTIFY_LEFT)` + `xalign = 0`
  - `.center` → `gtk_label_set_justify(label, GTK_JUSTIFY_CENTER)` + `xalign = 0.5`
  - `.trailing` → `gtk_label_set_justify(label, GTK_JUSTIFY_RIGHT)` + `xalign = 1.0`
- Note: `gtk_label_set_justify` affects multi-line justify; `xalign` affects single-line alignment

### "Find the GtkLabel" helper

Modifiers wrap content, so the label may be nested inside font/color wrapper boxes. Walk the widget tree to find the first GtkLabel descendant. If existing helpers exist in the renderer, reuse them. Otherwise add a small recursive helper.

### Tests (`Tests/BackendTests/GTK4Tests/GTK4TextFormattingTests.swift`)

- LineLimitView with limit 2 → label has wrap enabled, lines set to 2
- TruncationModeView with .tail → label has PANGO_ELLIPSIZE_END
- MultilineTextAlignmentView .center → label xalign is 0.5
- Non-label content passes through unchanged

### Files to edit

- `Sources/Backend/GTK4/Rendering/GTKRenderer.swift` — add 4 extensions
- `Tests/BackendTests/GTK4Tests/GTK4TextFormattingTests.swift` — new test file

### Files NOT to edit

- `Sources/SwiftOpenUI/` (core — coordinator owns)
- `docs/api/implementation-tracker/` (coordinator owns)
- `docs/architecture/swiftui-parity-matrix.md` (coordinator owns)
- `CLAUDE.md` (coordinator owns)

---

## Win32 Worker Instructions

### Context

Text is rendered as a Win32 Static Control with `SS_LEFTNOWORDWRAP` style in `WinRenderer.swift` (line 124). Currently single-line, no wrapping, no truncation.

### What to implement

Add `WinRenderable` extensions for all four modifier views in `WinRenderer.swift`.

### LineLimitView

- Render child content
- The key challenge: Static controls with `SS_LEFTNOWORDWRAP` don't wrap. To enable wrapping:
  - If `lineLimit != 1`: need to change the style to `SS_LEFT` (which word-wraps) and adjust height for multiple lines
  - Use `DrawTextW()` with `DT_WORDBREAK | DT_CALCRECT` to measure wrapped height for `lineLimit` lines
  - If `lineLimit` is a specific number, constrain the height to that many lines and enable truncation
- If child is not a Static text control, pass through unchanged

### TruncationModeView

- Render child content
- Find the Static control
- For single-line: use `SS_ENDELLIPSIS` (tail), `SS_PATHELLIPSIS` (middle)
- For multi-line: may need `DrawTextW` with `DT_END_ELLIPSIS` via owner-draw or subclass
- `.head` truncation: Win32 has no native head-ellipsis for static controls — apply `SS_ENDELLIPSIS` as fallback and document limitation

### LineSpacingView

- Render child content
- Win32 Static controls don't support line spacing natively
- Options:
  - Owner-draw with `DrawTextW` and custom line spacing — high complexity
  - Use D2D text layout with `IDWriteTextFormat::SetLineSpacing` if content is D2D-rendered
  - Simplest: document as a known limitation on Win32 for Batch A, implement basic pass-through
- Choose the approach that fits Win32 backend complexity. Don't over-engineer.

### MultilineTextAlignmentView

- Render child content
- Find the Static control
- Map alignment to window style:
  - `.leading` → `SS_LEFT`
  - `.center` → `SS_CENTER`
  - `.trailing` → `SS_RIGHT`
- May need to modify the existing style with `SetWindowLongW(hwnd, GWL_STYLE, ...)`

### Tests (`Tests/BackendTests/Win32Tests/Win32TextFormattingTests.swift`)

- LineLimitView with limit 1 → static control is single-line
- TruncationModeView with .tail → static control has SS_ENDELLIPSIS
- MultilineTextAlignmentView .center → static control has SS_CENTER style
- Non-text content passes through unchanged

### Files to edit

- `Sources/Backend/Win32/Rendering/WinRenderer.swift` — add 4 extensions
- `Tests/BackendTests/Win32Tests/Win32TextFormattingTests.swift` — new test file

### Files NOT to edit

- `Sources/SwiftOpenUI/` (core — coordinator owns)
- `docs/` (coordinator owns)
- `CLAUDE.md` (coordinator owns)

---

## Web Worker Instructions

### Context

Text is rendered as a `<span>` element in `WebRenderer.swift` (line 137). No wrapping, truncation, or alignment control currently. Font/color applied via wrapper `<div>` with CSS.

### What to implement

Add `WebRenderable` extensions for all four modifier views in `WebRenderer.swift`.

### LineLimitView

- Render child content
- Wrap in a `<div>` with CSS:
  - If `lineLimit == 1`: `white-space: nowrap; overflow: hidden;`
  - If `lineLimit > 1`: `display: -webkit-box; -webkit-line-clamp: {limit}; -webkit-box-orient: vertical; overflow: hidden;`
  - If `lineLimit == nil`: `white-space: normal;` (allow unlimited wrapping)
- `-webkit-line-clamp` is widely supported in modern browsers (Chrome, Safari, Firefox)

### TruncationModeView

- Render child content
- Wrap in a `<div>` with CSS:
  - `.tail`: `text-overflow: ellipsis; overflow: hidden; white-space: nowrap;`
  - `.head`: `direction: rtl; text-overflow: ellipsis; overflow: hidden; white-space: nowrap;` (CSS hack — ellipsis appears at start)
  - `.middle`: No native CSS support. Use `.tail` as fallback and document limitation.
- Note: `text-overflow: ellipsis` only works with `overflow: hidden` and `white-space: nowrap` (single-line). For multi-line, `-webkit-line-clamp` from LineLimitView handles tail truncation.

### LineSpacingView

- Render child content
- Wrap in a `<div>` with CSS:
  - `line-height: calc(1em + {spacing}px);`
  - Or compute from default line-height: if spacing is additional, use relative calculation
- CSS `line-height` is well-supported

### MultilineTextAlignmentView

- Render child content
- Wrap in a `<div>` with CSS:
  - `.leading` → `text-align: left;`
  - `.center` → `text-align: center;`
  - `.trailing` → `text-align: right;`

### Tests (`Tests/BackendTests/WebTests/WebTextFormattingTests.swift`)

- LineLimitView with limit 2 → wrapper has `-webkit-line-clamp: 2`
- TruncationModeView with .tail → wrapper has `text-overflow: ellipsis`
- LineSpacingView with 8.0 → wrapper has `line-height` set
- MultilineTextAlignmentView .center → wrapper has `text-align: center`
- Non-text content still gets wrapper (CSS applies to all inline content)

### Testing approach

Web tests can verify CSS strings on the wrapper div's `style` attribute. No browser runtime needed for these checks — extract style string and assert contents.

### Files to edit

- `Sources/Backend/Web/Rendering/WebRenderer.swift` — add 4 extensions
- `Tests/BackendTests/WebTests/WebTextFormattingTests.swift` — new test file

### Files NOT to edit

- `Sources/SwiftOpenUI/` (core — coordinator owns)
- `docs/` (coordinator owns)
- `CLAUDE.md` (coordinator owns)

---

## Handoff Protocol

1. Coordinator pushes core branch with base types + core tests
2. Each platform worker:
   - `git fetch origin`
   - `git switch -C <platform>-text-formatting-batch-a origin/<core-branch>`
   - `git rev-parse HEAD` — verify matches handoff hash
3. Platform workers edit ONLY their backend files + backend tests
4. Platform workers report back: branch, commit, base commit, changed files, tests run
5. Coordinator reviews and merges each platform branch into develop

## Known Limitations to Document

- Win32 `.lineSpacing()` may be limited or pass-through in Batch A (native Static controls don't support it)
- Web `.truncationMode(.head)` uses CSS `direction: rtl` hack — imperfect for mixed-direction text
- Web `.truncationMode(.middle)` falls back to `.tail` — no native CSS support
- Win32 `.truncationMode(.head)` falls back to `.tail` — no native API
