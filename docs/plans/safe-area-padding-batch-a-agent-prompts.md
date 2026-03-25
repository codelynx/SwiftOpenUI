# Safe Area Padding Batch A Agent Prompts

## Core Prompt

```text
Implement Safe Area Padding Batch A core API.

Base branch:
- develop

Branch:
- safe-area-padding-batch-a-core

Read first:
- docs/plans/safe-area-padding-batch-a-plan.md
- docs/plans/safe-area-padding-batch-a-worker-briefs.md

Scope:
- Sources/SwiftOpenUI/Modifiers/SafeAreaModifiers.swift
- shared modifier tests

Implement:
- SafeAreaPaddingView<Content>
- safeAreaPadding()
- safeAreaPadding(_ length: Int)
- safeAreaPadding(_ edges: Edge.Set, _ length: Int? = nil)

Storage contract:
- edges: Edge.Set
- length: Int?

Do not:
- add measured safe-area APIs
- implement backend rendering here
- update parity docs as final truth
```

## GTK Prompt

```text
Implement GTK support for Safe Area Padding Batch A.

Base branch:
- origin/safe-area-padding-batch-a-core

Branch:
- gtk-safe-area-padding-batch-a

Read first:
- docs/plans/safe-area-padding-batch-a-plan.md
- docs/plans/safe-area-padding-batch-a-worker-briefs.md

Scope:
- GTK backend files only
- GTK tests only

Requirements:
- render SafeAreaPaddingView safely
- explicit length uses exact amount
- nil length uses synthetic default 16
- selected edges are honored

Do not:
- change public API
- edit tracker/parity docs as final truth
```

## Win32 Prompt

```text
Implement Win32 support for Safe Area Padding Batch A.

Base branch:
- origin/safe-area-padding-batch-a-core

Branch:
- win32-safe-area-padding-batch-a

Read first:
- docs/plans/safe-area-padding-batch-a-plan.md
- docs/plans/safe-area-padding-batch-a-worker-briefs.md

Scope:
- Win32 backend files only
- Win32 tests only

Requirements:
- render SafeAreaPaddingView safely
- explicit length uses exact amount
- nil length uses synthetic default 16
- selected edges are honored

Do not:
- change public API
- invent measured safe-area/titlebar behavior
- edit tracker/parity docs as final truth
```

## Web Prompt

```text
Implement Web support for Safe Area Padding Batch A.

Base branch:
- origin/safe-area-padding-batch-a-core

Branch:
- web-safe-area-padding-batch-a

Read first:
- docs/plans/safe-area-padding-batch-a-plan.md
- docs/plans/safe-area-padding-batch-a-worker-briefs.md

Scope:
- Web backend files only
- Web tests only

Requirements:
- render SafeAreaPaddingView safely
- explicit length uses exact amount
- nil length uses synthetic default 16
- selected edges map to CSS padding edges correctly

Do not:
- change public API
- edit tracker/parity docs as final truth
```

## Coordinator Prompt

```text
Integrate Safe Area Padding Batch A after core and backend workers finish.

Requirements:
- verify the public API matches the batch plan
- verify GTK, Win32, and Web use the same synthetic default
- run swift test
- regenerate tracker docs
- update parity docs to say the feature is synthetic/partial on backends

Do not:
- overclaim measured native safe-area fidelity
- add post-Batch-A features during integration
```
