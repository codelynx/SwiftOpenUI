# Search Modifiers

Summary: 6 total, 0 implemented, 1 partial, 5 missing.

## Search Modifiers (~16)

6 total, 0 implemented, 1 partial, 5 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `searchable` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Partial | `Sources/SwiftOpenUI/Modifiers/SearchableModifier.swift` | Public surface exists, but only 3 overload(s) are present vs 4 in the curated reference families. \| Batch A fallback on GTK/Win32/Web: search field above content; placement stored but not differentiated yet. Win32 suppresses field when isPresented == false. |
| `searchCompletion` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `searchDictationBehavior` | Both | iOS 17 / watchOS 10 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `searchPresentationToolbarBehavior` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `searchScopes` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `searchSuggestions` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
