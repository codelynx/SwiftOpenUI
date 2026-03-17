# Examples Implementation Phases

Each phase ends with a push to `develop`. The user tests on macOS/Windows/Web, reviews, fixes, and merges back before the next phase starts.

## Phase 1 — Core examples (pure existing API)

Uses only views and modifiers already in SwiftOpenUI. No new API needed. Primary goal: validate rendering across all platforms.

| Example | Theme | Key Features |
|---------|-------|-------------|
| 01-HelloWorld | Minimal app | App, WindowGroup, Text, .padding() |
| 02-TextStyles | Typography and color | All Font presets, .foregroundColor(), Color.opacity() |
| 03-Buttons | User interaction | String label, custom label (ViewBuilder), actions |
| 04-State | Reactive state | @State (Int, String, Bool), @Binding, conditional rendering |
| 05-Layout | Spatial arrangement | VStack, HStack, ZStack, Spacer, Divider, .frame(), alignment |

## Phase 2 — Advanced patterns (still existing API)

Exercises deeper features that haven't been tested in examples yet. Good for catching wiring bugs across platforms.

| Example | Theme | Key Features |
|---------|-------|-------------|
| 06-Lists | Dynamic content | ForEach (range, Identifiable, keyPath), Group, dynamic add/remove |
| 07-Modifiers | View decoration | .padding() variants, .frame(), .foregroundColor(), .background(), .font(), .border(), stacking order, custom ViewModifier |
| 08-Environment | Dependency injection | .environment(), @Environment, .environmentObject(), @EnvironmentObject, custom EnvironmentKey |
| 09-ObservableObject | External state | @ObservedObject, @StateObject, @Published, superclass wiring |
| 10-Composition | Reusable components | Custom view structs, ViewModifier, AnyView, _ConditionalView, Optional view |

## Phase 3 — Real apps (may need new API)

Calculator may push us to add Grid or new layout features. PlatformTest is a stress test for edge cases.

| Example | Theme | Key Features |
|---------|-------|-------------|
| 11-Calculator | Real app | Button grid (4x5), @State for display/accumulator, layout precision |
| 12-PlatformTest | Cross-platform validation | Color rendering, font sizes, deep nesting, wide/long content, edge cases |
