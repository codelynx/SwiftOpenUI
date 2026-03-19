# SwiftUI vs SwiftOpenUI Feature Matrix

Comparison of SwiftUI features and their SwiftOpenUI implementation status across backends.

Last updated: 2026-03-19

## Legend

- Y — Implemented
- ~ — Partial / limited
- - — Not implemented
- N/A — Not applicable

## Views

| View | SwiftUI | Core | GTK4 | Win32 | Web | Android | Notes |
|------|---------|------|------|-------|-----|---------|-------|
| Text | Y | Y | Y | Y | Y | Y | |
| Button | Y | Y | Y | Y | Y | Y | Generic Label view supported |
| TextField | Y | Y | Y | Y | Y | Y | Single-line; Binding<String> |
| Toggle | Y | Y | Y | Y | - | - | GtkCheckButton / Win32 checkbox |
| Slider | Y | Y | Y | Y | - | - | Debounced commit on GTK4 (150ms) |
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
| SecureField | Y | Y | Y | - | - | - | GtkPasswordEntry with peek icon |
| TextEditor | Y | Y | Y | - | - | - | GtkTextView in ScrolledWindow |
| ProgressView | Y | Y | Y | - | - | - | Determinate; indeterminate pulse TODO |
| Stepper | Y | Y | Y | - | - | - | GtkSpinButton with label, range/step |
| Label | Y | Y | Y | - | - | - | systemImage or filePath + title |
| Link | Y | Y | Y | - | - | - | GtkLinkButton |
| TabView | Y | Y | Y | - | - | - | GtkStack + GtkStackSwitcher, TabBuilder |
| Grid | Y | Y | Y | - | - | - | Auto-wrap and explicit GridRow modes |
| GridRow | Y | Y | Y | - | - | - | MultiChildView, .gridCellColumns() span |
| DisclosureGroup | Y | Y | Y | - | - | - | GtkExpander, Binding<Bool> |
| Form | Y | Y | Y | - | - | - | Styled GtkBox with padding/spacing |
| Section | Y | Y | Y | - | - | - | Header (Pango markup), footer, separator |
| LazyVStack | Y | Y | Y | - | - | - | GtkListView factory pattern |
| LazyHStack | Y | Y | Y | - | - | - | GtkListView horizontal |
| LazyVGrid | Y | Y | Y | - | - | - | GtkGridView, GridItem adaptive/fixed |
| LazyHGrid | Y | Y | Y | - | - | - | GtkGridView horizontal |
| Picker | Y | Y | Y | - | - | - | GtkDropDown or segmented toggle group |
| DatePicker | Y | Y | Y | - | - | - | GtkCalendar, DateComponents type |
| GeometryReader | Y | Y | Y | - | - | - | Deferred map + tick resize tracking |
| Menu | Y | Y | Y | - | - | - | GMenu + GSimpleActionGroup + PopoverMenu |
| ConfirmationDialog | Y | - | - | - | - | - | Similar to Alert (not yet implemented) |
| Map | Y | - | - | - | - | - | Needs external map library |
| Canvas | Y | - | - | - | - | - | Needs Cairo binding |

## Modifiers

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
| .cornerRadius() | Y | Y | Y | - | - | - | CSS border-radius |
| .shadow() | Y | Y | Y | - | - | - | CSS box-shadow + margin |
| .rotationEffect() | Y | Y | Y | - | - | - | CSS transform rotate, Angle type |
| .overlay() | Y | Y | Y | - | - | - | GtkOverlay with alignment |
| .sheet() | Y | Y | Y | - | - | - | Modal GtkWindow, DismissAction env |
| .alert() | Y | Y | Y | - | - | - | Modal dialog with AlertButton array |
| .onAppear() | Y | Y | Y | - | - | - | "map" signal, rebuild-suppressed |
| .onDisappear() | Y | Y | Y | - | - | - | "unmap" signal, rebuild vs real |
| .searchable() | Y | Y | Y | - | - | - | GtkSearchEntry + binding |
| .toolbar() | Y | Y | Y | - | - | - | ToolbarProvider, header bar integration |
| .gridCellColumns() | Y | Y | Y | - | - | - | Column span in Grid/GridRow |
| .pickerStyle() | Y | Y | Y | - | - | - | .automatic, .segmented, .palette |
| .clipShape() | Y | - | - | - | - | - | |
| .task() | Y | - | - | - | - | - | Needs async runtime |

## State & Data

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

| Feature | SwiftUI | Core | GTK4 | Win32 | Web | Android | Notes |
|---------|---------|------|------|-------|-----|---------|-------|
| NavigationStack | Y | Y | Y | Y | Y | Y | |
| NavigationLink | Y | Y | Y | Y | Y | Y | String label |
| NavigationPath | Y | Y | Y | Y | Y | ~ | Bidirectional on GTK4/Win32/Web; Android is one-way rebuild |
| .navigationTitle() | Y | Y | Y | Y | Y | ~ | Header bar / title bar; Android falls back to path value |
| .navigationDestination() | Y | Y | Y | Y | Y | Y | Type-based |
| NavigateAction (env) | Y | Y | Y | Y | Y | Y | push/pop/popToRoot |
| NavigationSplitView | Y | - | - | - | - | - | |
| .navigationBarItems() | Y | - | - | - | - | - | |

## App Structure

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

| Category | SwiftUI Total | SwiftOpenUI Implemented | Coverage |
|----------|--------------|------------------------|----------|
| Views | 43 | 40 | ~93% |
| Modifiers | 36 | 34 | ~94% |
| State & Data | 13 | 10 | ~77% |
| Navigation | 8 | 6 | 75% |
| App structure | 9 | 5 | ~56% |
| Layout system | 9 | 7 | ~78% |
