# Roadmap

## Completed

- Core framework: View, State, Binding, ObservedObject, StateObject, EnvironmentObject, Environment
- ViewBuilder (`buildPartialBlock` + `ViewList` accumulation, no fixed child-count ceiling), App/Scene/WindowGroup
- Views: Text, Button, TextField, VStack, HStack, ZStack, Spacer, Divider, Color, Group, ForEach, AnyView
- Modifiers: padding, frame, foregroundColor, foregroundStyle, background, font, border
- GTK4 backend (Linux) — full rendering + reactive rebuilds + focus preservation + navigation + gestures + animation (CSS transitions)
- GTK4: Navigation — NavigationStack, NavigationLink, NavigationPath, .navigationTitle(), .navigationDestination(for:)
- GTK4: Gestures — .onTapGesture(), .onLongPressGesture(), .onDrag(minimumDistance:)
- GTK4: Animation — withAnimation(), .animation(), .opacity(), .offset(), .scaleEffect()
- GTK4+Win32: Toggle, Slider, ScrollView, List, Image (+ .imageScale())
- Win32 backend (Windows) — full rendering + layout engine + reactive rebuilds
- Win32: Navigation — NavigationStack, NavigationLink, NavigationPath, .navigationTitle(), .navigationDestination(for:)
- Win32: Gestures — .onTapGesture(), .onLongPressGesture(), .onDrag() with recursive subclassing
- Win32: Animation — withAnimation(), .animation(), .opacity(), .scaleEffect() via D2D surface + SetTimer 60fps
- Win32: Phase 4 parity — SecureField, TextEditor, Stepper, ProgressView, Picker, Label, Link, TabView, Grid, GridRow, Canvas, Menu, DisclosureGroup, DatePicker, GeometryReader, LazyStacks, LazyGrids, Form, Section
- Win32: Modifiers — .cornerRadius() (SetWindowRgn), .shadow() (layered alpha), .rotationEffect() (D2D SetTransform), .pickerStyle() (segmented radio buttons), .gridCellColumns(), .searchable(), .toolbar(), .sheet(), .alert(), .overlay(), .onAppear(), .onDisappear()
- macOS support — examples use real SwiftUI via conditional compilation
- Web/Wasm backend (experimental) — DOM rendering via JavaScriptKit, verified in browser
- `./configure` script — automated toolchain + Wasm SDK setup

## Next

### Views & Modifiers — Completed (Phase 3 & 4)
- ~~.clipShape()~~ — done
- ~~.clipped()~~ — done
- ~~.hidden(), .blur()~~ — done (blur: Win32 pass-through)
- ~~lineLimit, truncationMode, lineSpacing, multilineTextAlignment~~ — done
- ~~Circle, Rectangle, RoundedRectangle, Capsule, Ellipse~~ — done (Shape protocol + .fill()/.stroke())
- ~~.buttonStyle(), .toggleStyle(), .textFieldStyle()~~ — done (environment-based enums)
- ~~.onChange()~~ — done
- ~~.contextMenu()~~ — done
- ~~.popover()~~ — done
- ~~.position(), .layoutPriority(), .fixedSize()~~ — done (layoutPriority API only, engine deferred)
- ~~ScrollViewReader, .id(), ScrollViewProxy~~ — done

- ~~.fullScreenCover()~~ — done (GTK: fullscreen modal; Win32: WS_POPUP + WS_EX_TOPMOST; Web: fixed overlay)
- ~~.bold(), .italic(), .fontWeight(), .underline(), .strikethrough(), .textCase()~~ — done
- ~~LinearGradient, RadialGradient~~ — done (Win32: solid first-stop approximation)
- ~~.aspectRatio(), .scaledToFit(), .scaledToFill()~~ — done

### Views & Modifiers — Remaining
- .task() — needs Swift async runtime integration
- Canvas: stroke styles (line caps, joins, dash), bezier/quadratic curves, rotate/translate transforms

### State & Data
- Resolve ObservableObject/Published namespace conflict on macOS (see `docs/issues/`)
- @AppStorage, @SceneStorage

### Backends
- Web: release build optimization (reduce from 59MB debug)
- Web: serve workflow (dev server with hot reload)
- Android: core library cross-compiles (see [setup guide](guides/android-setup.md)); backend design complete (see [design doc](architecture/android-backend-design.md)); Phase 1 implementation pending (Text, Button, VStack/HStack, @State via batched JNI diffs to Kotlin host)

### Infrastructure
- CI: GitHub Actions for macOS + Linux + Wasm builds
- CI: automated test runs on all platforms
- Release build pipeline for Wasm (wasm-opt, strip)
