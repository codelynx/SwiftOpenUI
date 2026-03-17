# Examples Reorganization Plan

## Problem

The current examples are loosely organized:
- `HelloWorld` — minimal text + padding
- `Counter` — @State + button
- `Showcase1` — mixed bag: text, button, state, font, color, spacer, divider
- `Showcase2` — mixed bag: HStack, ForEach, ZStack, frame, background

No clear theme per example. Features overlap. Hard to know what's tested where. Doesn't scale as we add views and modifiers.

## Principles

1. **One theme per example** — each example demonstrates a specific category
2. **Single source, all platforms** — every example is one `main.swift` with `#if` import/entry-point boilerplate. View code is shared across macOS, Linux, Windows, and Web.
3. **Progressive complexity** — start simple, build up
4. **Every framework feature exercised** — if it exists in SwiftOpenUI, an example uses it
5. **Platform limitations labeled inline** — if a feature isn't available on a platform, the view shows a message instead of failing to compile:
   ```swift
   #if os(macOS)
   Canvas { context, size in ... }
   #else
   Text("Canvas not yet available on this platform")
       .foregroundColor(.gray)
   #endif
   ```
6. **Always compiles, always runs** — no example should fail to build on any supported platform
7. **Practical patterns** — real-world-ish apps, not just feature demos

## Proposed Structure

```
Examples/
├── 01-HelloWorld/          # Entry point: minimal app
├── 02-TextStyles/          # Text, Font, Color
├── 03-Buttons/             # Button, actions, labels
├── 04-State/               # @State, @Binding, reactivity
├── 05-Layout/              # VStack, HStack, ZStack, Spacer, alignment
├── 06-Lists/               # ForEach, Group, dynamic content
├── 07-Modifiers/           # padding, frame, foreground, background, border
├── 08-Environment/         # @EnvironmentObject, .environment(), custom keys
├── 09-ObservableObject/    # @ObservedObject, @StateObject, @Published
├── 10-Composition/         # Custom views, ViewModifier, AnyView, conditionals
├── 11-Calculator/          # Real app: layout grid, state, interaction
└── 12-PlatformTest/        # Platform-specific stress tests
```

## Example Details

### 01-HelloWorld
**Theme:** Minimal working app
**Features:** App, WindowGroup, Text, .padding()
**Keep as-is** — this is the first thing people run.

### 02-TextStyles
**Theme:** Typography and color
**Features:**
- Text with all Font presets (.largeTitle, .title, .title2, .title3, .headline, .subheadline, .body, .callout, .footnote, .caption, .caption2)
- Font.system(size:weight:design:) custom fonts
- .foregroundColor() / .foregroundStyle() with named colors
- Color.opacity()

### 03-Buttons
**Theme:** User interaction
**Features:**
- Button with string label
- Button with custom label (ViewBuilder)
- Button triggering state changes
- Multiple buttons in a layout
- Enabled/disabled styling (future)

### 04-State
**Theme:** Reactive state management
**Features:**
- @State with Int (counter)
- @State with String (text toggle)
- @State with Bool (toggle visibility)
- @Binding (parent ↔ child two-way)
- @FocusState (focus tracking)
- Multiple @State properties in one view
- State driving conditional rendering (if/else in ViewBuilder)

### 05-Layout
**Theme:** Spatial arrangement
**Features:**
- VStack with alignment (.leading, .center, .trailing)
- HStack with alignment (.top, .center, .bottom)
- VStack/HStack with custom spacing
- ZStack (layering)
- Spacer (flexible space, pushing content)
- Divider
- Nested stacks (VStack inside HStack inside VStack)
- .frame(width:height:) fixed sizing
- .frame(minWidth:maxWidth:) flexible sizing

### 06-Lists
**Theme:** Dynamic and repeated content
**Features:**
- ForEach with Range (0..<N)
- ForEach with Identifiable data
- ForEach with custom id keyPath
- Group (flattening children)
- Dynamic list that grows/shrinks via @State

### 07-Modifiers
**Theme:** View decoration and sizing
**Features:**
- .padding() uniform
- .padding(.horizontal, 10) edge-specific
- .padding(top:bottom:leading:trailing:) per-edge
- .frame(width:height:)
- .foregroundColor()
- .background()
- .font()
- .border()
- Modifier stacking order (background before padding vs after)
- Custom ViewModifier

