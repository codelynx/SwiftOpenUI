# Screenshot Comparison: macOS vs Win32

Side-by-side comparison of all Showcase and Parity examples.
Screenshots taken 2026-03-19 with latest develop branch.

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
| Reset/Start buttons | Rounded, colored bg, white text | Flat, colored bg, white text | Good |
| Divider | Subtle thin line | Subtle thin line | OK |
| Overall | Polished dark UI | Very close match | A- |

### 3. Color Studio

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Dark background | Full coverage | Full coverage | OK |
| Color swatch | Large blue rect 120x80 | Large blue rect 120x80 | OK |
| RGB sliders | SwiftUI native (colored track) | D2D custom (blue accent, white thumb) | Good |
| Slider background | Blends with dark bg | Blends with dark bg | OK |
| Swatches grid | Centered, evenly spaced | Centered, evenly spaced | OK |
| Lighter/Darker buttons | Rounded bordered | Flat colored | Minor |
| Color harmony | Centered columns | Centered columns | OK |
| Overall | Reference quality | Very close match | A |

## Parity Examples

### 4. ViewsBasic

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Text (plain/bold/colored) | Correct | Correct | OK |
| Large title / Caption | Correct sizes | Correct sizes | OK |
| Button (string label) | Rounded | Native Win32 button | OK |
| Button (custom label) | "Custom label ->" colored bg | Shows as "->" only (text rendering issue) | Gap |
| TextField | Placeholder visible | Placeholder not visible until focus | Minor |
| Color swatches | Two rows D2D | Two rows D2D | OK |
| Spacer (Left/Right) | Full width dark bar | Full width dark bar | OK |
| Divider | Thin line | Thin line | OK |
| Overall | Complete | Mostly complete | B+ |

### 5. ViewsLayout

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| VStack (leading/center/trailing) | 3 aligned columns | 3 aligned columns | OK |
| HStack (A/B/C) | Colored boxes in row | Colored boxes in row | OK |
| ZStack | "Top" overlaid on green | White box on green (text not visible) | Gap -- ZStack text overlay |
| Group items | 3 green items | 3 green items | OK |
| ForEach (0/1/2) | Purple numbered boxes | Purple numbered boxes | OK |
| +/- buttons | Working | Working | OK |
| AnyView | Orange text | Orange text | OK |
| EmptyView | "Before After" inline | "Before After" inline | OK |
| Overall | Complete | Nearly complete | B+ |

### 6. ViewsContainers

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Toggle | Checkbox + "Enabled" | Checkbox + "Enabled" | OK |
| Value: ON/OFF | Green text | Green text | OK |
| Slider | Native SwiftUI | D2D custom (blue/white) | Good |
| Blue bar driven by slider | Blue bar below | Blue bar below | OK |
| Image (system) | SF Symbols (star, heart, gear) | Text fallback [starred] etc. | Gap -- GTK icon names not Win32 icons |
| ScrollView | Dark scrollable list | Scrollable list | OK |
| List | 3 items with +/- | 3 items with +/- | OK |
| Overall | Complete | Good | B |

### 7. Modifiers

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| .padding() | 3 colored boxes | 3 colored boxes | OK |
| .frame() | "60x30" + "Flex" | "60x30" missing text + "Flex" | Gap -- frame text |
| .foregroundColor() | Red/Blue/Custom | Red/Blue/Custom | OK |
| .foregroundStyle() | Green text | Green text | OK |
| .background() | Yellow/Custom bg | Yellow/Custom bg | OK |
| .font() sizes | All 6 sizes | All 6 sizes | OK |
| .border() | Red/Blue borders | Red/Blue borders | OK |
| .opacity() | 100/70/40/15% | 100/70/40/15% | OK |
| .offset() | Orange shifted text | Orange shifted text | OK |
| .scaleEffect() | 1.0x/1.5x/0.7x | 1.0x/1.5x/0.7x | OK |
| .modifier() | Green highlighted | Green highlighted | OK |
| Overall | All 11 modifiers shown | All 11 modifiers shown | A- |

