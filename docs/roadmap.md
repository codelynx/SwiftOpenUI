# Roadmap

## Completed

- Core framework: View, State, Binding, ObservedObject, StateObject, EnvironmentObject, Environment
- ViewBuilder (up to 12 children), App/Scene/WindowGroup
- Views: Text, Button, TextField, VStack, HStack, ZStack, Spacer, Divider, Color, Group, ForEach, AnyView
- Modifiers: padding, frame, foregroundColor, foregroundStyle, background, font, border
- GTK4 backend (Linux) — full rendering + reactive rebuilds + focus preservation + navigation + gestures + animation (CSS transitions)
- GTK4: Navigation — NavigationStack, NavigationLink, NavigationPath, .navigationTitle(), .navigationDestination(for:)
- GTK4: Gestures — .onTapGesture(), .onLongPressGesture(), .onDrag(minimumDistance:)
- GTK4: Animation — withAnimation(), .animation(), .opacity(), .offset(), .scaleEffect()
- Win32 backend (Windows) — full rendering + layout engine + reactive rebuilds
- macOS support — examples use real SwiftUI via conditional compilation
- Web/Wasm backend (experimental) — DOM rendering via JavaScriptKit, verified in browser
- `./configure` script — automated toolchain + Wasm SDK setup

## Next

### Views & Modifiers
- Toggle/Switch, Slider
- List, ScrollView
- Image (with platform-native image loading)
- Rotation modifier
- DragGesture (SwiftUI-style Gesture protocol)

### State & Data
- Resolve ObservableObject/Published namespace conflict on macOS (see `docs/issues/`)
- @AppStorage, @SceneStorage

### Backends
- Win32/Web: port navigation, gesture, and animation rendering (core types exist, GTK4 backend done)
- Web: release build optimization (reduce from 59MB debug)
- Web: serve workflow (dev server with hot reload)
- Android: core library cross-compiles (see [setup guide](guides/android-setup.md)); backend design complete (see [design doc](architecture/android-backend-design.md)); Phase 1 implementation pending (Text, Button, VStack/HStack, @State via batched JNI diffs to Kotlin host)

### Infrastructure
- CI: GitHub Actions for macOS + Linux + Wasm builds
- CI: automated test runs on all platforms
- Release build pipeline for Wasm (wasm-opt, strip)
