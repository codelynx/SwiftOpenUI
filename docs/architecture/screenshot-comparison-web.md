# Screenshot Comparison: macOS vs Web (Wasm)

Side-by-side comparison of all Showcase and Parity examples.
Screenshots taken 2026-03-20 with latest develop branch.

Reference: `screenshots/macos/` (real SwiftUI) vs `screenshots/web/` (SwiftOpenUI Web/Wasm backend)

Note: parity-Modifiers is missing from Web — the Wasm build timed out during screenshot capture.

## Showcase Examples

### 1. HelloWorld

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Title bar | "Hello World" in macOS chrome | No title bar (browser page) | Expected |
| Text content | Centered in window | Top-left aligned | Issue — no centering |
| Text "Hello, SwiftOpenUI!" | Correct | Correct | OK |
| Font rendering | SF Pro | System sans-serif | Expected |
| Overall | Clean minimal | Functional, no centering | B |

### 2. Stopwatch

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Dark background | Fills window with rounded corners | Same as HelloWorld — no dark background visible | Issue — background not rendering |
| Timer "00:00.00" | Centered, thin weight, white text | Not visible (white on white) | Issue — dark bg missing |
| Buttons Reset/Start | Gray/green rounded | Not visible | Issue — dark bg missing |
| Overall | Polished dark UI | Broken — dark background not applied to page | D |

**Root cause:** The Web backend renders into a white page body. The Stopwatch's `.background(Color(...))` on the root VStack doesn't cover the full viewport. The dark theme requires the page/body background to match, or the root container to fill the viewport.

### 3. Color Studio

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Dark background | Full coverage | Full coverage with visible divider lines | OK |
| Color swatch | Large blue rect with border | Large blue rect with border | OK |
| Hex/RGB labels | "#50A0DC R:80 G:160 B:220" | Same values, correct colors | OK |
| RGB sliders | SwiftUI native (colored track) | Browser range input (blue track) | Good — functional, different style |
| Slider labels | R/G/B colored | R/G/B colored correctly | OK |
| Color swatches grid | 2 rows, 6+6 evenly spaced | 2 rows, 7+5 layout (slightly uneven) | Minor — swatch count per row differs |
| Lighter/Darker buttons | Rounded gray on dark bg | Bordered gray buttons, larger | OK |
| Harmony row | Complementary/Analogous/Shades | Same labels and color swatches | OK |
| Divider lines | Subtle | More visible (white lines on dark bg) | Minor — divider styling |
| Overall | Reference quality | Good match, functional | B+ |

## Parity Examples

### 4. ViewsBasic

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Text (plain/bold/colored) | Correct | Correct | OK |
| Large title / Caption | Correct sizes | Correct sizes, slightly larger | OK |
| Button (string label) | SwiftUI rounded | Browser button with border | OK |
| Button (custom label) | White/green on dark bg | White/green text, visible arrow | OK |
| TextField | Full-width with placeholder | Compact width with placeholder | Minor — not full-width |
| Color swatches | Two rows, small 24px squares | Two rows, correctly colored | OK |
| Spacer | Full-width dark bar "Left / Right" | Collapsed — "LeftRight" together, no spacing | Issue — Spacer not expanding in HStack |
| Divider | Full-width thin line | Full-width thin line | OK |
| Overall | Complete | Mostly complete, Spacer issue | B+ |

### 5. ViewsLayout

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| VStack (leading/center/trailing) | 3 aligned columns with colored boxes | 3 aligned columns, correct alignment | OK |
| HStack (A/B/C) | Colored boxes in row | Colored boxes in row | OK |
| HStack "Wide / Spacing" | Spread apart | Spread apart | OK |
| ZStack | Blue bg, green overlay, "Top" text | Blue bg, green overlay, "Top" text | OK |
| Group items | 3 cyan items, vertical | 3 cyan items, horizontal (no line breaks) | Issue — Group renders inline, not vertical |
| ForEach (0/1/2) | Purple numbered boxes | Purple numbered boxes | OK |
| -/+ buttons | Working | Working | OK |
| AnyView | Green text | Green text | OK |
| EmptyView | "Before After (EmptyView between)" | "BeforeAfter (EmptyView between)" | Minor — no HStack spacing |
| Overall | Complete | Close match, Group layout issue | B+ |

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
| List | 3 items with -/+, row separators | 3 items with -/+, bordered rows | OK |
| Overall | Complete | Complete, Image as text placeholder | B+ |

### 7. Modifiers

**Not captured** — Wasm build timed out during Puppeteer screenshot capture.

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
| NavigationLink buttons | "Go to Alpha", "Go to Beta" | Same, bordered buttons | OK |
| Path depth | "Path depth: 0" | "Path depth: 0" | OK |
| Push 42 / Push 99 | Present | Present | OK |
| NavigateAction section | Present | Present | OK |
| Overall | Complete | Complete with header bar | A |

### 10. Environment

| Aspect | macOS | Web | Rating |
|--------|-------|-----|--------|
| Custom accent (default blue) | Blue text | Blue underlined text | Minor — underline is an anchor/link style |
| Custom accent (red override) | Red text | Red text | OK |
| Toggle accent button | Present | Present | OK |
| Third accent (green) | Green text | Green text | OK |
| @EnvironmentObject | "Theme: Dark", "Font size: 14pt" | Same values | OK |
| Toggle/Size buttons | Present | Present | OK |
| Environment propagation | Orange "Nested child sees accent" | Orange text | OK |
| Overall | Complete | Very close match | A- |

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
| TextField width | Full-width | Compact | Minor — width differs |
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
| HelloWorld | B | Text not centered (no viewport fill) |
| Stopwatch | D | Dark background doesn't fill viewport — white on white |
| ColorMixer | B+ | Good match, minor swatch layout and divider styling |
| ViewsBasic | B+ | Spacer not expanding in HStack |
| ViewsLayout | B+ | Group renders inline (no vertical stacking) |
| ViewsContainers | B+ | Image renders as text placeholder (expected) |
| Modifiers | N/A | Wasm build timed out |
| StateData | A | Complete match |
| Navigation | A | Header bar present, correct |
| Environment | A- | Minor underline on accent text |
| Gestures | A | Full coverage, drag works on Web |
| Animation | A- | Minor layout differences in offset/withAnimation rows |
| Focus | A- | TextField width, minor spacing |
| AppStructure | A | Complete match |

## Key Issues to Address

1. **Stopwatch dark background** (High) — root `.background()` doesn't fill the browser viewport. Needs either a CSS `body` background or the root container to use `min-height: 100vh`.
2. **Spacer in HStack** (Medium) — Spacer doesn't expand to push children apart. The Web `Spacer` implementation may need `flex: 1` in a flex context.
3. **Group vertical stacking** (Medium) — Group renders children inline rather than vertically when inside a VStack. The Group `<div>` may need `display: flex; flex-direction: column` or `display: contents`.
4. **parity-Modifiers timeout** (Medium) — Wasm build or runtime issue prevents this example from rendering. Needs investigation.
5. **TextField width** (Low) — TextFields don't fill available width in all contexts. May need `width: 100%` applied more consistently.
