# State, Environment, and Deprecated Modifiers

Summary: 34 total, 9 implemented, 1 partial, 24 missing.

## State and Environment Modifiers (~20)

12 total, 1 implemented, 1 partial, 10 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `anchorPreference` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `environment` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Partial | `Sources/SwiftOpenUI/Modifiers/EnvironmentModifiers.swift` | KeyPath + Value \| Public surface exists, but only 1 overload(s) are present vs 2 in the curated reference families. |
| `environmentObject` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/EnvironmentModifiers.swift` | ObservableObject |
| `equatable` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `id` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `modelContainer` | Curated only | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `modelContext` | Curated only | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `onPreferenceChange` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `preference` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `tag` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/TagModifier.swift` | Thread-local tag propagation for selection-based controls. Infrastructure — no control reads tag yet. |
| `transformEnvironment` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `transformPreference` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |

## Deprecated Modifiers and Replacements (~52)

22 total, 6 implemented, 0 partial, 16 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `accentColor` | Both | - | Deprecated | Missing | `-` | iOS 17 |
| `accessibility` | Both | - | Deprecated | Missing | `-` | iOS 14 |
| `actionSheet` | Both | - | Deprecated | Missing | `-` | iOS 15 |
| `alert` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/AlertModifier.swift` | Batch B: title + isPresented + actions/message + error families via simplified AlertButton[] + String API. GTK: modal dialog; Win32: MessageBoxW; Web: modal overlay. |
| `animation` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/AnimationModifier.swift` | Preferred \| GTK4: CSS transitions + descriptors; Win32: D2D animation engine; Web: two-phase rebuild with CSS transitions; Android: JSON node stubs |
| `autocapitalization` | Both | - | Deprecated | Missing | `-` | iOS 15 |
| `background` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/StyleModifiers.swift` | Modern API \| Color and arbitrary view overloads |
| `colorScheme` | Both | - | Deprecated | Missing | `-` | iOS 15 |
| `coordinateSpace` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | Replaces deprecated coordinateSpace(name:) |
| `cornerRadius` | Both | - | Deprecated | Implemented | `Sources/SwiftOpenUI/Modifiers/CornerRadiusModifier.swift` | iOS 17 \| GTK/Web: CSS; Win32: SetWindowRgn rounded region |
| `disableAutocorrection` | Both | - | Deprecated | Missing | `-` | iOS 16.4 |
| `edgesIgnoringSafeArea` | Both | - | Deprecated | Missing | `-` | iOS 14 |
| `foregroundColor` | Both | - | Deprecated | Implemented | `Sources/SwiftOpenUI/Modifiers/StyleModifiers.swift` | iOS 17 |
| `mask` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `menuButtonStyle` | Both | - | Deprecated | Missing | `-` | macOS 13 |
| `navigationBarHidden` | Both | - | Deprecated | Missing | `-` | iOS 16 |
| `navigationBarItems` | Both | - | Deprecated | Missing | `-` | iOS 14 |
| `navigationBarTitle` | Both | - | Deprecated | Missing | `-` | iOS 14 |
| `navigationViewStyle` | Both | - | Deprecated | Missing | `-` | iOS 16 |
| `onChange` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/OnChangeModifier.swift` | onChange(of:perform:) variant. Render-pass counter-keyed value tracking. |
| `overlay` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/OverlayModifier.swift` | Modern API \| GTK: GtkOverlay; Win32: container; Web: absolute positioning |
| `statusBar` | Both | - | Deprecated | Missing | `-` | iOS 16 |
