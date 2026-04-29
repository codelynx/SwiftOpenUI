# SwiftUI vs SwiftOpenUI Feature Matrix

Comparison of SwiftUI features and their SwiftOpenUI implementation status across backends.

Last updated: 2026-04-28

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
| Toggle | Y | Y | Y | Y | Y | Y | GtkCheckButton / Win32 checkbox / Web checkbox |
| Slider | Y | Y | Y | Y | Y | Y | Debounced on GTK4; container subclass on Win32; Web range input |
| Image | Y | Y | Y | Y | ~ | - | GTK icon theme + file; Win32: WIC; Web: img tag (systemName as text placeholder) |
| Color | Y | Y | Y | Y | Y | Y | RGBA, hex, HSB constructors |
| Spacer | Y | Y | Y | Y | Y | Y | |
| Divider | Y | Y | Y | Y | Y | Y | |
| VStack | Y | Y | Y | Y | Y | Y | |
| HStack | Y | Y | Y | Y | Y | Y | |
| ZStack | Y | Y | Y | Y | Y | Y | |
| Group | Y | Y | Y | Y | Y | Y | |
| ForEach | Y | Y | Y | Y | Y | Y | Identifiable, keyPath, Range |
| List | Y | Y | Y | Y | Y | Y | Content-based; no selection yet |
| ScrollView | Y | Y | Y | Y | Y | Y | Axis OptionSet; Web: CSS overflow |
| ScrollViewReader | Y | Y | Y | Y | Y | - | ScrollViewProxy + .id() modifier; GTK: grab_focus; Win32: WM_VSCROLL; Web: scrollIntoView |
| LinearGradient | Y | Y | Y | ~ | Y | - | GTK4: CSS linear-gradient; Web: CSS; Win32: solid first-stop (D2D deferred) |
| RadialGradient | Y | Y | Y | ~ | Y | - | GTK4: CSS radial-gradient; Web: CSS (radii ignored); Win32: solid first-stop |
| AnyView | Y | Y | Y | Y | Y | Y | |
| EmptyView | Y | Y | Y | Y | Y | Y | |
| NavigationStack | Y | Y | Y | Y | Y | Y | GtkStack / Win32 HWND stack / DOM stack |
| NavigationLink | Y | Y | Y | Y | Y | Y | String and custom ViewBuilder labels |
| SecureField | Y | Y | Y | Y | Y | Y | GTK: PasswordEntry; Win32: EDIT+ES_PASSWORD; Web: password input |
| TextEditor | Y | Y | Y | Y | Y | Y | GTK: TextView+ScrolledWindow; Win32: EDIT+ES_MULTILINE; Web: textarea |
| ProgressView | Y | Y | Y | Y | Y | Y | GTK: GtkProgressBar; Win32: msctls_progress32; Web: progress element |
| Stepper | Y | Y | Y | Y | Y | - | GTK: SpinButton; Win32: label+buttons; Web: -/+ buttons |
| Label | Y | Y | Y | Y | Y | - | GTK: icon+text; Win32/Web: text with icon placeholder |
| Link | Y | Y | Y | Y | Y | - | GTK: LinkButton; Win32: ShellExecuteW; Web: anchor tag |
| TabView | Y | Y | Y | Y | Y | - | GTK: Stack+Switcher; Win32: button bar; Web: tab bar+panels |
| Grid | Y | Y | Y | Y | Y | - | GTK: GtkGrid; Win32: VStack of HStacks; Web: CSS grid |
| GridRow | Y | Y | Y | Y | Y | - | MultiChildView, .gridCellColumns() span |
| DisclosureGroup | Y | Y | Y | Y | Y | - | GTK: GtkExpander; Win32: toggle+show/hide; Web: details/summary. Custom label support. |
| OutlineGroup | Y | Y | Y | - | - | - | Hierarchical list view. GTK: recursive GtkExpander tree. |
| Form | Y | Y | Y | Y | Y | - | GTK: styled GtkBox; Win32: VStack+padding; Web: styled div |
| Section | Y | Y | Y | Y | Y | - | GTK: Pango header; Win32: header+divider; Web: h3+content |
| LazyVStack | Y | Y | Y | Y | Y | - | GTK: virtualized; Win32/Web: non-virtualized |
| LazyHStack | Y | Y | Y | Y | Y | - | GTK: horizontal; Win32/Web: non-virtualized |
| LazyVGrid | Y | Y | Y | Y | Y | - | GTK: GtkGridView; Win32/Web: CSS grid, non-virtualized |
| LazyHGrid | Y | Y | Y | Y | Y | - | GTK: horizontal; Win32/Web: CSS grid |
| Picker | Y | Y | Y | Y | Y | - | GTK: dropdown/segmented; Win32: ComboBox; Web: select |
| DatePicker | Y | Y | Y | Y | Y | - | GTK: GtkCalendar; Win32: SysDateTimePick32; Web: date input |
| GeometryReader | Y | Y | Y | Y | Y | - | GTK: map+tick; Win32: parent rect; Web: ResizeObserver |
| ViewThatFits | Y | Y | Y | Y | ~ | - | Batch A fallback on Web: initial-mount first-fit selection with fallback-to-last, but no resize reevaluation yet. GTK: GtkStack + tick-driven remeasurement; Win32: WM_SIZE remeasurement. |
| Menu | Y | Y | Y | Y | Y | - | GTK: GMenu+PopoverMenu; Win32: TrackPopupMenu; Web: dropdown div |
| ConfirmationDialog | Y | Y | Y | Y | Y | - | GTK: vertical modal; Win32: MessageBoxW; Web: inline overlay |
| Canvas | Y | Y | Y | ~ | Y | - | GTK: Cairo; Win32: D2D subset; Web: Canvas 2D API |
| Circle | Y | Y | Y | Y | Y | Y | Shape protocol + path(in:); GTK: Cairo; Win32: D2D; Web: SVG |
| Rectangle | Y | Y | Y | Y | Y | Y | |
| RoundedRectangle | Y | Y | Y | Y | Y | Y | cornerRadius + RoundedCornerStyle |
| Capsule | Y | Y | Y | Y | Y | Y | |
| Ellipse | Y | Y | Y | Y | Y | Y | |
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
| .animation() | Y | Y | Y | ~ | Y | Y | Win32: D2D only; Web: CSS transition with two-phase rebuild; Android: JSON node |
| .imageScale() | Y | Y | Y | ~ | - | - | Win32: no real image rendering |
| .onTapGesture() | Y | Y | Y | Y | Y | Y | count parameter |
| .onLongPressGesture() | Y | Y | Y | Y | Y | Y | minimumDuration |
| .onDrag() | Y | Y | Y | Y | Y | Y | minimumDistance filtering |
| .disabled() | Y | Y | Y | Y | ~ | - | Batch A on GTK/Win32/Web: inherited `isEnabled` environment; main interactive controls disabled. Web fallback: priority controls covered, but non-priority controls like Link/Menu remain enabled. |
| .environmentObject() | Y | Y | Y | Y | Y | Y | |
| .environment() | Y | Y | Y | Y | Y | Y | |
| .navigationTitle() | Y | Y | Y | Y | Y | Y | |
| .navigationDestination() | Y | Y | Y | Y | Y | Y | Type-based registry |
| .focused() | Y | Y | Y | Y | Y | Y | Web: DOM focus/blur + FocusState binding |
| .modifier() | Y | Y | Y | Y | Y | Y | Custom ViewModifier |
| withAnimation() | Y | Y | Y | Y | Y | ~ | Android: partial |
| .clipShape() | Y | Y | Y | Y | Y | Y | GTK: CSS border-radius + overflow; Win32: SetWindowRgn; Web: CSS clip-path |
| .clipped() | Y | Y | Y | Y | Y | - | GTK/Web: overflow hidden; Win32: CreateRectRgn |
| .hidden() | Y | Y | Y | Y | Y | - | GTK: wrapper with opacity 0 + interaction disabled; Win32: ShowWindow(SW_HIDE); Web: visibility hidden + pointer-events none |
| .blur() | Y | Y | Y | ~ | Y | - | GTK/Web: CSS filter blur; Win32: pass-through (known limitation) |
| .cornerRadius() | Y | Y | Y | Y | Y | - | GTK/Web: CSS; Win32: SetWindowRgn rounded region |
| .shadow() | Y | Y | Y | Y | Y | - | GTK/Web: CSS; Win32: layered shadow with alpha |
| .lineLimit() | Y | Y | Y | Y | Y | - | GTK: GtkLabel wrap/lines; Win32: Static style + DrawTextW; Web: -webkit-line-clamp |
| .truncationMode() | Y | Y | Y | ~ | Y | - | GTK: Pango ellipsize (all 3 modes); Win32: SS_ENDELLIPSIS/PATHELLIPSIS (head→tail fallback); Web: text-overflow (middle→tail fallback) |
| .lineSpacing() | Y | Y | Y | ~ | Y | - | GTK/Web: CSS line-height; Win32: pass-through |
| .multilineTextAlignment() | Y | Y | Y | Y | Y | - | GTK: justify + xalign; Win32: SS_LEFT/CENTER/RIGHT; Web: text-align |
| .rotationEffect() | Y | Y | Y | Y | Y | - | GTK/Web: CSS transform; Win32: D2D SetTransform |
| .overlay() | Y | Y | Y | Y | Y | - | GTK: GtkOverlay; Win32: container; Web: absolute positioning |
| .sheet() | Y | Y | Y | Y | Y | Y | Batch A: `isPresented`, `item`, and `onDismiss` families on GTK/Win32/Web. GTK: modal window; Win32: popup; Web: modal overlay. Android: ModalBottomSheet. |
| .alert() | Y | ~ | ~ | ~ | ~ | Y | Batch B: title + `isPresented` + actions/message + error families via simplified `AlertButton[]` + `String` API. GTK: modal dialog; Win32: MessageBoxW; Web: modal overlay. |
| .confirmationDialog() | Y | Y | ~ | ~ | ~ | - | Batch D fallback on GTK/Win32/Web: `titleVisibility == .hidden`, `message`, and `dismissalConfirmationDialog(_:shouldPresent:actions:)` are supported; `.automatic` currently behaves like `.visible`. `dismissalConfirmationDialog` now intercepts user-triggered sheet dismiss for `sheet(isPresented:)` and `sheet(item:)`; broader presenter interception remains deferred. GTK: vertical modal; Win32: MessageBoxW; Web: inline overlay. |
| .onAppear() | Y | Y | Y | Y | ~ | - | GTK: map signal; Win32: deferred; Web: fires on every render (host-level) |
| .onDisappear() | Y | Y | Y | ~ | - | - | GTK: unmap; Win32: WM_NCDESTROY (limited) |
| .searchable() | Y | Y | ~ | ~ | ~ | - | Batch E fallback on GTK/Win32/Web: search field above content; placement stored but not differentiated yet; tokens and editableTokens render as display-only chips; suggestions render as simple rows with click-to-complete behavior, including core-filtered `searchSuggestions(_:for:)`; scopes render as simple mutually exclusive controls. Search UI is hidden when `isPresented == false`. |
| .toolbar() | Y | Y | Y | Y | Y | - | Batch B fallback on GTK/Win32/Web: `toolbar(_:for:)` and `toolbar(removing:)` are supported for the active navigation/header toolbar surface; target handling is narrower than SwiftUI. GTK: header bar; Win32: nav header; Web: header right area. |
| .gridCellColumns() | Y | Y | Y | Y | Y | - | Column span in Grid/GridRow; Web: grid-column span |
| .buttonStyle() | Y | Y | Y | Y | Y | - | Environment-based: automatic, plain, bordered, borderedProminent |
| .toggleStyle() | Y | Y | Y | Y | Y | - | Environment-based: automatic, checkbox, switch. GTK: GtkSwitch |
| .textFieldStyle() | Y | Y | Y | Y | Y | - | Environment-based: automatic, plain, roundedBorder |
| .onChange() | Y | Y | Y | Y | Y | - | Render-pass counter-keyed value tracking |
| .contextMenu() | Y | Y | Y | Y | Y | - | GTK: GtkPopoverMenu; Win32: TrackPopupMenu; Web: CSS overlay (submenus omitted) |
| .popover() | Y | Y | Y | Y | Y | - | GTK: GtkPopover; Win32: popup window; Web: absolute overlay (dismiss listener leaks on non-click dismiss paths) |
| .position() | Y | Y | Y | Y | Y | - | GTK: GtkFixed; Win32: SetWindowPos; Web: CSS absolute |
| .layoutPriority() | Y | Y | Y | Y | Y | - | API surface only — layout engine integration deferred |
| .fixedSize() | Y | Y | Y | Y | Y | - | GTK: size_request; Win32: pass-through; Web: flex-shrink 0 |
| .id() | Y | Y | Y | Y | Y | - | Global ID registry for ScrollViewReader |
| .tag() | Y | Y | Y | Y | Y | - | Thread-local tag propagation for selection controls |
| .onSubmit() | Y | Y | Y | Y | Y | - | Environment-based SubmitAction; TextField + SecureField wired |
| .bold() | Y | Y | Y | Y | Y | - | GTK4/Web: CSS; Win32: LOGFONTW |
| .italic() | Y | Y | Y | Y | Y | - | GTK4/Web: CSS; Win32: LOGFONTW |
| .fontWeight() | Y | Y | Y | Y | Y | - | GTK4/Web: CSS 100-900; Win32: LOGFONTW |
| .underline() | Y | Y | Y | Y | Y | - | GTK4: Pango; Web: CSS; Win32: LOGFONTW |
| .strikethrough() | Y | Y | Y | Y | Y | - | GTK4: Pango; Web: CSS; Win32: LOGFONTW |
| .textCase() | Y | Y | Y | ~ | Y | - | GTK4: string transform; Web: CSS text-transform; Win32: pass-through |
| .aspectRatio() | Y | Y | Y | Y | Y | - | GTK4/Web: CSS aspect-ratio + object-fit; Win32: SetWindowPos |
| .scaledToFit() | Y | Y | Y | Y | Y | - | Convenience for aspectRatio(nil, .fit) |
| .scaledToFill() | Y | Y | Y | Y | Y | - | Convenience for aspectRatio(nil, .fill) |
| .pickerStyle() | Y | Y | Y | Y | Y | - | .automatic (select), .segmented (button row), .palette (alias) |
| .navigationSplitViewColumnWidth() | Y | Y | Y | Y | Y | - | min/ideal/max; Web: pass-through (consumed by NavigationSplitView) |
| .ignoresSafeArea() | Y | Y | Y | ~ | ~ | - | GTK: passthrough; Win32/Web: passthrough pending safe-area model |
| .safeAreaInset() | Y | Y | Y | ~ | ~ | - | GTK: GtkBox reserved-space layout; Win32/Web: reservation with spacing/alignment |
| .safeAreaPadding() | Y | Y | ~ | ~ | ~ | - | Batch A synthetic fallback on GTK/Win32/Web: explicit length uses exact amount; nil length uses synthetic default 16; not measured native safe-area padding. |
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
| OpenWindowAction (env) | Y | ~ | Environment key for opening Window scenes by ID. GTK/Win32: functional. Web: resolves to no-op default. |
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
| Window | Y | Y | Single-instance identified scene; GTK4 + Win32 support `openWindow(id:)` |
| WindowGroup | Y | Y | Title + content |
| @SceneBuilder | Y | Y | Two-scene overload (TupleScene) |
| @ViewBuilder | Y | Y | Up to 12 children |
| .defaultWindowSize() | Y | ~ | GTK4 + Win32 implemented; maps to native initial size |
| .windowSizeConstraints() | Y | ~ | Win32 min/max; GTK4 min only in first pass |
| .windowSizing() | Y | ~ | GTK4 + Win32: automatic/content/contentFixed/explicit size |
| .windowResizeBehavior() | Y | ~ | GTK4 + Win32: automatic/fixed/resizable |
| @main | Y | - | Platform-specific entry points instead |
| DocumentGroup | Y | - | |
| Settings | Y | - | macOS only in SwiftUI |
| Commands / menus | Y | Y | GTK4: GtkPopoverMenuBar; Win32: HMENU. M2.1 |
| @FocusedValue / .focusedValue() | Y | Y | Active-window-scoped state. GTK4 + Win32. M2.1 |
| .keyboardShortcut() | Y | Y | Window-scoped registry. GTK4: GtkEventControllerKey; Win32: ACCEL. M1 |
| .dropDestination(for:) | Y | Y | URL payloads. GTK4: GtkDropTarget; Win32: OLE IDropTarget. M3 |
| Image(systemName:) | Y | ~ | macOS: native SF Symbols via SwiftUI. GTK4: bundled Material Symbols font loads process-locally (M-Symbols-1, packaging only); SF→Material name mapping phased (M-Symbols-3). Win32/Web/Android packaging deferred. See `docs/architecture/icon-symbols.md` |
| Image(material:) | N/A (SwiftOpenUI-specific) | ~ | Direct Material Symbols name rendering on non-macOS. API shipped; GTK4 renders glyphs via Pango + SwiftOpenUISymbols font. Win32/Web/Android render text placeholder pending per-backend font adoption. macOS renders placeholder — use `Image(systemName:)` instead. M-Symbols-2 |

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
| Views | 45 | 44 | 44 | 43 | ~98% |
| Modifiers | 40 | 38 | 38 | 38 | ~95% |
| State & Data | 14 | 11 | 11 | 11 | ~79% |
| Navigation | 8 | 7 | 7 | 7 | 88% |
| App structure | 10 | 6 | 6 | 6 | 60% |
| Layout system | 9 | 7 | 7 | 7 | ~78% |
