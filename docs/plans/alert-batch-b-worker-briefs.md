# Alert Batch B Worker Briefs

## Core Owner

Branch:

- `alert-batch-b-core`

Scope:

- `Sources/SwiftOpenUI/Modifiers/AlertModifier.swift`
- `Tests/SwiftOpenUITests/ModifierTests/ModifierTests.swift`
- Batch B plan docs

Responsibilities:

- add `alert(isPresented:error:actions:)`
- derive title/message from the error
- suppress presentation when the error is `nil`
- keep lowering to `AlertModifierView`
- add storage tests

Do not:

- redesign alert rendering
- add builder DSL types
- update tracker/parity docs as final truth

## GTK Worker

Branch:

- `gtk-alert-batch-b`

Base:

- `origin/alert-batch-b-core`

Scope:

- GTK alert rendering/tests only if needed

Responsibilities:

- verify existing GTK alert rendering still works with the error-derived title/message/buttons
- add GTK tests only if a backend-specific adjustment is required

## Win32 Worker

Branch:

- `win32-alert-batch-b`

Base:

- `origin/alert-batch-b-core`

Scope:

- Win32 alert rendering/tests only if needed

Responsibilities:

- verify existing Win32 alert rendering still works with the lowered error-based primitive
- add Win32 tests only if a backend-specific adjustment is required

## Web Worker

Branch:

- `web-alert-batch-b`

Base:

- `origin/alert-batch-b-core`

Scope:

- Web alert rendering/tests only if needed

Responsibilities:

- verify existing Web alert rendering still works with the lowered error-based primitive
- add Web tests only if a backend-specific adjustment is required

## Coordinator

Responsibilities:

- merge the core branch first
- decide whether backend branches are no-op or need small verification/test commits
- regenerate the tracker
- update parity wording if needed
- push and clean up branches
