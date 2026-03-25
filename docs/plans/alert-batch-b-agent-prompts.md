# Alert Batch B Agent Prompts

## Core

```text
Implement Alert Batch B core support.

Base branch:
- develop

Branch:
- alert-batch-b-core

Scope:
- Sources/SwiftOpenUI/Modifiers/AlertModifier.swift
- Tests/SwiftOpenUITests/ModifierTests/ModifierTests.swift
- docs/plans/alert-batch-b-*.md

Required API:
- alert(isPresented:error:actions:)

Requirements:
- generic over Error
- derive title/message from the error
- suppress presentation when error is nil
- lower into the existing AlertModifierView primitive
- add storage tests

Do not:
- redesign alert rendering
- add SwiftUI-style builder DSL types
- update tracker/parity docs as final truth
```

## GTK

```text
Verify GTK behavior for Alert Batch B.

Base branch:
- origin/alert-batch-b-core

Branch:
- gtk-alert-batch-b

Scope:
- GTK alert files/tests only if needed

Goal:
- confirm existing GTK alert rendering works with the new error-based overload after lowering to AlertModifierView
- add GTK tests only if a GTK-specific adjustment is required

Do not:
- change public API
- change non-GTK files unless a test truly belongs in shared core
- update tracker/parity docs as final truth
```

## Win32

```text
Verify Win32 behavior for Alert Batch B.

Base branch:
- origin/alert-batch-b-core

Branch:
- win32-alert-batch-b

Scope:
- Win32 alert files/tests only if needed

Goal:
- confirm existing Win32 alert rendering works with the new error-based overload after lowering to AlertModifierView
- add Win32 tests only if a Win32-specific adjustment is required

Do not:
- change public API
- update tracker/parity docs as final truth
```

## Web

```text
Verify Web behavior for Alert Batch B.

Base branch:
- origin/alert-batch-b-core

Branch:
- web-alert-batch-b

Scope:
- Web alert files/tests only if needed

Goal:
- confirm existing Web alert rendering works with the new error-based overload after lowering to AlertModifierView
- add Web tests only if a Web-specific adjustment is required

Do not:
- change public API
- update tracker/parity docs as final truth
```
