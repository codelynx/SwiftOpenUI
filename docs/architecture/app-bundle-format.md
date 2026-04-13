# App Bundle Format

Per-platform `.app` bundle format for SwiftOpenUI applications. Each bundle targets a single OS (macOS, Linux, or Windows) and may contain multiple CPU architectures for that OS.

## Overview

SwiftOpenUI applications are packaged as `.app` bundles — self-contained directories with a standard layout for executables, metadata, and resources. Each platform produces its own bundle, but they share a common convention:

- One mental model for app packaging (same API and convention, per OS)
- A platform-independent `AppBundle` API for resource discovery (same code, any OS)
- Optional multi-architecture support within a single-OS bundle (e.g., x86-64 + ARM64 Linux)
- Plain directory format — xcopy/drag deployment, no installers or custom file formats

## Bundle Structure

Each bundle targets exactly one OS. A macOS `.app` is not expected to run on Linux, and vice versa. The on-disk layout is **platform-specific** behind a **normalized API** — macOS uses its native `.app/Contents/` convention. Linux uses a common layout with `lib/` for shared libraries. Windows colocates DLLs directly beside each executable (no separate library directory). Multi-architecture support means bundling x86-64 and ARM64 binaries for the *same* OS, not cross-OS packaging.

### Architecture Naming Convention

Directory names under `bin/` and values in `Info.json.architectures` use the **platform-native** architecture identifier:

| Platform | 64-bit x86 | 64-bit ARM | Source |
|----------|-----------|-----------|--------|
| Linux | `x86_64` | `aarch64` | `uname -m` output |
| Windows | `x86_64` | `arm64` | Microsoft convention |
| macOS | n/a (universal binary) | n/a | handled by `lipo` |

There is no cross-platform normalization — `aarch64` and `arm64` are distinct identifiers for distinct platforms. A Linux bundle uses `bin/aarch64/`, a Windows bundle uses `bin\arm64\`. `Info.json.architectures` lists the platform-native names.

### Shared Structure (Linux and Windows)

Both Linux and Windows bundles share this common skeleton:

```
MyApp.app/
├── Info.json                  ← bundle metadata
├── <launcher>                 ← platform-specific entry point
├── bin/
│   ├── x86_64/
│   │   └── <executable>       ← x86-64 binary
│   └── <alt-arch>/
│       └── <executable>       ← ARM64 / aarch64 binary
└── Resources/
    ├── icons/
    ├── assets/
    └── <locale>.lproj/       ← localized resources
