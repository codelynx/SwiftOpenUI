# Phase 2 Linux Implementation Plan

Branch: `experimental/phase2-linux`

## Order

### 1. Input-State Preservation (first)
- Save/restore cursor position, selection, and focus across GTK ViewHost rebuilds
- Reference: SwiftLinuxUI's `saveFocusInfo` / `restoreFocusInfo`
- Unblocks usable TextField — cursor currently resets on every @State change

### 2. Gestures
- `.onTapGesture {}`, `.onLongPressGesture {}`, `DragGesture`
- Core modifier views + GTK event controller wiring (GtkGestureClick, GtkGestureLongPress, GtkGestureDrag)

### 3. Navigation
- `NavigationStack`, `NavigationLink`, `NavigationPath` in core
- GTK: GtkStack with header bar, push/pop transitions, back button

### 4. Animations
- `withAnimation {}`, `.animation(.easeInOut, value:)` modifier
- Initial scope: opacity and offset transitions via GTK CSS transitions
