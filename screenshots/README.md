# Screenshots

Cross-platform screenshot comparison for SwiftOpenUI examples.

## Structure

```
screenshots/
├── linux/      ← GTK4 (captured via gnome-screenshot)
├── macos/      ← Native SwiftUI
├── windows/    ← Win32
└── web/        ← Browser/Wasm
```

## Capturing

### Linux

```bash
# Capture all examples
./screenshots/capture-linux.sh

# Capture one example
./screenshots/capture-linux.sh HelloWorld
```

Requires `gnome-screenshot` and a running display server (X11 or Wayland).

### Windows

```powershell
# Capture all examples
.\screenshots\capture-windows.ps1

# Capture one example
.\screenshots\capture-windows.ps1 HelloWorld
```

Uses Win32 `FindWindow` + GDI+ `CopyFromScreen` to capture by window title. Saves as PNG. No external tools needed.

### macOS / Web

Platform-specific capture scripts TBD. For now, capture manually and save to the appropriate directory.

## Naming Convention

Screenshots are named to match example numbers:

| File | Example | Command |
|------|---------|---------|
| `01-HelloWorld.png` | HelloWorld | `swift run HelloWorld` |
| `02-TextStyles.png` | TextStyles | `swift run TextStyles` |
| `03-Buttons.png` | Buttons | `swift run Buttons` |
| `04-State.png` | State | `swift run StateDemo` |
| `05-Layout.png` | Layout | `swift run Layout` |