```

Linux adds `lib/` for shared libraries. Windows colocates DLLs beside each executable in `bin/<arch>/`. See per-platform details below.

### macOS

Uses Apple's native `.app/Contents/` structure as-is. The `AppBundle` API wraps `Foundation.Bundle.main`.

```
MyApp.app/
├── Contents/
│   ├── MacOS/MyApp            ← universal binary (native support)
│   ├── Resources/
│   ├── Frameworks/
│   └── Info.plist
```

### Linux

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

**Launcher** — a small shell script or static binary that detects architecture, sets up the library search path, and exec's the right binary:

```bash
#!/bin/sh
BUNDLE_DIR="$(cd "$(dirname "$0")" && pwd)"
ARCH="$(uname -m)"
export LD_LIBRARY_PATH="$BUNDLE_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$BUNDLE_DIR/bin/$ARCH/MyApp" "$@"
```

**Library loading contract**: The launcher sets `LD_LIBRARY_PATH` to include the bundle's `lib/` directory before exec. The packaging tool also embeds `$ORIGIN/../../lib` as an rpath in each binary under `bin/<arch>/`, so the app works when launched directly (without the launcher). Both mechanisms coexist — rpath is primary, `LD_LIBRARY_PATH` is the backup for runtime `dlopen`.

**Single-arch shortcut** — if only one architecture is needed, the launcher can be the binary itself placed at the bundle root (no `bin/` subdirectory). The binary's rpath is set to `$ORIGIN/lib`.

### Windows

```
MyApp.app\
├── MyApp.exe                  ← launcher shim (x86-64, arch detection)
├── Info.json
├── bin\
│   ├── x86_64\
│   │   ├── MyApp.exe
│   │   └── SwiftOpenUI.dll    ← DLLs colocated with each arch binary
│   └── arm64\
│       ├── MyApp.exe
│       └── SwiftOpenUI.dll
└── Resources\
```

**Launcher (multi-arch only)**: A single x86-64 `.exe` at the bundle root that detects architecture via `IsWow64Process2()` / `GetNativeSystemInfo()` and spawns the native binary from `bin\<arch>\` via `CreateProcessW`. The x86-64 launcher runs on ARM64 via Windows' built-in x86 emulation (Prism), present on all Windows 11 ARM64. Windows 10 ARM64 IoT (no emulation) is not a supported target.

**`executableName` semantics**: `Info.json.executableName` always names the top-level entry point (`MyApp`). In a multi-arch bundle this is the launcher; in a single-arch bundle this is the real binary itself. `AppBundle.executablePath` returns the path of the currently running binary (resolved at runtime via `GetModuleFileNameW()`).

**DLL loading contract**: The packaging tool **colocates required DLLs with each real executable** in `bin\<arch>\`. Windows resolves import-time DLL dependencies from the directory containing the loading `.exe`, and APIs like `SetDllDirectoryW()` only affect the calling process, not a spawned child. There is no separate library directory — DLLs exist only beside each executable, eliminating dual-load ABI/state-split risk.

**Single-arch shortcut** — skip `bin\` and make the top-level `.exe` the real binary with DLLs alongside it. No launcher needed.

## Info.json / BundleInfo

`Info.json` is the metadata file for Linux and Windows bundles. macOS uses its native `Info.plist`.

Linux example (uses `aarch64`):

```json
{
  "bundleIdentifier": "com.example.myapp",
  "bundleName": "MyApp",
  "bundleVersion": "1.0.0",
  "executableName": "MyApp",
  "minimumSwiftOpenUIVersion": "0.1.0",
  "architectures": ["x86_64", "aarch64"],
  "icon": "Resources/icons/app.png"
}
```

Windows example (uses `arm64`):

```json
{
  "bundleIdentifier": "com.example.myapp",
  "bundleName": "MyApp",
  "bundleVersion": "1.0.0",
  "executableName": "MyApp",
  "minimumSwiftOpenUIVersion": "0.1.0",
  "architectures": ["x86_64", "arm64"],
  "icon": "Resources/icons/app.ico"
}
```

### BundleInfo Struct

```swift
public struct BundleInfo: Codable, Equatable {
    public var bundleIdentifier: String
    public var bundleName: String?
    public var bundleVersion: String?
    public var executableName: String
    public var minimumSwiftOpenUIVersion: String?
    public var architectures: [String]?
    public var icon: String?
}
```

Only `bundleIdentifier` and `executableName` are required on all platforms. The remaining fields are optional to accommodate valid macOS bundles that omit `CFBundleName` or `CFBundleShortVersionString`.

### Info.plist Mapping (macOS)

| BundleInfo field | Info.json key | Info.plist key (with fallback chain) |
|-----------------|---------------|--------------------------------------|
| `bundleIdentifier` | `bundleIdentifier` | `CFBundleIdentifier` |
| `bundleName` | `bundleName` | `CFBundleDisplayName` → `CFBundleName` |
| `bundleVersion` | `bundleVersion` | `CFBundleShortVersionString` → `CFBundleVersion` |
| `executableName` | `executableName` | `CFBundleExecutable` |
| `icon` | `icon` | `CFBundleIconFile` |

On macOS, `BundleInfo` is populated from `Info.plist` using fallback chains: `bundleName` tries `CFBundleDisplayName` first, then `CFBundleName`; `bundleVersion` tries `CFBundleShortVersionString` first, then `CFBundleVersion`. Fields absent from `Info.plist` (`architectures`, `minimumSwiftOpenUIVersion`) are nil. The mapping is explicit, one-directional (plist → BundleInfo), and non-lossy.

## AppBundle API

Platform-independent API for resource discovery at runtime. Implemented in `Sources/SwiftOpenUI/App/AppBundle.swift`.

```swift
public struct AppBundle {
    /// The main application bundle, discovered once at first access.
    /// Returns `nil` if no bundle structure is found (e.g., running via `swift run`).
    public private(set) static var main: AppBundle? { get }

    /// Root directory of the bundle (e.g., /path/to/MyApp.app/).
    public var bundlePath: String { get }

    /// Path to the running executable.
    public var executablePath: String { get }

    /// Path to the Resources/ directory.
    public var resourcesPath: String { get }

    /// Path to the directory containing shared libraries for the running process.
    /// - macOS: Contents/Frameworks/
    /// - Linux: lib/
    /// - Windows: directory containing the running .exe (DLLs colocated)
    public var librariesPath: String { get }

