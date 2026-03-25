# SwiftUI 2025 Comprehensive Reference

Complete catalog of SwiftUI Views and Modifiers as of 2025 (through iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2), with platform availability and deprecation status.

Sources: [Apple Developer Documentation](https://developer.apple.com/documentation/swiftui), [Hacking with Swift](https://www.hackingwithswift.com/swiftui)

---

# Part 1: Views

## 1. Text Views

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **Text** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **Label** | iOS 14 | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | No |
| **TextField** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **SecureField** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **TextEditor** | iOS 14 | iOS, macOS 11, visionOS 1 | No |

## 2. Controls

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **Button** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **Toggle** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **Slider** | iOS 13 | iOS, macOS 10.15, watchOS 6, visionOS 1 | No |
| **Stepper** | iOS 13 | iOS, macOS 10.15, watchOS 9, visionOS 1 | No |
| **Picker** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **DatePicker** | iOS 13 | iOS, macOS 10.15, watchOS 10, visionOS 1 | No |
| **MultiDatePicker** | iOS 16 | iOS, visionOS 1 | No |
| **ColorPicker** | iOS 14 | iOS, macOS 11, visionOS 1 | No |
| **EditButton** | iOS 13 | iOS, visionOS 1 | No |
| **PasteButton** | iOS 16 | iOS, macOS 10.15, visionOS 1 | No |
| **RenameButton** | iOS 16 | iOS, macOS 13, tvOS 16, visionOS 1 | No |
| **ShareLink** | iOS 16 | iOS, macOS 13, watchOS 9, visionOS 1 | No |
| **Link** | iOS 14 | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | No |
| **Menu** | iOS 14 | iOS, macOS 11, tvOS 17, visionOS 1 | No |
| **ControlGroup** | iOS 15 | iOS, macOS 12, tvOS 17, visionOS 1 | No |
| **ContactAccessButton** | iOS 18 | iOS, visionOS 2 | No |

## 3. Indicators

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **ProgressView** | iOS 14 | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | No |
| **Gauge** | iOS 16 | iOS, macOS 13, watchOS 7, visionOS 1 | No |

## 4. Images & Media

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **Image** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **AsyncImage** | iOS 15 | iOS, macOS 12, watchOS 8, tvOS 15, visionOS 1 | No |
| **VideoPlayer** | iOS 14 | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 (AVKit) | No |
| **SpriteView** | iOS 14 | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 (SpriteKit) | No |
| **PhotosPicker** | iOS 16 | iOS, macOS 13, watchOS 9, visionOS 1 (PhotosUI) | No |

## 5. Layout Containers

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **VStack** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **HStack** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **ZStack** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **LazyVStack** | iOS 14 | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | No |
| **LazyHStack** | iOS 14 | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | No |
| **LazyVGrid** | iOS 14 | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | No |
| **LazyHGrid** | iOS 14 | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | No |
| **Grid** | iOS 16 | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | No |
| **GridRow** | iOS 16 | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | No |
| **Spacer** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **Divider** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **GeometryReader** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **ViewThatFits** | iOS 16 | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | No |
| **ScrollViewReader** | iOS 14 | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | No |
| **ContentUnavailableView** | iOS 17 | iOS, macOS 14, watchOS 10, tvOS 17, visionOS 1 | No |

## 6. Collection Views

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **List** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **ScrollView** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **Form** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **Table** | iOS 16 | iOS, macOS 12, visionOS 1 | No |
| **ForEach** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **Section** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |

## 7. Grouping & Disclosure

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **Group** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **GroupBox** | iOS 14 | iOS, macOS 10.15, visionOS 1 | No |
| **DisclosureGroup** | iOS 14 | iOS, macOS 11, visionOS 1 | No |
| **OutlineGroup** | iOS 14 | iOS, macOS 11, visionOS 1 | No |
| **LabeledContent** | iOS 16 | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | No |

## 8. Navigation

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **NavigationView** | iOS 13 | iOS, macOS 10.15, watchOS 7, tvOS 13, visionOS 1 | **Yes** (iOS 16) — use NavigationStack/NavigationSplitView |
| **NavigationStack** | iOS 16 | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | No |
| **NavigationSplitView** | iOS 16 | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | No |
| **NavigationLink** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **NavigationPath** | iOS 16 | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | No (type) |
| **TabView** | iOS 13 | iOS, macOS 10.15, watchOS 7, tvOS 13, visionOS 1 | No |
| **Tab** | iOS 18 | iOS, macOS 15, watchOS 11, tvOS 18, visionOS 2 | No |

## 9. Presentation

| View/Modifier | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **.sheet()** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **.fullScreenCover()** | iOS 14 | iOS, watchOS 7, tvOS 14, visionOS 1 | No |
| **.alert()** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **.confirmationDialog()** | iOS 15 | iOS, macOS 12, watchOS 8, tvOS 15, visionOS 1 | No |
| **.popover()** | iOS 13 | iOS, macOS 10.15, visionOS 1 | No |
| **.inspector()** | iOS 17 | iOS, macOS 14, visionOS 1 | No |
| **ActionSheet** | iOS 13 | iOS, tvOS 13 | **Yes** (iOS 15) — use .confirmationDialog |

## 10. Drawing & Graphics

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **Canvas** | iOS 15 | iOS, macOS 12, watchOS 8, tvOS 15, visionOS 1 | No |
| **Path** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **Color** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **MeshGradient** | iOS 18 | iOS, macOS 15, watchOS 11, tvOS 18, visionOS 2 | No |
| **LinearGradient** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **RadialGradient** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **AngularGradient** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **EllipticalGradient** | iOS 15 | iOS, macOS 12, watchOS 8, tvOS 15, visionOS 1 | No |
| **ContainerRelativeShape** | iOS 14 | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | No |
| **TimelineView** | iOS 15 | iOS, macOS 12, watchOS 8, tvOS 15, visionOS 1 | No |

## 11. Shapes

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **Rectangle** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **RoundedRectangle** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **UnevenRoundedRectangle** | iOS 17 | iOS, macOS 14, watchOS 10, tvOS 17, visionOS 1 | No |
| **Circle** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **Ellipse** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **Capsule** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |

## 12. Structural / Utility Views

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **AnyView** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **EmptyView** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **EquatableView** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **TupleView** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |
| **SubscriptionView** | iOS 13 | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | No |

## 13. Map & Location

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **Map** | iOS 14 (redesigned iOS 17) | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 (MapKit) | No |
| **LocationButton** | iOS 15 | iOS, macOS 12, watchOS 8 (CoreLocationUI) | No |

## 14. Scenes

| Type | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **WindowGroup** | iOS 14 | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | No |
| **Window** | macOS 13 | macOS | No |
| **DocumentGroup** | iOS 14 | iOS, macOS 11, visionOS 1 | No |
| **Settings** | macOS 11 | macOS | No |

## 15. visionOS-Specific Views

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **RealityView** | visionOS 1 | visionOS (RealityKit) | No |
| **Model3D** | visionOS 1 | visionOS (RealityKit) | No |
| **ImmersiveSpace** (Scene) | visionOS 1 | visionOS | No |
| **Volume** (WindowStyle) | visionOS 1 | visionOS | No |

## 16. StoreKit Views

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **StoreView** | iOS 17 | iOS, macOS 14, watchOS 10, tvOS 17, visionOS 1 | No |
| **ProductView** | iOS 17 | iOS, macOS 14, watchOS 10, tvOS 17, visionOS 1 | No |
| **SubscriptionStoreView** | iOS 17 | iOS, macOS 14, watchOS 10, tvOS 17, visionOS 1 | No |

## 17. Auth Views

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **SignInWithAppleButton** | iOS 14 | iOS, macOS 11, watchOS 7, tvOS 14 (AuthenticationServices) | No |

## 18. WWDC25 (iOS 26 / macOS 26)

| View | Introduced | Availability | Deprecated |
|------|-----------|-------------|------------|
| **WebView** | iOS 26 | iOS, macOS 26, visionOS 26 (WebKit) | No |

---

## Deprecated Views Summary

| Deprecated View | Replacement | Since |
|----------------|------------|-------|
| **NavigationView** | NavigationStack / NavigationSplitView | iOS 16 |
| **ActionSheet** | .confirmationDialog() | iOS 15 |
| **NavigationViewStyle** | NavigationStack / NavigationSplitView styles | iOS 16 |

## Views by Release

| Release | New Views |
|---------|-----------|
| **iOS 13 (2019)** | Text, TextField, SecureField, Button, Toggle, Slider, Stepper, Picker, DatePicker, Image, Color, List, ScrollView, Form, VStack, HStack, ZStack, NavigationView, NavigationLink, TabView, Spacer, Divider, Section, ForEach, Group, GeometryReader, Path, Rectangle, RoundedRectangle, Circle, Ellipse, Capsule, LinearGradient, RadialGradient, AngularGradient, AnyView, EmptyView |
| **iOS 14 (2020)** | Label, TextEditor, ColorPicker, ProgressView, Link, LazyVStack, LazyHStack, LazyVGrid, LazyHGrid, DisclosureGroup, OutlineGroup, GroupBox, ScrollViewReader, Map, VideoPlayer, SpriteView, ContainerRelativeShape, SignInWithAppleButton, WindowGroup, DocumentGroup |
| **iOS 15 (2021)** | AsyncImage, Canvas, TimelineView, ControlGroup, LocationButton, EllipticalGradient |
| **iOS 16 (2022)** | NavigationStack, NavigationSplitView, NavigationPath, Grid, GridRow, Table, ViewThatFits, MultiDatePicker, ShareLink, PasteButton, RenameButton, LabeledContent, Gauge, PhotosPicker |
| **iOS 17 (2023)** | ContentUnavailableView, UnevenRoundedRectangle, StoreView, ProductView, SubscriptionStoreView |
| **iOS 18 (2024)** | Tab, MeshGradient, ContactAccessButton |
| **iOS 26 / WWDC25** | WebView |

---

# Part 2: Modifiers

## 1. Layout Modifiers (~43)

### Size

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `frame(width:height:alignment:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `frame(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:alignment:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `frame(depth:alignment:)` | visionOS 1 | 3D layout |
| `fixedSize()` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `fixedSize(horizontal:vertical:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `layoutPriority(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `containerRelativeFrame(_:alignment:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |

### Position

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `position(_:)` / `position(x:y:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `offset(_:)` / `offset(x:y:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `offset(z:)` | visionOS 1 | 3D offset |
| `coordinateSpace(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Replaces deprecated `coordinateSpace(name:)` |
| `alignmentGuide(_:computeValue:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |

### Padding and Spacing

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `padding(_:)` / `padding(_:_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `padding3D(_:)` | visionOS 1 | 3D padding |
| `scenePadding(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `listRowInsets(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `listRowSpacing(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `listSectionSpacing(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |

### Grid Configuration

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `gridCellColumns(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `gridCellAnchor(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `gridCellUnsizedAxes(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `gridColumnAlignment(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |

### Safe Area and Margins

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `ignoresSafeArea(_:edges:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `safeAreaInset(edge:alignment:spacing:content:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `safeAreaPadding(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `contentMargins(_:for:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |

### Layer Order

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `zIndex(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `layoutDirectionBehavior(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | |
| `layoutValue(key:value:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Custom Layout |

---

## 2. Appearance Modifiers (~81)

### Colors and Styles

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `foregroundStyle(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Replaces deprecated foregroundColor |
| `foregroundStyle(_:_:)` / `foregroundStyle(_:_:_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Multi-level hierarchy |
| `backgroundStyle(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `tint(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Replaces deprecated accentColor |
| `preferredColorScheme(_:)` | iOS 13 / macOS 11 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `allowedDynamicRange(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17, HDR |

### Borders, Overlay, Background

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `border(_:width:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `overlay(alignment:content:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Modern API |
| `overlay(_:in:fillStyle:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Shape-based |
| `background(alignment:content:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Modern API |
| `background(_:in:fillStyle:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Shape-based |
| `listRowBackground(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `scrollContentBackground(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `containerBackground(_:for:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `alternatingRowBackgrounds(_:)` | macOS 14 | macOS-only |
| `glassBackgroundEffect(displayMode:)` | visionOS 1 | visionOS-only |

### Control Configuration

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `controlSize(_:)` | iOS 15 / macOS 10.15 / watchOS 9 / visionOS 1 | |
| `buttonBorderShape(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `buttonRepeatBehavior(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `headerProminence(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `menuOrder(_:)` | iOS 16 / macOS 13 / tvOS 16 / visionOS 1 | |

### Scroll Configuration

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `scrollDisabled(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `scrollBounceBehavior(_:axes:)` | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | |
| `scrollIndicators(_:axes:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `scrollClipDisabled(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |

### Symbol Effects

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `symbolEffect(_:options:isActive:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `symbolEffectsRemoved(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | |

### Privacy and Redaction

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `privacySensitive(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `redacted(reason:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `unredacted()` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `invalidatableContent(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |

### Visibility

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `hidden()` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `labelsHidden()` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `listRowSeparator(_:edges:)` | iOS 15 / macOS 13 / visionOS 1 | |
| `listSectionSeparator(_:edges:)` | iOS 15 / macOS 13 / visionOS 1 | |
| `persistentSystemOverlays(_:)` | iOS 16 / macOS 13 / tvOS 16 / visionOS 1 | |

### Sensory Feedback

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `sensoryFeedback(_:trigger:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 | New iOS 17 |

### Window Behaviors (macOS 15)

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `windowDismissBehavior(_:)` | macOS 15 / visionOS 2 | New macOS 15 |
| `windowFullScreenBehavior(_:)` | macOS 15 | New macOS 15 |
| `windowMinimizeBehavior(_:)` | macOS 15 | New macOS 15 |
| `windowResizeBehavior(_:)` | macOS 15 | New macOS 15 |

---

## 3. Text and Symbol Modifiers (~50)

### Fonts

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `font(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `dynamicTypeSize(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |

### Text Style

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `bold(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `italic(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `fontDesign(_:)` | iOS 16.1 / macOS 13 / watchOS 9.1 / tvOS 16.1 / visionOS 1 | |
| `fontWeight(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `fontWidth(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `monospaced(_:)` | iOS 15.4 / macOS 12.3 / watchOS 8.5 / tvOS 15.4 / visionOS 1 | |
| `monospacedDigit()` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `strikethrough(_:pattern:color:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `underline(_:pattern:color:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `textCase(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `textScale(_:isEnabled:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |

### Text Layout

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `allowsTightening(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `baselineOffset(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `kerning(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `minimumScaleFactor(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `tracking(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `truncationMode(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `typesettingLanguage(_:isEnabled:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `lineLimit(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `lineLimit(_:reservesSpace:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `lineSpacing(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `multilineTextAlignment(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |

### Text Entry

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `textSelection(_:)` | iOS 15 / macOS 12 / visionOS 1 | |
| `autocorrectionDisabled(_:)` | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | |
| `keyboardType(_:)` | iOS 13 / visionOS 1 | iOS/visionOS-only |
| `scrollDismissesKeyboard(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `textInputAutocapitalization(_:)` | iOS 15 / tvOS 15 / visionOS 1 | |
| `textInputSuggestions(_:)` | iOS 18 / macOS 15 / visionOS 2 | New iOS 18 |
| `textContentType(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `submitLabel(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |

### Find and Replace

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `findNavigator(isPresented:)` | iOS 16 / macOS 13 / visionOS 1 | |
| `findDisabled(_:)` | iOS 16 / macOS 13 / visionOS 1 | |
| `replaceDisabled(_:)` | iOS 16 / macOS 13 / visionOS 1 | |

### Symbol Appearance

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `symbolRenderingMode(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `symbolVariant(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `imageScale(_:)` | iOS 13 / macOS 11 / watchOS 6 / tvOS 13 / visionOS 1 | |

---

## 4. Style Modifiers (~21)

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `buttonStyle(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `datePickerStyle(_:)` | iOS 13 / macOS 10.15 / watchOS 10 / visionOS 1 | |
| `menuStyle(_:)` | iOS 16 / macOS 13 / tvOS 17 / visionOS 1 | |
| `pickerStyle(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `toggleStyle(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `gaugeStyle(_:)` | iOS 16 / macOS 13 / watchOS 7 / visionOS 1 | |
| `progressViewStyle(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `labelStyle(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `textFieldStyle(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `textEditorStyle(_:)` | iOS 17 / macOS 14 / visionOS 1 | New iOS 17 |
| `listStyle(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `tableStyle(_:)` | iOS 16 / macOS 12 / visionOS 1 | |
| `disclosureGroupStyle(_:)` | iOS 16 / macOS 13 / visionOS 1 | |
| `navigationSplitViewStyle(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `tabViewStyle(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `controlGroupStyle(_:)` | iOS 15 / macOS 12 / tvOS 17 / visionOS 1 | |
| `groupBoxStyle(_:)` | iOS 14 / macOS 11 / visionOS 1 | |
| `indexViewStyle(_:)` | iOS 14 / watchOS 8 / tvOS 14 / visionOS 1 | |
| `presentedWindowStyle(_:)` | macOS 13 / visionOS 1 | |
| `formStyle(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |

---

## 5. Graphics and Rendering Modifiers (~53)

### Masks and Clipping

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `mask(alignment:_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `clipped(antialiased:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `clipShape(_:style:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `containerShape(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |

### Scale and Aspect Ratio

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `scaledToFill()` / `scaledToFit()` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `scaleEffect(_:anchor:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `scaleEffect(x:y:z:anchor:)` | visionOS 1 | 3D scale |
| `aspectRatio(_:contentMode:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |

### Rotation and Transformation

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `rotationEffect(_:anchor:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `rotation3DEffect(_:axis:anchor:anchorZ:perspective:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `perspectiveRotationEffect(...)` | visionOS 1 | visionOS-only |
| `projectionEffect(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `transformEffect(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `transform3DEffect(_:)` | visionOS 1 | visionOS-only |

### Graphical Effects

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `blur(radius:opaque:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `opacity(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `brightness(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `contrast(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `colorInvert()` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `colorMultiply(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `saturation(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `grayscale(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `hueRotation(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `luminanceToAlpha()` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `shadow(color:radius:x:y:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `visualEffect(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |

### Metal Shaders

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `colorEffect(_:isEnabled:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `distortionEffect(_:maxSampleOffset:isEnabled:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `layerEffect(_:maxSampleOffset:isEnabled:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |

### Composites

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `blendMode(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `compositingGroup()` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `drawingGroup(opaque:colorMode:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |

### Animation

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `animation(_:value:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Preferred |
| `animation(_:body:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Scoped |
| `keyframeAnimator(initialValue:repeating:content:keyframes:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `phaseAnimator(_:content:animation:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `contentTransition(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `transition(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `matchedGeometryEffect(id:in:...)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `geometryGroup()` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `transaction(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `withAnimation(_:_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Top-level function |
| `withAnimation(_:completionCriteria:_:completion:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Completion callback |

---

## 6. Navigation and Auxiliary Modifiers (~48)

### Navigation

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `navigationTitle(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `navigationSubtitle(_:)` | macOS 11 / visionOS 1 | macOS/visionOS |
| `navigationDocument(_:)` | iOS 16 / macOS 13 / visionOS 1 | |
| `navigationBarBackButtonHidden(_:)` | iOS 13 / macOS 13 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `navigationBarTitleDisplayMode(_:)` | iOS 14 / watchOS 8 / visionOS 1 | |
| `navigationDestination(for:destination:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `navigationDestination(isPresented:destination:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `navigationDestination(item:destination:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `navigationSplitViewColumnWidth(_:)` | iOS 16 / macOS 13 / visionOS 1 | |

### Tab Views (iOS 18)

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `tabViewCustomization(_:)` | iOS 18 / macOS 15 / tvOS 18 / visionOS 2 | New iOS 18 |
| `tabViewSidebarHeader(content:)` | iOS 18 / macOS 15 / visionOS 2 | New iOS 18 |
| `tabViewSidebarFooter(content:)` | iOS 18 / macOS 15 / visionOS 2 | New iOS 18 |
| `sectionActions(content:)` | iOS 18 / macOS 15 / visionOS 2 | New iOS 18 |

### Toolbars

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `toolbar(content:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `toolbar(id:content:)` | iOS 16 / macOS 13 / visionOS 1 | Customizable |
| `toolbar(_:for:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | Visibility |
| `toolbar(removing:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `toolbarVisibility(_:for:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |
| `toolbarBackground(_:for:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `toolbarBackgroundVisibility(_:for:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |
| `toolbarForegroundStyle(_:for:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |
| `toolbarColorScheme(_:for:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `toolbarRole(_:)` | iOS 16 / macOS 13 / visionOS 1 | |
| `toolbarTitleMenu(content:)` | iOS 16 / macOS 13 / visionOS 1 | |
| `toolbarTitleDisplayMode(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |

### Context Menus

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `contextMenu(menuItems:)` | iOS 13 / macOS 10.15 / watchOS 6.2 / tvOS 14 / visionOS 1 | |
| `contextMenu(menuItems:preview:)` | iOS 16 / macOS 13 / tvOS 16 / visionOS 1 | |
| `contextMenu(forSelectionType:menu:primaryAction:)` | iOS 16 / macOS 13 / visionOS 1 | |

### Badges and Help

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `badge(_:)` | iOS 15 / macOS 12 / visionOS 1 | |
| `badgeProminence(_:)` | iOS 17 / macOS 14 / visionOS 1 | New iOS 17 |
| `help(_:)` | iOS 15.4 / macOS 11 / watchOS 8 / tvOS 15 / visionOS 1 | |

---

## 7. Presentation Modifiers (~97)

### Alerts

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `alert(_:isPresented:actions:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Multiple overloads |
| `alert(_:isPresented:actions:message:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | With message |
| `alert(isPresented:error:actions:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Error-based |

### Confirmation Dialogs

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `confirmationDialog(_:isPresented:titleVisibility:actions:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Multiple overloads |
| `dismissalConfirmationDialog(_:shouldPresent:actions:)` | iOS 18 / macOS 15 / visionOS 2 | New iOS 18 |
| `dialogSeverity(_:)` | iOS 17 / macOS 13 / visionOS 1 | |
| `dialogSuppressionToggle(isSuppressed:)` | iOS 17 / macOS 14 / visionOS 1 | New iOS 17 |

### Sheets and Covers

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `sheet(isPresented:onDismiss:content:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `sheet(item:onDismiss:content:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `fullScreenCover(isPresented:onDismiss:content:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `fullScreenCover(item:onDismiss:content:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |

### Popovers

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `popover(isPresented:attachmentAnchor:arrowEdge:content:)` | iOS 13.4 / macOS 10.15 / visionOS 1 | |
| `popover(item:attachmentAnchor:arrowEdge:content:)` | iOS 13.4 / macOS 10.15 / visionOS 1 | |

### Presentation Configuration

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `interactiveDismissDisabled(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `presentationDetents(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `presentationDragIndicator(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `presentationBackground(_:)` | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | |
| `presentationBackgroundInteraction(_:)` | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | |
| `presentationCompactAdaptation(_:)` | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | |
| `presentationContentInteraction(_:)` | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | |
| `presentationCornerRadius(_:)` | iOS 16.4 / macOS 13.3 / watchOS 9.4 / tvOS 16.4 / visionOS 1 | |
| `presentationSizing(_:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |

### Inspectors

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `inspector(isPresented:content:)` | iOS 17 / macOS 14 / visionOS 1 | New iOS 17 |
| `inspectorColumnWidth(_:)` | iOS 17 / macOS 14 / visionOS 1 | |

### File Dialogs

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `fileExporter(isPresented:document:...)` | iOS 14 / macOS 11 / visionOS 1 | Multiple overloads |
| `fileImporter(isPresented:allowedContentTypes:...)` | iOS 14 / macOS 11 / visionOS 1 | |
| `fileMover(isPresented:file:...)` | iOS 14 / macOS 11 / visionOS 1 | |
| `fileDialogDefaultDirectory(_:)` | iOS 17 / macOS 14 / visionOS 1 | New iOS 17 |
| `fileDialogMessage(_:)` | iOS 17 / macOS 14 / visionOS 1 | New iOS 17 |

---

## 8. Input and Event Modifiers (~148)

### View Life Cycle

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `onAppear(perform:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `onDisappear(perform:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `task(priority:_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Async |
| `task(id:priority:_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Restartable |
| `onChange(of:initial:_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Replaces deprecated onChange(of:perform:) |
| `onReceive(_:perform:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | Combine |

### Interactivity

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `disabled(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |

### Taps and Gestures

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `onTapGesture(count:perform:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 16 / visionOS 1 | |
| `onTapGesture(count:coordinateSpace:perform:)` | iOS 17 / macOS 14 / watchOS 10 / visionOS 1 | New iOS 17 |
| `onLongPressGesture(...)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 14 / visionOS 1 | |
| `gesture(_:including:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `gesture(_:isEnabled:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |
| `gesture(_:name:isEnabled:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |
| `highPriorityGesture(_:including:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `highPriorityGesture(_:isEnabled:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |
| `simultaneousGesture(_:including:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `simultaneousGesture(_:isEnabled:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |
| `defersSystemGestures(on:)` | iOS 16 / macOS 13 / visionOS 1 | |

### Keyboard Input

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `onKeyPress(_:action:)` | iOS 17 / macOS 14 / tvOS 17 / visionOS 1 | New iOS 17 |
| `onKeyPress(characters:phases:action:)` | iOS 17 / macOS 14 / tvOS 17 / visionOS 1 | |
| `onModifierKeysChanged(mask:initial:_:)` | iOS 18 / macOS 15 / visionOS 2 | New iOS 18 |
| `keyboardShortcut(_:modifiers:)` | iOS 14 / macOS 11 / visionOS 1 | |
| `modifierKeyAlternate(_:_:)` | iOS 18 / macOS 15 / visionOS 2 | New iOS 18 |

### Hover and Pointer

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `onHover(perform:)` | iOS 13.4 / macOS 10.15 / tvOS 16 / visionOS 1 | |
| `onContinuousHover(coordinateSpace:perform:)` | iOS 16 / macOS 13 / tvOS 16 / visionOS 1 | |
| `hoverEffect(_:)` | iOS 13.4 / tvOS 16 / visionOS 1 | |
| `hoverEffect(_:isEnabled:)` | iOS 17 / tvOS 17 / visionOS 1 | |
| `defaultHoverEffect(_:)` | iOS 18 / tvOS 18 / visionOS 2 | New iOS 18 |
| `hoverEffectGroup()` | iOS 18 / tvOS 18 / visionOS 2 | New iOS 18 |
| `pointerVisibility(_:)` | iOS 18 / macOS 15 / visionOS 2 | New iOS 18 |
| `pointerStyle(_:)` | iOS 18 / macOS 15 / visionOS 2 | New iOS 18 |

### Scroll Controls

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `scrollPosition(id:anchor:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | |
| `scrollPosition(_:anchor:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18, ScrollPosition binding |
| `defaultScrollAnchor(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | |
| `scrollTargetBehavior(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `scrollTargetLayout(isEnabled:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | |
| `onScrollGeometryChange(for:of:action:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |
| `onScrollTargetVisibilityChange(...)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |
| `onScrollVisibilityChange(threshold:_:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |
| `onScrollPhaseChange(_:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |
| `scrollTransition(_:axis:transition:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | |

### Geometry

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `onGeometryChange(for:of:action:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18, modern GeometryReader replacement |

### Focus

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `focused(_:equals:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `focused(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `focusable(_:)` | iOS 17 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `focusable(_:interactions:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | |
| `focusSection()` | iOS 17 / macOS 14 / tvOS 15 / visionOS 1 | |
| `focusEffectDisabled(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | |
| `defaultFocus(_:_:priority:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `searchFocused(_:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |

### List Controls

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `swipeActions(edge:allowsFullSwipe:content:)` | iOS 15 / macOS 12 / watchOS 8 / visionOS 1 | |
| `refreshable(action:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `selectionDisabled(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | |

### Drag and Drop

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `draggable(_:)` | iOS 16 / macOS 13 / visionOS 1 | |
| `draggable(_:preview:)` | iOS 16 / macOS 13 / visionOS 1 | |
| `dropDestination(for:action:isTargeted:)` | iOS 16 / macOS 13 / visionOS 1 | |
| `onDrag(_:)` | iOS 13.4 / macOS 10.15 / visionOS 1 | |
| `onDrop(of:isTargeted:perform:)` | iOS 14 / macOS 11 / visionOS 1 | |

### Copy, Cut, Paste

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `copyable(_:)` | iOS 16 / macOS 13 / visionOS 1 | |
| `cuttable(for:action:)` | iOS 16 / macOS 13 / visionOS 1 | |
| `pasteDestination(for:action:validator:)` | iOS 16 / macOS 13 / visionOS 1 | |

### Submission

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `onSubmit(of:_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `submitScope(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |

### Content Shape

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `contentShape(_:eoFill:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `contentShape(_:_:eoFill:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | Kind-specific |
| `allowsHitTesting(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |

### User Activities and URLs

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `userActivity(_:element:_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `onContinueUserActivity(_:perform:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `onOpenURL(perform:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |

---

## 9. Search Modifiers (~16)

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `searchable(text:placement:prompt:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `searchable(text:isPresented:placement:prompt:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `searchable(text:tokens:placement:prompt:token:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `searchable(text:editableTokens:placement:prompt:token:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `searchSuggestions(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `searchSuggestions(_:for:)` | iOS 18 / macOS 15 / watchOS 11 / tvOS 18 / visionOS 2 | New iOS 18 |
| `searchCompletion(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `searchScopes(_:scopes:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `searchPresentationToolbarBehavior(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `searchDictationBehavior(_:)` | iOS 17 / watchOS 10 / visionOS 1 | New iOS 17 |

---

## 10. Accessibility Modifiers (~67)

### Labels, Values, Hints

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `accessibilityLabel(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `accessibilityLabel(_:isEnabled:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Conditional |
| `accessibilityValue(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `accessibilityHint(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `accessibilityInputLabels(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |

### Actions

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `accessibilityAction(_:_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `accessibilityActions(_:)` | iOS 16 / macOS 13 / watchOS 9 / tvOS 16 / visionOS 1 | |
| `accessibilityAdjustableAction(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `accessibilityScrollAction(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |

### Elements and Traits

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `accessibilityElement(children:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `accessibilityChildren(children:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `accessibilityHidden(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `accessibilityAddTraits(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `accessibilityRemoveTraits(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |
| `accessibilityIdentifier(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |

### Custom Content

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `accessibilityRepresentation(representation:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `accessibilityRespondsToUserInteraction(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | |
| `accessibilityCustomContent(_:_:importance:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |

### Rotors

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `accessibilityRotor(_:entries:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `accessibilityRotorEntry(id:in:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `accessibilitySortPriority(_:)` | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / visionOS 1 | |

### Focus

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `accessibilityFocused(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `accessibilityFocused(_:equals:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |

### VoiceOver Speech

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `speechAdjustedPitch(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `speechAlwaysIncludesPunctuation(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `speechAnnouncementsQueued(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |
| `speechSpellsOutCharacters(_:)` | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 / visionOS 1 | |

---

## 11. State and Environment Modifiers (~20)

### Identity

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `id(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `tag(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `equatable()` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |

### Environment

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `environment(_:_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | KeyPath + Value |
| `environment(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | Observable object |
| `environmentObject(_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | ObservableObject |
| `transformEnvironment(_:transform:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |

### Preferences

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `preference(key:value:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `transformPreference(_:_:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `onPreferenceChange(_:perform:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |
| `anchorPreference(key:value:transform:)` | iOS 13 / macOS 10.15 / watchOS 6 / tvOS 13 / visionOS 1 | |

### SwiftData

| Modifier | Availability | Notes |
|----------|-------------|-------|
| `modelContext(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |
| `modelContainer(_:)` | iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1 | New iOS 17 |

---

## 12. Deprecated Modifiers and Replacements (~52)

| Deprecated Modifier | Replacement | Since |
|---------------------|-------------|-------|
| `foregroundColor(_:)` | `foregroundStyle(_:)` | iOS 17 |
| `accentColor(_:)` | `tint(_:)` | iOS 17 |
| `cornerRadius(_:antialiased:)` | `clipShape(RoundedRectangle(...))` | iOS 17 |
| `animation(_:)` (no value) | `animation(_:value:)` or `withAnimation` | iOS 15 |
| `onChange(of:perform:)` | `onChange(of:initial:_:)` | iOS 17 |
| `background(_:alignment:)` | `background(alignment:content:)` | iOS 15 |
| `overlay(_:alignment:)` | `overlay(alignment:content:)` | iOS 15 |
| `mask(_:)` (ViewBuilder) | `mask(alignment:_:)` | iOS 15 |
| `edgesIgnoringSafeArea(_:)` | `ignoresSafeArea(_:edges:)` | iOS 14 |
| `coordinateSpace(name:)` | `coordinateSpace(_:)` | iOS 17 |
| `colorScheme(_:)` | `preferredColorScheme(_:)` | iOS 15 |
| `navigationBarTitle(_:)` | `navigationTitle(_:)` | iOS 14 |
| `navigationBarTitle(_:displayMode:)` | `navigationTitle` + `navigationBarTitleDisplayMode` | iOS 14 |
| `navigationBarItems(leading:trailing:)` | `toolbar(content:)` | iOS 14 |
| `navigationBarHidden(_:)` | `toolbar(.hidden, for: .navigationBar)` | iOS 16 |
| `navigationViewStyle(_:)` | `navigationSplitViewStyle(_:)` | iOS 16 |
| `statusBar(hidden:)` | `statusBarHidden(_:)` | iOS 16 |
| `actionSheet(isPresented:content:)` | `confirmationDialog(_:isPresented:actions:)` | iOS 15 |
| `alert(isPresented:content:)` (old) | `alert(_:isPresented:actions:)` | iOS 15 |
| `autocapitalization(_:)` | `textInputAutocapitalization(_:)` | iOS 15 |
| `disableAutocorrection(_:)` | `autocorrectionDisabled(_:)` | iOS 16.4 |
| `accessibility(label:)` | `accessibilityLabel(_:)` | iOS 14 |
| `accessibility(value:)` | `accessibilityValue(_:)` | iOS 14 |
| `accessibility(hidden:)` | `accessibilityHidden(_:)` | iOS 14 |
| `accessibility(identifier:)` | `accessibilityIdentifier(_:)` | iOS 14 |
| `accessibility(hint:)` | `accessibilityHint(_:)` | iOS 14 |
| `accessibility(addTraits:)` | `accessibilityAddTraits(_:)` | iOS 14 |
| `accessibility(removeTraits:)` | `accessibilityRemoveTraits(_:)` | iOS 14 |
| `accessibility(sortPriority:)` | `accessibilitySortPriority(_:)` | iOS 14 |
| `menuButtonStyle(_:)` | `menuStyle(_:)` | macOS 13 |

---

## Totals

| Category | Count (approx) |
|----------|---------------|
| **Views** | **~90** |
| Layout Modifiers | 43 |
| Appearance Modifiers | 81 |
| Text and Symbol Modifiers | 50 |
| Style Modifiers | 21 |
| Graphics and Rendering | 53 |
| Navigation and Auxiliary | 48 |
| Presentation Modifiers | 97 |
| Input and Event Modifiers | 148 |
| Search Modifiers | 16 |
| Accessibility Modifiers | 67 |
| State and Environment | 20 |
| **Total Modifiers (non-deprecated)** | **~644** |
| Deprecated Modifiers | ~52 |
| **Grand Total** | **~90 views + ~696 modifiers** |

---

## New by Release (Highlights)

### iOS 17 / macOS 14 (2023)
- Views: ContentUnavailableView, UnevenRoundedRectangle, StoreView, ProductView, SubscriptionStoreView
- Modifiers: containerRelativeFrame, scrollTargetBehavior, scrollPosition, contentMargins, inspector, keyframeAnimator, phaseAnimator, visualEffect, Metal shaders (colorEffect, distortionEffect, layerEffect), sensoryFeedback, symbolEffect, onKeyPress, onChange(of:initial:), textScale, typesettingLanguage, geometryGroup, dialogSuppressionToggle, scrollClipDisabled, textEditorStyle, modelContext/modelContainer (SwiftData)

### iOS 18 / macOS 15 (2024)
- Views: Tab, MeshGradient, ContactAccessButton
- Modifiers: onScrollGeometryChange, onScrollPhaseChange, onScrollVisibilityChange, onGeometryChange, presentationSizing, dismissalConfirmationDialog, tabViewCustomization, searchFocused, gesture(_:isEnabled:), onModifierKeysChanged, hoverEffectGroup, pointerVisibility, pointerStyle, toolbarVisibility, toolbarBackgroundVisibility, toolbarForegroundStyle, windowDismiss/FullScreen/Minimize/ResizeBehavior, textInputSuggestions, scrollPosition (ScrollPosition binding)

---

Sources:
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [View protocol](https://developer.apple.com/documentation/swiftui/view)
- [Layout modifiers](https://developer.apple.com/documentation/swiftui/view-layout)
- [Appearance modifiers](https://developer.apple.com/documentation/swiftui/view-appearance)
- [Text and symbol modifiers](https://developer.apple.com/documentation/swiftui/view-text-and-symbols)
- [Style modifiers](https://developer.apple.com/documentation/swiftui/view-style-modifiers)
- [Graphics and rendering](https://developer.apple.com/documentation/swiftui/view-graphics-and-rendering)
- [Input and event modifiers](https://developer.apple.com/documentation/swiftui/view-input-and-events)
- [Presentation modifiers](https://developer.apple.com/documentation/swiftui/view-presentation)
- [Search modifiers](https://developer.apple.com/documentation/swiftui/view-search)
- [Accessibility modifiers](https://developer.apple.com/documentation/swiftui/view-accessibility)
- [State modifiers](https://developer.apple.com/documentation/swiftui/view-state)
- [Deprecated modifiers](https://developer.apple.com/documentation/swiftui/view-deprecated)
- [What's new in SwiftUI - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10144/)
- [What's new in SwiftUI - WWDC23](https://developer.apple.com/videos/play/wwdc2023/10148/)
- [Hacking with Swift - SwiftUI](https://www.hackingwithswift.com/swiftui)
