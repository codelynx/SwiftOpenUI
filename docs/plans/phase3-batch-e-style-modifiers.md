# Phase 3 Batch E — Style Modifiers

## Goal

Add `.buttonStyle()`, `.toggleStyle()`, `.textFieldStyle()` modifiers with environment-based style resolution and built-in style variants. Backends read the active style and adjust rendering.

## Scope

**In scope:** Environment-based style selection with built-in named styles. Backends switch on the style enum to produce different visual appearances.

**Not in scope:** Custom `makeBody(configuration:)` protocol pattern. That requires rendering a style's body view within the control, which is a deeper architectural change. Deferred to a future batch.

## Existing Foundation

- Environment system works (`EnvironmentValues`, `EnvironmentKey`, TLS propagation)
- `.environment()` modifier propagates values down the tree
- Picker already has a style enum (but stored on the view, not in environment)
- Button, Toggle, TextField are primitive views with hardwired default rendering

## Core Design (coordinator delivers)

### Style Enums

```swift
// Sources/SwiftOpenUI/Modifiers/ControlStyleModifiers.swift

public enum ButtonStyleType: Equatable {
    case automatic      // platform default
    case plain          // no chrome, just the label
    case bordered       // visible border
    case borderedProminent  // filled/prominent background
}

public enum ToggleStyleType: Equatable {
    case automatic      // platform default (checkbox or switch)
    case checkbox       // always checkbox
    case `switch`       // always switch
}

public enum TextFieldStyleType: Equatable {
    case automatic      // platform default
    case plain          // no border
    case roundedBorder  // rounded border
}
```

### Environment Keys

```swift
struct ButtonStyleKey: EnvironmentKey {
    static let defaultValue: ButtonStyleType = .automatic
}

struct ToggleStyleKey: EnvironmentKey {
    static let defaultValue: ToggleStyleType = .automatic
}

struct TextFieldStyleKey: EnvironmentKey {
    static let defaultValue: TextFieldStyleType = .automatic
}

extension EnvironmentValues {
    var buttonStyle: ButtonStyleType { ... }
    var toggleStyle: ToggleStyleType { ... }
    var textFieldStyle: TextFieldStyleType { ... }
}
```

### Modifier Views

```swift
public struct ButtonStyleModifier<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let style: ButtonStyleType
}

extension View {
    public func buttonStyle(_ style: ButtonStyleType) -> ButtonStyleModifier<Self>
}
```

Same pattern for `.toggleStyle()` and `.textFieldStyle()`.

### Core Tests

- Environment keys have correct defaults
- Modifiers store style and wrap content
- Style propagates through environment

---

## GTK4 Worker Instructions

### Button style rendering

Read `getCurrentEnvironment().buttonStyle` in `Button.gtkCreateWidget()`:
- `.automatic` / `.bordered`: current default (gtk_button, with border CSS)
- `.plain`: `border: none; background: none; padding: 0;`
- `.borderedProminent`: `background: @accent_bg_color; color: white; border-radius: 6px; padding: 6px 12px;`

### Toggle style rendering

Read `getCurrentEnvironment().toggleStyle` in `Toggle.gtkCreateWidget()`:
- `.automatic` / `.checkbox`: current default (`gtk_check_button_new_with_label`)
- `.switch`: `gtk_switch_new()` with label in a horizontal box

### TextField style rendering

Read `getCurrentEnvironment().textFieldStyle` in `TextField.gtkCreateWidget()`:
- `.automatic` / `.roundedBorder`: current default
- `.plain`: `border: none; outline: none;` CSS

### Style modifier rendering

Each style modifier sets environment before rendering content:

```swift
extension ButtonStyleModifier: GTKRenderable {
    public func gtkCreateWidget() -> OpaquePointer {
        var env = getCurrentEnvironment()
        env.buttonStyle = style
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(env)
        defer { setCurrentEnvironment(prev) }
        return widgetFromOpaque(gtkRenderView(content))
    }
}
```

### Files to edit

- `Sources/Backend/GTK4/Rendering/GTKRenderer.swift` — Button/Toggle/TextField style reading + modifier extensions
- `Tests/BackendTests/GTK4Tests/GTK4StyleTests.swift` — new

---

## Win32 Worker Instructions

### Button style rendering

Read `getCurrentEnvironment().buttonStyle` in `Button.winCreateWidget()`:
- `.automatic` / `.bordered`: current default (D2D flat button)
- `.plain`: minimal button, no background fill
- `.borderedProminent`: filled background with accent color

### Toggle style rendering

Read `getCurrentEnvironment().toggleStyle`:
- `.automatic` / `.checkbox`: current default (native checkbox)
- `.switch`: would need a toggle switch control — may use checkbox as fallback for Batch E

### TextField style rendering

Read `getCurrentEnvironment().textFieldStyle`:
- `.automatic` / `.roundedBorder`: current default
- `.plain`: remove WS_BORDER style

### Files to edit

- `Sources/Backend/Win32/Rendering/WinRenderer.swift`
- `Tests/BackendTests/Win32Tests/Win32StyleTests.swift` — new

---

## Web Worker Instructions

### Button style rendering

Read `getCurrentEnvironment().buttonStyle` in `Button.webCreateElement()`:
- `.automatic` / `.bordered`: `border: 1px solid currentColor; padding: 6px 12px; border-radius: 4px;`
- `.plain`: `border: none; background: none; padding: 0;`
- `.borderedProminent`: `background: #007AFF; color: white; border: none; border-radius: 6px; padding: 8px 16px;`

### Toggle style rendering

Read `getCurrentEnvironment().toggleStyle`:
- `.automatic` / `.checkbox`: current default (`<input type="checkbox">`)
- `.switch`: use CSS-styled toggle switch or `<input type="checkbox">` with switch appearance

### TextField style rendering

Read `getCurrentEnvironment().textFieldStyle`:
- `.automatic` / `.roundedBorder`: `border: 1px solid #ccc; border-radius: 4px; padding: 4px 8px;`
- `.plain`: `border: none; outline: none;`

### Files to edit

- `Sources/Backend/Web/Rendering/WebRenderer.swift`
- `Tests/BackendTests/WebTests/WebStyleTests.swift` — new

---

## Handoff Protocol

Same as previous batches. Coordinator pushes core, workers branch from it.

## Known Limitations

- Style enums, not protocols — no custom `makeBody(configuration:)` in this batch
- `.switch` toggle style may fall back to checkbox on Win32 (no native switch control)
- Style only affects direct controls, not nested ones (except through environment cascade)
- PickerStyle remains a direct property, not environment-based (consistency refactor deferred)
