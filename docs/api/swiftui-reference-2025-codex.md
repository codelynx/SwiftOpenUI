# SwiftUI Views and View Modifiers Reference (2025 Baseline)

Generated on 2026-03-24 from the public SwiftUI and SwiftUICore `.swiftinterface` files in the locally installed Apple SDK, then filtered to APIs available by the 2025 platform baseline: iOS 18, macOS 15, tvOS 18, watchOS 11, and visionOS 2.

## Scope

- Views: 98 public non-underscored types that directly conform to `View`.
- View modifiers: 437 public non-underscored members declared on `View` extensions, collapsed by base name across overloads.
- Status: `Current` means at least one matching API is not deprecated. `Deprecated` means only deprecated overloads remain for that name.
- Availability values are the earliest platform versions seen in the public interface for that symbol or modifier name.
- This list is intentionally limited to `View` and `View` modifiers. View-specific APIs like `Text.bold()` are not included unless they are declared on `View` itself.

## Sources

- Apple SwiftUI overview: https://developer.apple.com/swiftui/
- Apple documentation, Configuring views: https://developer.apple.com/documentation/swiftui/configuring-views
- Apple documentation, Layout modifiers: https://developer.apple.com/documentation/swiftui/view-layout
- Apple documentation, Text: https://developer.apple.com/documentation/swiftui/text

## Views

| View | Availability | Status | Notes |
|---|---|---|---|
| `AngularGradient` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `AnyView` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `AsyncImage` | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `Button` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `Canvas` | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `Color` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `ColorPicker` | iOS 14+, macOS 11+ | Current | - |
| `ContentUnavailableView` | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `ControlGroup` | iOS 15+, macOS 12+, tvOS 17+ | Current | - |
| `DatePicker` | iOS 13+, macOS 10.15+, watchOS 10+ | Current | - |
| `DefaultDateProgressLabel` | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `DefaultDocumentGroupLaunchActions` | iOS 18+, macOS 15+, visionOS 2+ | Current | - |
| `DefaultSettingsLinkLabel` | macOS 14+ | Current | - |
| `DefaultShareLinkLabel` | iOS 16+, macOS 13+, watchOS 9+ | Current | - |
| `DefaultTabLabel` | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `DefaultWindowVisibilityToggleLabel` | macOS 15+ | Current | - |
| `DisclosureGroup` | iOS 14+, macOS 11+ | Current | - |
| `Divider` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `DocumentLaunchView` | iOS 18+ | Current | - |
| `EditableCollectionContent` | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `EditButton` | iOS 13+ | Current | - |
| `EllipticalGradient` | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `EmptyView` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `EquatableView` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `ForEach` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `Form` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `Gauge` | iOS 16+, macOS 13+, watchOS 7+ | Current | - |
| `GeometryReader` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `Grid` | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `GridRow` | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `Group` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `GroupBox` | iOS 14+, macOS 10.15+ | Current | - |
| `GroupElementsOfContent` | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `GroupSectionsOfContent` | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `HelpLink` | macOS 14+ | Current | - |
| `HSplitView` | macOS 10.15+ | Current | - |
| `HStack` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `Image` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `KeyframeAnimator` | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `Label` | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `LabeledContent` | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `LabeledControlGroupContent` | iOS 16+, macOS 13+, tvOS 17+ | Current | - |
| `LabeledToolbarItemGroupContent` | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `LazyHGrid` | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `LazyHStack` | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `LazyVGrid` | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `LazyVStack` | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `LinearGradient` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `Link` | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `List` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `Menu` | iOS 14+, macOS 11+, tvOS 17+ | Current | - |
| `MenuButton` | macOS 10.15+ | Deprecated | Use `Menu` instead. |
| `MeshGradient` | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `ModifiedContent` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `MultiDatePicker` | iOS 16+ | Current | - |
| `NavigationLink` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `NavigationSplitView` | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `NavigationStack` | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `NavigationView` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 7+, visionOS 1+ | Deprecated | use NavigationStack or NavigationSplitView instead |
| `NewDocumentButton` | iOS 18+, macOS 15+, visionOS 2+ | Current | - |
| `OutlineGroup` | iOS 14+, macOS 11+ | Current | - |
| `OutlineSubgroupChildren` | iOS 14+, macOS 11+ | Current | - |
| `PasteButton` | iOS 16+, macOS 10.15+ | Current | - |
| `PhaseAnimator` | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `Picker` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `PlaceholderContentView` | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `PresentedWindowContent` | iOS 16+, macOS 13+ | Current | - |
| `PreviewModifierContent` | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `ProgressView` | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `RadialGradient` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `RenameButton` | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `ScrollView` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `ScrollViewReader` | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `Section` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `SecureField` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `SettingsLink` | macOS 14+ | Current | - |
| `ShareLink` | iOS 16+, macOS 13+, watchOS 9+ | Current | - |
| `Slider` | iOS 13+, macOS 10.15+, watchOS 6+ | Current | - |
| `Spacer` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `Stepper` | iOS 13+, macOS 10.15+, watchOS 9+ | Current | - |
| `SubscriptionView` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `Subview` | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `SubviewsCollection` | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `SubviewsCollectionSlice` | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `Table` | iOS 16+, macOS 12+ | Current | - |
| `TabView` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 7+ | Current | - |
| `Text` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `TextEditor` | iOS 14+, macOS 11+ | Current | - |
| `TextField` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `TextFieldLink` | watchOS 9+ | Current | - |
| `TimelineView` | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `Toggle` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `TupleView` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `ViewThatFits` | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `VSplitView` | macOS 10.15+ | Current | - |
| `VStack` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `WindowVisibilityToggle` | macOS 15+ | Current | - |
| `ZStack` | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |

