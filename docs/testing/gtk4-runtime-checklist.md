# GTK4 runtime verification checklist (Synca acceptance)

Deferred interactive checks for the SwiftOpenUI features validated through
Synca (issues #1–#6). None of these are drivable headlessly — they need an
**interactive GTK4 session** (a real display + mouse/keyboard, and Orca for
a11y). Each item lists steps, the expected result, the failure signal, and
the **remedy if it fails** (pre-diagnosed so you don't re-derive it).

## Setup

```bash
# Ensure the sibling checkouts are current:
#   ../SwiftOpenUI >= 68f07b0   ../diffa (any)   Synca feature/windows-port
cd ~/Projects/Synca && swift run Synca
```
Then: pick a Source and Target folder that **differ** (some added, some
removed, some modified files), run **Compare**, and use the Compare Result
window for the checks below. For Sync/Merge checks, escalate to Sync and
pick **Merge** mode.

For the memory-safety item, prefer a sanitized build:
```bash
swift run -Xswiftc -sanitize=address Synca    # ASan; or run under valgrind
```

---

## #2 — `.textSelection` (selectable label text)

- [ ] In the Compare Result window, the **status-line** text (bottom bar)
      and the **path rows** (header) are mouse-selectable (drag to select,
      Ctrl+C copies).
- [ ] **Critical case — the ellipsized labels:** narrow the window so the
      status line / a path row **truncates** (shows `…`), then drag-select
      *that* truncated label.
  - **Why this specific case:** `.textSelection` walks to the label via
    `findAllGtkLabels`. If `.lineLimit`/`.truncationMode` ever rendered to
    a *container* instead of a bare `GtkLabel`, selection silently no-ops —
    and it only shows on the truncated label.
  - **If it fails (truncated label not selectable):** the ellipsized chain
    is wrapping in a container. Confirm `LineLimitView`/`TruncationModeView`
    still set ellipsize as label *properties* and return the same
    `GtkLabel`; if not, that's the regression.

## #3 — `.onExitCommand` (ESC in the filter field)

- [ ] Press **⌘F/Ctrl+F** (or click the filter field) to focus it, type a
      filter, then press **Esc** → the filter clears and the field defocuses.
- [ ] **Both focus states:** (a) focus on the tree/list, press Esc; (b)
      focus in the filter field, press Esc.
  - **Nuance:** the window key controller is bubble-phase, so a focused
    `GtkText` that binds Esc could swallow it. The *intended* path (clear
    the filter) fires when the event reaches the window controller.
  - **If Esc does nothing:** verify the Compare Result **Window** got
    `gtkAttachKeyboardShortcutController` (same controller `.keyboardShortcut`
    uses). If ESC also closes the window, check for a competing
    close-request handler on that window.

## #4 — hidden `.keyboardShortcut` (⌘F / Ctrl+F "Find")

- [ ] With focus on the **tree/list** (not the field), press **Ctrl+F** →
      the filter field gains focus (cursor appears).
- [ ] Repeat with focus already in the field (may be swallowed by GtkText's
      own Ctrl+F binding — that's acceptable; you're already focused).
  - **If Ctrl+F never focuses the field (from elsewhere):** the hidden
    button's shortcut didn't register. Confirm `HiddenView` creates the
    Button (registration in `gtkCreateWidget`) before hiding, and that the
    `.background(findShortcutHook)` hook is in the tree. `.command` maps to
    `GDK_CONTROL_MASK`, so the physical key is **Ctrl+F** on Linux.

## #5 — `.accessibilityLabel` (screen-reader announces the action)

Run with **Orca** enabled. Use Sync → **Merge** mode so action badges show.
- [ ] Navigate to an action badge; Orca announces the human label
      ("will be copied to destination", etc.), **not** the icon's symbol
      codepoint/name.
- [ ] **Double-announce check:** listen for whether Orca reads *both* the
      container label *and* the inner symbol.
  - **If it double-announces:** setting the label on the container doesn't
    suppress child a11y nodes. **Remedy (pre-diagnosed):** set the inner
    content's role to `GTK_ACCESSIBLE_ROLE_PRESENTATION` (a11y "none") so
    only the label is announced. Tracked in `gtk4-win32-accessibilitylabel`.

## Reconcile-safety (dynamic `.accessibilityLabel` / `.textSelection`)

- [ ] In Merge mode, change a row's resolution (or any state that changes a
      badge's a11y label / a selectable value) and confirm the widget
      reflects the **new** value (Orca reads the new label; selectability
      matches). Covered by unit tests at the plan layer; this is the live
      confirmation that the rebuild actually re-applies.

---

## #6 — `Menu` + `.menuStyle` (the big one)

Use Sync → **Merge** mode; each **modified** row's badge is a `Menu`.

### Basic function
- [ ] Click a badge → a popover opens showing **Use Source / Use
      Destination / Keep Both** (each with its icon+label).
- [ ] Click an item → its action fires (the resolution changes) **and** the
      popover dismisses.
- [ ] `.menuStyle(.borderlessButton)`: the trigger badge has **no button
      frame/chrome** around it (looks like the bare badge, not a bordered
      button).

### §5 — rebuild-on-change trigger (is it stale?)
- [ ] After picking a resolution, the **trigger badge updates** to reflect
      the new resolution (new icon/color) — it is **not** stale showing the
      old resolution.
  - **Expected mechanism:** `Menu` is a childless opaque composite, which
    `gtkCanApplyTextColorHostMutation` rejects → forces a full rebuild →
    the badge re-renders. If the badge **is** stale, that assumption broke;
    the fix is the deferred **label-only narrow-mutation** (below).

### §5 — the popover-reachability PROBE (the pivot decision)
This decides whether the deferred **label-only narrow-mutation** (describe
the trigger label as the Menu's only child, so it narrow-mutates without a
full rebuild) is viable.
- [ ] **Probe:** from the live `GtkMenuButton`, walk `gtk_widget_get_first_child`
      recursively and log the widget types. Determine whether the
      **popover's item widgets appear in that walk** (i.e. GTK parents the
      popover under the button) or are on a **detached surface**.
  - **If items are NOT reachable** (detached surface): label-only describe
    is safe — the slot-capture sees only the label, narrow-mutates it, and
    never rebuilds on an item click. **Wire it** (adds a `gtkDescribeNode`
    returning `.composite` with `[gtkDescribeView(label)]`). This also
    **removes the §2 UAF** (no rebuild → no popover free).
  - **If items ARE reachable:** label-only describe causes a slot-capture
    count mismatch (phantom popover widgets not in the descriptor) → capture
    bails → full rebuild anyway. Then keep rebuild-on-change + the §2 guard;
    don't wire label-only.

### §2 — dismissal-under-rebuild (UAF)
- [ ] Under **ASan/valgrind**, click menu items rapidly / repeatedly
      (each click triggers a resolution change → rebuild). Confirm **no
      use-after-free** on the popover.
  - The `gtk_swift_is_widget` + `GTK_IS_POPOVER` guards mitigate a *stale*
    pointer but not a freed-then-reused address. **If ASan flags a UAF:**
    the real fix is the label-only narrow-mutation above (no rebuild on
    item click → popover never freed mid-`clicked`).

### Nested Menu (submenu) — dropped test coverage
- [ ] If you construct a `Menu` whose content contains a **nested `Menu`**,
      confirm the `GtkMenuButton`-inside-`GtkPopover` renders and opens.
      (The old `SubMenu`-in-`Menu` test was removed; submenus are nested
      Menus now.)

---

## Win32 / Web (when those runtimes are available)

- [ ] **Win32:** the merge badge shows the **label trigger**, but **no
      popup opens** (known regression — view items can't use `TrackPopupMenu`;
      the view-shaped popup is the deferred Windows rework).
- [ ] **Web:** the label trigger renders and the dropdown shows the item
      views with working actions.

## Examples/Parity (macOS-reference side — mac agent)
- [ ] Add/verify `Examples/Parity` entries for `.controlSize`/`.listStyle`
      (#1), `.textSelection` (#2), `.onExitCommand` (#3), window-scoped
      shortcut (#4), `.accessibilityLabel` (#5), and a labeled `Menu` (#6),
      exercised on all backends.