    /// Parsed bundle metadata.
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

### Resource Access

```swift
guard let bundle = AppBundle.main else {
    // Not running from a .app bundle (e.g., swift run, swift test)
    return
}

// Find a resource by name and extension
let iconPath = bundle.path(forResource: "app-icon", ofType: "png")
// → <bundle>/Resources/app-icon.png

// Resource in a subdirectory
let sfx = bundle.path(forResource: "click", ofType: "wav", in: "sounds")
// → <bundle>/Resources/sounds/click.wav

// Localized resource (explicit locale subdirectory)
let greeting = bundle.path(forResource: "welcome", ofType: "strings", in: "en.lproj")
// → <bundle>/Resources/en.lproj/welcome.strings

// Load data directly
if let data = bundle.data(forResource: "config", ofType: "json") {
    let config = try JSONDecoder().decode(AppConfig.self, from: data)
}

// Bundle metadata (optional fields — nil on macOS if plist keys are absent)
let version = bundle.info.bundleVersion   // Optional("1.0.0")
let name = bundle.info.bundleName         // Optional("MyApp")
```

### macOS Interop

On macOS, `AppBundle.main` wraps `Foundation.Bundle.main` (only when running from an actual `.app` bundle). Resource lookup delegates to Foundation for native localization fallback chains. Asset-catalog entries are not supported through this API — use `NSImage(named:)` or `UIImage(named:)` directly for compiled asset catalogs.

### Bundle Root Discovery

Each platform discovers the bundle root differently:

| Platform | Executable location | Method |
|----------|-------------------|--------|
| macOS | `Bundle.main.bundlePath` | Foundation (requires `.app` suffix) |
| Linux | `/proc/self/exe` → realpath | Walk up to find `Info.json` |
| Windows | `GetModuleFileNameW()` | Walk up to find `Info.json` |

On Linux and Windows, the discovery walks up from the executable's directory (up to 5 parent levels) until a directory containing `Info.json` is found.

### Library Directory Normalization

| Platform | On-disk directory | `librariesPath` returns |
|----------|------------------|------------------------|
| macOS | `Contents/Frameworks/` | `<bundle>/Contents/Frameworks/` |
| Linux | `lib/` | `<bundle>/lib/` |
| Windows | DLLs beside executable | directory containing the running `.exe` |

On Windows, `librariesPath` returns the directory containing the running `.exe` — the bundle root (single-arch) or `bin\<arch>\` (multi-arch). This ensures it always points where the process's libraries actually are.

## Runtime Loader Contract

The bundle format guarantees shared libraries are found at process startup. The mechanism differs by platform.

### Linux

1. **Launcher sets `LD_LIBRARY_PATH`**: Prepends `<bundle>/lib/` before exec.
2. **Binaries embed rpath**: `$ORIGIN/../../lib` (for `bin/<arch>/`) or `$ORIGIN/lib` (for single-arch root binary). Allows direct execution without the launcher.
3. **Both mechanisms coexist**: rpath is primary, `LD_LIBRARY_PATH` is backup for runtime `dlopen`.

### Windows

1. **DLLs are colocated with each real executable**: Copied into each `bin\<arch>\` directory at packaging time. Windows resolves import-time dependencies from the loading `.exe`'s directory.
2. **Single-arch bundles**: DLLs sit alongside the root `.exe`.
3. **No separate library directory**: Eliminates the risk of dual-loading two physical copies of the same DLL.

### macOS

Handled natively via `@rpath` and `@executable_path` in Mach-O binaries, plus the standard bundle structure.

## Design Decisions

- **macOS stays native**: Wraps `.app/Contents/` and `Foundation.Bundle` — no reinvention. macOS-only developers can ignore this format entirely.
- **Info.json over Info.plist**: JSON is simpler to parse without Foundation. macOS uses its native plist; `BundleInfo` maps explicitly.
- **Platform-specific library placement**: `lib/` on Linux, `Contents/Frameworks/` on macOS, colocated with executable on Windows. Each follows its platform's convention. `librariesPath` normalizes access.
- **Launcher is optional**: Single-arch apps skip the launcher and `bin/` directory. The top-level executable IS the app.
- **Loader contract differs by platform**: Linux uses rpath + `LD_LIBRARY_PATH`. Windows colocates DLLs — no inherited search path tricks. macOS uses native Mach-O loader.
- **Plain directory format**: No archive, no signature envelope. Code signing can be layered on later.
- **Not a replacement for system packages**: Does not replace `.deb`, `.msi`, or Flatpak. This is an app-level container for portable deployment.
- **No Wasm bundles**: Web apps have their own packaging (HTML + JS + Wasm). A `.app` directory does not map to web deployment.
- **Windows 10 ARM64 IoT not supported**: The x86-64 launcher requires Prism (Windows 11 ARM64).

## Implementation Status

| Component | Status | Location |
|-----------|--------|----------|
| `BundleInfo` struct | Done | `Sources/SwiftOpenUI/App/AppBundle.swift` |
| `AppBundle` API | Done | `Sources/SwiftOpenUI/App/AppBundle.swift` |
| macOS discovery (Foundation) | Done | `Sources/SwiftOpenUI/App/AppBundle.swift` |
| Linux discovery (`/proc/self/exe`) | Done | `Sources/SwiftOpenUI/App/AppBundle.swift` |
| Windows discovery (`GetModuleFileNameW`) | Done | `Sources/SwiftOpenUI/App/AppBundle.swift` |
| Resource lookup | Done | `Sources/SwiftOpenUI/App/AppBundle.swift` |
| Unit tests | Done (13) | `Tests/SwiftOpenUITests/AppBundleTests.swift` |
| Packaging tool | Not started | — |
| Linux static ELF launcher | Not started | — |
| Windows launcher shim | Not started | — |
| Desktop integration | Not started | — |

## Related

- [App Bundle Packaging Guide](../guides/app-bundle-packaging.md) — step-by-step build and packaging instructions
- [Getting Started](../guides/getting-started.md) — build and run on all platforms
- [Rendering Backends](rendering-backends.md) — backend architecture overview
