# SwiftUI vs SwiftOpenUI Feature Matrix

Comparison of SwiftUI features and their SwiftOpenUI implementation status across backends.

Last updated: 2026-03-18

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
| Image (system) | Y | Y | Y | Y | - | - | GTK icon theme names, not SF Symbols |
| Image (file) | Y | Y | Y | Y | - | - | |
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
| TabView | Y | - | - | - | - | - | |
| GeometryReader | Y | - | - | - | - | - | |
| LazyVStack | Y | - | - | - | - | - | |
| LazyHStack | Y | - | - | - | - | - | |
| LazyVGrid | Y | - | - | - | - | - | |
| LazyHGrid | Y | - | - | - | - | - | |
| Grid | Y | - | - | - | - | - | |
| Sheet | Y | - | - | - | - | - | |
| Alert | Y | - | - | - | - | - | |
| ConfirmationDialog | Y | - | - | - | - | - | |
| Picker | Y | - | - | - | - | - | |
| DatePicker | Y | - | - | - | - | - | |
| ProgressView | Y | - | - | - | - | - | |
| Menu | Y | - | - | - | - | - | |
| Label | Y | - | - | - | - | - | |
| Link | Y | - | - | - | - | - | |
| DisclosureGroup | Y | - | - | - | - | - | |
| Form | Y | - | - | - | - | - | |
| Section | Y | - | - | - | - | - | |
| SecureField | Y | - | - | - | - | - | |
| TextEditor | Y | - | - | - | - | - | |
| Stepper | Y | - | - | - | - | - | |
| Map | Y | - | - | - | - | - | |
| Canvas | Y | - | - | - | - | - | |

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
| .animation() | Y | Y | Y | ~ | Y | - | Win32: D2D only; Android: stub |
| .imageScale() | Y | Y | Y | Y | - | - | |
| .onTapGesture() | Y | Y | Y | Y | Y | Y | count parameter |
| .onLongPressGesture() | Y | Y | Y | Y | Y | Y | minimumDuration |
| .onDrag() | Y | Y | Y | Y | Y | Y | minimumDistance filtering |
| .environmentObject() | Y | Y | Y | Y | Y | Y | |
| .environment() | Y | Y | Y | Y | Y | Y | |
| .navigationTitle() | Y | Y | Y | Y | Y | Y | |
| .navigationDestination() | Y | Y | Y | Y | Y | Y | Type-based registry |
| .focused() | Y | Y | Y | Y | ~ | Y | Web: stub |
| .modifier() | Y | Y | Y | Y | Y | Y | Custom ViewModifier |
| withAnimation() | Y | Y | Y | Y | Y | ~ | Android: partial |
| .rotationEffect() | Y | - | - | - | - | - | |
| .shadow() | Y | - | - | - | - | - | |
| .cornerRadius() | Y | - | - | - | - | - | |
| .clipShape() | Y | - | - | - | - | - | |
| .overlay() | Y | - | - | - | - | - | |
| .sheet() | Y | - | - | - | - | - | |
| .alert() | Y | - | - | - | - | - | |
| .onAppear() | Y | - | - | - | - | - | |
| .onDisappear() | Y | - | - | - | - | - | |
| .task() | Y | - | - | - | - | - | |
| .searchable() | Y | - | - | - | - | - | |
| .toolbar() | Y | - | - | - | - | - | |

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
| @AppStorage | Y | - | |
| @SceneStorage | Y | - | |
| @FetchRequest | Y | - | Core Data specific |
| ObservableObject | Y | Y | Protocol marker |
| Observable (@Observable) | Y | - | Swift 5.9 macro-based |

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
| Layout protocol | Y | - | Custom layout engine |
| AlignmentGuide | Y | - | |
| GeometryReader | Y | - | |

## Summary

| Category | SwiftUI Total | SwiftOpenUI Implemented | Coverage |
|----------|--------------|------------------------|----------|
| Views | ~45 | 20 | ~44% |
| Modifiers | ~35 | 22 | ~63% |
| State wrappers | 10 | 8 | 80% |
| Navigation | 7 | 6 | 86% |
| App structure | 8 | 5 | 63% |
