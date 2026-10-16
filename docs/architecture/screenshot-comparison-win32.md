# Screenshot Comparison: macOS vs Win32

Side-by-side comparison of all Showcase and Parity examples.
Screenshots recaptured 2026-10-15 on `develop` @ `401212b` (after the DPI merges #8, #11, #22),
Windows 11 arm64 at 100% display scale (96 DPI), with `screenshots/capture-windows.ps1`
(PrintWindow + DWM crop). LayoutStress is not covered by the capture script; its screenshot is still from March.

Reference: `screenshots/macos/` (real SwiftUI) vs `screenshots/windows/` (SwiftOpenUI Win32 backend)

**What changed since the March pass**
- **Typography.** Plain `Text` now renders in Segoe UI instead of the legacy bitmap System font (#22), so
  text weight and size closely match macOS across every example. The old captures looked uniformly bold.
- **Window size.** Windows now open at the shared 800x600 automatic default (`6d7d982`, April) instead of
  sizing to their content. Short examples gain empty space; tall Parity examples are now **clipped** (see Open Issue 1).

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
| Divider | Not visible | Bright line near the bottom | Minor -- divider contrast |
| Overall | Polished dark UI | Very close match | A- |

### 3. Color Studio

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Color swatch + hex/RGB readout | Correct | Correct | OK |
| RGB sliders | SwiftUI native | D2D custom (blue accent, white thumb) | Good |
| Swatches grid | Centered, evenly spaced | Centered, evenly spaced | OK |
| Lighter/Darker buttons | Rounded bordered | Flat, dark | Minor |
| Section dividers | Not visible | Bright white lines | Minor -- divider contrast |
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
| Canvas page frame | Bordered page inset in canvas | No page frame visible | Open -- not investigated |
| Overall | Complete | Mostly complete | B+ |

## Parity Examples

### 6. ViewsBasic

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Text (plain/bold/colored/large/caption) | Correct | Correct, matching weights | OK |
| Button (string label) | Rounded | D2D rounded | OK |
| Button (custom label) | Faint "Custom label ->" | Faint "Custom label ->" | OK |
| TextField | Full width, system font | Full width, Segoe UI | OK |
| Color swatches | Two rows | Two rows | OK |
| Spacer / Divider sections | Visible | Clipped by window height | Open -- window fit |
| Overall | Complete | Complete but clipped | B+ |

### 7. ViewsLayout

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| VStack (leading/center/trailing) | 3 aligned columns | 3 aligned columns | OK |
| HStack / ZStack / Group | Correct | Correct | OK |
| ForEach (0/1/2) + +/- buttons | Working | Working | OK |
| Label text on colored boxes | Black | Black | OK |
| AnyView / EmptyView sections | Visible | Clipped by window height | Open -- window fit |
| Overall | Complete | Complete but clipped | A- |

### 8. ViewsContainers

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Toggle + Value: ON | Correct | Correct | OK |
| Slider + driven bar | Native | D2D custom | Good |
| Image (system) | SF Symbols | Win32 stock icons (labeled) | OK |
| ScrollView | Content-width, rows leading-aligned | Full width, rows centered | Open -- row alignment |
| List | Rows leading-aligned | Rows centered; rows 1-2 clipped | Open -- row alignment, window fit |
| Overall | Complete | Functional | B+ |

### 9. Modifiers

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| .padding() | 3 colored boxes | 3 colored boxes | OK |
| .frame() | "60×30" + "Flex" (100pt) | "60×30" renders; "Flex" at min width | Minor -- flex frame width |
| .foregroundColor() / .foregroundStyle() | Correct | Correct | OK |
| .background() | Yellow/Custom bg | Yellow/Custom bg | OK |
| .font() sizes | All 6 sizes | All 6 sizes | OK |
| .border() ... .modifier() | 6 sections visible | Clipped by window height | Open -- window fit |
| Overall | All 11 modifiers shown | 6 of 11 visible, all correct | B+ |

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
| Tap / Double-tap / Long press | White text on color | Black text on color | Open -- foregroundColor outside background |
| 1s duration | Correct | Correct | OK |
| Drag | "(not available on macOS)" | "Drag me" + offset + reset | OK -- Win32 has more |
| Overall | Core gestures | All gestures, low-contrast labels | B+ |

### 14. Animation

| Aspect | macOS | Win32 | Rating |
|--------|-------|-------|--------|
| Fade / Scale / Slide / withAnimation | 4 animations, white labels | 4 animations, black labels | Open -- foregroundColor outside background |
| Toggle / withAnimation buttons | Correct | Correct | OK |
| Overall | 4 animations shown | 4 animations shown | B+ |

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
| A | HelloWorld, StateData, Environment, AppStructure |
| A- | Stopwatch, ColorStudio, Calculator, ViewsLayout, Navigation, Focus |
| B+ | SimplePaint, ViewsBasic, ViewsContainers, Modifiers, Gestures, Animation |

Most B+ ratings come from two shared causes (Open Issues 1-2), not from per-example bugs.

## DPI Scaling

Verified at 150% (144 DPI) on 2026-10-15 with HelloWorld and ParityNavigation, including a pushed
destination: window default, text, buttons, navigation header and back button all scale, nothing clips.
Evidence: `docs/evidence/win32-default-text-font/`. Not yet checked at 125% or 175%.

## Remaining Open Issues

| # | Issue | Affects | Type | Effort |
|---|-------|---------|------|--------|
| 1 | Window doesn't grow to fit content: the 800x600 automatic default clips tall content, while macOS sizes the window to at least the content's height | ViewsBasic, ViewsLayout, ViewsContainers, Modifiers | Window sizing | Medium |
| 2 | `.foregroundColor()` applied after `.padding().background()` doesn't reach the inner `Text` | Gestures, Animation | Modifier propagation | Medium |
| 3 | ScrollView / List rows are centered instead of leading-aligned | ViewsContainers | Layout | Medium |
| 4 | Dividers on dark backgrounds are bright white instead of subtle | ColorStudio, Stopwatch | Styling | Low |
| 5 | SimplePaint canvas page frame not drawn | SimplePaint | Not investigated | ? |
| 6 | `.frame(minWidth:maxWidth:)` "Flex" box renders at min width (40) instead of max (100) | Modifiers | Layout | Low |

## All Fixes Applied

| Fix | Commit | Impact |
|-----|--------|--------|
| TextField/SecureField/TextEditor/search field font + TextField width | this PR | Focus B+ -> A-, ViewsBasic B -> B+ |
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

Rating changes in this pass mostly come from the window now being a fixed 800x600 (Open Issue 1)
and from closer side-by-side checking, not from rendering regressions. The March captures were content-sized,
so clipping and alignment gaps weren't visible then.

## Platform Differences (Expected)

These are inherent Win32 vs SwiftUI differences, not bugs:
- Button style: D2D flat buttons with rounded corners (close to SwiftUI but not identical)
- Font weight: .thin weight not available in Win32 text pipeline
- Slider: D2D custom slider is close but not identical to SwiftUI native
- Navigation title: drawn as an in-content header bar rather than in the window title bar
- Window chrome: Win32 title bar vs macOS traffic lights
