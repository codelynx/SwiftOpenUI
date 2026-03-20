# Web Backend Parity Plan

Gap analysis and implementation plan for the Web/Wasm backend. Phases A–B target common view/modifier parity. Phases C–D address complex UI patterns and architectural prerequisites. Full GTK4/Win32 parity requires all phases plus the remaining gaps listed at the end.

Last updated: 2026-03-20

## Implementation Pattern

Each view needs an `extension MyView: WebRenderable` with `webCreateElement() -> JSValue` in `Sources/Backend/Web/Rendering/WebRenderer.swift`.

- Create DOM elements via `document.createElement()`
- Wire events with `JSClosure` + `webRetainClosure()`
- Render children with `webRenderView()`
- For bindings: read `.wrappedValue` for initial state, write back in event handler

## Architectural Prerequisite: Rebuild Model

The current `WebViewHost` clears `_webRetainedClosures` and wipes `container.innerHTML` on every rebuild (`WebViewHost.swift:53`). This full-teardown model has consequences:

- **No element identity across rebuilds** — every DOM node is recreated on every state change
- **No mount/unmount tracking** — there is no way to distinguish "first appearance" from "rebuild"
- **Dialog elements are destroyed** — even if closures are retained separately, the `<dialog>` DOM node itself is wiped and must be re-created and re-shown
- **MutationObserver sees rebuild churn** — every rebuild triggers removal notifications for all nodes

This means `.onAppear()`, `.onDisappear()`, `.sheet()`, `.alert()`, and `.confirmationDialog()` cannot be implemented correctly without first addressing the rebuild model. Options:

1. **Mount-tracking flag per host** — track whether a host has rendered before; `.onAppear()` fires only on first host render, not rebuilds. **Host-level approximation only** — does not handle views that appear later inside an already-mounted host (e.g., conditional content introduced by state change). Correct per-view `.onAppear()` requires per-element identity tracking across rebuilds.
2. **Stable-identity diffing** — instead of `innerHTML = ""`, diff the existing DOM against the new render tree and patch in place. Correct but complex (virtual DOM approach).
3. **Dialog hoisting** — modal elements are appended to `document.body` outside the host's container, so they survive rebuilds. Closures retained in a separate collection keyed by dialog identity. Targeted fix for modals only.

Recommendation: Option 1 + 3 covers `.onAppear()` and modal modifiers without a full virtual DOM rewrite. `.onDisappear()` remains hard — defer to Phase D.

## Phase A — Trivial (~10 lines each)

No architectural prerequisites. Pure DOM element creation.

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

No architectural prerequisites except `.onAppear()` which needs mount-tracking (option 1 above).

| View/Modifier | HTML Element | Notes |
|---|---|---|
| List | styled `<div>` rows | Render children with row borders |
| Image (file) | `<img src>` | systemName → text placeholder (no browser icon theme) |
| ProgressView | `<progress>` | Browser handles indeterminate natively |
| Stepper | `-` button + display + `+` button | |
| Label | icon + text `<span>` | systemImage needs mapping or placeholder |
| DisclosureGroup | `<details>` + `<summary>` | Native HTML collapsible element |
| Picker | `<select>` + `<option>` | .segmented → row of `<button>` |
| DatePicker | `<input type="date">` | DateComponents ↔ ISO date string |
| .overlay() | `position: relative/absolute` | Alignment-based positioning |
| .onAppear() | Fire on first mount only | Host-level approximation only (see prerequisite); correct per-view semantics needs per-element identity tracking |
| .searchable() | `<input type="search">` + content | Almost identical to TextField + VStack |
| ConfirmationDialog | `<dialog>` modal | Requires dialog hoisting (see prerequisite) |
| .pickerStyle() | Style selector for Picker | .automatic, .segmented, .palette |
| .navigationSplitViewColumnWidth() | CSS width on sidebar column | Used with NavigationSplitView |

## Phase C — Medium (~40-60 lines, state management)

Requires dialog hoisting prerequisite for .sheet() and .alert().