### 08-Environment
**Theme:** Dependency injection down the view tree
**Features:**
- .environment(\.colorScheme, .dark)
- @Environment(\.colorScheme) reading
- .environmentObject() injection
- @EnvironmentObject reading
- Custom EnvironmentKey
- Environment propagation through nested views

### 09-ObservableObject
**Theme:** External state objects
**Features:**
- Class conforming to ObservableObject with @Published
- @ObservedObject — external object, view rebuilds on change
- @StateObject — view-owned object, persists across rebuilds
- Multiple @Published properties
- Superclass @Published wiring (inherited properties)

### 10-Composition
**Theme:** Building reusable components
**Features:**
- Extracting views into reusable structs
- Custom ViewModifier (modifier(MyModifier()))
- AnyView (type erasure)
- _ConditionalView (if/else branches)
- Optional view rendering
- Composing small views into larger screens

### 11-Calculator
**Theme:** A real app — layout grid, state, interaction
**Features:**
- Button grid (4x5) using nested HStack/VStack (or Grid when available)
- @State for display value and accumulator
- Button actions driving computation
- .font(), .foregroundColor(), .background(), .frame() on every cell
- Exercises layout precision across platforms

### 12-PlatformTest
**Theme:** Cross-platform rendering validation
**Features:**
- Color rendering (named colors, custom RGB, opacity)
- Font rendering at all sizes
- Nested layout stress test (deep nesting)
- Wide content (many horizontal items)
- Long content (many vertical items)
- Empty views, spacers at edges
- Modifier stacking edge cases

## Feature Coverage Matrix

| Feature | Current Example | Proposed Example |
|---------|----------------|-----------------|
| Text | HelloWorld, Showcase1, Showcase2 | 01, 02 |
| Button | Counter, Showcase1 | 03, 04 |
| @State | Counter, Showcase1 | 04 |
| @Binding | — | 04 |
| VStack | Counter, Showcase1, Showcase2 | 05 |
| HStack | Showcase2 | 05 |
| ZStack | Showcase2 | 05 |
| Spacer | Showcase1 | 05 |
| Divider | Showcase1, Showcase2 | 05 |
| ForEach | Showcase2 | 06 |
| Group | — | 06 |
| .padding() | HelloWorld, Counter, Showcase1, Showcase2 | 07 |
| .frame() | Showcase2 | 07 |
| .foregroundColor() | Showcase1 | 02, 07 |
| .background() | Showcase2 | 07 |
| .font() | Showcase1, Showcase2 | 02, 07 |
| .border() | — | 07 |
| Color | Showcase2 | 02 |
| Color.opacity() | Showcase2 | 02 |
| @EnvironmentObject | — | 08 |
| @Environment | — | 08 |
| .environmentObject() | — | 08 |
| @ObservedObject | — | 09 |
| @StateObject | — | 09 |
| @Published | — | 09 |
| ViewModifier | — | 10 |
| AnyView | — | 10 |
| _ConditionalView | — | 10 |
| Optional view | — | 10 |
| @FocusState | — | 04 |

## Migration Strategy

1. Keep `HelloWorld` as-is (01)
2. Remove `Counter` (absorbed into 04-State)
3. Replace `Showcase1` and `Showcase2` with the new themed examples
4. Add new examples incrementally — don't need all 12 at once
5. Update Package.swift executable targets as examples are added/removed
6. Each example is self-contained: one `main.swift`, same boilerplate import/entry-point pattern

## Priority Order

1. **01-HelloWorld** — keep (done)
2. **04-State** — counter + toggle + conditional (replaces Counter example)
3. **05-Layout** — most visual, validates backends
4. **07-Modifiers** — tests modifier stacking and rendering
5. **02-TextStyles** — typography across platforms
6. **03-Buttons** — interaction patterns
7. **06-Lists** — dynamic content
8. **08-Environment** — currently untested in examples
9. **09-ObservableObject** — currently untested in examples
10. **10-Composition** — advanced patterns
11. **11-Calculator** — real app, exercises layout + state + interaction
12. **12-PlatformTest** — backend validation

## Future Examples (blocked on new APIs)

These examples require features not yet in SwiftOpenUI. They are roadmap drivers, not current candidates. They will be added to the examples list once the required APIs ship.

### PaintSwift
**Requires:** Canvas/drawing view, gesture handlers (onDrag, onTapGesture)
**Drives:** gesture API, canvas rendering, platform-specific drawing extensions
**Features:**
- Canvas/drawing area
- Drag-to-draw gesture
- Color picker (grid of swatches)
- @State for stroke list, current color
- Would exercise every platform's native drawing path
