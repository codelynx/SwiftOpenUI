# Screenshot Comparison: macOS vs Web (Wasm)

Side-by-side comparison of all Showcase and Parity examples.
Screenshots recaptured 2026-03-20 after rendering fixes (viewport fill, Button reset, Frame centering, Group display:contents).

Reference: `screenshots/macos/` (real SwiftUI) vs `screenshots/web/` (SwiftOpenUI Web/Wasm backend)

Note: parity-Modifiers times out during Puppeteer capture (Wasm init delay, not a build failure — the example runs when loaded manually).

## Showcase Examples

### 1. HelloWorld

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Title bar | "Hello World" in macOS chrome | No title bar (browser page) | Expected |
| Text content | Centered in window | Top-left aligned | Minor — VStack defaults to leading |
| Text "Hello, SwiftOpenUI!" | Correct | Correct | OK |
| Font rendering | SF Pro | System sans-serif | Expected |
| Overall | Clean minimal | Functional | B+ |

### 2. Stopwatch

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Dark background | Fills window with rounded corners | Fills viewport (dark bg visible) | OK |
| Timer "00:00.00" | Centered, thin weight, white text | Centered, white text | OK |
| Reset button | Orange rounded, centered text | Orange flat, centered text, no border | OK |
| Start button | Green rounded, centered text | Green flat, centered text, no border | OK |
| Button text alignment | Vertically centered | Vertically centered | OK |
| Divider | White line below buttons | White line below buttons | OK |
| Lower area | Dark, empty (no laps) | White area below dark region | Issue — bg doesn't extend to bottom |
| Overall | Polished dark UI | Good match, bottom area white | A- |

### 3. Color Studio

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Dark background | Full coverage | Full coverage | OK |
| Color swatch | Large blue rect with border | Large blue rect with border | OK |
| Hex/RGB labels | "#50A0DC R:80 G:160 B:220" | Same values, correct colors | OK |
| RGB sliders | SwiftUI native (colored track) | Browser range input (blue track) | Good — functional, different style |
| Slider labels | R/G/B colored | R/G/B colored correctly | OK |
| Color swatches grid | 2 rows, evenly spaced | 2 rows, 7+6 layout | OK |
| Lighter/Darker buttons | Rounded gray | Flat gray, no border | OK |
| Harmony row | Complementary/Analogous/Shades | Same labels and color swatches | OK |
| Overall | Reference quality | Very close match | A- |

## Parity Examples

### 4. ViewsBasic

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Text (plain/bold/colored) | Correct | Correct | OK |
| Large title / Caption | Correct sizes | Correct sizes | OK |
| Button (string label) | SwiftUI rounded | Flat button, no border | OK |
| Button (custom label) | White/green arrow | Green arrow only visible (white text on white bg) | Minor — custom label styling |
| TextField | Full-width with placeholder | Compact width with placeholder | Minor — leading alignment |
| Color swatches | Two rows, small 24px squares | Two rows, correctly colored | OK |
| Spacer | Full-width dark bar "Left / Right" | Collapsed — "LeftRight" together | Issue — Spacer still not expanding |
| Divider | Full-width thin line | Full-width thin line | OK |
| Overall | Complete | Mostly complete | B+ |

### 5. ViewsLayout

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| VStack (leading/center/trailing) | 3 aligned columns with colored boxes | 3 aligned columns, correct alignment | OK |
| HStack (A/B/C) | Colored boxes in row | Colored boxes in row | OK |
| HStack "Wide / Spacing" | Spread apart | Spread apart | OK |
| ZStack | Blue bg, green overlay, "Top" text | Blue bg, green overlay, "Top" text | OK |
| Group items | 3 cyan items, vertical | 3 cyan items, horizontal (display:contents) | Minor — still inline within VStack |
| ForEach (0/1/2) | Purple numbered boxes | Purple numbered boxes | OK |
| -/+ buttons | Working | Working | OK |
| AnyView | Green text | Green text | OK |
| EmptyView | "Before After (EmptyView between)" | "BeforeAfter (EmptyView between)" | Minor — no HStack spacing |
| Overall | Complete | Close match | B+ |

### 6. ViewsContainers

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Toggle | SwiftUI checkbox + "Enabled" | Browser checkbox + "Enabled" | OK |
| Value: ON/OFF | Green text | Green text | OK |
| Slider | SwiftUI native track | Browser range input (blue) | Good — functional |
| Blue bar driven by slider | Blue rect below slider | Blue rect below slider | OK |
| Image (system) | SF Symbols (star, heart, gear) | Text placeholders: [starred] [emblem-favorite] [preferences-system] | Expected — no browser icon theme |
| Image (file) | Fallback text | Fallback text | OK |
| ScrollView | Dark scrollable area, 4 items visible | Dark scrollable area, 3 items visible | OK |
| List | 3 items with -/+, bordered rows | 3 items with -/+, bordered rows | OK |
| Overall | Complete | Complete, Image as text placeholder | B+ |

### 7. Modifiers

**Not captured** — Wasm init times out during Puppeteer automated capture. The example builds and runs when loaded manually in browser.

