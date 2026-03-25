# Toolbar Batch B Worker Briefs

## Coordinator

Responsibilities:

- land the core Batch B API on a base branch
- verify the remote branch hash before handoff
- collect GTK, Win32, and Web platform changes
- regenerate the tracker
- update parity wording

## Core Owner

Branch:

- `toolbar-batch-b-core`

Files:

- `Sources/SwiftOpenUI/Modifiers/ToolbarModifier.swift`
- `Tests/SwiftOpenUITests/ViewTests/Phase4FViewTests.swift`
- `docs/plans/toolbar-batch-b-plan.md`
- `docs/plans/toolbar-batch-b-worker-briefs.md`
- `docs/plans/toolbar-batch-b-agent-prompts.md`

Required work:

- add toolbar visibility/removal configuration types
- add `toolbar(_:for:)`
- add `toolbar(removing:)`
- add storage/composition tests

## GTK Worker

Branch:

- `gtk-toolbar-batch-b`

Files:

- GTK backend/navigation files
- GTK tests

Required behavior:

- hide relevant toolbar chrome when stored visibility is `.hidden`
- drop removed placements from the rendered toolbar items

## Win32 Worker

Branch:

- `win32-toolbar-batch-b`

Files:

- Win32 backend files
- Win32 tests

Required behavior:

- hide relevant toolbar chrome when stored visibility is `.hidden`
- drop removed placements from rendered toolbar items

## Web Worker

Branch:

- `web-toolbar-batch-b`

Files:

- Web backend files
- Web tests

Required behavior:

- hide relevant toolbar chrome when stored visibility is `.hidden`
- drop removed placements from rendered toolbar items

## Worker Report Template

- Branch:
- Commit:
- Base:
- Changed files:
- What was implemented:
- What remains partial:
- Tests ran:
- Merge or cherry-pick:
