# Graphics and Rendering Modifiers

Summary: 38 total, 10 implemented, 0 partial, 28 missing.

## Graphics and Rendering Modifiers (~53)

38 total, 7 implemented, 0 partial, 31 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `aspectRatio` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/AspectRatioModifier.swift` | GTK4/Web: CSS aspect-ratio + object-fit; Win32: SetWindowPos resize |
| `blendMode` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `blur` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/AppearanceModifiers.swift` | GTK/Web: CSS filter blur; Win32: pass-through (known limitation) |
| `brightness` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `clipped` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/ClipModifiers.swift` | GTK/Web: overflow hidden; Win32: CreateRectRgn |
| `clipShape` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/ClipModifiers.swift` | GTK: CSS border-radius + overflow; Win32: SetWindowRgn (path region fallback for custom shapes); Web: CSS clip-path. Custom shapes: GTK/Web rectangular fallback, Win32 sampled-path region. |
| `colorEffect` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `colorInvert` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `colorMultiply` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `compositingGroup` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `containerShape` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `contentTransition` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `contrast` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `distortionEffect` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `drawingGroup` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `geometryGroup` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `grayscale` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `hueRotation` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `keyframeAnimator` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `layerEffect` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `luminanceToAlpha` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `matchedGeometryEffect` | Both | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | Current | Missing | `-` | - |
| `opacity` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/AnimationModifier.swift` | - |
| `perspectiveRotationEffect` | Curated only | visionOS 1 | Current | Missing | `-` | visionOS-only |
| `phaseAnimator` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `projectionEffect` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `rotation3DEffect` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `rotationEffect` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/RotationModifier.swift` | GTK/Web: CSS transform; Win32: D2D SetTransform |
| `saturation` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `scaledToFill` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/AspectRatioModifier.swift` | Convenience for .aspectRatio(nil, contentMode: .fill) |
| `scaledToFit` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/AspectRatioModifier.swift` | Convenience for .aspectRatio(nil, contentMode: .fit) |
| `scaleEffect` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/AnimationModifier.swift` | Win32: D2D surface only |
| `shadow` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/ShadowModifier.swift` | GTK/Web: CSS; Win32: layered shadow with alpha |
| `transaction` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `transform3DEffect` | Curated only | visionOS 1 | Current | Missing | `-` | visionOS-only |
| `transformEffect` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `transition` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `visualEffect` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
