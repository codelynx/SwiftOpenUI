# SwiftUI vs SwiftOpenUI Feature Matrix

Comparison of SwiftUI features and their SwiftOpenUI implementation status across backends.

Last updated: 2026-03-19

## Legend

- Y — Implemented
- ~ — Partial / limited
- - — Not implemented
- N/A — Not applicable

## Views
<!-- Parity: Examples/Parity/ViewsBasic, ViewsLayout, ViewsContainers -->

| View | SwiftUI | Core | GTK4 | Win32 | Web | Android | Notes |
|------|---------|------|------|-------|-----|---------|-------|
| Text | Y | Y | Y | Y | Y | Y | |
| Button | Y | Y | Y | Y | Y | Y | Generic Label view supported |
| TextField | Y | Y | Y | Y | Y | Y | Single-line; Binding<String> |
| Toggle | Y | Y | Y | Y | - | - | GtkCheckButton / Win32 checkbox |
| Slider | Y | Y | Y | Y | - | - | Debounced on GTK4; container subclass on Win32 |
| Image | Y | Y | Y | ~ | - | - | GTK icon theme + file; Win32: text fallback |
| Color | Y | Y | Y | Y | Y | Y | RGBA, hex, HSB constructors |
| Spacer | Y | Y | Y | Y | Y | Y | |
| Divider | Y | Y | Y | Y | Y | Y | |
| VStack | Y | Y | Y | Y | Y | Y | |
| HStack | Y | Y | Y | Y | Y | Y | |
| ZStack | Y | Y | Y | Y | Y | Y | |
| Group | Y | Y | Y | Y | Y | Y | |
| ForEach | Y | Y | Y | Y | Y | Y | Identifiable, keyPath, Range |
| List | Y | Y | Y | Y | - | - | Content-based; no selection yet |
| ScrollView | Y | Y | Y | Y | - | - | Axis OptionSet |
| AnyView | Y | Y | Y | Y | Y | Y | |
| EmptyView | Y | Y | Y | Y | Y | Y | |
| NavigationStack | Y | Y | Y | Y | Y | Y | GtkStack / Win32 HWND stack / DOM stack |
| NavigationLink | Y | Y | Y | Y | Y | Y | String label only |
| SecureField | Y | Y | Y | Y | - | - | GTK: PasswordEntry; Win32: EDIT+ES_PASSWORD |
| TextEditor | Y | Y | Y | Y | - | - | GTK: TextView+ScrolledWindow; Win32: EDIT+ES_MULTILINE |
| ProgressView | Y | Y | Y | Y | - | - | GTK: GtkProgressBar; Win32: msctls_progress32 |
| Stepper | Y | Y | Y | Y | - | - | GTK: SpinButton; Win32: label+buttons |
| Label | Y | Y | Y | Y | - | - | GTK: icon+text; Win32: text with [icon] prefix |
| Link | Y | Y | Y | Y | - | - | GTK: LinkButton; Win32: ShellExecuteW |
| TabView | Y | Y | Y | Y | - | - | GTK: Stack+Switcher; Win32: button bar |
| Grid | Y | Y | Y | Y | - | - | GTK: GtkGrid auto-wrap+rows; Win32: VStack of HStacks |
| GridRow | Y | Y | Y | Y | - | - | MultiChildView, .gridCellColumns() span |
| DisclosureGroup | Y | Y | Y | Y | - | - | GTK: GtkExpander; Win32: toggle+show/hide |
| Form | Y | Y | Y | Y | - | - | GTK: styled GtkBox; Win32: VStack+padding |
| Section | Y | Y | Y | Y | - | - | GTK: Pango header; Win32: header+divider |
| LazyVStack | Y | Y | Y | Y | - | - | GTK: virtualized GtkListView; Win32: non-virtualized |
| LazyHStack | Y | Y | Y | Y | - | - | GTK: GtkListView horizontal; Win32: HStack |
| LazyVGrid | Y | Y | Y | Y | - | - | GTK: GtkGridView adaptive; Win32: non-virtualized |
| LazyHGrid | Y | Y | Y | Y | - | - | GTK: GtkGridView horizontal; Win32: Grid |
| Picker | Y | Y | Y | Y | - | - | GTK: dropdown/segmented; Win32: ComboBox |
| DatePicker | Y | Y | Y | Y | - | - | GTK: GtkCalendar; Win32: SysDateTimePick32 + binding |
| GeometryReader | Y | Y | Y | Y | - | - | GTK: map+tick; Win32: parent rect |
| Menu | Y | Y | Y | Y | - | - | GTK: GMenu+PopoverMenu; Win32: TrackPopupMenu |
| ConfirmationDialog | Y | Y | Y | Y | - | - | GTK: vertical modal; Win32: MessageBoxW |
| Canvas | Y | Y | Y | ~ | - | - | GTK: Cairo; Win32: D2D subset (paths, transforms, alpha; no filters/symbols) |
| Map | Y | - | - | - | - | - | No core type defined; needs external map library |

