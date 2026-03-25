# Search Suggestions For Batch E Worker Briefs

## Coordinator

Responsibilities:

- land the core Batch E API on a base branch
- verify the remote branch hash before handoff
- collect GTK, Win32, and Web verification reports
- regenerate the tracker
- update parity wording

Do not ask platform workers to update tracker/parity docs as final truth.

## Core Owner

Branch:

- `search-suggestions-for-batch-e-core`

Files:

- `Sources/SwiftOpenUI/Modifiers/SearchableModifier.swift`
- `Tests/SwiftOpenUITests/ViewTests/Phase4FViewTests.swift`
- `docs/plans/search-suggestions-for-batch-e-plan.md`
- `docs/plans/search-suggestions-for-batch-e-worker-briefs.md`
- `docs/plans/search-suggestions-for-batch-e-agent-prompts.md`

Required work:

- add `searchSuggestions(_:for:)`
- extend `SearchSuggestionMode`
- filter lowered suggestions in core
- add focused storage/filtering tests

## GTK Worker

Branch:

- `gtk-search-suggestions-for-batch-e`

Files:

- GTK backend files only if needed
- GTK tests only if needed

Expected outcome:

- verification-only if existing suggestion UI works unchanged with filtered rows

## Win32 Worker

Branch:

- `win32-search-suggestions-for-batch-e`

Files:

- Win32 backend files only if needed
- Win32 tests only if needed

Expected outcome:

- verification-only if existing suggestion UI works unchanged with filtered rows

## Web Worker

Branch:

- `web-search-suggestions-for-batch-e`

Files:

- Web backend files only if needed
- Web tests only if needed

Expected outcome:

- verification-only if existing suggestion UI works unchanged with filtered rows

## Worker Report Template

- Branch:
- Commit:
- Base:
- Changed files:
- What was implemented:
- What remains partial:
- Tests ran:
- Merge or cherry-pick:
