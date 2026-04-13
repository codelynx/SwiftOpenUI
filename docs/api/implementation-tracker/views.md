# Views

Summary: 89 total, 54 implemented, 0 partial, 35 missing.

## Text Views

5 total, 5 implemented, 0 partial, 0 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `Label` | Both | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Label.swift` | GTK: icon+text; Win32/Web: text with icon placeholder |
| `SecureField` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/SecureField.swift` | GTK: PasswordEntry; Win32: EDIT+ES_PASSWORD; Web: password input |
| `Text` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Text.swift` | - |
| `TextEditor` | Both | iOS, macOS 11, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/TextEditor.swift` | GTK: TextView+ScrolledWindow; Win32: EDIT+ES_MULTILINE; Web: textarea |
| `TextField` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/TextField.swift` | Single-line; Binding<String> |

## Controls

16 total, 8 implemented, 0 partial, 8 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `Button` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Button.swift` | Generic Label view supported |
| `ColorPicker` | Both | iOS, macOS 11, visionOS 1 | Current | Missing | `-` | - |
| `ContactAccessButton` | Curated only | iOS, visionOS 2 | Current | Missing | `-` | - |
| `ControlGroup` | Both | iOS, macOS 12, tvOS 17, visionOS 1 | Current | Missing | `-` | - |
| `DatePicker` | Both | iOS, macOS 10.15, watchOS 10, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/DatePicker.swift` | GTK: GtkCalendar; Win32: SysDateTimePick32; Web: date input |
| `EditButton` | Both | iOS, visionOS 1 | Current | Missing | `-` | - |
| `Link` | Both | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Link.swift` | GTK: LinkButton; Win32: ShellExecuteW; Web: anchor tag |
| `Menu` | Both | iOS, macOS 11, tvOS 17, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Menu.swift` | GTK: GMenu+PopoverMenu; Win32: TrackPopupMenu; Web: dropdown div |
| `MultiDatePicker` | Both | iOS, visionOS 1 | Current | Missing | `-` | - |
| `PasteButton` | Both | iOS, macOS 10.15, visionOS 1 | Current | Missing | `-` | - |
| `Picker` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Picker.swift` | GTK: dropdown/segmented; Win32: ComboBox; Web: select |
| `RenameButton` | Both | iOS, macOS 13, tvOS 16, visionOS 1 | Current | Missing | `-` | - |
| `ShareLink` | Both | iOS, macOS 13, watchOS 9, visionOS 1 | Current | Missing | `-` | - |
| `Slider` | Both | iOS, macOS 10.15, watchOS 6, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Slider.swift` | Debounced on GTK4; container subclass on Win32; Web range input |
| `Stepper` | Both | iOS, macOS 10.15, watchOS 9, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Stepper.swift` | GTK: SpinButton; Win32: label+buttons; Web: -/+ buttons |
| `Toggle` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Toggle.swift` | GtkCheckButton / Win32 checkbox / Web checkbox |

## Indicators

2 total, 1 implemented, 0 partial, 1 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `Gauge` | Both | iOS, macOS 13, watchOS 7, visionOS 1 | Current | Missing | `-` | - |
| `ProgressView` | Both | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/ProgressView.swift` | GTK: GtkProgressBar; Win32: msctls_progress32; Web: progress element |

## Images & Media

5 total, 1 implemented, 0 partial, 4 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `AsyncImage` | Both | iOS, macOS 12, watchOS 8, tvOS 15, visionOS 1 | Current | Missing | `-` | - |
| `Image` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Image.swift` | GTK icon theme + file; Win32: WIC; Web: img tag (systemName as text placeholder) |
| `PhotosPicker` | Curated only | iOS, macOS 13, watchOS 9, visionOS 1 (PhotosUI) | Current | Missing | `-` | - |
| `SpriteView` | Curated only | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 (SpriteKit) | Current | Missing | `-` | - |
| `VideoPlayer` | Curated only | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 (AVKit) | Current | Missing | `-` | - |

## Layout Containers

15 total, 13 implemented, 0 partial, 2 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `ContentUnavailableView` | Both | iOS, macOS 14, watchOS 10, tvOS 17, visionOS 1 | Current | Missing | `-` | - |
| `Divider` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Spacer.swift` | - |
| `GeometryReader` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/GeometryReader.swift` | GTK: map+tick; Win32: parent rect; Web: ResizeObserver |
| `Grid` | Both | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Grid.swift` | GTK: GtkGrid; Win32: VStack of HStacks; Web: CSS grid |
| `GridRow` | Both | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/GridRow.swift` | MultiChildView, .gridCellColumns() span |
| `HStack` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Stacks.swift` | - |
| `LazyHGrid` | Both | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/LazyGrids.swift` | GTK: horizontal; Win32/Web: CSS grid |
| `LazyHStack` | Both | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/LazyStacks.swift` | GTK: horizontal; Win32/Web: non-virtualized |
| `LazyVGrid` | Both | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/LazyGrids.swift` | GTK: GtkGridView; Win32/Web: CSS grid, non-virtualized |
| `LazyVStack` | Both | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/LazyStacks.swift` | GTK: virtualized; Win32/Web: non-virtualized |
| `ScrollViewReader` | Both | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/ScrollViewReader.swift` | GTK: grab_focus auto-scroll; Win32: WM_VSCROLL; Web: scrollIntoView. Global ID registry with .id() modifier. |
| `Spacer` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Spacer.swift` | - |
| `ViewThatFits` | Both | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/ViewThatFits.swift` | Batch A fallback on Web: initial-mount first-fit selection with fallback-to-last, but no resize reevaluation yet. GTK: GtkStack + tick-driven remeasurement; Win32: WM_SIZE remeasurement. |
| `VStack` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Stacks.swift` | - |
| `ZStack` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Stacks.swift` | - |

## Collection Views

6 total, 5 implemented, 0 partial, 1 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `ForEach` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/ForEach.swift` | Identifiable, keyPath, Range |
| `Form` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Form.swift` | GTK: styled GtkBox; Win32: VStack+padding; Web: styled div |
| `List` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/ListView.swift` | Content-based; no selection yet |
| `ScrollView` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/ScrollView.swift` | Axis OptionSet; Web: CSS overflow |
| `Section` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Section.swift` | GTK: Pango header; Win32: header+divider; Web: h3+content |
| `Table` | Both | iOS, macOS 12, visionOS 1 | Current | Missing | `-` | - |

## Grouping & Disclosure

5 total, 3 implemented, 0 partial, 2 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `DisclosureGroup` | Both | iOS, macOS 11, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/DisclosureGroup.swift` | GTK: GtkExpander; Win32: toggle+show/hide; Web: details/summary |
| `Group` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Group.swift` | - |
| `GroupBox` | Both | iOS, macOS 10.15, visionOS 1 | Current | Missing | `-` | - |
| `LabeledContent` | Both | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | Current | Missing | `-` | - |
| `OutlineGroup` | Both | iOS, macOS 11, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/OutlineGroup.swift` | Hierarchical list view; GTK: recursive GtkExpander tree |

## Navigation

6 total, 5 implemented, 0 partial, 1 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `NavigationLink` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Navigation/NavigationLink.swift` | String and custom ViewBuilder labels |
| `NavigationSplitView` | Both | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/NavigationSplitView.swift` | - |
| `NavigationStack` | Both | iOS, macOS 13, watchOS 9, tvOS 16, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Navigation/NavigationStack.swift` | GtkStack / Win32 HWND stack / DOM stack |
| `NavigationView` | Both | iOS, macOS 10.15, watchOS 7, tvOS 13, visionOS 1 | Deprecated | Missing | `-` | Yes (iOS 16) — use NavigationStack/NavigationSplitView |
| `Tab` | Curated only | iOS, macOS 15, watchOS 11, tvOS 18, visionOS 2 | Current | Implemented | `Sources/SwiftOpenUI/Views/TabView.swift` | - |
| `TabView` | Both | iOS, macOS 10.15, watchOS 7, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/TabView.swift` | GTK: Stack+Switcher; Win32: button bar; Web: tab bar+panels |

## Drawing & Graphics

9 total, 2 implemented, 0 partial, 7 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `AngularGradient` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Missing | `-` | - |
| `Canvas` | Both | iOS, macOS 12, watchOS 8, tvOS 15, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Canvas.swift` | GTK: Cairo; Win32: D2D subset; Web: Canvas 2D API |
| `Color` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Color.swift` | RGBA, hex, HSB constructors |
| `ContainerRelativeShape` | Curated only | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 | Current | Missing | `-` | - |
| `EllipticalGradient` | Both | iOS, macOS 12, watchOS 8, tvOS 15, visionOS 1 | Current | Missing | `-` | - |
| `LinearGradient` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Gradients.swift` | GTK4: CSS linear-gradient; Web: CSS linear-gradient; Win32: solid first-stop color (D2D gradient brush deferred) |
| `MeshGradient` | Both | iOS, macOS 15, watchOS 11, tvOS 18, visionOS 2 | Current | Missing | `-` | - |
| `RadialGradient` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Gradients.swift` | GTK4: CSS radial-gradient; Web: CSS radial-gradient (startRadius/endRadius ignored); Win32: solid first-stop color (D2D gradient brush deferred) |
| `TimelineView` | Both | iOS, macOS 12, watchOS 8, tvOS 15, visionOS 1 | Current | Missing | `-` | - |

## Shapes

6 total, 5 implemented, 0 partial, 1 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `Capsule` | Curated only | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Shapes.swift` | GTK4: Cairo; Win32: D2D; Web: SVG |
| `Circle` | Curated only | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Shapes.swift` | GTK4: Cairo; Win32: D2D; Web: SVG |
| `Ellipse` | Curated only | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Shapes.swift` | GTK4: Cairo; Win32: D2D; Web: SVG |
| `Rectangle` | Curated only | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Shapes.swift` | GTK4: Cairo; Win32: D2D; Web: SVG |
| `RoundedRectangle` | Curated only | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/Shapes.swift` | GTK4: Cairo; Win32: D2D; Web: SVG |
| `UnevenRoundedRectangle` | Curated only | iOS, macOS 14, watchOS 10, tvOS 17, visionOS 1 | Current | Missing | `-` | iOS 17+ |

## Structural / Utility Views

5 total, 3 implemented, 0 partial, 2 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `AnyView` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/AnyView.swift` | - |
| `EmptyView` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/View.swift` | - |
| `EquatableView` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Missing | `-` | - |
| `SubscriptionView` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Missing | `-` | - |
| `TupleView` | Both | iOS, macOS 10.15, watchOS 6, tvOS 13, visionOS 1 | Current | Implemented | `Sources/SwiftOpenUI/Views/TupleView.swift` | - |

## Map & Location

2 total, 0 implemented, 0 partial, 2 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `LocationButton` | Curated only | iOS, macOS 12, watchOS 8 (CoreLocationUI) | Current | Missing | `-` | - |
| `Map` | Curated only | iOS, macOS 11, watchOS 7, tvOS 14, visionOS 1 (MapKit) | Current | Missing | `-` | No core type defined; needs external map library |

## Auth Views

1 total, 0 implemented, 0 partial, 1 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `SignInWithAppleButton` | Curated only | iOS, macOS 11, watchOS 7, tvOS 14 (AuthenticationServices) | Current | Missing | `-` | - |

## visionOS-Specific Views

2 total, 0 implemented, 0 partial, 2 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `Model3D` | Curated only | visionOS (RealityKit) | Current | Missing | `-` | - |
| `RealityView` | Curated only | visionOS (RealityKit) | Current | Missing | `-` | - |

## StoreKit Views

3 total, 0 implemented, 0 partial, 3 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `ProductView` | Curated only | iOS, macOS 14, watchOS 10, tvOS 17, visionOS 1 | Current | Missing | `-` | - |
| `StoreView` | Curated only | iOS, macOS 14, watchOS 10, tvOS 17, visionOS 1 | Current | Missing | `-` | - |
| `SubscriptionStoreView` | Curated only | iOS, macOS 14, watchOS 10, tvOS 17, visionOS 1 | Current | Missing | `-` | - |

## WWDC25 (iOS 26 / macOS 26)

1 total, 0 implemented, 0 partial, 1 missing.

| Feature | Seen In | SwiftUI Availability | SwiftUI Status | SwiftOpenUI | Evidence | Notes |
|---|---|---|---|---|---|---|
| `WebView` | Curated only | iOS, macOS 26, visionOS 26 (WebKit) | Current | Missing | `-` | - |
