# Navigation and Auxiliary Modifiers

Summary: 24 total, 4 implemented, 1 partial, 19 missing.

## Navigation and Auxiliary Modifiers (~48)

24 total, 3 implemented, 1 partial, 20 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `badge` | Both | iOS 15 / macOS 12 / visionOS 1 | Current | Missing | `-` | - |
| `badgeProminence` | Both | iOS 17 / macOS 14 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `contextMenu` | Both | iOS 13 / macOS 10.15 / watchOS 6.2 / tvOS 14 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/ContextMenuModifier.swift` | GTK4: GtkPopoverMenu (right-click); Win32: TrackPopupMenu (WM_RBUTTONUP); Web: CSS overlay (contextmenu event, submenus omitted) |
| `help` | Both | iOS 15.4 / macOS 11 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `navigationBarBackButtonHidden` | Both | iOS 13 / macOS 13 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `navigationBarTitleDisplayMode` | Both | iOS 14 / watchOS 8 / visionOS 1 | Current | Missing | `-` | - |
| `navigationDestination` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Partial | `Sources/SwiftOpenUI/Navigation/NavigationDestination.swift` | Public surface exists, but only 1 overload(s) are present vs 3 in the curated reference families. \| Type-based registry |
| `navigationDocument` | Both | iOS 16 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `navigationSplitViewColumnWidth` | Both | iOS 16 / macOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/NavigationSplitViewColumnWidthModifier.swift` | min/ideal/max; Web: pass-through (consumed by NavigationSplitView) |
| `navigationSubtitle` | Both | macOS 11 / visionOS 1 | Current | Missing | `-` | macOS/visionOS |
| `navigationTitle` | Both | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Navigation/NavigationTitle.swift` | - |
| `sectionActions` | Both | iOS 18 / macOS 15 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `tabViewCustomization` | Both | iOS 18 / macOS 15 / tvOS 18 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `tabViewSidebarFooter` | Both | iOS 18 / macOS 15 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `tabViewSidebarHeader` | Both | iOS 18 / macOS 15 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `toolbar` | Both | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/ToolbarModifier.swift` | Batch B fallback on GTK/Win32/Web: toolbar(_:for:) and toolbar(removing:) are supported for the active navigation/header toolbar surface; target handling is narrower than SwiftUI. GTK: header bar; Win32: nav header; Web: header right area. |
| `toolbarBackground` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `toolbarBackgroundVisibility` | Both | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `toolbarColorScheme` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `toolbarForegroundStyle` | Both | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `toolbarRole` | Both | iOS 16 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `toolbarTitleDisplayMode` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `toolbarTitleMenu` | Both | iOS 16 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `toolbarVisibility` | Both | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
