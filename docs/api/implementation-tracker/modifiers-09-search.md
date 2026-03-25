# Search Modifiers

Summary: 6 total, 3 implemented, 1 partial, 2 missing.

## Search Modifiers (~16)

6 total, 3 implemented, 1 partial, 2 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `searchable` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/SearchableModifier.swift` | Batch C fallback on GTK/Win32/Web: search field above content; placement stored but not differentiated yet; tokens and editableTokens render as display-only chips; suggestions render as simple rows with click-to-complete behavior. Win32 suppresses the search UI when isPresented == false. |
| `searchCompletion` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/SearchableModifier.swift` | - |
| `searchDictationBehavior` | Both | iOS 17 / watchOS 10 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `searchPresentationToolbarBehavior` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `searchScopes` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/SearchableModifier.swift` | - |
| `searchSuggestions` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Partial | `Sources/SwiftOpenUI/Modifiers/SearchableModifier.swift` | Public surface exists, but only 1 overload(s) are present vs 2 in the curated reference families. |
