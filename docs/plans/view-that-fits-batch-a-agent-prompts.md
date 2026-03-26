# ViewThatFits Batch A Agent Prompts

## GTK

```text
Implement GTK support for ViewThatFits Batch A.

Base:
- use the coordinator-provided core branch for ViewThatFits Batch A

Scope:
- ViewThatFits { ... }
- first child that fits
- fallback to last child
- no axis parameter

Files:
- Sources/Backend/GTK4/Rendering/GTKRenderer.swift
- GTK tests if needed

Guidance:
- Prefer a direct primitive implementation
- Reuse the existing swiftlinuxui ViewThatFits approach where it fits
- Preserve source order
- If no child fits, render the last child

Do not:
- change public API
- edit non-GTK files
- update tracker/parity docs

Report back with:
- branch
- commit hash
- what was implemented
- what remains partial
- tests run
```

## Win32

```text
Implement Win32 support for ViewThatFits Batch A.

Base:
- use the coordinator-provided core branch for ViewThatFits Batch A

Scope:
- ViewThatFits { ... }
- first child that fits
- fallback to last child
- no axis parameter

Files:
- Sources/Backend/Win32/Rendering/WinRenderer.swift
- Win32 render tests

Guidance:
- Measure candidate children with the existing render/layout machinery
- Render/select only the chosen child
- Preserve source order
- If no child fits, render the last child

Do not:
- change public API
- edit non-Win32 files
- update tracker/parity docs

Report back with:
- branch
- commit hash
- what was implemented
- what remains partial
- tests run
```

## Web

```text
Implement Web support for ViewThatFits Batch A.

Base:
- use the coordinator-provided core branch for ViewThatFits Batch A

Scope:
- ViewThatFits { ... }
- first child that fits
- fallback to last child
- no axis parameter

Files:
- Sources/Backend/Web/Rendering/WebRenderer.swift
- Web tests
- Web descriptor tree only if needed

Guidance:
- Best-effort DOM measurement is acceptable
- Preserve source order
- If no child fits, render the last child
- Avoid unnecessary descriptor complexity

Do not:
- change public API
- edit non-Web files
- update tracker/parity docs

Report back with:
- branch
- commit hash
- what was implemented
- what remains partial
- tests run
```
