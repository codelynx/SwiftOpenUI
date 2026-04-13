# Adjacent APIs

Items mentioned in the curated reference that do not fit cleanly into the direct `View` or `View`-modifier inventories.

## View-Adjacent

9 total, 4 implemented, 0 partial, 5 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `ActionSheet` | Curated only | iOS, tvOS 13 | Deprecated | Missing | `-` | Yes (iOS 15) — use .confirmationDialog |
| `DocumentGroup` | Curated only | iOS, macOS 11, visionOS 1 | Current | Missing | `-` | - |
| `ImmersiveSpace` | Curated only | visionOS | Current | Missing | `-` | - |
| `NavigationPath` | Curated only | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Navigation/NavigationPath.swift` | - |
| `Path` | Curated only | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Path.swift` | - |
| `Settings` | Curated only | macOS | Current | Missing | `-` | - |
| `Volume` | Curated only | visionOS | Current | Missing | `-` | - |
| `Window` | Curated only | macOS | Current | Implemented | `Sources/SwiftOpenUI/App/Window.swift` | GTK4 + Win32 backends render identified single-instance windows and wire `OpenWindowAction` |
| `WindowGroup` | Curated only | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/App/App.swift` | - |

## Modifier-Adjacent

1 total, 0 implemented, 1 partial, 0 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `withAnimation` | Curated only | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Partial | `Sources/SwiftOpenUI/Modifiers/AnimationModifier.swift` | Top-level function \| Public surface exists, but only 1 overload(s) are present vs 2 in the curated reference families. \| GTK4/Win32/Web: working; Android: partial |
