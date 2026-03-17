# Views

All view structs live in `Sources/SwiftOpenUI/Views/` and `Sources/SwiftOpenUI/Navigation/`. Each is a value type conforming to `View` with `Body = Never` (primitive views rendered by backends).

## Display

| View | Description |
|------|-------------|
| `Text(_ string:)` | Static text label. Supports `.font()`, `.foregroundColor()`, `.foregroundStyle()`. |
| `Color` | Fills available space with a solid color. |
| `Divider` | Horizontal separator line. |
| `Spacer` | Flexible space that expands along the stack axis. |

## Controls

| View | Description |
|------|-------------|
| `Button(_ label:, action:)` | Tappable button with a text label and action closure. |
| `TextField(_ placeholder:, text: Binding<String>)` | Single-line text input bound to a `@State` string. |

## Layout

| View | Description |
|------|-------------|
| `VStack(spacing:)` | Vertical stack via `@ViewBuilder`. |
| `HStack(spacing:)` | Horizontal stack via `@ViewBuilder`. |
| `ZStack` | Overlay stack (back-to-front). |

## Containers

| View | Description |
|------|-------------|
| `Group` | Transparent grouping — no visual effect, passes children through. |
| `ForEach` | Data-driven repetition of views from a `RandomAccessCollection`. |
| `AnyView` | Type-erased wrapper for heterogeneous view storage. |
| `EmptyView` | Renders nothing. Used as a default placeholder. |

## Navigation

| View / Modifier | Description |
|-----------------|-------------|
| `NavigationStack` | Container managing a push/pop view stack. Accepts optional `path: Binding<NavigationPath>` for programmatic navigation. |
| `NavigationLink(_ label:, title:, destination:)` | Button that pushes a destination view onto the stack. |
| `NavigationPath` | Type-erased collection of navigation stack elements. Methods: `append()`, `removeLast()`. |
| `.navigationTitle(_ title:)` | Sets the title displayed in the header bar for this view. |
| `.navigationDestination(for:destination:)` | Registers a destination factory for path-based navigation. |
| `NavigateAction` | Environment value (`.navigate`) with `push()`, `pop()`, `popToRoot()` for programmatic control. |

### Backend support

- **GTK4**: GtkStack + GtkHeaderBar with back button and slide transitions.
- **macOS**: Uses real SwiftUI's NavigationStack.
- **Win32 / Web**: Core types compile; backend rendering not yet implemented.
