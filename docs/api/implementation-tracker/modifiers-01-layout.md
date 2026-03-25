# Layout Modifiers

Summary: 24 total, 2 implemented, 4 partial, 18 missing.

## Layout Modifiers (~43)

24 total, 2 implemented, 4 partial, 18 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `alignmentGuide` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `containerRelativeFrame` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `contentMargins` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `fixedSize` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `frame` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Partial | `Sources/SwiftOpenUI/Modifiers/FrameModifier.swift` | Public surface exists, but only 2 overload(s) are present vs 3 in the curated reference families. \| width/height/min/max |
| `gridCellAnchor` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `gridCellColumns` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/GridRow.swift` | Column span in Grid/GridRow; Web: grid-column span |
| `gridCellUnsizedAxes` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `gridColumnAlignment` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `ignoresSafeArea` | Both | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | Current | Partial | `Sources/SwiftOpenUI/Modifiers/SafeAreaModifiers.swift` | Core API + GTK4 passthrough; other backends pending |
| `layoutDirectionBehavior` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | - |
| `layoutPriority` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `layoutValue` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | Custom Layout |
| `listRowInsets` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `listRowSpacing` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `listSectionSpacing` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `offset` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Partial | `Sources/SwiftOpenUI/Modifiers/AnimationModifier.swift` | Public surface exists, but only 1 overload(s) are present vs 3 in the curated reference families. \| CSS transform on GTK4 |
| `padding` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/PaddingModifier.swift` | Edge-specific variants |
| `padding3D` | Curated only | visionOS 1 | Current | Missing | `-` | 3D padding |
| `position` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `safeAreaInset` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Partial | `Sources/SwiftOpenUI/Modifiers/SafeAreaModifiers.swift` | Core API + GTK4 reserved-space layout; other backends pending |
| `safeAreaPadding` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `scenePadding` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `zIndex` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