### 8. StateData

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| @State counter | "Counter: 0" with -/+ | "Counter: 0" with -/+ | OK |
| Text toggle | "Text: Hello" + button | "Text: Hello" + button | OK |
| Flag toggle | "Flag: ON" + conditional text | "Flag: ON" + green conditional text | OK |
| @Binding | "Parent value: 0", child sees 0 | Same, correct binding display | OK |
| @StateObject | "Store count: 0", "Store label: Ready" | Same values | OK |
| Increment store button | Present | Present | OK |
| Overall | Complete | Complete match | A |

### 9. Navigation

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Title bar | "Navigation" in macOS chrome | "Home" in gray header bar | OK — Web header visible |
| NavigationLink buttons | "Go to Alpha", "Go to Beta" | Same, flat buttons | OK |
| Path depth | "Path depth: 0" | "Path depth: 0" | OK |
| Push 42 / Push 99 | Present | Present | OK |
| NavigateAction section | Present | Present | OK |
| Overall | Complete | Complete with header bar | A |

### 10. Environment

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Custom accent (default blue) | Blue text | Blue text | OK |
| Custom accent (red override) | Red text | Red text | OK |
| Toggle accent button | Present | Present | OK |
| Third accent (green) | Green text | Green text | OK |
| @EnvironmentObject | "Theme: Dark", "Font size: 14pt" | Same values | OK |
| Toggle/Size buttons | Present | Present | OK |
| Environment propagation | Orange "Nested child sees accent" | Orange text | OK |
| Overall | Complete | Very close match | A |

### 11. Gestures

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Tap target | Blue "Tap me (0)" | Blue "Tap me (0)" | OK |
| Double-tap target | Green "Double-tap me (0)" | Green "Double-tap me (0)" | OK |
| Long press target | Red "Long press me (0)" | Red "Long press me (0)" | OK |
| .onDrag() | macOS shows fallback text (SwiftUI conflict) | Gray "Drag me" with offset display + reset button | OK — Web has full drag support |
| Overall | Complete (minus drag on macOS) | Complete | A |

### 12. Animation

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Fade (opacity) | Blue "Fade" + Toggle | Blue "Fade" + Toggle | OK |
| Scale (scaleEffect) | Green "Scale" + Toggle | Green "Scale" + Toggle | OK |
| Offset (slide) | Orange "Slide" + Toggle (right-aligned) | Orange "Slide" + Toggle (side by side) | Minor — layout differs |
| withAnimation | Purple "Animated" + button (right-aligned) | Purple "Animated" + button (side by side) | Minor — layout differs |
| Overall | Complete | Complete, minor layout differences | A- |

### 13. Focus

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| @FocusState (Bool) | TextField + "Focused: NO" + Focus/Unfocus | TextField + "Focused: NO" + Focus/Unfocus | OK |
| TextField width | Full-width | Compact | Minor — leading alignment |
| @FocusState (enum) | 3 TextFields (Name/Email/Notes) | 3 TextFields (Name/Email/Notes) | OK |
| Active indicator | "Active: None" in blue | "Active:None" in blue (no space) | Minor — missing space |
| Focus buttons | Name/Email/Notes/Clear | Name/Email/Notes/Clear | OK |
| Overall | Complete | Complete | A- |

### 14. AppStructure

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| App + Scene + WindowGroup | 4 bullet points | 4 bullet points | OK |
| @ViewBuilder | "Child 1", "Child 2" | "Child 1", "Child 2" | OK |
| Conditional (true/false) | Green + Red text | Green + Red text | OK |
| Optional (visible) | Blue text | Blue text | OK |
| Many children (1-6) | Orange numbers in row | Orange numbers in row | OK |
| Overall | Complete | Complete match | A |

## Summary

| Example | Rating | Key Issues |
|---------|--------|-----------|
| HelloWorld | B+ | Text top-left (no centering) |
| Stopwatch | A- | Dark bg fills viewport; bottom area white |
| ColorMixer | A- | Very close match |
| ViewsBasic | B+ | Spacer not expanding in HStack context |
| ViewsLayout | B+ | Group items inline, EmptyView no spacing |
| ViewsContainers | B+ | Image renders as text placeholder (expected) |
| Modifiers | N/A | Puppeteer capture timeout (runs manually) |
| StateData | A | Complete match |
| Navigation | A | Header bar present, correct |
| Environment | A | Close match |
| Gestures | A | Full coverage, drag works on Web |
| Animation | A- | Minor layout differences |
| Focus | A- | TextField width, minor spacing |
| AppStructure | A | Complete match |

**Rating distribution:** 6x A/A-, 4x B+, 1x N/A. No D or C ratings.

## Remaining Issues

1. **Spacer in HStack** (Medium) — Spacer has `flex: 1` but doesn't expand when the parent HStack is inside a `.frame().background()` chain. The FrameView centers content, which may constrain flex expansion.
2. **Group display:contents** (Low) — Group uses `display: contents` which makes children participate in parent flex, but Text children render as inline `<span>` elements, so they flow horizontally rather than vertically.
3. **parity-Modifiers timeout** (Low) — Puppeteer automated capture times out. The example works when loaded manually. May need a longer Wasm init wait or a different wait condition.
4. **Stopwatch bottom area** (Low) — Dark background doesn't extend below the divider when there are no laps. The Spacer below the lap list should push the background down but flex:1 isn't propagating through all wrappers.
