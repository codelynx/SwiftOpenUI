# NavigationSplitView Win32 Implementation Plan

Plan to bring Win32 NavigationSplitView to parity with GTK4.

## Current State

**Core**: Full 2-column and 3-column `NavigationSplitView` with `sidebarWidth`, `columnVisibility` binding, and `.navigationSplitViewColumnWidth()` modifier.

**GTK4**: Complete — nested `GtkPaned` for 3-column, visibility control, column width constraints, toolbar.

**Win32 (current)**: Complete — 2/3-column layout, sidebarWidth property, `.navigationSplitViewColumnWidth()` modifier with min/ideal/max constraints via Mirror-walking extraction, column visibility binding (.automatic/.all/.doubleColumn/.detailOnly), draggable divider with mouse capture and resize cursor, visible divider lines via WM_PAINT, WM_SIZE responsive layout.

**SwiftWindowsUI reference**: Has a proper `SplitViewState` + subclass proc for WM_SIZE handling, but only 2-column.

## Core API Surface

### NavigationSplitView

```
Sources/SwiftOpenUI/Views/NavigationSplitView.swift
```

- `NavigationSplitView<Sidebar, Content, Detail>` with `Body = Never`
- `sidebar`, `content` (EmptyView in 2-column), `detail` columns
- `sidebarWidth: Int` — default 250 (2-col) or 200 (3-col)
- `columnVisibility: Binding<NavigationSplitViewVisibility>?`
- `hasContentColumn: Bool` — detects 2-col vs 3-col mode

### Column Width Modifier

```
Sources/SwiftOpenUI/Modifiers/NavigationSplitViewColumnWidthModifier.swift
```

- `NavigationSplitViewColumnWidthProvider` protocol with `columnMinWidth`, `columnIdealWidth`, `columnMaxWidth`
- `NavigationSplitViewColumnWidthView<Content>` wrapper
- `.navigationSplitViewColumnWidth(min:ideal:max:)` and `.navigationSplitViewColumnWidth(_:)` convenience

### Visibility

```
Sources/SwiftOpenUI/Navigation/NavigationSplitViewVisibility.swift
```

- `.automatic`, `.all`, `.doubleColumn`, `.detailOnly`

## GTK4 Reference (how it works)

File: `Sources/Backend/GTK4/Rendering/GTKNavigation.swift`

- **2-column**: Single horizontal `GtkPaned` with sidebar as start child, detail as end child
- **3-column**: Nested paned — outer `[innerPaned | detail]`, inner `[sidebar | content]`
- **Column widths**: Mirror-walks view tree (depth 20) to find `NavigationSplitViewColumnWidthProvider`, applies `gtk_widget_set_size_request()` for min and `gtk_swift_paned_set_position()` for ideal
- **Visibility**: `gtk_widget_set_visible()` to show/hide columns, paned position set to 0 for detailOnly
- **Toolbar**: Extracts toolbar items from detail view tree into `GtkHeaderBar`

## SwiftWindowsUI Reference

File: `SwiftWindowsUI/Sources/SwiftWindowsUI/Views/NavigationSplitView.swift`

- 2-column only, `SplitViewState` class stored via `SetWindowSubclass()`
- `splitViewLayoutProc` handles `WM_SIZE` to reposition sidebar + detail
- Sidebar: `(0, 0, sidebarWidth, totalH)`, Detail: `(sidebarWidth+1, 0, remaining, totalH)`
- Forwards `WM_COMMAND` to parent, cleans up on `WM_NCDESTROY`

## Implementation Steps

| Step | Feature | Approach | Complexity |
|------|---------|----------|------------|
| 1 | Respect sidebarWidth property | Use `self.sidebarWidth` instead of hard-coded 200 | Trivial |
| 2 | WM_SIZE subclass | `SplitViewState` class + layout proc (from SwiftWindowsUI pattern) — sidebar and detail resize when container resizes | Low |
| 3 | Column width modifier | Mirror-walk sidebar/content to extract `NavigationSplitViewColumnWidthProvider`, apply min/ideal/max constraints during layout | Low |
| 4 | 3-column layout | Detect `hasContentColumn`, split container into sidebar \| content \| detail with two divider positions | Medium |
| 5 | Column visibility | Read `columnVisibility` binding, show/hide columns via `ShowWindow(SW_HIDE/SW_SHOW)` + adjust positions | Medium |
| 6 | Draggable divider | Subclass container with WM_LBUTTONDOWN hit-testing near divider position, WM_MOUSEMOVE for drag, respecting min/max constraints | Medium |
| 7 | Update parity matrix | Mark Win32 as `Y` for NavigationSplitView and .navigationSplitViewColumnWidth() | Trivial |

Steps 1-5 are the core parity with GTK4. Step 6 (draggable divider) is a nice-to-have — GTK4's `GtkPaned` provides this natively, but Win32 needs manual hit-testing.

## Key Files to Modify

- `Sources/Backend/Win32/Rendering/WinRenderer.swift` — rewrite `extension NavigationSplitView: WinRenderable`
- `docs/architecture/swiftui-parity-matrix.md` — update NavigationSplitView and .navigationSplitViewColumnWidth() Win32 columns
