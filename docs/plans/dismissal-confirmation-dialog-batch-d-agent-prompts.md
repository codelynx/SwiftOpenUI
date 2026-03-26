# Dismissal Confirmation Dialog Batch D Agent Prompts

## GTK

```text
Implement GTK dismissal-confirmation interception for sheets.

Base:
- dismissal-confirmation-dialog-batch-d-core

Scope:
- dismissalConfirmationDialog(_:shouldPresent:actions:) semantics for sheet presenters

Files:
- Sources/Backend/GTK4/Rendering/GTKRenderer.swift
- GTK tests if needed

Requirements:
- if presented sheet content carries dismissal-confirmation configuration
- user-triggered close should not destroy the sheet immediately
- instead set the dismissal-confirmation binding to true
- keep the sheet open
- preserve existing programmatic dismiss behavior for isPresented=false or item=nil
- preserve ordinary sheet behavior when no dismissal-confirmation config exists

Do not:
- change public API
- edit non-GTK files
- update tracker/parity docs

Report back with:
- branch
- commit hash
- changed files
- tests run
```

## Win32

```text
Implement Win32 dismissal-confirmation interception for sheets.

Base:
- dismissal-confirmation-dialog-batch-d-core

Scope:
- dismissalConfirmationDialog(_:shouldPresent:actions:) semantics for sheet presenters

Files:
- Sources/Backend/Win32/Rendering/WinRenderer.swift
- Win32 tests

Requirements:
- if presented sheet content carries dismissal-confirmation configuration
- WM_CLOSE / user-triggered close should not destroy the sheet immediately
- instead set the dismissal-confirmation binding to true
- keep the sheet open
- preserve existing programmatic dismiss behavior for isPresented=false or item=nil
- preserve ordinary sheet behavior when no dismissal-confirmation config exists

Do not:
- change public API
- edit non-Win32 files
- update tracker/parity docs

Report back with:
- branch
- commit hash
- changed files
- tests run
```

## Web

```text
Implement Web dismissal-confirmation interception for sheets.

Base:
- dismissal-confirmation-dialog-batch-d-core

Scope:
- dismissalConfirmationDialog(_:shouldPresent:actions:) semantics for sheet presenters

Files:
- Sources/Backend/Web/Rendering/WebRenderer.swift
- Sources/Backend/Web/Rendering/WebViewHost.swift if needed
- Web tests

Requirements:
- if presented sheet content carries dismissal-confirmation configuration
- user-triggered sheet close should not remove the overlay immediately
- instead set the dismissal-confirmation binding to true
- keep the sheet open
- preserve existing programmatic dismiss behavior for isPresented=false or item=nil
- preserve ordinary sheet behavior when no dismissal-confirmation config exists
- inject dismiss environment behavior for sheet content if needed

Do not:
- change public API
- edit non-Web files except the minimal host support needed
- update tracker/parity docs

Report back with:
- branch
- commit hash
- changed files
- tests run
```
