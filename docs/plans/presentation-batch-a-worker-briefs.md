# Presentation Batch A Worker Briefs

## Core Owner

Branch:

- `presentation-batch-a-core`

Scope:

- `Sources/SwiftOpenUI/Modifiers/SheetModifier.swift`
- `Sources/SwiftOpenUI/Modifiers/AlertModifier.swift`
- shared tests only
- planning docs if needed

Responsibilities:

- add `sheet(isPresented:onDismiss:content:)`
- add item-based `sheet(item:onDismiss:content:)`
- add alert overloads:
  - `alert(_:isPresented:actions:)`
  - `alert(_:isPresented:actions:message:)`
- preserve existing API behavior where possible
- add shared storage tests

Do not:

- edit backend renderers as part of the core branch
- update tracker/parity docs as final truth
- add full alert builder DSL in Batch A

## GTK Worker

Branch:

- `gtk-presentation-batch-a`

Base:

- `origin/presentation-batch-a-core`

Scope:

- GTK renderer files only
- GTK tests if available

Responsibilities:

- adapt sheet presentation to honor `onDismiss`
- support item-based sheet presentation/dismissal
- avoid duplicate GTK window presentation on rebuild
- keep alert behavior working with the expanded overload surface

Fallbacks allowed:

- preserve current modal window sheet style
- preserve current alert window style

Do not:

- change public API
- edit non-GTK backends
- update tracker/parity docs as final truth

## Win32 Worker

Branch:

- `win32-presentation-batch-a`

Base:

- `origin/presentation-batch-a-core`

Scope:

- Win32 renderer files only
- Win32 tests if available

Responsibilities:

- adapt sheet presentation to honor `onDismiss`
- support item-based sheet presentation/dismissal
- avoid duplicate popup/window presentation on rebuild
- keep alert behavior working with the expanded overload surface

Fallbacks allowed:

- preserve current popup/modal sheet style
- preserve current `MessageBoxW` alert style

Do not:

- change public API
- edit non-Win32 backends
- update tracker/parity docs as final truth

## Web Worker

Branch:

- `web-presentation-batch-a`

Base:

- `origin/presentation-batch-a-core`

Scope:

- Web renderer/descriptor files only
- Web tests

Responsibilities:

- adapt sheet presentation to honor `onDismiss`
- support item-based sheet presentation/dismissal
- ensure wrapper/descriptor ordering stays rebuild-safe
- keep alert behavior working with the expanded overload surface

Fallbacks allowed:

- preserve current modal overlay sheet style
- preserve current modal overlay alert style

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
