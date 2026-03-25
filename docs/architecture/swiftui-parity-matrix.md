# SwiftUI vs SwiftOpenUI Feature Matrix

Comparison of SwiftUI features and their SwiftOpenUI implementation status across backends.

Last updated: 2026-03-25

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
| Toggle | Y | Y | Y | Y | Y | - | GtkCheckButton / Win32 checkbox / Web checkbox |
| Slider | Y | Y | Y | Y | Y | - | Debounced on GTK4; container subclass on Win32; Web range input |
| Image | Y | Y | Y | Y | ~ | - | GTK icon theme + file; Win32: WIC; Web: img tag (systemName as text placeholder) |
| Color | Y | Y | Y | Y | Y | Y | RGBA, hex, HSB constructors |
| Spacer | Y | Y | Y | Y | Y | Y | |
| Divider | Y | Y | Y | Y | Y | Y | |
| VStack | Y | Y | Y | Y | Y | Y | |
| HStack | Y | Y | Y | Y | Y | Y | |
| ZStack | Y | Y | Y | Y | Y | Y | |
| Group | Y | Y | Y | Y | Y | Y | |
| ForEach | Y | Y | Y | Y | Y | Y | Identifiable, keyPath, Range |
| List | Y | Y | Y | Y | Y | - | Content-based; no selection yet |
| ScrollView | Y | Y | Y | Y | Y | - | Axis OptionSet; Web: CSS overflow |
| AnyView | Y | Y | Y | Y | Y | Y | |
| EmptyView | Y | Y | Y | Y | Y | Y | |
| NavigationStack | Y | Y | Y | Y | Y | Y | GtkStack / Win32 HWND stack / DOM stack |
| NavigationLink | Y | Y | Y | Y | Y | Y | String and custom ViewBuilder labels |
| SecureField | Y | Y | Y | Y | Y | - | GTK: PasswordEntry; Win32: EDIT+ES_PASSWORD; Web: password input |
| TextEditor | Y | Y | Y | Y | Y | - | GTK: TextView+ScrolledWindow; Win32: EDIT+ES_MULTILINE; Web: textarea |
| ProgressView | Y | Y | Y | Y | Y | - | GTK: GtkProgressBar; Win32: msctls_progress32; Web: progress element |
| Stepper | Y | Y | Y | Y | Y | - | GTK: SpinButton; Win32: label+buttons; Web: -/+ buttons |
| Label | Y | Y | Y | Y | Y | - | GTK: icon+text; Win32/Web: text with icon placeholder |
| Link | Y | Y | Y | Y | Y | - | GTK: LinkButton; Win32: ShellExecuteW; Web: anchor tag |
| TabView | Y | Y | Y | Y | Y | - | GTK: Stack+Switcher; Win32: button bar; Web: tab bar+panels |
| Grid | Y | Y | Y | Y | Y | - | GTK: GtkGrid; Win32: VStack of HStacks; Web: CSS grid |
| GridRow | Y | Y | Y | Y | Y | - | MultiChildView, .gridCellColumns() span |
| DisclosureGroup | Y | Y | Y | Y | Y | - | GTK: GtkExpander; Win32: toggle+show/hide; Web: details/summary |
| Form | Y | Y | Y | Y | Y | - | GTK: styled GtkBox; Win32: VStack+padding; Web: styled div |
| Section | Y | Y | Y | Y | Y | - | GTK: Pango header; Win32: header+divider; Web: h3+content |
| LazyVStack | Y | Y | Y | Y | Y | - | GTK: virtualized; Win32/Web: non-virtualized |
| LazyHStack | Y | Y | Y | Y | Y | - | GTK: horizontal; Win32/Web: non-virtualized |
| LazyVGrid | Y | Y | Y | Y | Y | - | GTK: GtkGridView; Win32/Web: CSS grid, non-virtualized |
| LazyHGrid | Y | Y | Y | Y | Y | - | GTK: horizontal; Win32/Web: CSS grid |
| Picker | Y | Y | Y | Y | Y | - | GTK: dropdown/segmented; Win32: ComboBox; Web: select |
| DatePicker | Y | Y | Y | Y | Y | - | GTK: GtkCalendar; Win32: SysDateTimePick32; Web: date input |
| GeometryReader | Y | Y | Y | Y | Y | - | GTK: map+tick; Win32: parent rect; Web: ResizeObserver |
| Menu | Y | Y | Y | Y | Y | - | GTK: GMenu+PopoverMenu; Win32: TrackPopupMenu; Web: dropdown div |
| ConfirmationDialog | Y | Y | Y | Y | Y | - | GTK: vertical modal; Win32: MessageBoxW; Web: inline overlay |
| Canvas | Y | Y | Y | ~ | Y | - | GTK: Cairo; Win32: D2D subset; Web: Canvas 2D API |
| Map | Y | - | - | - | - | - | No core type defined; needs external map library |

## Modifiers
<!-- Parity: Examples/Parity/Modifiers, Gestures, Animation -->

