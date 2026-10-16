# Screenshot Comparison: macOS vs Win32

Side-by-side comparison of all Showcase and Parity examples.
Screenshots recaptured 2026-10-15 on `develop` @ `401212b` (after the DPI merges #8, #11, #22),
Windows 11 arm64 at 100% display scale (96 DPI), with `screenshots/capture-windows.ps1`
(PrintWindow + DWM crop). LayoutStress is not covered by the capture script; its screenshot is still from March.

Reference: `screenshots/macos/` (real SwiftUI) vs `screenshots/windows/` (SwiftOpenUI Win32 backend)

**What changed since the March pass**
- **Typography.** Plain `Text` now renders in Segoe UI instead of the legacy bitmap System font (#22), so
  text weight and size closely match macOS across every example. The old captures looked uniformly bold.
- **Window size.** Windows open at the shared 800x600 automatic default (`6d7d982`, April) and grow
  to fit taller or wider content, capped at 3/4 of the screen. Short examples gain empty space versus March.

## Showcase Examples

### 1. HelloWorld

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Title bar | "Hello World" | "Hello World" | OK |
| Text content | Centered in window | Centered in window | OK |
| Font | System body | Segoe UI body | OK |
| Overall | Clean minimal | Matches | A |

### 2. Stopwatch

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Dark background | Fills entire window | Fills entire window | OK |
| Timer "00:00.00" | Centered, thin weight | Centered, regular weight | Minor -- font weight |
| Reset / Start buttons | Orange / green | Orange / green, flat | OK |
| Divider | Not visible | Subtle gray line near the bottom | OK |
| Overall | Polished dark UI | Very close match | A- |

### 3. Color Studio

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Color swatch + hex/RGB readout | Correct | Correct | OK |
| RGB sliders | SwiftUI native | D2D custom (blue accent, white thumb) | Good |
| Swatches grid | Centered, evenly spaced | Centered, evenly spaced | OK |
| Lighter/Darker buttons | Rounded bordered | Flat, dark | Minor |
| Section dividers | Not visible | Subtle gray lines | OK |
| Color harmony | Centered columns | Centered columns | OK |
| Overall | Reference quality | Very close match | A- |

### 4. Calculator

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Display "0" | Right-aligned | Right-aligned | OK |
| Button grid 4x5 | Even grid, dark gaps | Even grid, light gaps | Minor |
| Orange operators | /, x, -, +, = | /, x, -, +, = | OK |
| Window sizing | Exact fit | Exact fit (contentFixed) | OK |
| Overall | Reference quality | Close match | A- |

### 5. SimplePaint

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Toolbar (New/Undo/Redo, tool name) | Correct | Correct | OK |
| Tool palette | 5 tools, selected highlighted | 5 tools, selected highlighted | OK |
| Color palette + brush size slider | Correct | Correct | OK |
| Canvas page frame | Bordered page, centered | Bordered page, centered horizontally, top-aligned | Minor |
| Drawing (pencil drag) | Works | Works | OK |
| Overall | Complete | Complete | A- |

## Parity Examples

### 6. ViewsBasic

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Text (plain/bold/colored/large/caption) | Correct | Correct, matching weights | OK |
| Button (string label) | Rounded | D2D rounded | OK |
| Button (custom label) | Faint "Custom label ->" | Faint "Custom label ->" | OK |
| TextField | Full width, system font | Full width, Segoe UI | OK |
| Color swatches | Two rows | Two rows | OK |
| Spacer / Divider sections | Visible | Visible | OK |
| Overall | Complete | Complete | A- |

### 7. ViewsLayout

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| VStack (leading/center/trailing) | 3 aligned columns | 3 aligned columns | OK |
| HStack / ZStack / Group | Correct | Correct | OK |
| ForEach (0/1/2) + +/- buttons | Working | Working | OK |
| Label text on colored boxes | Black | Black | OK |
| AnyView / EmptyView sections | Visible | Visible | OK |
| Overall | Complete | Complete | A |

### 8. ViewsContainers

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Toggle + Value: ON | Correct | Correct | OK |
| Slider + driven bar | Native | D2D custom | Good |
| Image (system) | SF Symbols | Win32 stock icons (labeled) | OK |
| ScrollView | Hugs content width | Fills width, content centered (SwiftUI centering) | Open -- ScrollView width |
| List | Rows leading-aligned, inset, separators | Rows leading-aligned, no inset or separators | Minor |
| Overall | Complete | Complete | A- |

### 9. Modifiers

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| .padding() | 3 colored boxes | 3 colored boxes | OK |
| .frame() | "60×30" + "Flex" (100pt) | "60×30" renders; "Flex" at min width | Minor -- flex frame width |
| .foregroundColor() / .foregroundStyle() | Correct | Correct | OK |
| .background() | Yellow/Custom bg | Yellow/Custom bg | OK |
| .font() sizes | All 6 sizes | All 6 sizes | OK |
| .border() ... .modifier() | 6 sections visible | 6 sections visible | OK |
| Overall | All 11 modifiers shown | All 11 shown | A- |

### 10. StateData

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| @State counter / toggle / conditional view | Working | Working | OK |
| @Binding parent/child | Working | Working | OK |
| @StateObject + @Published | Store count + label | Store count + label | OK |
| Title "State & Data" | Ampersand renders | Ampersand renders | OK |
| Overall | All state types working | All state types working | A |

### 11. Navigation

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| NavigationLink | "Go to Alpha/Beta" | "Go to Alpha/Beta" | OK |
| NavigationPath | "Path depth: 0", Push 42/99 | Same | OK |
| Navigation title | Window title bar | In-content header bar | Platform difference |
| Content fills window | Yes | Yes (#11 expansion fix) | OK |
| Overall | Clean navigation demo | Close match | A- |

### 12. Environment

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Custom accent colors | Blue/Red/Green | Blue/Red/Green | OK |
| EnvironmentObject | Theme + font size | Theme + font size | OK |
| Propagation | "Nested child sees accent" | "Nested child sees accent" | OK |
| Overall | Complete | Complete | A |

### 13. Gestures

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Tap / Double-tap / Long press | White text on color | White text on color | OK |
| 1s duration | Correct | Correct | OK |
| Drag | "(not available on macOS)" | "Drag me" + offset + reset | OK -- Win32 has more |
| Overall | Core gestures | All gestures including drag | A |

### 14. Animation

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Fade / Scale / Slide / withAnimation | 4 animations, white labels | 4 animations, white labels | OK |
| Slide / Animated label position | Centered in box | Sits low in box | Minor |
| Toggle / withAnimation buttons | Correct | Correct | OK |
| Overall | 4 animations shown | 4 animations shown | A- |

### 15. Focus

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| @FocusState (Bool) + Focus/Unfocus | Working | Working | OK |
| @FocusState (enum) + Name/Email/Notes/Clear | Working | Working | OK |
| TextFields | Full width, system font | Full width, Segoe UI | OK |
| Overall | Full focus demo | Full focus demo | A- |

### 16. AppStructure

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Bullet list | 4 bullet items | 4 bullet items | OK |
| @ViewBuilder / conditions / optional | Correct | Correct | OK |
| Numbers 1-6 | Colored row | Colored row | OK |
| Overall | Complete | Complete | A |

## Summary

| Rating | Examples |
|--------|----------|
| A | HelloWorld, ViewsLayout, StateData, Environment, Gestures, AppStructure |
| A- | Stopwatch, ColorStudio, Calculator, SimplePaint, ViewsBasic, ViewsContainers, Modifiers, Navigation, Animation, Focus |

No shared cause remains; the open issues below are each local to one or two examples.

## DPI Scaling

Verified at 150% (144 DPI) on 2026-10-15 with HelloWorld and ParityNavigation, including a pushed
destination: window default, text, buttons, navigation header and back button all scale, nothing clips.
Evidence: `docs/evidence/win32-default-text-font/`. Not yet checked at 125% or 175%.

## Remaining Open Issues

| # | Issue | Affects | Type | Effort |
|---|-------|---------|------|--------|
| 1 | Vertical ScrollView fills the available width; on macOS it hugs its content width | ViewsContainers | Layout | Medium |
| 2 | `.frame(minWidth:maxWidth:)` "Flex" box renders at min width (40) instead of max (100) | Modifiers | Layout | Low |

## All Fixes Applied

| Fix | Commit | Impact |
|-----|--------|--------|
| D2D views (Divider) clear to the inherited background, not white | `b3fcf03` | Stopwatch/ColorStudio dividers subtle on dark backgrounds |
| SimplePaint: border the non-macOS canvas (example only had it on macOS) | `4a161bd` | SimplePaint B+ -> A- |
| List rows leading-aligned | `6c75b5e` | ViewsContainers B+ -> A- |
| Outer .foregroundColor() reaches text through .background()/ZStack; innermost color wins | `7b399b8` | Gestures B+ -> A, Animation B+ -> A-; also fixes label colors in ViewsLayout, Modifiers, Navigation |
| Automatic window grows to fit content | `a557817` | ViewsBasic B+ -> A-, ViewsLayout A- -> A, Modifiers B+ -> A- |
| TextField/SecureField/TextEditor/search field font + TextField width | `d26f7bb` | Focus B+ -> A-, ViewsBasic B -> B+ |
| Default Segoe UI font for plain Text (#22) | `83c32bd` | Typography matches macOS everywhere; "×" glyph renders (Modifiers "D0x30" fixed) |
| Navigation expansion + header DPI (#11) | `fd4d1e3`..`c646d8e` | Navigation content fills the window; header scales at 125-175% |
| DPI-scaled text, D2D, symbols, window default (#8) | `dc482d8`, `9181cd8`, `6ca8904` | Correct sizing at 150% |
| HelloWorld centering | before `9896fa8` | HelloWorld B -> A |
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

Rating drops in the October pass came from closer side-by-side checking and the then-fixed 800x600 window
(since fixed), not from rendering regressions. The March captures were content-sized, so alignment gaps weren't visible then.

## Platform Differences (Expected)

These are inherent Win32 vs SwiftUI differences, not bugs:
- Button style: D2D flat buttons with rounded corners (close to SwiftUI but not identical)
- Font weight: .thin weight not available in Win32 text pipeline
- Slider: D2D custom slider is close but not identical to SwiftUI native
- Navigation title: drawn as an in-content header bar rather than in the window title bar
- Window chrome: Win32 title bar vs macOS traffic lights
