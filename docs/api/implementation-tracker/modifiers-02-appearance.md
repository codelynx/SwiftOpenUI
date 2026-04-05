# Appearance Modifiers

Summary: 36 total, 3 implemented, 1 partial, 32 missing.

## Appearance Modifiers (~81)

36 total, 3 implemented, 1 partial, 32 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `allowedDynamicRange` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17, HDR |
| `alternatingRowBackgrounds` | Both | macOS 14 | Current | Missing | `-` | macOS-only |
| `backgroundStyle` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `border` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/StyleModifiers.swift` | - |
| `buttonBorderShape` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `buttonRepeatBehavior` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `containerBackground` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `controlSize` | Both | iOS 15 / macOS 10.15 / watchOS 9 / visionOS 1 | Current | Missing | `-` | - |
| `foregroundStyle` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Partial | `Sources/SwiftOpenUI/Modifiers/StyleModifiers.swift` | Replaces deprecated foregroundColor \| Public surface exists, but only 1 overload(s) are present vs 3 in the curated reference families. \| Color only (no gradients) |
| `glassBackgroundEffect` | Curated only | visionOS 1 | Current | Missing | `-` | visionOS-only |
| `headerProminence` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `hidden` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/AppearanceModifiers.swift` | GTK: wrapper with opacity 0 + interaction disabled (layout preserved); Win32: ShowWindow(SW_HIDE) (layout preservation observed but not explicitly guaranteed); Web: visibility hidden + pointer-events none (layout preserved) |
| `invalidatableContent` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `labelsHidden` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `listRowBackground` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `listRowSeparator` | Both | iOS 15 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `listSectionSeparator` | Both | iOS 15 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `menuOrder` | Both | iOS 16 / macOS 13 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `persistentSystemOverlays` | Both | iOS 16 / macOS 13 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `preferredColorScheme` | Both | iOS 13 / macOS 11 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `privacySensitive` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `redacted` | Both | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | Current | Missing | `-` | - |
| `scrollBounceBehavior` | Both | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | Current | Missing | `-` | - |
| `scrollClipDisabled` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `scrollContentBackground` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `scrollDisabled` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `scrollIndicators` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `sensoryFeedback` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 | Current | Missing | `-` | New iOS 17 |
| `symbolEffect` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `symbolEffectsRemoved` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | - |
| `tint` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | Replaces deprecated accentColor |
| `unredacted` | Both | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | Current | Missing | `-` | - |
| `windowDismissBehavior` | Both | macOS 15 / visionOS 2 | Current | Missing | `-` | New macOS 15 |
| `windowFullScreenBehavior` | Both | macOS 15 | Current | Missing | `-` | New macOS 15 |
| `windowMinimizeBehavior` | Both | macOS 15 | Current | Missing | `-` | New macOS 15 |
| `windowResizeBehavior` | Both | macOS 15 | Current | Implemented | `Sources/SwiftOpenUI/App/WindowSizing.swift` | New macOS 15 |
