# Presentation Batch A Agent Prompts

## Core

```text
Implement Presentation Batch A core API.

Branch:
- presentation-batch-a-core

Scope:
- Sources/SwiftOpenUI/Modifiers/SheetModifier.swift
- Sources/SwiftOpenUI/Modifiers/AlertModifier.swift
- shared tests only

Read first:
- docs/plans/presentation-batch-a-plan.md
- docs/plans/presentation-batch-a-worker-briefs.md

Implement:
- sheet(isPresented:onDismiss:content:)
- sheet(item:onDismiss:content:)
- alert(_:isPresented:actions:)
- alert(_:isPresented:actions:message:)

Constraints:
- keep Batch A narrow
- do not add full alert builder DSL
- do not edit backend renderers
- do not update tracker/parity docs as final truth

Testing:
- add shared storage tests for new sheet and alert overloads
```

## GTK

```text
Implement GTK support for Presentation Batch A.

Base:
- origin/presentation-batch-a-core

Branch:
- gtk-presentation-batch-a

Scope:
- GTK renderer files only
- GTK tests if available

Read first:
- docs/plans/presentation-batch-a-plan.md
- docs/plans/presentation-batch-a-worker-briefs.md

Implement:
- honor sheet onDismiss
- support item-based sheet presentation/dismissal
- avoid duplicate modal presentation on rebuild
- keep alert behavior working with the expanded overload surface

Fallbacks allowed:
- preserve current modal window styles

Do not:
- change public API
- edit non-GTK backends
- update tracker/parity docs as final truth
```

## Win32

```text
Implement Win32 support for Presentation Batch A.

Base:
- origin/presentation-batch-a-core

Branch:
- win32-presentation-batch-a

Scope:
- Win32 renderer files only
- Win32 tests if available

Read first:
- docs/plans/presentation-batch-a-plan.md
- docs/plans/presentation-batch-a-worker-briefs.md

Implement:
- honor sheet onDismiss
- support item-based sheet presentation/dismissal
- avoid duplicate popup/modal presentation on rebuild
- keep alert behavior working with the expanded overload surface

Fallbacks allowed:
- preserve current popup/modal styles
- preserve current MessageBoxW alert style

Do not:
- change public API
- edit non-Win32 backends
- update tracker/parity docs as final truth
```

## Web

```text
Implement Web support for Presentation Batch A.

Base:
- origin/presentation-batch-a-core

Branch:
- web-presentation-batch-a

Scope:
- Web renderer/descriptor files only
- Web tests

Read first:
- docs/plans/presentation-batch-a-plan.md
- docs/plans/presentation-batch-a-worker-briefs.md

Implement:
- honor sheet onDismiss
- support item-based sheet presentation/dismissal
- keep descriptor/DOM ordering rebuild-safe
- keep alert behavior working with the expanded overload surface

Fallbacks allowed:
- preserve current modal overlay styles

Do not:
- change public API
- edit non-Web backends
- update tracker/parity docs as final truth
```
