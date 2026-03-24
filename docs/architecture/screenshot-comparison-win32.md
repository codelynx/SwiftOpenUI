# Screenshot Comparison: macOS vs Win32

Side-by-side comparison of all Showcase and Parity examples.
Screenshots recaptured 2026-03-22 with PrintWindow + DWM crop (no shadow/bleed).

Reference: `screenshots/macos/` (real SwiftUI) vs `screenshots/windows/` (SwiftOpenUI Win32 backend)

## Showcase Examples

### 1. HelloWorld

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Title bar | "Hello World" | "Hello World" | OK |
| Text content | Centered in window | Top-left aligned | Gap -- no implicit window centering |
| Overall | Clean minimal | Functional | B |

### 2. Stopwatch

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Dark background | Fills entire window | Fills entire window | OK |
| Timer "00:00.00" | Centered, thin weight | Centered, regular weight | Minor -- font weight |
| Reset button | Orange, rounded | Orange, flat | OK |
| Start button | Green, rounded | Green, flat | OK |
| Divider | Subtle thin line | Subtle thin line | OK |
| Timer ticking | Works | Works (Foundation Timer + RunLoop) | OK |
| Overall | Polished dark UI | Very close match | A- |

### 3. Color Studio

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Dark background | Full coverage | Full coverage | OK |
| Color swatch | Large blue rect 120x80 | Large blue rect 120x80 | OK |
| RGB sliders | SwiftUI native (colored track) | D2D custom (blue accent, white thumb) | Good |
| Slider background | Blends with dark bg | Blends with dark bg (inherited) | OK |
| Swatches grid | Centered, evenly spaced | Centered, evenly spaced | OK |
| Lighter/Darker buttons | Rounded bordered | Flat colored | Minor |
| Color harmony | Centered columns | Centered columns | OK |
| Overall | Reference quality | Very close match | A |

### 4. Calculator

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Dark background | Full window | Full window | OK |
| Display "0" | Right-aligned | Right-aligned | OK |
| Button grid 4x5 | Even grid | Even grid | OK |
| AC/+/-/% row | Gray buttons | Gray buttons | OK |
| Orange operators | /, x, -, +, = | /, x, -, +, = | OK |
| Window sizing | Exact fit | Exact fit (contentFixed) | OK |
| Overall | Reference quality | Close match | A- |

## Parity Examples

### 5. ViewsBasic

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Text (plain/bold/colored) | Correct | Correct | OK |
| Large title / Caption | Correct sizes | Correct sizes | OK |
| Button (string label) | Rounded | Native Win32 button | OK |
| Button (custom label) | "Custom label ->" colored bg | Shows as "->" only | Open -- custom label text |
| TextField | Placeholder "Type here..." | Placeholder "Type here..." | OK |
| Color swatches | Two rows D2D | Two rows D2D | OK |
| Spacer (Left/Right) | Full width dark bar | Full width dark bar | OK |
| Divider | Thin line | Thin line | OK |
| Overall | Complete | Mostly complete | B+ |

### 6. ViewsLayout

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| VStack (leading/center/trailing) | 3 aligned columns | 3 aligned columns | OK |
| HStack (A/B/C) | Colored boxes in row | Colored boxes in row | OK |
| ZStack | "Top" on green/blue | "Top" on green/blue | OK |
| Group items | 3 green items | 3 green items | OK |
| ForEach (0/1/2) | Purple numbered boxes | Purple numbered boxes | OK |
| +/- buttons | Working | Working | OK |
| AnyView | Orange text | Orange text | OK |
| EmptyView | "Before After" inline | "Before After" inline | OK |
| Overall | Complete | Complete | A |

### 7. ViewsContainers

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Toggle | Checkbox + "Enabled" | Checkbox + "Enabled" | OK |
| Value: ON/OFF | Green text | Green text | OK |
| Slider | Native SwiftUI | D2D custom (blue/white) | Good |
| Blue bar driven by slider | Blue bar below | Blue bar below | OK |
| Image (system) | SF Symbols (star, heart, gear) | Win32 stock icons (info, warning, shield) | OK |
| ScrollView | Dark scrollable list | Scrollable list | OK |
| List | 3 items with +/- | 3 items with +/- | OK |
| Overall | Complete | Complete | A- |

### 8. Modifiers

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| .padding() | 3 colored boxes | 3 colored boxes | OK |
| .frame() | "60x30" + "Flex" | "D0x30" (x glyph issue) + "Flex" | Open -- Unicode rendering |
| .foregroundColor() | Red/Blue/Custom | Red/Blue/Custom | OK |
| .foregroundStyle() | Green text | Green text | OK |
| .background() | Yellow/Custom bg | Yellow/Custom bg | OK |
| .font() sizes | All 6 sizes | All 6 sizes | OK |
| .border() | Red/Blue borders | Red/Blue borders | OK |
| .opacity() | 100/70/40/15% | 100/70/40/15% | OK |
| .offset() | Orange shifted text | Orange shifted text | OK |
| .scaleEffect() | 1.0x/1.5x/0.7x | 1.0x/1.5x/0.7x | OK |
| .modifier() | Green highlighted | Green highlighted | OK |
| Overall | All 11 modifiers shown | 10 of 11 correct | A- |

### 9. StateData

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| @State counter +/- | Working | Working | OK |
| Toggle text/flag | Working | Working | OK |
| Conditional view | "Visible when ON" green | "Visible when ON" green | OK |
| @Binding parent/child | Working | Working | OK |
| @StateObject + @Published | Store count + label | Store count + label | OK |
| Title "State & Data" | Ampersand renders | Ampersand renders | OK |
| Overall | All state types working | All state types working | A |