| Modifier | SwiftUI | Core | GTK4 | Win32 | Web | Android | Notes |
|----------|---------|------|------|-------|-----|---------|-------|
| .padding() | Y | Y | Y | Y | Y | Y | Edge-specific variants |
| .frame() | Y | Y | Y | Y | Y | Y | width/height/min/max |
| .foregroundColor() | Y | Y | Y | Y | Y | Y | |
| .foregroundStyle() | Y | Y | Y | Y | Y | Y | Color only (no gradients) |
| .background() | Y | Y | Y | Y | Y | Y | Color and arbitrary view overloads |
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
| .focused() | Y | Y | Y | Y | Y | Y | Web: DOM focus/blur + FocusState binding |
| .modifier() | Y | Y | Y | Y | Y | Y | Custom ViewModifier |
| withAnimation() | Y | Y | Y | Y | Y | ~ | Android: partial |
| .cornerRadius() | Y | Y | Y | Y | Y | - | GTK/Web: CSS; Win32: SetWindowRgn rounded region |
| .shadow() | Y | Y | Y | Y | Y | - | GTK/Web: CSS; Win32: layered shadow with alpha |
| .rotationEffect() | Y | Y | Y | Y | Y | - | GTK/Web: CSS transform; Win32: D2D SetTransform |
| .overlay() | Y | Y | Y | Y | Y | - | GTK: GtkOverlay; Win32: container; Web: absolute positioning |
| .sheet() | Y | Y | Y | Y | Y | - | GTK: modal window; Win32: popup; Web: modal overlay |
| .alert() | Y | Y | Y | Y | Y | - | GTK: modal dialog; Win32: MessageBoxW; Web: modal overlay |
| .confirmationDialog() | Y | Y | Y | Y | Y | - | GTK: vertical modal; Win32: MessageBoxW; Web: inline overlay |
| .onAppear() | Y | Y | Y | Y | ~ | - | GTK: map signal; Win32: deferred; Web: fires on every render (host-level) |
| .onDisappear() | Y | Y | Y | ~ | - | - | GTK: unmap; Win32: WM_NCDESTROY (limited) |
| .searchable() | Y | Y | ~ | ~ | ~ | - | Batch A fallback on GTK/Win32/Web: search field above content; placement stored but not differentiated yet. Win32 suppresses field when `isPresented == false`. |
| .toolbar() | Y | Y | Y | Y | Y | - | GTK: header bar; Win32: nav header; Web: header right area |
| .gridCellColumns() | Y | Y | Y | Y | Y | - | Column span in Grid/GridRow; Web: grid-column span |
| .pickerStyle() | Y | Y | Y | Y | Y | - | .automatic (select), .segmented (button row), .palette (alias) |
| .navigationSplitViewColumnWidth() | Y | Y | Y | Y | Y | - | min/ideal/max; Web: pass-through (consumed by NavigationSplitView) |
| .ignoresSafeArea() | Y | Y | Y | ~ | ~ | - | GTK: passthrough; Win32/Web: passthrough pending safe-area model |
| .safeAreaInset() | Y | Y | Y | ~ | ~ | - | GTK: GtkBox reserved-space layout; Win32/Web: reservation with spacing/alignment |
| .safeAreaPadding() | Y | Y | ~ | ~ | ~ | - | Batch A synthetic fallback on GTK/Win32/Web: explicit length uses exact amount; nil length uses synthetic default 16; not measured native safe-area padding. |
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
| NavigationLink | Y | Y | Y | Y | Y | Y | String and custom ViewBuilder labels |
| NavigationPath | Y | Y | Y | Y | Y | ~ | Bidirectional on GTK4/Win32/Web; Android is one-way rebuild |
| .navigationTitle() | Y | Y | Y | Y | Y | ~ | Header bar / title bar; Android falls back to path value |
| .navigationDestination() | Y | Y | Y | Y | Y | Y | Type-based |
| NavigateAction (env) | Y | Y | Y | Y | Y | Y | push/pop/popToRoot |
| NavigationSplitView | Y | Y | Y | Y | Y | - | GTK: GtkPaned; Win32: draggable divider; Web: flexbox columns |
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
| .defaultWindowSize() | Y | ~ | GTK4 + Win32 implemented; maps to native initial size |
| .windowSizeConstraints() | Y | ~ | Win32 min/max; GTK4 min only in first pass |
| .windowSizing() | Y | ~ | GTK4 + Win32: automatic/content/contentFixed/explicit size |
| .windowResizeBehavior() | Y | ~ | GTK4 + Win32: automatic/fixed/resizable |
| @main | Y | - | Platform-specific entry points instead |
| DocumentGroup | Y | - | |
| Settings | Y | - | macOS only in SwiftUI |
| Commands / menus | Y | - | |

## Layout System
<!-- Parity: Examples/Parity/ViewsLayout (Alignment, Edge, EdgeInsets, ProposedViewSize) -->

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
| Modifiers | 40 | 38 | 38 | 38 | ~95% |
| State & Data | 13 | 10 | 10 | 10 | ~77% |
| Navigation | 8 | 7 | 7 | 7 | 88% |
| App structure | 9 | 5 | 5 | 5 | ~56% |
| Layout system | 9 | 7 | 7 | 7 | ~78% |