## View Modifiers

| Modifier | Overloads | Availability | Status | Notes |
|---|---:|---|---|---|
| `.accentColor(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+ | Deprecated | will be removed |
| `.accessibility(...)` | 12 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+ | Deprecated | Renamed to `accessibilityValue(_:)` |
| `.accessibilityAction(...)` | 6 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityActions(...)` | 2 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 2+ | Current | - |
| `.accessibilityActivationPoint(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityAddTraits(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+, visionOS 2+ | Current | - |
| `.accessibilityAdjustableAction(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.accessibilityChartDescriptor(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.accessibilityChildren(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityCustomContent(...)` | 12 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | Using non-localized strings for labels is not directly supported. Instead, wrap both the label and the value in a Text struct. |
| `.accessibilityDirectTouch(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `.accessibilityDragPoint(...)` | 8 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityDropPoint(...)` | 8 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityElement(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.accessibilityFocused(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityHeading(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityHidden(...)` | 2 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+, visionOS 2+ | Current | - |
| `.accessibilityHint(...)` | 8 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityIdentifier(...)` | 2 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+, visionOS 2+ | Current | - |
| `.accessibilityIgnoresInvertColors(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+, visionOS 1+ | Current | - |
| `.accessibilityInputLabels(...)` | 6 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityLabel(...)` | 9 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityLabeledPair(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityLinkedGroup(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `.accessibilityQuickAction(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityRemoveTraits(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityRepresentation(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.accessibilityRespondsToUserInteraction(...)` | 2 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 2+ | Current | - |
| `.accessibilityRotor(...)` | 20 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | use Animatable directly; Some overloads deprecated |
| `.accessibilityRotorEntry(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 2+ | Current | - |
| `.accessibilityScrollAction(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+ | Current | - |
| `.accessibilityScrollStatus(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityShowsLargeContentViewer(...)` | 2 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.accessibilitySortPriority(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `.accessibilityTextContentType(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.accessibilityValue(...)` | 8 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.accessibilityZoomAction(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.actionSheet(...)` | 2 | iOS 13+, tvOS 13+, watchOS 6+, visionOS 1+ | Deprecated | use `View.confirmationDialog(title:isPresented:titleVisibility:presenting::actions:)`instead. |
| `.alert(...)` | 20 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | Use View.alert(_:isPresented:presenting:actions:) instead.; Some overloads deprecated |
| `.alignmentGuide(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+, macCatalyst 13+ | Current | - |
| `.allowedDynamicRange(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 6+ | Current | - |
| `.allowsHitTesting(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.allowsTightening(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Deprecated | Renamed to `lineHeightMultiple` |
| `.allowsWindowActivationEvents(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.alternatingRowBackgrounds(...)` | 1 | iOS 16+, macOS 14+, tvOS 16+, watchOS 9+ | Current | - |
| `.anchorPreference(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.animation(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | Use withAnimation or animation(_:value:) instead.; Some overloads deprecated |
| `.aspectRatio(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.autocapitalization(...)` | 1 | iOS 13+, tvOS 13+, visionOS 1+ | Deprecated | use textInputAutocapitalization(_:) |
| `.autocorrectionDisabled(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 8+ | Current | - |
| `.background(...)` | 8 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | Use `background(alignment:content:)` instead.; Some overloads deprecated |
| `.backgroundPreferenceValue(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.backgroundStyle(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.badge(...)` | 5 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.badgeProminence(...)` | 1 | iOS 17+, macOS 14+ | Current | - |
| `.baselineOffset(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.blendMode(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.blur(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.bold(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.border(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.brightness(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.buttonBorderShape(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.buttonRepeatBehavior(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 2+ | Current | - |
| `.buttonStyle(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+ | Current | Use EnvironmentValues.isPresented or EnvironmentValues.dismiss; Some overloads deprecated |
| `.clipped(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.clipShape(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.colorEffect(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, visionOS 2+ | Current | - |
| `.colorInvert(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.colorMultiply(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.colorScheme(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+ | Deprecated | Renamed to `preferredColorScheme(_:)` |
| `.compositingGroup(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.confirmationDialog(...)` | 16 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.containerBackground(...)` | 2 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+ | Current | - |
| `.containerRelativeFrame(...)` | 3 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+ | Current | - |
| `.containerShape(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 2+ | Deprecated | Use Color(cgColor:) when converting a CGColor, or create a standard Color directly |
| `.containerValue(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.contentCaptureProtected(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.contentMargins(...)` | 3 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `.contentShape(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.contentToolbar(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.contentTransition(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+ | Deprecated | - |
| `.contextMenu(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 14+, watchOS 6+, visionOS 1+ | Current | Renamed to `MagnifyGesture`; Some overloads deprecated |
| `.contrast(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.controlGroupStyle(...)` | 1 | iOS 15+, macOS 12+, tvOS 17+ | Current | - |
| `.controlSize(...)` | 1 | iOS 15+, macOS 10.15+, tvOS 15+, watchOS 9+, visionOS 1+ | Current | - |
| `.coordinateSpace(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+ | Current | replace styled NavigationView with NavigationStack or NavigationSplitView instead; Some overloads deprecated |
| `.copyable(...)` | 1 | macOS 13+ | Current | - |
| `.cornerRadius(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+ | Deprecated | Use `clipShape` or `fill` instead. |
| `.cuttable(...)` | 1 | macOS 13+ | Current | - |
| `.datePickerStyle(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 16+, watchOS 10+ | Current | - |
| `.defaultAdaptableTabBarPlacement(...)` | 1 | iOS 18+, macOS 13+ | Current | - |
| `.defaultAppStorage(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `.defaultFocus(...)` | 1 | iOS 17+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+ | Current | - |
| `.defaultHoverEffect(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.defaultScrollAnchor(...)` | 2 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 2+ | Current | - |
| `.defaultWheelPickerItemHeight(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.defersSystemGestures(...)` | 1 | iOS 16+ | Current | - |
| `.deleteDisabled(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.dialogIcon(...)` | 1 | iOS 17+, macOS 13+, tvOS 17+, watchOS 10+ | Current | - |
| `.dialogSeverity(...)` | 1 | iOS 17+, macOS 13+, tvOS 17+, watchOS 10+, visionOS 1+ | Deprecated | Use .menuStyle(.button) and .buttonStyle(.borderless). |
| `.dialogSuppressionToggle(...)` | 5 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.digitalCrownAccessory(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.digitalCrownRotation(...)` | 6 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.disableAutocorrection(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 8+, visionOS 1+ | Deprecated | Renamed to `autocorrectionDisabled(_:)` |
| `.disabled(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.disclosureGroupStyle(...)` | 1 | iOS 16+, macOS 13+ | Current | - |
| `.dismissalConfirmationDialog(...)` | 8 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.distortionEffect(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.documentBrowserContextMenu(...)` | 1 | macOS 11+, tvOS 16+, watchOS 9+ | Current | - |
| `.dragConfiguration(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.dragContainer(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.dragContainerSelection(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.draggable(...)` | 6 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.dragPreviewsFormation(...)` | 1 | iOS 16+, tvOS 16+, watchOS 9+ | Current | - |
| `.drawingGroup(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.dropConfiguration(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.dropDestination(...)` | 1 | iOS 16+, macOS 13+ | Deprecated | Use `dropDestination(for:isEnabled:action:)` with an `action` that takes a `DropSession` parameter instead. |
| `.dynamicTypeSize(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.edgesIgnoringSafeArea(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+ | Deprecated | Use ignoresSafeArea(_:edges:) instead. |
| `.environment(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.environmentObject(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.equatable(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+ | Current | - |
| `.exportableToServices(...)` | 2 | iOS 13+, macOS 13+, tvOS 13+, watchOS 6+ | Current | - |
| `.exportsItemProviders(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.fileDialogBrowserOptions(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.fileDialogConfirmationLabel(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.fileDialogCustomizationID(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.fileDialogDefaultDirectory(...)` | 1 | iOS 17+, macOS 14+, tvOS 13+, watchOS 6+ | Current | - |
| `.fileDialogImportsUnresolvedAliases(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.fileDialogMessage(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.fileDialogURLEnabled(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.fileExporter(...)` | 10 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.fileExporterFilenameLabel(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.fileImporter(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.fileMover(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | Provide `UTType`s as the `supportedContentTypes` instead.; Some overloads deprecated |
| `.findDisabled(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.findNavigator(...)` | 1 | iOS 16+ | Current | - |
| `.fixedSize(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.flipsForRightToLeftLayoutDirection(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+ | Current | - |
| `.focusable(...)` | 3 | iOS 13.4+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | Use FocusState<T> and View.focused(_:equals) for functionality previously provided by the onChange parameter.; Some overloads deprecated |
| `.focused(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.focusedObject(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.focusedSceneObject(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.focusedSceneValue(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.focusedValue(...)` | 3 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `.focusEffectDisabled(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `.focusScope(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.focusSection(...)` | 1 | iOS 17.4+, macOS 13+, tvOS 15+, visionOS 1.1+ | Current | - |
| `.font(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.fontDesign(...)` | 1 | iOS 16.1+, macOS 13+, tvOS 16.1+, watchOS 9.1+ | Current | - |
| `.fontWeight(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.fontWidth(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.foregroundColor(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+ | Deprecated | Renamed to `foregroundStyle(_:)` |
| `.foregroundStyle(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.formStyle(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.frame(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | Please pass one or more parameters.; Some overloads deprecated |
| `.fullScreenCover(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.gaugeStyle(...)` | 1 | iOS 16+, macOS 13+, watchOS 7+ | Current | - |
| `.geometryGroup(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `.gesture(...)` | 5 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+, macCatalyst 13+ | Current | - |
| `.glassEffectID(...)` | 1 | visionOS 2+ | Current | - |
| `.grayscale(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.gridCellAnchor(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.gridCellColumns(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.gridCellUnsizedAxes(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.gridColumnAlignment(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.groupBoxStyle(...)` | 1 | iOS 14+, macOS 11+, tvOS 15+, watchOS 8+, visionOS 2+ | Current | - |
| `.handGestureShortcut(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, macCatalyst 16.2+ | Deprecated | Use `Menu` instead. |
| `.handlesExternalEvents(...)` | 1 | iOS 14+, macOS 11+ | Current | - |
| `.headerProminence(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.help(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.hidden(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.highPriorityGesture(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.horizontalRadioGroupLayout(...)` | 1 | iOS 14+, macOS 10.15+, tvOS 14+, watchOS 7+ | Current | - |
| `.hoverEffect(...)` | 5 | iOS 13.4+, macOS 14+, tvOS 16+, visionOS 1+ | Current | - |
| `.hoverEffectDisabled(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.hoverEffectGroup(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.hueRotation(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+ | Current | - |
| `.id(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.ignoresSafeArea(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `.imageScale(...)` | 1 | iOS 13+, macOS 11+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Deprecated | Use `EnvironmentValues.appearsActive` instead. |
| `.immersiveEnvironmentPicker(...)` | 1 | visionOS 2+ | Current | - |
| `.importableFromServices(...)` | 1 | macOS 13+ | Current | - |
| `.importsItemProviders(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.indexViewStyle(...)` | 1 | iOS 14+, tvOS 14+, watchOS 8+ | Current | - |
| `.inspector(...)` | 1 | iOS 17+, macOS 14+, tvOS 14+, watchOS 7+ | Current | - |
| `.inspectorColumnWidth(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.interactionActivityTrackingTag(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.interactiveDismissDisabled(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 1+ | Current | - |
| `.invalidatableContent(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+ | Deprecated | Provide `UTType`s as the `types` instead. |
| `.italic(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.itemProvider(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.kerning(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.keyboardShortcut(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.keyboardType(...)` | 1 | iOS 13+, macOS 12+, tvOS 13+ | Current | - |
| `.keyframeAnimator(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+, macCatalyst 13+ | Current | - |
| `.labeledContentStyle(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.labelIconToTitleSpacing(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.labelsHidden(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+ | Current | - |
| `.labelStyle(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+, visionOS 2+ | Current | - |
| `.labelsVisibility(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.layerEffect(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.layoutDirectionBehavior(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 2+ | Current | - |
| `.layoutPriority(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.layoutValue(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.lineLimit(...)` | 5 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+ | Current | - |
| `.lineSpacing(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.listItemTint(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.listRowBackground(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.listRowHoverEffect(...)` | 1 | visionOS 1+ | Current | - |
| `.listRowHoverEffectDisabled(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.listRowInsets(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+ | Deprecated | replace styled NavigationView with NavigationSplitView |
| `.listRowPlatterColor(...)` | 1 | iOS 13+, macOS 13+, tvOS 13+, watchOS 6+ | Deprecated | Renamed to `listItemTint(_:)` |
| `.listRowSeparator(...)` | 1 | iOS 15+, macOS 13+, tvOS 13+, watchOS 6+ | Current | - |
| `.listRowSeparatorTint(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.listRowSpacing(...)` | 1 | iOS 15+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `.listSectionSeparator(...)` | 1 | iOS 15+, macOS 13+ | Current | - |
| `.listSectionSeparatorTint(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.listSectionSpacing(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.listStyle(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+ | Current | - |
| `.luminanceToAlpha(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.mask(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | Use overload where mask accepts a @ViewBuilder instead.; Some overloads deprecated |
| `.matchedGeometryEffect(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `.matchedTransitionSource(...)` | 2 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | Use MenuButton instead.; Some overloads deprecated |
| `.materialActiveAppearance(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.menuActionDismissBehavior(...)` | 1 | iOS 16.4+, macOS 13.3+, tvOS 16.4+, watchOS 9.4+ | Current | - |
| `.menuButtonStyle(...)` | 1 | macOS 10.15+ | Deprecated | Use `MenuStyle` instead. |
| `.menuIndicator(...)` | 1 | iOS 15+, macOS 12+, tvOS 17+, watchOS 11+, visionOS 2+ | Current | - |
| `.menuOrder(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+ | Current | - |
| `.menuStyle(...)` | 1 | iOS 14+, macOS 11+, tvOS 17+ | Current | - |
| `.minimumScaleFactor(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.modifier(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+ | Deprecated | - |
| `.modifierKeyAlternate(...)` | 1 | macOS 15+ | Current | - |
| `.monospaced(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.monospacedDigit(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.moveDisabled(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.multilineTextAlignment(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Deprecated | Use string interpolation on `Text` instead: `Text(\ |
| `.navigationBarBackButtonHidden(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.navigationBarHidden(...)` | 1 | iOS 13+, macOS 13+, tvOS 13+, watchOS 6+, visionOS 1+ | Deprecated | Use toolbar(.hidden) |
| `.navigationBarItems(...)` | 3 | iOS 13+, macOS 13+, tvOS 13+, watchOS 7+, visionOS 1+ | Deprecated | Use toolbar(_:) with navigationBarLeading or navigationBarTrailing placement |
| `.navigationBarTitle(...)` | 6 | iOS 13+, tvOS 13+, watchOS 6+, visionOS 1+ | Deprecated | Renamed to `navigationTitle(_:)` |
| `.navigationBarTitleDisplayMode(...)` | 1 | iOS 14+, watchOS 8+ | Current | - |
| `.navigationDestination(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.navigationDocument(...)` | 6 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+ | Current | Use visualEffect, scrollTransition, or onGeometryChange instead; Some overloads deprecated |
| `.navigationLinkIndicatorVisibility(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+ | Current | - |
| `.navigationSplitViewColumnWidth(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | Renamed to `VerticalTabViewStyle`; Some overloads deprecated |
| `.navigationSplitViewStyle(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.navigationSubtitle(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.navigationTitle(...)` | 6 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.navigationTransition(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.navigationViewStyle(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 7+, visionOS 1+ | Deprecated | replace styled NavigationView with NavigationStack or NavigationSplitView instead |
| `.offset(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+, macCatalyst 13+ | Current | - |
| `.onAppear(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+ | Deprecated | obsolete |
| `.onChange(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | Use `onChange` with a two or zero parameter action closure instead.; Some overloads deprecated |
| `.onCommand(...)` | 1 | macOS 10.15+ | Current | - |
| `.onContinueUserActivity(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.onContinuousHover(...)` | 2 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+ | Current | use overload that accepts a CoordinateSpaceProtocol instead; Some overloads deprecated |
| `.onCopyCommand(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.onCutCommand(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.onDeleteCommand(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.onDisappear(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.onDrag(...)` | 2 | iOS 13.4+, macOS 10.15+ | Current | - |
| `.onDrop(...)` | 6 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | Provide `UTType`s as the `supportedContentTypes` instead.; Some overloads deprecated |
| `.onExitCommand(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.onGeometryChange(...)` | 2 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.onHover(...)` | 1 | iOS 13.4+, macOS 10.15+ | Current | - |
| `.onKeyPress(...)` | 5 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.onLongPressGesture(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | Renamed to `onLongPressGesture(minimumDuration:maximumDuration:perform:onPressingChanged:)`; Some overloads deprecated |
| `.onLongTouchGesture(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 6+ | Current | - |
| `.onModifierKeysChanged(...)` | 1 | macOS 15+ | Current | - |
| `.onMoveCommand(...)` | 1 | iOS 18+, macOS 10.15+, tvOS 13+, watchOS 9+, visionOS 2+ | Current | - |
| `.onOpenURL(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.onPasteCommand(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | Provide `UTType`s as the `supportedContentTypes` instead.; Some overloads deprecated |
| `.onPencilDoubleTap(...)` | 1 | iOS 17.5+, macOS 14.5+ | Current | - |
| `.onPencilSqueeze(...)` | 1 | iOS 17.5+, macOS 14.5+ | Current | - |
| `.onPlayPauseCommand(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.onPreferenceChange(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.onReceive(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.onScrollGeometryChange(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.onScrollPhaseChange(...)` | 2 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.onScrollTargetVisibilityChange(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.onScrollVisibilityChange(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.onSubmit(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 2+ | Current | - |
| `.onTapGesture(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 16+, watchOS 6+, visionOS 1+ | Current | use overload that accepts a CoordinateSpaceProtocol instead; Some overloads deprecated |
| `.onVolumeViewpointChange(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+, visionOS 2+ | Current | - |
| `.onWorldRecenter(...)` | 1 | iOS 14.5+, macOS 11+, tvOS 14.5+, watchOS 7.4+ | Current | - |
| `.opacity(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+ | Current | - |
| `.ornament(...)` | 1 | iOS 16.1+, macOS 13+, tvOS 16.1+, watchOS 9.1+, visionOS 1+ | Current | - |
| `.overlay(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | Use `overlay(alignment:content:)` instead.; Some overloads deprecated |
| `.overlayPreferenceValue(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.padding(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.pageCommand(...)` | 1 | tvOS 14.3+ | Current | - |
| `.paletteSelectionEffect(...)` | 1 | iOS 17+, macOS 14+, tvOS 14+, watchOS 7+, visionOS 2+ | Current | - |
| `.pasteDestination(...)` | 1 | macOS 13+ | Current | - |
| `.persistentSystemOverlays(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.phaseAnimator(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.pickerStyle(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+ | Current | - |
| `.pointerVisibility(...)` | 1 | macOS 15+ | Current | - |
| `.popover(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+ | Current | - |
| `.position(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.preference(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.preferredColorScheme(...)` | 1 | iOS 13+, macOS 11+, tvOS 13+, watchOS 6+ | Current | - |
| `.prefersDefaultFocus(...)` | 1 | iOS 17+, macOS 12+, tvOS 14+, watchOS 7+ | Current | - |
| `.presentationBackground(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.presentationBackgroundInteraction(...)` | 1 | iOS 16.4+, macOS 13.3+, tvOS 16.4+, watchOS 9.4+ | Current | - |
| `.presentationCompactAdaptation(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.presentationContentInteraction(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.presentationCornerRadius(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.presentationDetents(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.presentationDragIndicator(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.presentationSizing(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.presentedWindowStyle(...)` | 1 | iOS 13+, macOS 11+, tvOS 15+, watchOS 6+, visionOS 1+ | Current | - |
| `.presentedWindowToolbarStyle(...)` | 1 | iOS 16+, macOS 11+, watchOS 9+ | Current | - |
| `.previewContext(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `.previewDevice(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.previewDisplayName(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.previewInterfaceOrientation(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.previewLayout(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.privacySensitive(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.progressViewStyle(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `.projectionEffect(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+ | Current | - |
| `.redacted(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `.refreshable(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 2+ | Current | - |
| `.renameAction(...)` | 2 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.replaceDisabled(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.rotation3DEffect(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.rotationEffect(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+ | Current | - |
| `.safeAreaInset(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+, macCatalyst 13+ | Current | - |
| `.safeAreaPadding(...)` | 3 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `.saturation(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+ | Current | - |
| `.scaledToFill(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.scaledToFit(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.scaleEffect(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.scenePadding(...)` | 2 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.scrollBounceBehavior(...)` | 1 | iOS 16.4+, macOS 13.3+, tvOS 16.4+, watchOS 9.4+ | Current | - |
| `.scrollClipDisabled(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `.scrollContentBackground(...)` | 1 | iOS 16+, macOS 13+, watchOS 9+ | Current | - |
| `.scrollDisabled(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.scrollDismissesKeyboard(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.scrollIndicators(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.scrollIndicatorsFlash(...)` | 2 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `.scrollInputBehavior(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.scrollPosition(...)` | 2 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 2+ | Current | - |
| `.scrollTargetBehavior(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 2+ | Current | - |
| `.scrollTargetLayout(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `.scrollTransition(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.searchable(...)` | 35 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | Use the searchable modifier with the searchSuggestions modifier; Some overloads deprecated |
| `.searchCompletion(...)` | 2 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.searchDictationBehavior(...)` | 1 | iOS 17+, visionOS 1+ | Current | - |
| `.searchFocused(...)` | 2 | iOS 18+, macOS 15+, tvOS 16+, watchOS 9+, visionOS 2+ | Current | - |
| `.searchPresentationToolbarBehavior(...)` | 1 | iOS 17.1+, macOS 14.1+, tvOS 17.1+, watchOS 10.1+ | Current | - |
| `.searchScopes(...)` | 2 | iOS 16+, macOS 13+, tvOS 16.4+, watchOS 7+ | Current | - |
| `.searchSuggestions(...)` | 2 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.sectionActions(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.selectionDisabled(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+ | Current | - |
| `.sensoryFeedback(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.shadow(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.sheet(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.simultaneousGesture(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.sliderThumbVisibility(...)` | 1 | tvOS 18+ | Current | - |
| `.speechAdjustedPitch(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.speechAlwaysIncludesPunctuation(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.speechAnnouncementsQueued(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.speechSpellsOutCharacters(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.springLoadingBehavior(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `.statusBar(...)` | 1 | iOS 13+, visionOS 1+ | Deprecated | Renamed to `statusBarHidden(_:)` |
| `.statusBarHidden(...)` | 1 | iOS 13+, visionOS 2+ | Current | - |
| `.strikethrough(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.submitLabel(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 1+ | Current | - |
| `.submitScope(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.supportedVolumeViewpoints(...)` | 1 | iOS 16+, macOS 13+, tvOS 15+, watchOS 7+, visionOS 2+ | Current | - |
| `.swipeActions(...)` | 1 | iOS 15+, macOS 12+, tvOS 14+, watchOS 8+ | Current | - |
| `.symbolEffect(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.symbolEffectsRemoved(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 2+ | Current | - |
| `.symbolRenderingMode(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 2+, macCatalyst 15+ | Current | - |
| `.symbolVariant(...)` | 1 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.tabItem(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 7+ | Deprecated | Use `Tab(title:image:value:content:)` and related initializers instead |
| `.tableColumnHeaders(...)` | 1 | iOS 17+, macOS 14+, tvOS 14+, watchOS 7+ | Current | - |
| `.tableStyle(...)` | 1 | iOS 16+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.tabViewBottomAccessory(...)` | 1 | macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.tabViewCustomization(...)` | 1 | iOS 18+, macOS 15+, visionOS 2+ | Current | - |
| `.tabViewSearchActivation(...)` | 1 | tvOS 16+, watchOS 9+, visionOS 2+ | Current | - |
| `.tabViewSidebarBottomBar(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.tabViewSidebarFooter(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.tabViewSidebarHeader(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.tabViewStyle(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `.tag(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 2+ | Current | - |
| `.task(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.textCase(...)` | 1 | iOS 14+, macOS 11+, tvOS 14+, watchOS 7+ | Current | - |
| `.textContentType(...)` | 1 | iOS 13+, tvOS 13+ | Current | - |
| `.textEditorStyle(...)` | 1 | iOS 17+, macOS 14+, tvOS 13+, watchOS 6+, visionOS 1+ | Current | - |
| `.textFieldStyle(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.textInputAutocapitalization(...)` | 1 | iOS 15+, tvOS 15+, watchOS 8+ | Current | - |
| `.textInputCompletion(...)` | 1 | iOS 14+, macOS 15+, tvOS 16.4+, watchOS 9.4+ | Deprecated | Use `BorderedButtonMenuStyle` instead. |
| `.textInputSuggestions(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.textRenderer(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.textScale(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `.textSelection(...)` | 1 | iOS 15+, macOS 12+, tvOS 16+, watchOS 9+, visionOS 2+ | Current | - |
| `.textSelectionAffinity(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.tint(...)` | 2 | iOS 15+, macOS 12+, tvOS 15+, watchOS 8+ | Current | - |
| `.toggleStyle(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.toolbar(...)` | 5 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | Renamed to `toolbarVisibility(_:for:)`; Some overloads deprecated |
| `.toolbarBackground(...)` | 2 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 2+ | Current | Renamed to `toolbarBackgroundVisibility(_:for:)`; Some overloads deprecated |
| `.toolbarBackgroundVisibility(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.toolbarColorScheme(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.toolbarForegroundStyle(...)` | 1 | watchOS 9+ | Current | - |
| `.toolbarItemHidden(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.toolbarRole(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Deprecated | Use the `menu` style instead. |
| `.toolbarTitleDisplayMode(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 2+ | Current | - |
| `.toolbarTitleMenu(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.toolbarVisibility(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Current | - |
| `.touchBar(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.touchBarCustomizationLabel(...)` | 1 | macOS 10.15+ | Current | - |
| `.touchBarItemPresence(...)` | 1 | iOS 13+, macOS 10.15+, watchOS 10+ | Current | - |
| `.touchBarItemPrincipal(...)` | 1 | macOS 10.15+ | Current | - |
| `.tracking(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.transaction(...)` | 3 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.transformAnchorPreference(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.transformEffect(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.transformEnvironment(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.transformPreference(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.transition(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |
| `.truncationMode(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.typeSelectEquivalent(...)` | 4 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | Use `HierarchicalShapeStyle` instead.; Some overloads deprecated |
| `.typesettingLanguage(...)` | 2 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `.underline(...)` | 1 | iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ | Current | - |
| `.unredacted(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+ | Current | - |
| `.userActivity(...)` | 2 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.visualEffect(...)` | 1 | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ | Current | - |
| `.windowDismissBehavior(...)` | 1 | iOS 16+, macOS 15+, tvOS 16+ | Current | - |
| `.windowFullScreenBehavior(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.windowMinimizeBehavior(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.windowResizeAnchor(...)` | 1 | iOS 14+, tvOS 13+, watchOS 6+ | Deprecated | Use .menuStyle(.button) and .buttonStyle(.bordered). |
| `.windowResizeBehavior(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+, macCatalyst 13+ | Current | - |
| `.windowToolbarFullScreenVisibility(...)` | 1 | iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+ | Deprecated | Use `contextMenu(menuItems:)` instead. |
| `.writingToolsBehavior(...)` | 1 | iOS 18+, macOS 15+ | Current | - |
| `.zIndex(...)` | 1 | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ | Current | - |