### 8. StateData

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| @State counter +/- | Working | Working | OK |
| Toggle text/flag | Working | Working | OK |
| Conditional view | "Visible when ON" green | "Visible when ON" green | OK |
| @Binding parent/child | Working | Working | OK |
| @StateObject + @Published | Store count + label | Store count + label | OK |
| Title "State & Data" | Ampersand renders | Shows "State _Data" | Minor -- `&` encoding |
| Overall | All state types shown | All state types working | A- |

### 9. Navigation

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| NavigationLink | "Go to Alpha/Beta" | "Go to Alpha/Beta" | OK |
| NavigationPath | "Path depth: 0", Push 42/99 | Same | OK |
| NavigateAction | Description text | Description text | OK |
| Navigation title | "Navigation" in title bar | "Home" header bar | Minor -- different title display |
| Overall | Clean navigation demo | Functional | B+ |

### 10. Environment

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Custom accent colors | Blue/Red/Green | Blue/Red/Green | OK |
| Toggle accent | Working | Working | OK |
| EnvironmentObject | Theme + font size | Theme + font size | OK |
| Propagation | "Nested child sees accent" | "Nested child sees accen" (truncated) | Minor |
| Overall | Complete | Complete | A- |

### 11. Gestures

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Tap (blue) | "Tap me (0)" | "Tap me (0)" | OK |
| Double-tap (green) | "Double-tap me (0)" | "Double-tap me (0)" | OK |
| Long press (red) | "Long press me (0)" | "Long press me (0)" | OK |
| 1s duration | "With 1s duration (0)" | "With 1s duration (0)" | OK |
| Drag | "(not available on macOS)" | "Drag me" + offset display | OK -- Win32 has more |
| Overall | Core gestures | All gestures including drag | A |

### 12. Animation

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Fade (opacity) | Blue "Fade" + Toggle | Blue "Fade" + Toggle | OK |
| Scale | Green "Scale" + Toggle | Green "Scale" + Toggle | OK |
| Slide (offset) | Orange "Slide" + Toggle | Missing "Slide" label | Gap -- offset view not showing |
| withAnimation | Purple "Animated" + button | Missing "Animated" label | Gap -- withAnimation view not showing |
| Overall | 4 animations shown | 2 of 4 visible | B- |

### 13. Focus

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| @FocusState (Bool) | TextField with placeholder | TextField (no placeholder) | Minor |
| Focused: YES/NO | Working | Working | OK |
| Focus/Unfocus buttons | Working | Working | OK |
| @FocusState (enum) | 3 labeled TextFields | 3 TextFields (no labels) | Gap -- placeholder not showing |
| Active: None/Name/Email/Notes | Working | Working | OK |
| Name/Email/Notes/Clear buttons | Working | Working | OK |
| Overall | Full focus demo | Functional, missing labels | B |

### 14. AppStructure

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
| A | ColorStudio, Gestures, AppStructure |
| A- | Stopwatch, Modifiers, StateData, Environment |
| B+ | ViewsBasic, ViewsLayout, Navigation |
| B | ViewsContainers, Focus |
| B- | Animation |
| Gap | HelloWorld (centering only) |

## Top Issues to Fix Next

1. **Animation** -- offset/withAnimation views not rendering (most visible gap)
2. **Focus** -- TextField placeholders not showing
3. **HelloWorld** -- root content centering in window
4. **ViewsContainers** -- Image system names use GTK names in `#else` block, not Win32 stock icons
5. **ZStack** -- text overlay not visible (white-on-white inside ZStack)
6. **StateData** -- ampersand in title not rendering (shows underscore)
7. **Custom Button labels** -- text inside custom-label buttons partially missing
8. **Frame text** -- text inside `.frame()` not visible in some cases

## Platform Differences (Expected)

These are inherent Win32 vs SwiftUI differences, not bugs:
- Button style: Win32 native pushbuttons vs SwiftUI rounded buttons
- Font weight: `.thin` weight not available in Win32 text pipeline
- TextField: Win32 EDIT controls vs SwiftUI text fields (visual styling)
- Slider: D2D custom slider is close but not identical to SwiftUI native
- Window chrome: Win32 title bar vs macOS traffic lights
