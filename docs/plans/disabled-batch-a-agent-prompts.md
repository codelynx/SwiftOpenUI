# Disabled Batch A Agent Prompts

## GTK

```text
Implement GTK support for Disabled Batch A.

Base:
- use the coordinator-provided disabled-batch-a-core branch

Scope:
- `.disabled(_:)`
- inherited enabled state via EnvironmentValues.isEnabled
- ancestor composition:
  - parent disabled(true) must not be undone by child disabled(false)

Files:
- Sources/Backend/GTK4/Rendering/GTKRenderer.swift
- GTK tests

Targets:
- Button
- TextField
- SecureField
- TextEditor
- Toggle
- Slider
- Stepper
- Picker
- DatePicker if cheap

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
Implement Win32 support for Disabled Batch A.

Base:
- use the coordinator-provided disabled-batch-a-core branch

Scope:
- `.disabled(_:)`
- inherited enabled state via EnvironmentValues.isEnabled
- ancestor composition:
  - parent disabled(true) must not be undone by child disabled(false)

Files:
- Sources/Backend/Win32/Rendering/WinRenderer.swift
- Win32 render tests

Targets:
- Button
- TextField
- SecureField
- TextEditor
- Toggle
- Slider
- Stepper
- Picker
- DatePicker if cheap

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
Implement Web support for Disabled Batch A.

Base:
- use the coordinator-provided disabled-batch-a-core branch

Scope:
- `.disabled(_:)`
- inherited enabled state via EnvironmentValues.isEnabled
- ancestor composition:
  - parent disabled(true) must not be undone by child disabled(false)

Files:
- Sources/Backend/Web/Rendering/WebRenderer.swift
- Web tests

Targets:
- Button
- TextField
- SecureField
- TextEditor
- Toggle
- Slider
- Stepper
- Picker
- DatePicker if cheap

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
