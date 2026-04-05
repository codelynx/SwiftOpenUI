# Presentation Modifiers

Summary: 23 total, 5 implemented, 0 partial, 18 missing.

## Presentation Modifiers (~97)

23 total, 3 implemented, 0 partial, 20 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `confirmationDialog` | Both | iOS, macOS 12, watchOS 8, tvOS 15, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/ConfirmationDialogModifier.swift` | Batch D fallback on GTK/Win32/Web: titleVisibility == .hidden, message, and dismissalConfirmationDialog(_:shouldPresent:actions:) are supported; .automatic currently behaves like .visible. dismissalConfirmationDialog now intercepts user-triggered sheet dismiss for sheet(isPresented:) and sheet(item:); broader presenter interception remains deferred. GTK: vertical modal; Win32: MessageBoxW; Web: inline overlay. |
| `dialogSeverity` | Both | iOS 17 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `dialogSuppressionToggle` | Both | iOS 17 / macOS 14 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `dismissalConfirmationDialog` | Both | iOS 18 / macOS 15 / visionOS 2 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/ConfirmationDialogModifier.swift` | New iOS 18 |
| `fileDialogDefaultDirectory` | Both | iOS 17 / macOS 14 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `fileDialogMessage` | Both | iOS 17 / macOS 14 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `fileExporter` | Both | iOS 14 / macOS 11 / visionOS 1 | Current | Missing | `-` | Multiple overloads |
| `fileImporter` | Both | iOS 14 / macOS 11 / visionOS 1 | Current | Missing | `-` | - |
| `fileMover` | Both | iOS 14 / macOS 11 / visionOS 1 | Current | Missing | `-` | - |
| `fullScreenCover` | Both | iOS, watchOS 7, tvOS 14, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/FullScreenCoverModifier.swift` | GTK4: fullscreen modal window; Win32: WS_POPUP + WS_EX_TOPMOST + Escape hook; Web: fixed overlay |
| `inspector` | Both | iOS, macOS 14, visionOS 1 | Current | Missing | `-` | - |
| `inspectorColumnWidth` | Both | iOS 17 / macOS 14 / visionOS 1 | Current | Missing | `-` | - |
| `interactiveDismissDisabled` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `popover` | Both | iOS, macOS 10.15, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/PopoverModifier.swift` | GTK4: GtkPopover; Win32: popup window; Web: absolute overlay (dismiss listener partially leaks on non-click dismiss paths) |
| `presentationBackground` | Both | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | Current | Missing | `-` | - |
| `presentationBackgroundInteraction` | Both | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | Current | Missing | `-` | - |
| `presentationCompactAdaptation` | Both | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | Current | Missing | `-` | - |
| `presentationContentInteraction` | Both | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | Current | Missing | `-` | - |
| `presentationCornerRadius` | Both | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | Current | Missing | `-` | - |
| `presentationDetents` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `presentationDragIndicator` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `presentationSizing` | Both | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `sheet` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/SheetModifier.swift` | Batch A: isPresented, item, and onDismiss families on GTK/Win32/Web. GTK: modal window; Win32: popup; Web: modal overlay. |
