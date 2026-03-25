# Safe Area Padding Batch A Worker Briefs

Use these with [safe-area-padding-batch-a-plan.md](/Users/kyoshikawa/Projects/SwiftOpenUI/docs/plans/safe-area-padding-batch-a-plan.md).

## Core Owner

Branch:

- `safe-area-padding-batch-a-core`

Scope:

- `Sources/SwiftOpenUI/Modifiers/SafeAreaModifiers.swift`
- shared tests for modifier storage

Required work:

- add `SafeAreaPaddingView`
- add:
  - `safeAreaPadding()`
  - `safeAreaPadding(_ length: Int)`
  - `safeAreaPadding(_ edges: Edge.Set, _ length: Int? = nil)`
- store `edges`
- store `length: Int?`

Rules:

- do not add measured safe-area APIs yet
- do not add backend logic here
- do not update parity docs as final truth

Verification:

- modifier storage tests
- `swift test`

## GTK Worker

Branch:

- `gtk-safe-area-padding-batch-a`

Scope:

- GTK backend files only
- GTK tests only

Required work:

- render `SafeAreaPaddingView`
- explicit length uses the exact amount
- nil length uses synthetic default `16`
- selected edges are honored

Acceptable Batch A lowering:

- use existing padding/container layout patterns
- synthetic default instead of true measured insets

Do not:

- change public API
- edit tracker/parity docs as final truth

## Win32 Worker

Branch:

- `win32-safe-area-padding-batch-a`

Scope:

- Win32 backend files only
- Win32 tests only

Required work:

- render `SafeAreaPaddingView`
- explicit length uses exact amount
- nil length uses synthetic default `16`
- selected edges are honored

Acceptable Batch A lowering:

- reuse existing padding/layout container plumbing

Do not:

- invent native-titlebar or measured safe-area behavior
- change public API
- edit tracker/parity docs as final truth

## Web Worker

Branch:

- `web-safe-area-padding-batch-a`

Scope:

- Web backend files only
- Web tests only

Required work:

- render `SafeAreaPaddingView`
- explicit length uses exact amount
- nil length uses synthetic default `16`
- selected edges map to CSS padding edges correctly

Acceptable Batch A lowering:

- CSS padding-based implementation

Do not:

- change public API
- edit tracker/parity docs as final truth

## Coordinator

Coordinator owns:

- review of all platform branches
- merge conflict resolution
- tracker regeneration
- parity matrix update

Responsibilities:

- verify the core API matches the batch plan
- verify GTK/Win32/Web use the same synthetic default
- verify docs call the feature partial where appropriate
- regenerate tracker docs after core merge
- update parity notes after all backend merges

Final checks:

- `swift test`
- tracker regeneration
- no doc claims beyond synthetic Batch A behavior
