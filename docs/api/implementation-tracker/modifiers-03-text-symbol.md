# Text and Symbol Modifiers

Summary: 37 total, 12 implemented, 0 partial, 25 missing.

## Text and Symbol Modifiers (~50)

37 total, 6 implemented, 0 partial, 31 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `allowsTightening` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `autocorrectionDisabled` | Both | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | Current | Missing | `-` | - |
| `baselineOffset` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `bold` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/TextDecorationModifiers.swift` | GTK4/Web: CSS font-weight bold; Win32: LOGFONTW FW_BOLD |
| `dynamicTypeSize` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `findDisabled` | Both | iOS 16 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `findNavigator` | Both | iOS 16 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `font` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/StyleModifiers.swift` | Preset + custom |
| `fontDesign` | Both | iOS 16.1 / macOS 13 / watchOS 9.1 / tvOS 16.1 / visionOS 1 | Current | Missing | `-` | - |
| `fontWeight` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/TextDecorationModifiers.swift` | GTK4/Web: CSS font-weight 100-900; Win32: LOGFONTW lfWeight |
| `fontWidth` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `imageScale` | Both | iOS 13 / macOS 11 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Image.swift` | Win32: no real image rendering |
| `italic` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/TextDecorationModifiers.swift` | GTK4/Web: CSS font-style italic; Win32: LOGFONTW lfItalic |
| `kerning` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `keyboardType` | Both | iOS 13 / visionOS 1 | Current | Missing | `-` | iOS/visionOS-only |
| `lineLimit` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/TextModifiers.swift` | GTK4: GtkLabel wrap/lines; Win32: Static style + DrawTextW; Web: -webkit-line-clamp |
| `lineSpacing` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/TextModifiers.swift` | GTK4/Web: CSS line-height; Win32: pass-through (known limitation) |
| `minimumScaleFactor` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `monospaced` | Both | iOS 15.4 / macOS 12.3 / watchOS 8.5 / tvOS 15.4 / visionOS 1 | Current | Missing | `-` | - |
| `monospacedDigit` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `multilineTextAlignment` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/TextModifiers.swift` | GTK4: justify + xalign; Win32: SS_LEFT/CENTER/RIGHT; Web: text-align |
| `replaceDisabled` | Both | iOS 16 / macOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `scrollDismissesKeyboard` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `strikethrough` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/TextDecorationModifiers.swift` | GTK4: Pango strikethrough; Web: CSS line-through; Win32: LOGFONTW lfStrikeOut |
| `submitLabel` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `symbolRenderingMode` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `symbolVariant` | Both | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `textCase` | Both | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/TextDecorationModifiers.swift` | GTK4: string transform (markup no-op); Web: CSS text-transform; Win32: pass-through |
| `textContentType` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Missing | `-` | - |
| `textInputAutocapitalization` | Both | iOS 15 / tvOS 15 / visionOS 1 | Current | Missing | `-` | - |
| `textInputSuggestions` | Both | iOS 18 / macOS 15 / visionOS 2 | Current | Missing | `-` | New iOS 18 |
| `textScale` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `textSelection` | Both | iOS 15 / macOS 12 / visionOS 1 | Current | Missing | `-` | - |
| `tracking` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Missing | `-` | - |
| `truncationMode` | Both | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/TextModifiers.swift` | GTK4: Pango ellipsize; Win32: SS_ENDELLIPSIS/PATHELLIPSIS (head→tail fallback); Web: text-overflow ellipsis (middle→tail fallback) |
| `typesettingLanguage` | Both | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Current | Missing | `-` | New iOS 17 |
| `underline` | Both | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Modifiers/TextDecorationModifiers.swift` | GTK4: Pango underline; Web: CSS underline; Win32: LOGFONTW lfUnderline |
