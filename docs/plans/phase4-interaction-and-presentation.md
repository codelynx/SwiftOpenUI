# Phase 4 — Interaction & Presentation

**Status: Substantially complete. Batch C (fullScreenCover) deferred.**

## Goal

Add commonly needed interaction and presentation APIs to make SwiftOpenUI apps more interactive and complete.

## Batches (ordered by complexity)

### Batch A: onChange

React to value changes — extremely common pattern.

```swift
.onChange(of: someValue) { newValue in ... }
```

**Scope:** Core modifier + environment/state integration. Backends don't need rendering changes — this is a pure state-observation modifier that fires a closure when a tracked value changes during rebuild.

---

### Batch B: contextMenu

Standard long-press / right-click interaction pattern.

```swift
.contextMenu {
    Button("Copy") { ... }
    Button("Delete") { ... }
}
```

**Scope:**
- Core: `ContextMenuView<Content, MenuContent>` modifier
- GTK4: `GtkPopoverMenu` triggered by right-click gesture
- Win32: `TrackPopupMenu` with HMENU
- Web: Custom overlay triggered by `contextmenu` event

---

### Batch C: fullScreenCover

Modal presentation that covers the entire screen.

```swift
.fullScreenCover(isPresented: $showDetail) { DetailView() }
```

**Scope:** Similar to existing `.sheet()` but full-screen. Backends already have sheet infrastructure — extend it with a fullscreen flag.

---

### Batch D: popover

Positioned popover attached to a view.

```swift
.popover(isPresented: $showPopover) { PopoverContent() }
```

**Scope:**
- Core: `PopoverView<Content, Popover>` modifier
- GTK4: `GtkPopover` attached to the anchor widget
- Win32: Popup window positioned relative to anchor
- Web: Absolutely positioned overlay near anchor element

---

### Batch E: Complete frame overloads + layoutPriority

Fill in frame modifier gaps and add layout priority.

```swift
.frame(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:alignment:)
.layoutPriority(_:)
```

**Scope:** Core modifier types. Backend layout engines need to respect priority during space distribution.

---

### Batch F: ScrollViewReader + ID system (last)

Programmatic scroll positioning with view identity.

```swift
ScrollViewReader { proxy in
    ScrollView {
        ForEach(items) { item in
            Text(item.name).id(item.id)
        }
    }
    Button("Jump") { proxy.scrollTo(targetID) }
}
```

**Scope:**
- Core: `.id()` modifier, `ScrollViewProxy`, `ScrollViewReader` view
- Requires ID registry infrastructure (cross-cutting)
- GTK4: `gtk_scrolled_window` adjustment API
- Win32: `WM_VSCROLL` / child position calculation
- Web: `element.scrollIntoView()` (trivial)

**Why last:** Requires an ID system that doesn't exist yet. Other items are self-contained.

---

## Execution Order

- ~~A: onChange~~ — Done
- ~~B: contextMenu~~ — Done
- C: fullScreenCover — **Deferred**
- ~~D: popover~~ — Done
- ~~E: frame/layoutPriority/fixedSize/position~~ — Done
- ~~F: ScrollViewReader + ID system~~ — Done