## Modifiers
<!-- Parity: Examples/Parity/Modifiers, Gestures, Animation -->

| Modifier | SwiftUI | Core | GTK4 | Win32 | Web | Android | Notes |
|----------|---------|------|------|-------|-----|---------|-------|
| .padding() | Y | Y | Y | Y | Y | Y | Edge-specific variants |
| .frame() | Y | Y | Y | Y | Y | Y | width/height/min/max |
| .foregroundColor() | Y | Y | Y | Y | Y | Y | |
| .foregroundStyle() | Y | Y | Y | Y | Y | Y | Color only (no gradients) |
| .background() | Y | Y | Y | Y | Y | Y | Color only |
| .font() | Y | Y | Y | Y | Y | Y | Preset + custom |
| .border() | Y | Y | Y | Y | Y | Y | |
| .opacity() | Y | Y | Y | Y | Y | Y | |
| .offset() | Y | Y | Y | Y | Y | Y | CSS transform on GTK4 |
| .scaleEffect() | Y | Y | Y | ~ | Y | Y | Win32: D2D surface only |
| .animation() | Y | Y | Y | ~ | Y | Y | Win32: D2D only; Android: JSON node |
| .imageScale() | Y | Y | Y | ~ | - | - | Win32: no real image rendering |
| .onTapGesture() | Y | Y | Y | Y | Y | Y | count parameter |
| .onLongPressGesture() | Y | Y | Y | Y | Y | Y | minimumDuration |
| .onDrag() | Y | Y | Y | Y | Y | Y | minimumDistance filtering |
| .environmentObject() | Y | Y | Y | Y | Y | Y | |
| .environment() | Y | Y | Y | Y | Y | Y | |
| .navigationTitle() | Y | Y | Y | Y | Y | Y | |
| .navigationDestination() | Y | Y | Y | Y | Y | Y | Type-based registry |
| .focused() | Y | Y | Y | Y | - | Y | Web: no-op (pass-through) |
| .modifier() | Y | Y | Y | Y | Y | Y | Custom ViewModifier |
| withAnimation() | Y | Y | Y | Y | Y | ~ | Android: partial |
| .cornerRadius() | Y | Y | Y | Y | - | - | GTK: CSS; Win32: SetWindowRgn rounded region |
| .shadow() | Y | Y | Y | Y | - | - | GTK: CSS; Win32: layered shadow with alpha |
| .rotationEffect() | Y | Y | Y | Y | - | - | GTK: CSS transform; Win32: D2D SetTransform |
| .overlay() | Y | Y | Y | Y | - | - | GTK: GtkOverlay; Win32: container |
| .sheet() | Y | Y | Y | Y | - | - | GTK: modal window; Win32: popup |
| .alert() | Y | Y | Y | Y | - | - | GTK: modal dialog; Win32: MessageBoxW |
| .confirmationDialog() | Y | Y | Y | Y | - | - | GTK: vertical modal; Win32: MessageBoxW |
| .onAppear() | Y | Y | Y | Y | - | - | GTK: map signal; Win32: deferred |
| .onDisappear() | Y | Y | Y | ~ | - | - | GTK: unmap; Win32: WM_NCDESTROY (limited) |
| .searchable() | Y | Y | Y | Y | - | - | GTK: SearchEntry; Win32: EDIT |
| .toolbar() | Y | Y | Y | Y | - | - | GTK: header bar; Win32: nav header |
| .gridCellColumns() | Y | Y | Y | Y | - | - | Column span in Grid/GridRow |
| .pickerStyle() | Y | Y | Y | Y | - | - | .automatic, .segmented, .palette |
| .navigationSplitViewColumnWidth() | Y | Y | Y | - | - | - | min/ideal/max; GTK divider stays resizable |
| .clipShape() | Y | - | - | - | - | - | |
| .task() | Y | - | - | - | - | - | Needs async runtime |

