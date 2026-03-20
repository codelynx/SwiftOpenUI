# Web Backend Parity Plan

Gap analysis and implementation plan to bring the Web/Wasm backend to parity with GTK4 and Win32.

Last updated: 2026-03-20

## Implementation Pattern

Each view needs an `extension MyView: WebRenderable` with `webCreateElement() -> JSValue` in `Sources/Backend/Web/Rendering/WebRenderer.swift`.

- Create DOM elements via `document.createElement()`
- Wire events with `JSClosure` + `webRetainClosure()`
- Render children with `webRenderView()`
- For bindings: read `.wrappedValue` for initial state, write back in event handler

## Phase A — Trivial (~10 lines each)

| View/Modifier | HTML Element | Notes |
|---|---|---|
| Toggle | `<input type="checkbox">` + `<label>` | Same binding pattern as TextField |
| Slider | `<input type="range">` | min/max/step/value attributes |
| ScrollView | `<div>` + CSS `overflow: auto` | Pure CSS, no JS needed |
| SecureField | `<input type="password">` | Clone of TextField |
| TextEditor | `<textarea>` | Clone of TextField |
| Link | `<a href target="_blank">` | No JS needed |
| Form | styled `<div>` | VStack with padding |
| Section | `<div>` + `<h3>` header + footer | |
| .cornerRadius() | CSS `border-radius` | |
| .shadow() | CSS `box-shadow` | |
| .rotationEffect() | CSS `transform: rotate()` | |

## Phase B — Easy (~20-30 lines each)

| View/Modifier | HTML Element | Notes |
|---|---|---|
| List | styled `<div>` rows | Render children with row borders |
| Image (file) | `<img src>` | systemName → text placeholder |
| ProgressView | `<progress>` | Browser handles indeterminate natively |
| Stepper | `-` button + display + `+` button | |
| Label | icon + text `<span>` | systemImage needs mapping or placeholder |
| DisclosureGroup | `<details>` + `<summary>` | Native HTML collapsible element |
| Picker | `<select>` + `<option>` | .segmented → row of `<button>` |
| DatePicker | `<input type="date">` | DateComponents ↔ ISO date string |
| .overlay() | `position: relative/absolute` | Alignment-based positioning |
| .onAppear() | Fire immediately in `webCreateElement()` | Or defer by one frame via `requestAnimationFrame` |
| .searchable() | `<input type="search">` + content | Almost identical to TextField + VStack |
| ConfirmationDialog | `<dialog>` modal | Mirrors AlertModifierView |

## Phase C — Medium (~40-60 lines, state management)

| View/Modifier | HTML Element | Notes |
|---|---|---|
| TabView | Tab bar `<button>`s + content `<div>`s | Pre-render all tabs, hide/show inactive |
| Grid/GridRow | CSS `display: grid` | Cell span detection via `GridCellSpanView`, two modes (auto-wrap + explicit rows) |
| Menu | Custom dropdown `<div>` | `position: absolute`, dismiss-on-outside-click |
| NavigationSplitView | Flexbox row columns | Fixed sidebar width, optional content column |
| .sheet() | `<dialog>` + `showModal()` | Rebuild guard needed (dialog lifecycle across rebuilds) |
| .alert() | `<dialog>` modal | Same rebuild guard as .sheet() |
| .onDisappear() | `MutationObserver` | No native DOM lifecycle hook for removal |

## Phase D — Hard (architectural issues)

| View/Modifier | Issue |
|---|---|
| GeometryReader | Needs `ResizeObserver` + async rebuild. Web renders synchronously with no layout pass. Initial render uses zero proxy, then `ResizeObserver` triggers rebuild with actual dimensions. |
| Canvas | `DrawingContext.cr` is an `OpaquePointer` to Cairo — cannot hold a JS canvas 2D context. Needs either a platform-agnostic drawing abstraction in core, or a Web-only stub rendering an empty `<canvas>`. |
| .toolbar() | Requires extending `WebNavigationContext` to accept toolbar items and render them into the navigation header bar. |
| .focused() | Currently no-op pass-through. Real implementation needs DOM `focus()`/`blur()` wiring + `FocusState` binding updates. |

## Architectural Blockers

### Canvas / DrawingContext
The `DrawingContext` struct in `Sources/SwiftOpenUI/Views/Canvas.swift` carries `let cr: OpaquePointer` which is semantically tied to Cairo/GTK. The Web backend cannot use this. Options:
1. Ignore `drawHandler` and render an empty `<canvas>` (stub)
2. Introduce a platform-agnostic drawing protocol in core
3. Add a parallel `webDrawHandler` closure to Canvas

### GeometryReader async dimensions
The Web backend renders synchronously. `GeometryReader` in GTK polls allocated dimensions via `gtk_widget_get_allocated_width/height` on a tick callback. On Web, `ResizeObserver` is the right tool but requires deferred rebuild infrastructure — initial render calls `content(GeometryProxy(size: GeometrySize(width: 0, height: 0)))`, then the observer triggers a rebuild with actual dimensions.

### Dialog lifecycle (.sheet, .alert, .confirmationDialog)
`_webRetainedClosures` is cleared on every `WebViewHost.rebuild()`. Dialogs that need to survive across rebuilds must store their closures elsewhere — e.g., attached to the dialog element via a JS data attribute, or in a separate retained collection keyed by dialog identity.

## Current Web Status (from parity matrix)

**Implemented (Y):** Text, Button, TextField, Color, Spacer, Divider, VStack, HStack, ZStack, Group, ForEach, AnyView, EmptyView, NavigationStack, NavigationLink, .padding(), .frame(), .foregroundColor(), .foregroundStyle(), .background(), .font(), .border(), .opacity(), .offset(), .scaleEffect(), .animation(), .onTapGesture(), .onLongPressGesture(), .onDrag(), .environmentObject(), .environment(), .navigationTitle(), .navigationDestination(), .modifier(), withAnimation()

**Not implemented (-):** All Phase A/B/C/D items listed above

## Priority

1. Phase A (11 items) — closes the biggest visual gaps, all trivial
2. Phase B (12 items) — covers remaining common views
3. Phase C (7 items) — complex UI patterns
4. Phase D (4 items) — architectural work needed first

Phase A + B (23 items) would bring Web to near-parity with GTK4/Win32 for common views and modifiers.