### 10. Navigation

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| NavigationLink | "Go to Alpha/Beta" | "Go to Alpha/Beta" | OK |
| NavigationPath | "Path depth: 0", Push 42/99 | Same | OK |
| NavigateAction | Description text | Description text | OK |
| Navigation title | "Navigation" in header | "Navigation" in header | OK |
| Overall | Clean navigation demo | Functional | A- |

### 11. Environment

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Custom accent colors | Blue/Red/Green | Blue/Red/Green | OK |
| Toggle accent | Working | Working | OK |
| EnvironmentObject | Theme + font size | Theme + font size | OK |
| Propagation | "Nested child sees accent" | "Nested child sees accent" | OK |
| Overall | Complete | Complete | A- |

### 12. Gestures

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Tap (blue) | "Tap me (0)" | "Tap me (0)" | OK |
| Double-tap (green) | "Double-tap me (0)" | "Double-tap me (0)" | OK |
| Long press (red) | "Long press me (0)" | "Long press me (0)" | OK |
| 1s duration | "With 1s duration (0)" | "With 1s duration (0)" | OK |
| Drag | "(not available on macOS)" | "Drag me" + offset display | OK -- Win32 has more |
| Overall | Core gestures | All gestures including drag | A |

### 13. Animation

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Fade (opacity) | Blue "Fade" + Toggle | Blue "Fade" + Toggle | OK |
| Scale | Green "Scale" + Toggle | Green "Scale" + Toggle | OK |
| Slide (offset) | Orange "Slide" + Toggle | Orange "Slide" + Toggle | OK |
| withAnimation | Purple "Animated" + button | Purple "Animated" + button | OK |
| Overall | 4 animations shown | 4 animations shown | A- |

### 14. Focus

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| @FocusState (Bool) | TextField with placeholder | TextField with placeholder | OK |
| Focused: YES/NO | Working | Working | OK |
| Focus/Unfocus buttons | Working | Working | OK |
| @FocusState (enum) | 3 labeled TextFields | 3 labeled TextFields | OK |
| Active: None/Name/Email/Notes | Working | Working | OK |
| Name/Email/Notes/Clear buttons | Working | Working | OK |
| Overall | Full focus demo | Full focus demo | A- |

### 15. AppStructure

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Bullet list | 4 bullet items | 4 bullet items | OK |
| @ViewBuilder | Child 1, Child 2 | Child 1, Child 2 | OK |
| Condition true/false | Green/Red text | Green/Red text | OK |
| Optional: visible | Blue text | Blue text | OK |
| Numbers 1-6 | Colored row | Colored row | OK |
| Overall | Complete | Complete | A |

## Summary

| Rating | Examples |
|--------|----------|
| A | ColorStudio, ViewsLayout, StateData, Gestures, AppStructure |
| A- | Stopwatch, Calculator, ViewsContainers, Modifiers, Navigation, Environment, Animation, Focus |
| B+ | ViewsBasic |
| B | HelloWorld (centering) |

## Remaining Open Issues

| # | Issue | Type | Effort |
|---|-------|------|--------|
| 1 | HelloWorld centering | Architectural -- layout model (top-down proposal) | Hard |
| 2 | Modifiers "D0x30" | Unicode multiplication sign glyph rendering | Low-Med |
| 3 | ViewsBasic custom button label | Custom label text partially missing in button | Medium |

## All Fixes Applied

| Fix | Commit | Impact |
|-----|--------|--------|
| OffsetView (0,0) orphan | `39ef76c` | Animation B- -> A- |
| ComCtl32 v6 visual styles | `c795721` | Focus B -> A- |
| ZStack HOLLOW_BRUSH | `dad6bb6` | ViewsLayout B+ -> A |
| D2D custom slider | `62e572c` | All slider examples improved |
| Shared layout migration | `a393333` | FrameView/VStack/HStack/ZStack on shared helpers |
| SS_NOPREFIX for & rendering | `f0b42ec` | StateData A- -> A |
| Win32 stock icons | `d5aa146` | ViewsContainers B+ -> A- |
| Navigation title extraction | `3e4c5b0` | Navigation B+ -> A- |
| Window sizing for explicit sizes | `3e4c5b0` | Calculator gutters fixed |
| FrameView expand propagation | `cded1d1` | Calculator right-align fixed |
| Slider background inheritance | `62e572c` | ColorMixer slider blends |
| ForegroundColor WM_CTLCOLORSTATIC | session fix | Stopwatch buttons visible |
| Phase 6 dependency tracking | `d2b52d5` | Aligned with GTK4/Web |
| Phase 7 input-equality | `d25c1d1` | Aligned with GTK4/Web |
| Slot validation | `785990b` | Aligned with GTK4/Web |
| Shadow-free screenshots | `db47b65` | Clean captures via PrintWindow |

## Platform Differences (Expected)

These are inherent Win32 vs SwiftUI differences, not bugs:
- Button style: D2D flat buttons with rounded corners (close to SwiftUI but not identical)
- Font weight: .thin weight not available in Win32 text pipeline
- TextField: Win32 EDIT controls vs SwiftUI text fields (visual styling)
- Slider: D2D custom slider is close but not identical to SwiftUI native
- Window chrome: Win32 title bar vs macOS traffic lights