## State & Data
<!-- Parity: Examples/Parity/StateData, Environment, Focus -->

| Feature | SwiftUI | SwiftOpenUI | Notes |
|---------|---------|-------------|-------|
| @State | Y | Y | Thread-safe storage |
| @Binding | Y | Y | .constant() helper |
| @ObservedObject | Y | Y | |
| @StateObject | Y | Y | Lazy creation, survives rebuilds |
| @EnvironmentObject | Y | Y | |
| @Published | Y | Y | Observer-based change notification |
| @Environment | Y | Y | Custom keys supported |
| @FocusState | Y | Y | Bool and enum variants |
| @Observable | Y | Y | Swift Observation framework, withObservationTracking |
| ObservableObject | Y | Y | Protocol marker |
| @AppStorage | Y | - | |
| @SceneStorage | Y | - | |
| @FetchRequest | Y | - | Core Data specific |

## Navigation
<!-- Parity: Examples/Parity/Navigation -->

| Feature | SwiftUI | Core | GTK4 | Win32 | Web | Android | Notes |
|---------|---------|------|------|-------|-----|---------|-------|
| NavigationStack | Y | Y | Y | Y | Y | Y | |
| NavigationLink | Y | Y | Y | Y | Y | Y | String label |
| NavigationPath | Y | Y | Y | Y | Y | ~ | Bidirectional on GTK4/Win32/Web; Android is one-way rebuild |
| .navigationTitle() | Y | Y | Y | Y | Y | ~ | Header bar / title bar; Android falls back to path value |
| .navigationDestination() | Y | Y | Y | Y | Y | Y | Type-based |
| NavigateAction (env) | Y | Y | Y | Y | Y | Y | push/pop/popToRoot |
| NavigationSplitView | Y | Y | Y | - | - | - | 2/3-column GtkPaned, visibility, column width |
| .navigationBarItems() | Y | - | - | - | - | - | |

## App Structure
<!-- Parity: Examples/Parity/AppStructure -->

| Feature | SwiftUI | SwiftOpenUI | Notes |
|---------|---------|-------------|-------|
| App protocol | Y | Y | |
| Scene protocol | Y | Y | |
| WindowGroup | Y | Y | Title + content |
| @SceneBuilder | Y | Y | Single scene only |
| @ViewBuilder | Y | Y | Up to 12 children |
| @main | Y | - | Platform-specific entry points instead |
| DocumentGroup | Y | - | |
| Settings | Y | - | macOS only in SwiftUI |
| Commands / menus | Y | - | |

## Layout System

| Feature | SwiftUI | SwiftOpenUI | Notes |
|---------|---------|-------------|-------|
| HorizontalAlignment | Y | Y | leading, center, trailing |
| VerticalAlignment | Y | Y | top, center, bottom |
| Alignment | Y | Y | 9 compound values |
| Edge / Edge.Set | Y | Y | OptionSet |
| EdgeInsets | Y | Y | |
| ProposedViewSize | Y | Y | |
| GeometryReader | Y | Y | Deferred + tick-based resize |
| Layout protocol | Y | - | Custom layout engine |
| AlignmentGuide | Y | - | |

## Summary

| Category | SwiftUI Total | Core Implemented | GTK4 | Win32 | Coverage |
|----------|--------------|-----------------|------|-------|----------|
| Views | 44 | 43 | 43 | 43 | ~98% |
| Modifiers | 38 | 36 | 36 | 35 | ~95% |
| State & Data | 13 | 10 | 10 | 10 | ~77% |
| Navigation | 8 | 7 | 7 | 6 | 88% |
| App structure | 9 | 5 | 5 | 5 | ~56% |
| Layout system | 9 | 7 | 7 | 7 | ~78% |
