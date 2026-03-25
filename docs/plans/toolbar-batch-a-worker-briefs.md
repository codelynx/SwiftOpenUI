# Toolbar Batch A Worker Briefs

## Core Owner

Branch:

- `toolbar-batch-a-core`

Scope:

- `Sources/SwiftOpenUI/Modifiers/ToolbarModifier.swift`
- shared toolbar tests only
- planning docs if needed

Responsibilities:

- add multi-item toolbar content support
- add `toolbar(id:content:)`
- preserve existing single-item `toolbar` behavior
- add shared tests for:
  - multiple items
  - stored toolbar id

Do not:

- edit backend renderers as part of the core branch
- update tracker/parity docs as final truth
- add visibility/removal families in Batch A

## GTK Worker

Branch:

- `gtk-toolbar-batch-a`

Base:

- `origin/toolbar-batch-a-core`

Scope:

- GTK renderer/navigation files only
- GTK tests if needed

Responsibilities:

- adapt GTK toolbar extraction/rendering to the new core shape if needed
- verify multiple items still render in header-bar order
- keep `toolbarID` stored-only unless a GTK-specific use is truly necessary

Do not:

- change public API
- edit non-GTK backends
- update tracker/parity docs as final truth

## Win32 Worker

Branch:

- `win32-toolbar-batch-a`

Base:

- `origin/toolbar-batch-a-core`

Scope:

- Win32 renderer files only
- Win32 tests if needed

Responsibilities:

- adapt Win32 toolbar rendering to the new core shape if needed
- verify multiple items still render in the correct leading/trailing buckets
- keep `toolbarID` stored-only unless required for internal bookkeeping

Do not:

- change public API
- edit non-Win32 backends
- update tracker/parity docs as final truth

## Web Worker

Branch:

- `web-toolbar-batch-a`

Base:

- `origin/toolbar-batch-a-core`

Scope:

- Web renderer files only
- Web tests

Responsibilities:

- adapt Web toolbar rendering to the new core shape if needed
- verify multiple items render in source order in the current navigation header area
- keep `toolbarID` stored-only unless required for DOM bookkeeping

Do not:

- change public API
- edit non-Web backends
- update tracker/parity docs as final truth

## Coordinator

Responsibilities:

- review all branches
- merge accepted branches into `develop`
- regenerate implementation tracker
- update parity matrix notes
- run shared verification

Coordinator-owned shared truth:

- `docs/api/implementation-tracker/**`
- `docs/architecture/swiftui-parity-matrix.md`
- `CLAUDE.md`
