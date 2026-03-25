# Searchable Batch A Agent Prompts

Use these prompts with:

- [searchable-batch-a-plan.md](/Users/kyoshikawa/Projects/SwiftOpenUI/docs/plans/searchable-batch-a-plan.md)
- [searchable-batch-a-worker-briefs.md](/Users/kyoshikawa/Projects/SwiftOpenUI/docs/plans/searchable-batch-a-worker-briefs.md)

## Core Prompt

```text
Implement the core Searchable Batch A layer for SwiftOpenUI.

Branch:
- searchable-batch-a-core

Scope:
- Sources/SwiftOpenUI/Modifiers/*
- Sources/SwiftOpenUI/Layout/* if needed
- Tests/SwiftOpenUITests/*

Requirements:
- Add SearchFieldPlacement
- Extend SearchableView to store:
  - content
  - text binding
  - prompt
  - placement
  - optional isPresented binding
- Add public APIs:
  - searchable(text:placement:prompt:)
  - searchable(text:isPresented:placement:prompt:)
- Keep the existing convenience behavior working via .automatic
- Preserve prompt default "Search"
- Keep the primitive wrapper backend-agnostic

Do not:
- Implement backend rendering
- Add tokens, searchSuggestions, searchScopes, or searchCompletion
- Update tracker/parity docs as final truth

Verification:
- Add shared unit tests for storage shape
- Run swift test

You are not alone in the codebase. Do not revert unrelated edits.
```

## GTK Prompt

```text
Implement GTK4 support for SwiftOpenUI Searchable Batch A.

Branch:
- gtk-searchable-batch-a

Scope:
- Sources/Backend/GTK4/Rendering/*
- GTK tests only if needed

Assume core already provides:
- SearchFieldPlacement
- SearchableView with placement and optional isPresented

Requirements:
- Keep GtkSearchEntry as the search field
- Preserve current .automatic behavior: search field above content
- Preserve prompt behavior
- Preserve text binding updates
- Honor isPresented where practical
- If true collapsed/presented search UI is awkward, always-visible fallback is acceptable in Batch A
- Non-default placement may be advisory in Batch A, but must be stored/handled coherently

Do not:
- Change public API
- Edit non-GTK backends
- Add token/suggestion/scope features

Suggested verification:
- searchable smoke test
- isPresented path renders safely
- no text-binding regressions

You are not alone in the codebase. Do not revert unrelated edits.
```

## Win32 Prompt

```text
Implement Win32 support for SwiftOpenUI Searchable Batch A.

Branch:
- win32-searchable-batch-a

Scope:
- Sources/Backend/Win32/Rendering/WinRenderer.swift
- Win32 tests only if needed

Assume core already provides:
- SearchFieldPlacement
- SearchableView with placement and optional isPresented

Requirements:
- Keep EDIT-based search rendering
- Preserve current .automatic behavior: search field above content
- Preserve cue-banner prompt behavior
- Preserve text binding updates
- Honor isPresented where practical
- Visibility toggle is acceptable if easy; always-visible fallback is acceptable if coherent
- Non-default placement may be advisory in Batch A

Do not:
- Change public API
- Edit non-Win32 backends
- Add token/suggestion/scope features

Suggested verification:
- searchable smoke test
- isPresented path renders safely
- no text-binding regressions

You are not alone in the codebase. Do not revert unrelated edits.
```

## Web Prompt

```text
Implement Web support for SwiftOpenUI Searchable Batch A.

Branch:
- web-searchable-batch-a

Scope:
- Sources/Backend/Web/Rendering/*
- Web descriptor/tests only if needed

Assume core already provides:
- SearchFieldPlacement
- SearchableView with placement and optional isPresented

Requirements:
- Keep input[type=search] rendering
- Preserve current .automatic behavior: search field above content
- Preserve placeholder behavior
- Preserve text binding updates
- Honor isPresented where practical
- Visibility-based fallback is acceptable in Batch A
- Non-default placement may be advisory in Batch A

Do not:
- Change public API
- Edit non-Web backends
- Add token/suggestion/scope features

Suggested verification:
- searchable smoke test
- descriptor coverage for new storage if appropriate
- isPresented path does not break rendering

You are not alone in the codebase. Do not revert unrelated edits.
```

## Coordinator Prompt

```text
Integrate and review SwiftOpenUI Searchable Batch A after core and backend workers finish.

Scope:
- integration review
- shared verification
- docs/tracker updates

Requirements:
- Verify public API matches the Searchable Batch A plan
- Verify searchable now covers 2 curated families instead of 1
- Verify GTK4, Win32, and Web preserve .automatic behavior
- Verify placement and optional isPresented are stored consistently
- Run swift test
- Regenerate tracker docs
- Update:
  - docs/api/implementation-tracker/modifiers-09-search.md
  - docs/architecture/swiftui-parity-matrix.md

Do not:
- Mark searchable Implemented if token families are still missing
- Add Batch B features during integration
- Leave tracker/doc claims ahead of the code
```
