# Toolbar Batch A Agent Prompts

## Core

```text
Implement Toolbar Batch A core API.

Branch:
- toolbar-batch-a-core

Scope:
- Sources/SwiftOpenUI/Modifiers/ToolbarModifier.swift
- shared toolbar tests only

Read first:
- docs/plans/toolbar-batch-a-plan.md
- docs/plans/toolbar-batch-a-worker-briefs.md

Implement:
- multi-item toolbar content support
- toolbar(id:content:)

Constraints:
- keep Batch A narrow
- do not add toolbar visibility/removing families
- do not edit backend renderers
- do not update tracker/parity docs as final truth

Testing:
- add shared tests for multiple toolbar items and stored toolbar id
```

## GTK

```text
Implement GTK support for Toolbar Batch A.

Base:
- origin/toolbar-batch-a-core

Branch:
- gtk-toolbar-batch-a

Scope:
- GTK renderer/navigation files only
- GTK tests if needed

Read first:
- docs/plans/toolbar-batch-a-plan.md
- docs/plans/toolbar-batch-a-worker-briefs.md

Implement:
- adapt GTK toolbar extraction/rendering to the new core shape if needed
- preserve multiple-item rendering order
- keep toolbarID stored-only unless GTK needs it for bookkeeping

Do not:
- change public API
- edit non-GTK backends
- update tracker/parity docs as final truth
```

## Win32

```text
Implement Win32 support for Toolbar Batch A.

Base:
- origin/toolbar-batch-a-core

Branch:
- win32-toolbar-batch-a

Scope:
- Win32 renderer files only
- Win32 tests if needed

Read first:
- docs/plans/toolbar-batch-a-plan.md
- docs/plans/toolbar-batch-a-worker-briefs.md

Implement:
- adapt Win32 toolbar rendering to the new core shape if needed
- preserve leading/trailing grouping and source-order behavior
- keep toolbarID stored-only unless needed for internal bookkeeping

Do not:
- change public API
- edit non-Win32 backends
- update tracker/parity docs as final truth
```

## Web

```text
Implement Web support for Toolbar Batch A.

Base:
- origin/toolbar-batch-a-core

Branch:
- web-toolbar-batch-a

Scope:
- Web renderer files only
- Web tests

Read first:
- docs/plans/toolbar-batch-a-plan.md
- docs/plans/toolbar-batch-a-worker-briefs.md

Implement:
- adapt Web toolbar rendering to the new core shape if needed
- preserve item order in the current navigation header area
- keep toolbarID stored-only unless needed for DOM bookkeeping

Do not:
- change public API
- edit non-Web backends
- update tracker/parity docs as final truth
```