| View/Modifier | HTML Element | Notes |
|---|---|---|
| TabView | Tab bar `<button>`s + content `<div>`s | Pre-render all tabs, hide/show inactive |
| Grid/GridRow | CSS `display: grid` | Cell span detection via `GridCellSpanView`, two modes (auto-wrap + explicit rows) |
| LazyVStack | `<div>` (non-virtualized) | Same as VStack on Web; virtualization is a future optimization |
| LazyHStack | `<div>` (non-virtualized) | Same as HStack on Web |
| LazyVGrid | CSS `display: grid` | Same as Grid on Web, non-virtualized |
| LazyHGrid | CSS `display: grid` horizontal | Same as Grid horizontal |
| Menu | Custom dropdown `<div>` | `position: absolute`, dismiss-on-outside-click |
| NavigationSplitView | Flexbox row columns | Fixed sidebar width, optional content column |
| .sheet() | `<dialog>` hoisted to `document.body` | Requires dialog hoisting + closure retention outside host |
| .alert() | `<dialog>` hoisted | Same infrastructure as .sheet() |
| .gridCellColumns() | CSS `grid-column: span N` | Used with Grid/GridRow |

## Phase D — Hard (architectural issues)

| View/Modifier | Issue | Status |
|---|---|---|
| .focused() | DOM `focus()`/`blur()` + `FocusState` binding wiring | **Done** |
| .toolbar() | Extend `WebNavigationContext` header with toolbar area | **Done** |
| GeometryReader | `ResizeObserver` + deferred re-render with actual dimensions. | **Done** |
| Canvas | Wraps JS CanvasRenderingContext2D in a class, stores pointer in `DrawingContext.cr`. Full drawing API mapped to Canvas 2D. | **Done** |
| .onDisappear() | No reliable DOM lifecycle hook. `MutationObserver` sees rebuild churn as removal. Needs stable-identity diffing or explicit unmount tracking. | Remaining |

## Architectural Blockers

### Canvas / DrawingContext
`DrawingContext` in `Sources/SwiftOpenUI/Views/Canvas.swift` carries `let cr: OpaquePointer` tied to Cairo/GTK. Options:
1. Ignore `drawHandler` and render an empty `<canvas>` (stub)
2. Introduce a platform-agnostic drawing protocol in core
3. Add a parallel `webDrawHandler` closure to Canvas

### GeometryReader async dimensions
Web renders synchronously with no layout pass. `ResizeObserver` is the right tool but requires deferred rebuild — initial render with zero proxy, then observer triggers rebuild with actual dimensions.

### Dialog lifecycle (.sheet, .alert, .confirmationDialog)
`_webRetainedClosures` is cleared on every `WebViewHost.rebuild()`. Additionally, `container.innerHTML = ""` destroys the `<dialog>` DOM node itself. Dialog elements must be hoisted to `document.body` (outside the host container) and closures retained in a separate collection keyed by dialog identity.

### Rebuild model and .onDisappear()
The full-teardown rebuild (`innerHTML = ""`) makes `.onDisappear()` fundamentally difficult. Every rebuild looks like a disappearance of all nodes. Correct implementation requires either stable-identity DOM diffing or explicit unmount tracking — both are significant infrastructure work.

## Current Web Status (from parity matrix)

**Implemented (Y):** Text, Button, TextField, Color, Spacer, Divider, VStack, HStack, ZStack, Group, ForEach, AnyView, EmptyView, NavigationStack, NavigationLink, .padding(), .frame(), .foregroundColor(), .foregroundStyle(), .background(), .font(), .border(), .opacity(), .offset(), .scaleEffect(), .animation(), .onTapGesture(), .onLongPressGesture(), .onDrag(), .environmentObject(), .environment(), .navigationTitle(), .navigationDestination(), .modifier(), withAnimation()

**Not implemented (-):** All Phase A/B/C/D items listed above

## Remaining Gaps (not covered in phases above)

These are in the GTK4/Win32 matrix but excluded from this plan due to low priority or external dependencies:

| Item | Reason |
|---|---|
| Map | No core type defined; needs external map library |
| .clipShape() | Not implemented in core |
| .task() | Needs async runtime |
| .navigationBarItems() | Not implemented in core |
| @AppStorage | Not implemented in core |
| @SceneStorage | Not implemented in core |

## Priority

1. ~~**Phase A** (11 items)~~ — Done
2. ~~**Phase B** (14 items)~~ — Done
3. ~~**Phase C** (11 items)~~ — Done
4. ~~**Phase D partial** (.focused, .toolbar)~~ — Done
5. **Phase D remaining** (1 item) — .onDisappear() — needs stable-identity rebuild model

40 of 41 items implemented. Web is at near-parity with GTK4/Win32 for views and modifiers.
