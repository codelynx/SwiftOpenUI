# Cross-platform changelog

Append-only log of **shared-surface** changes — anything in a backend or the
shared core that *another* backend/platform consumes and could be affected by
(the shared symbol map, core `View`/`Layout` types, the view-host, cross-cutting
behavior). Backend-only internals that can't regress another platform don't
belong here — keep those in the backend's own docs/issues.

Every SwiftOpenUI backend agent clones this repo, so this is the discovery
point for "did someone change something under me?" **Newest entries on top.**
One entry per shared change; always say who to ping if it regresses your
backend.

```
## YYYY-MM-DD — <platform/agent> — <summary>
- Shared surface: <what shared/core file or type changed>
- Impact: <who consumes it / could regress; verification if known>
- Ping: <owner/agent>
- Refs: <commits / issue docs>
```

---

## 2026-10-10 — Windows (Win32) — shared symbol map: device / media entries

- **Shared surface:** `SwiftOpenUISymbols/SFSymbolCompatibility.swift` +
  `MaterialSymbolsCodepoints.swift` — added `camera → photo_camera` (0xE412),
  `iphone.gen3 → smartphone` (0xE32C), `iphone.slash → no_sim` (0xE0CC),
  `record.circle → fiber_manual_record` (0xE061), `square.on.square → history`
  (0xE889). Additive; no existing mapping changed.
- **Impact:** every backend resolves these five SF names now (macOS uses native
  SF Symbols → no-op). All 65 codepoints in the table were checked against the
  bundled `MaterialSymbolsRounded-Regular.ttf`; the PR's original `no_sim`
  value (0xE0CE) was `wifi_tethering_off` and is corrected here. Not yet seen
  rendered on Win32 or GTK4.
- **Open question:** `square.on.square → history` is a loose match (the SF
  symbol usually reads as copy/duplicate; `doc.on.doc` already maps to
  `content_copy`). Kept as contributed; revisit if it reads wrong in an app.
- **Ping:** coordinator (symbol map).
- **Refs:** PR #9 (`8d5deb6`, cherry-picked) + follow-up codepoint fix.

## 2026-07-10 — Windows (Win32) — shared symbol map entry + child-@State convergence

- **Shared surface:** `SwiftOpenUISymbols/SFSymbolCompatibility.swift` +
  `MaterialSymbolsCodepoints.swift` — added `circle.dotted →
  radio_button_unchecked` (0xE836). Additive; no existing mapping changed.
- **Impact:** every backend resolves `circle.dotted` now (macOS uses native SF
  Symbols → no-op). Verified benign on macOS; **net positive on GTK4** (the
  `SyncAction.ignore` badge now resolves to a real Material glyph instead of a
  missing symbol).
- **Awareness (not a shared-code change):** the Win32 child-`@State`
  reconciliation gap (`docs/issues/win32-conditional-view-rebuild.md`) is a
  **shared view-host problem** — GTK4 independently hits the same
  OutlineGroup-expansion-resets-on-ancestor-rebuild failure. Likely **one fix
  at the shared view-host layer** (ID-keyed child-state persistence) retires
  the workarounds on *both* Win32 and GTK4. Reconcile the two designs before
  either backend invests further.
- **Ping:** Win32 agent (symbol map); Win32 + Linux agents (reconciliation).
- **Refs:** SwiftOpenUI `629323a`;
  `docs/issues/win32-outlinegroup-dropdown-followups.md`.
