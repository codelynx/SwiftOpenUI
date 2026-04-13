# App Bundle Format

Unified `.app` bundle format for SwiftOpenUI applications across macOS, Linux, and Windows.

## Motivation

macOS `.app` bundles are self-contained, drag-to-install, and cleanly structured. Linux and Windows lack an equivalent convention, leading to scattered files, platform-specific installers, and no standard way to locate resources at runtime.

SwiftOpenUI targets all three desktop platforms. A consistent bundle format would give developers:
- One mental model for app packaging across platforms
- A platform-independent `AppBundle` API for resource discovery
- Optional universal binary support (multiple architectures in one bundle)
- Clean xcopy/drag deployment without installers

## Bundle Structure

```
MyApp.app/
├── Info.json                  ← bundle metadata
├── <launcher>                 ← platform-specific entry point
├── bin/
│   ├── x86_64/
│   │   └── <executable>       ← x86-64 binary
│   └── <alt-arch>/
│       └── <executable>       ← ARM64 / aarch64 binary
├── Resources/
│   ├── icons/
│   ├── assets/
│   └── <locale>.lproj/       ← localized resources
└── Frameworks/                ← bundled shared libraries
    └── <libs>
```

### Per-Platform Details

#### macOS

Uses Apple's native `.app/Contents/` structure as-is. The `AppBundle` API wraps `Foundation.Bundle.main`. No changes needed — macOS is the reference implementation.

```
MyApp.app/
├── Contents/
│   ├── MacOS/MyApp            ← universal binary (native support)
│   ├── Resources/
│   ├── Frameworks/
│   └── Info.plist
```

#### Linux

```
MyApp.app/
├── MyApp                      ← launcher (shell script or static ELF shim)
├── Info.json
├── bin/
│   ├── x86_64/MyApp
│   └── aarch64/MyApp
├── Resources/
└── lib/
    └── libSwiftOpenUI.so
```

**Launcher** — a small shell script or static binary that detects architecture and exec's the right binary:

```bash
#!/bin/sh
BUNDLE_DIR="$(cd "$(dirname "$0")" && pwd)"
ARCH="$(uname -m)"
exec "$BUNDLE_DIR/bin/$ARCH/MyApp" "$@"
```

**Desktop integration** — a `.desktop` file can point to the launcher for app menu integration.

**Single-arch shortcut** — if only one architecture is needed, the launcher can be the binary itself (no `bin/` subdirectory).

#### Windows

```
MyApp.app\
├── MyApp.exe                  ← launcher shim (small x86-64 EXE)
├── Info.json
├── bin\
│   ├── x86_64\MyApp.exe
│   └── arm64\MyApp.exe
├── Resources\
└── Frameworks\
    └── SwiftOpenUI.dll
```

**Launcher shim** — a tiny `.exe` that detects architecture via `IsWow64Process2()` or `GetNativeSystemInfo()`, then launches the correct binary from `bin\`. Passes through args and exit code.

**Single-arch shortcut** — same as Linux; skip `bin/` and make the top-level `.exe` the real binary.

## Info.json

Minimal metadata file (macOS uses `Info.plist` instead):

```json
{
  "bundleIdentifier": "com.example.myapp",
  "bundleName": "MyApp",
  "bundleVersion": "1.0.0",
  "executableName": "MyApp",
  "minimumSwiftOpenUIVersion": "0.1.0",
  "architectures": ["x86_64", "aarch64"],
  "icon": "Resources/icons/app.ico"
}
```

## AppBundle API

Platform-independent API for resource discovery at runtime. Lives in `Sources/SwiftOpenUI/App/`.

```swift
public struct AppBundle {
    /// The main application bundle.
    public static var main: AppBundle { get }

    /// Root directory of the bundle (e.g., /path/to/MyApp.app/).
    public var bundlePath: String { get }

    /// Path to the running executable.
    public var executablePath: String { get }

    /// Path to the Resources/ directory.
    public var resourcesPath: String { get }

    /// Path to the Frameworks/ (or lib/) directory.
    public var librariesPath: String { get }

    /// Parsed Info.json (or Info.plist on macOS) metadata.
    public var info: BundleInfo { get }

    /// Locate a named resource.
    public func path(forResource name: String,
                     ofType ext: String? = nil,
                     in subdirectory: String? = nil) -> String?

    /// Load raw data for a named resource.
    public func data(forResource name: String,
                     ofType ext: String? = nil,
                     in subdirectory: String? = nil) -> Data?
}
```

### Finding the Bundle Root

Each platform walks up from the executable to find the bundle root:

| Platform | Executable location | Method |
|----------|-------------------|--------|
| macOS | `Bundle.main.bundlePath` | Foundation (native) |
| Linux | `/proc/self/exe` → realpath | Walk up to find `Info.json` |
| Windows | `GetModuleFileNameW()` | Walk up to find `Info.json` |

**Heuristic**: from the executable's directory, walk up until a directory containing `Info.json` (or `Contents/Info.plist` on macOS) is found. That's the bundle root.

## Implementation Plan

### Phase 1: AppBundle API + Resource Discovery
- [ ] `AppBundle` struct in `Sources/SwiftOpenUI/App/AppBundle.swift`
- [ ] `BundleInfo` struct for parsed metadata
- [ ] macOS: wrap `Foundation.Bundle.main`
- [ ] Linux: `/proc/self/exe` + directory walk
- [ ] Windows: `GetModuleFileNameW()` + directory walk
- [ ] Unit tests for path resolution

### Phase 2: Packaging Tool
- [ ] `swift-openui-package` CLI tool (or SPM plugin)
- [ ] Input: built binary + Resources directory
- [ ] Output: `.app/` bundle with correct structure
- [ ] `--architectures` flag for multi-arch bundles
- [ ] Platform launcher generation (shell script for Linux, shim .exe for Windows)

### Phase 3: Universal Binary Support
- [ ] Linux launcher shim (static ELF, replaces shell script)
- [ ] Windows launcher shim (tiny .exe, arch detection + exec)
- [ ] Multi-arch build orchestration (`swift build` for each target, combine into bundle)

### Phase 4: Desktop Integration
- [ ] Linux: `.desktop` file generation, XDG icon installation
- [ ] Windows: shortcut creation, Start Menu integration, `.app` folder icon overlay (registry)
- [ ] macOS: already handled by native `.app` format

## Design Decisions

- **macOS stays native**: Don't reinvent `.app/Contents/` — wrap it. Developers who ship macOS-only can ignore this entirely.
- **Info.json over Info.plist**: JSON is simpler to parse without Foundation. macOS uses its native plist.
- **Launcher is optional**: Single-arch apps can skip the launcher and `bin/` directory. The top-level executable IS the app.
- **No custom file format**: The bundle is a plain directory. No archive, no signature envelope. Tools like code signing can be layered on later.
- **Not a replacement for system packages**: This doesn't replace `.deb`, `.msi`, or Flatpak for system-level distribution. It's an app-level container for portable deployment.

## Open Questions

1. **Should we support Wasm bundles?** Web apps have their own packaging (HTML + JS + Wasm). A `.app` directory doesn't map well to web deployment.
2. **Code signing**: macOS has codesign. Should we define a signing format for Linux/Windows bundles?
3. **Auto-update**: Should the bundle format include provisions for delta updates?
4. **Compression**: Should we support a `.app.zip` or `.app.tar.gz` distribution format with a standard layout inside?
