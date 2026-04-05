# Layout Modifiers

Summary: 24 total, 8 implemented, 2 partial, 14 missing.

## Layout Modifiers (~43)

24 total, 5 implemented, 2 partial, 17 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `alignmentGuide` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `containerRelativeFrame` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `contentMargins` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `fixedSize` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/LayoutModifiers.swift` | GTK: disables expand; Web: flex-shrink 0; Win32: pass-through |
| `frame` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Partial | `Sources/SwiftOpenUI/Modifiers/FrameModifier.swift` | Public surface exists, but only 2 overload(s) are present vs 3 in the curated reference families. \| width/height/min/max |
| `gridCellAnchor` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `gridCellColumns` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/GridRow.swift` | Column span in Grid/GridRow; Web: grid-column span |
| `gridCellUnsizedAxes` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `gridColumnAlignment` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `ignoresSafeArea` | Both | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/SafeAreaModifiers.swift` | GTK: passthrough; Win32/Web: passthrough pending safe-area model |
| `layoutDirectionBehavior` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | - |
| `layoutPriority` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/LayoutModifiers.swift` | Value stored; layout engine integration deferred |
| `layoutValue` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | Custom Layout |
| `listRowInsets` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `listRowSpacing` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `listSectionSpacing` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `offset` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Partial | `Sources/SwiftOpenUI/Modifiers/AnimationModifier.swift` | Public surface exists, but only 1 overload(s) are present vs 3 in the curated reference families. \| CSS transform on GTK4 |
| `padding` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/PaddingModifier.swift` | Edge-specific variants |
| `padding3D` | Curated only | visionOS 1 | Current | Missing | `-` | 3D padding |
| `position` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/LayoutModifiers.swift` | GTK: GtkFixed; Win32: SetWindowPos; Web: CSS absolute positioning |
| `safeAreaInset` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/SafeAreaModifiers.swift` | GTK: GtkBox reserved-space layout; Win32/Web: reservation with spacing/alignment |
| `safeAreaPadding` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/SafeAreaModifiers.swift` | New iOS 17 \| Batch A synthetic fallback on GTK/Win32/Web: explicit length uses exact amount; nil length uses synthetic default 16; not measured native safe-area padding. |
| `scenePadding` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `zIndex` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
