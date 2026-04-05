# SwiftUI Implementation Tracker

Merged from:

- `docs/api/swiftui-reference-2025-clade.md`
- `docs/api/swiftui-reference-2025-codex.md`

Status is derived from the public SwiftOpenUI surface under `Sources/SwiftOpenUI/`.

Rules for this tracker:

- `Implemented` means SwiftOpenUI exposes a matching public type or `View` modifier today.
- `Partial` currently applies to modifier families: SwiftOpenUI exposes the base name, but only a subset of the curated canonical family set (or the generated baseline when no curated family count exists).
- `Missing` means no matching public surface exists yet.
- `Seen In` shows whether the feature came from the curated reference, the SDK-scan reference, or both.
- Curated grouping comes from `swiftui-reference-2025-clade.md`.
- Extra public surface found only by the SDK scan is split into separate generated-only files.
- View-adjacent and modifier-adjacent items that do not fit the direct `View` / `View`-modifier model are kept in `adjacent-apis.md`.
- When curated and generated metadata disagree, the curated reference is treated as canonical for availability, status, and human notes.
- This tracker is surface-first. Backend and behavioral parity still belong in `docs/architecture/swiftui-parity-matrix.md`.
- Views are still tracked at type presence level today; view-specific surface limitations stay in row notes until the tracker grows a reliable view-family metric.

Regenerate with:

- `python3 tools/build_feature_tracker.py`

## Coverage

- Views: 119 total, 54 implemented, 0 partial, 65 missing.
- Modifiers: 444 total, 67 implemented, 6 partial, 371 missing.
- Adjacent APIs: 10 total, 3 implemented, 1 partial, 6 missing.

## Files

- `views.md`: curated view groups that map cleanly onto direct `View` types
- `views-generated-only.md`: SDK-scan-only public `View` types
- `modifiers-01-layout.md`
- `modifiers-02-appearance.md`
- `modifiers-03-text-symbol.md`
- `modifiers-04-style.md`
- `modifiers-05-graphics-rendering.md`
- `modifiers-06-navigation-auxiliary.md`
- `modifiers-07-presentation.md`
- `modifiers-08-input-events.md`
- `modifiers-09-search.md`
- `modifiers-10-accessibility.md`
- `modifiers-11-state-environment.md`
- `modifiers-generated-a-g.md`
- `modifiers-generated-h-p.md`
- `modifiers-generated-q-z.md`
- `adjacent-apis.md`
