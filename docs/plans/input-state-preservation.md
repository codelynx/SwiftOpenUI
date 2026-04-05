# Input-State Preservation — Phase 2 Item 4

**Status: Implemented (Win32, GTK4, Web). Android unverified.**

## Goal

Cursor position, text selection, and focus survive full rebuilds on all platforms.

## Current Status

| Platform | Focus | Cursor | Selection | Tests | Status |
|----------|-------|--------|-----------|-------|--------|
| Win32 | Save by class+index | EM_GETSEL/EM_SETSEL | All Edit controls | 7 tests | **Done, validated** |
| GTK4 | Save by DFS index | gtk_text_iter offsets | GtkTextView/Editable | 12 tests | **Done, aligned** |
| Web | Save by tag+type+index | selectionStart/End | Text-selectable only | 15 tests | **Done, needs browser verification** |
| Android | Delegated to Compose | Delegated to Compose | Delegated to Compose | 0 tests | **Unverified** |

All three implemented backends share consistent suppress semantics: `suppressNextFocusRestore` skips focus but still restores cursor/selection.

---

## Web — Implementation

### Problem

`WebViewHost.rebuild()` does `innerHTML = ""`, destroying all DOM elements. Any focused input loses cursor position, selection, and focus.

### Approach

Save/restore around rebuild, narrowed to text-selectable controls only.

### Input type classification

Not all `<input>` types support `selectionStart`/`selectionEnd`/`setSelectionRange()`. The save/restore must distinguish:

| Element / type | Focus restorable | Selection restorable |
|----------------|-----------------|---------------------|
| `<input type="text">` | Yes | Yes |
| `<input type="password">` | Yes | Yes |
| `<input type="search">` | Yes | Yes |
| `<textarea>` | Yes | Yes |
| `<input type="checkbox">` | Yes | No |
| `<input type="range">` | Yes | No |
| `<input type="date">` | Yes | No |

**Rule:** Only call `setSelectionRange()` on text/password/search/textarea. For other focused controls, restore `focus()` only.

**Error tolerance:** If `selectionStart`/`selectionEnd`/`selectionDirection` cannot be read during save, or if `focus()`/`setSelectionRange()` fails during restore (e.g., element not visible, type mismatch), fall back silently to focus-only or skip entirely. Never treat a restore failure as an error — conservative skip is correct behavior, same principle as the animation batch.

### Identity matching

DFS index alone is not robust — if rebuild changes the number or order of earlier controls, the index shifts. Use a composite identity signal with a bail-out guard:

1. Record the focused element's **tag** (`input`/`textarea`), **type attribute** (`text`/`password`/`range`/etc.), and **DFS index** among elements of the same tag+type.
2. After rebuild, find elements matching the same tag+type, locate the Nth one.
3. **Bail-out guard**: If the total count of that tag+type changed between old and new DOM, skip restoration entirely. Structural change means we can't match confidently.

```swift
struct WebFocusSnapshot {
    let tag: String          // "input" or "textarea"
    let inputType: String    // "text", "password", "range", etc.
    let typeIndex: Int       // Nth element of this tag+type
    let typeCount: Int       // Total count of this tag+type (for bail guard)
    let selectionStart: Int? // Only for text-selectable types
    let selectionEnd: Int?
    let selectionDirection: String?
}
```

### Files

- `Sources/Backend/Web/Rendering/WebViewHost.swift`
  - Add `WebFocusSnapshot` struct
  - Add `webSaveFocusState(in:)` → reads `document.activeElement`, classifies type, captures selection if applicable
  - Add `webRestoreFocusState(_:in:)` → finds matching element, applies `focus()` + `setSelectionRange()` if applicable
  - In `rebuild()`: save before `innerHTML = ""`, restore after `container.appendChild(element)`
  - Bail guard: if `typeCount` changed, skip restore

### Tests

- `Tests/BackendTests/WebTests/WebInputStateTests.swift`
  - `WebFocusSnapshot` construction for text input, textarea, checkbox, range
  - Selection fields nil for non-text types
  - Bail guard logic: count mismatch → skip
  - Tag+type+index matching logic

**Residual risk:** DOM-runtime behavior (`document.activeElement`, `setSelectionRange()` timing after `appendChild`) cannot be unit tested without a browser. Browser verification is **required**, not optional.

### Manual verification (required)

After implementation, run the ParityFocus example in the browser:
1. Type in a TextField, place cursor in the middle
2. Trigger a state change (e.g., toggle a boolean)
3. Verify cursor position is preserved
4. Repeat with text selection active
5. Repeat with a non-text control (Slider) focused
6. Verify no console errors from failed `focus()`/`setSelectionRange()` calls

---

## GTK4 — Done

Implementation complete with suppress semantics aligned to Win32/Web. 12 tests in `GTK4FocusTests.swift` covering focusable input classification, DFS ordering stability, cursor position read/write, and API accessibility. Suppress fix: always saves state, skips only `gtk_widget_grab_focus` when suppressed.

---

## Win32 — Done

7 tests covering focus binding, cursor preservation, multi-field selection, and suppress-focus-with-edit-state. No work needed.

---

## Android — Unverified

`AndroidViewHost.rebuild()` re-renders the full JSON tree. Cursor/selection preservation depends on the Kotlin/Compose layer's diff algorithm, which is not verified by any test in this repo.

**Action:** Mark as unverified. Requires manual testing on Android:
1. Type in a TextField, place cursor
2. Trigger state change
3. Check if cursor survives

If Compose handles it, no code change needed. If not, add explicit state preservation to the JSON protocol (e.g., `focusedNodeId`, `selectionStart`, `selectionEnd` fields in the render diff).

---

## IME Composition — Deferred

IME composition survival (CJK input mid-composition) is not preserved on any platform. This is a hard, platform-specific problem. Defer until TextField is a primary feature focus.

---

## Remaining Work

1. **Web browser verification** (required — DOM-runtime behavior untested)
2. **Android manual verification** (when on Android device)
