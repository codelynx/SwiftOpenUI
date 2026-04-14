# Input and Event Modifiers

Summary: 55 total, 7 implemented, 1 partial, 47 missing.

## Input and Event Modifiers (~148)

55 total, 6 implemented, 1 partial, 48 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `allowsHitTesting` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `contentShape` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `copyable` | Both | iOS 16 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `cuttable` | Both | iOS 16 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `defaultFocus` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `defaultHoverEffect` | Both | iOS 18 / tvOS 18 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `defaultScrollAnchor` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | - |
| `defersSystemGestures` | Both | iOS 16 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `disabled` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/DisabledModifier.swift` | - |
| `draggable` | Both | iOS 16 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `dropDestination` | Both | iOS 16 / macOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/DropDestinationModifier.swift` | GTK4: GtkDropTarget with GDK_TYPE_FILE_LIST; Win32: OLE IDropTarget. URL.self only. M3 |
| `focusable` | Both | iOS 17 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `focused` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/FocusModifier.swift` | Web: DOM focus/blur + FocusState binding |
| `focusEffectDisabled` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | - |
| `focusSection` | Both | iOS 17 / macOS 14 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `gesture` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `highPriorityGesture` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `hoverEffect` | Both | iOS 13.4 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `hoverEffectGroup` | Both | iOS 18 / tvOS 18 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `keyboardShortcut` | Both | iOS 14 / macOS 11 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/KeyboardShortcutModifier.swift` | KeyEquivalent + EventModifiers + window-scoped registry. GTK4: GtkEventControllerKey; Win32: ACCEL. M1 |
| `modifierKeyAlternate` | Both | iOS 18 / macOS 15 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `onAppear` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/LifecycleModifier.swift` | GTK: map signal; Win32: deferred; Web: fires on every render (host-level) |
| `onContinueUserActivity` | Both | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | Current | Missing | `-` | - |
| `onContinuousHover` | Both | iOS 16 / macOS 13 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `onDisappear` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/LifecycleModifier.swift` | GTK: unmap; Win32: WM_NCDESTROY (limited) |
| `onDrag` | Both | iOS 13.4 / macOS 10.15 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/GestureModifier.swift` | minimumDistance filtering |
| `onDrop` | Both | iOS 14 / macOS 11 / visionOS 1 | Current | Missing | `-` | - |
| `onGeometryChange` | Both | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | Current | Missing | `-` | New iOS 18, modern GeometryReader replacement |
| `onHover` | Both | iOS 13.4 / macOS 10.15 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `onKeyPress` | Both | iOS 17 / macOS 14 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `onLongPressGesture` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 14 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/GestureModifier.swift` | minimumDuration |
| `onModifierKeysChanged` | Both | iOS 18 / macOS 15 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `onOpenURL` | Both | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | Current | Missing | `-` | - |
| `onReceive` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | Combine |
| `onScrollGeometryChange` | Both | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `onScrollPhaseChange` | Both | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `onScrollTargetVisibilityChange` | Both | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `onScrollVisibilityChange` | Both | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `onSubmit` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/OnSubmitModifier.swift` | Environment-based SubmitAction. GTK4: activate signal; Win32: VK_RETURN subclass; Web: keydown Enter. TextField + SecureField wired, TextEditor excluded. |
| `onTapGesture` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 16 / visionOS 1 | Current | Partial | `Sources/SwiftOpenUI/Modifiers/GestureModifier.swift` | Public surface exists, but only 1 overload(s) are present vs 2 in the curated reference families. \| count parameter |
| `pasteDestination` | Both | iOS 16 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `pointerStyle` | Curated only | iOS 18 / macOS 15 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `pointerVisibility` | Both | iOS 18 / macOS 15 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `refreshable` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `scrollPosition` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | - |
| `scrollTargetBehavior` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `scrollTargetLayout` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | - |
| `scrollTransition` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | - |
| `searchFocused` | Both | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `selectionDisabled` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | - |
| `simultaneousGesture` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `submitScope` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `swipeActions` | Both | iOS 15 / macOS 12 / watchOS 8 / visionOS 1 | Current | Missing | `-` | - |
| `task` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | Async \| Needs async runtime |
| `userActivity` | Both | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | Current | Missing | `-` | - |
