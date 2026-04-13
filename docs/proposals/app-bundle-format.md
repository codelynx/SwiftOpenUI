# App Bundle Format

Per-platform `.app` bundle format for SwiftOpenUI applications. Each bundle targets a single OS (macOS, Linux, or Windows) and may contain multiple CPU architectures for that OS.

## Motivation

macOS `.app` bundles are self-contained, drag-to-install, and cleanly structured. Linux and Windows lack an equivalent convention, leading to scattered files, platform-specific installers, and no standard way to locate resources at runtime.

SwiftOpenUI targets all three desktop platforms. Each platform produces its own bundle, but they share a common convention so developers get:
- One mental model for app packaging (same API and convention, per OS)
- A platform-independent `AppBundle` API for resource discovery (same code, any OS)
- Optional multi-architecture support within a single-OS bundle (e.g., x86-64 + ARM64 Linux)
- Clean xcopy/drag deployment without installers

## Bundle Structure

Each bundle targets exactly one OS. A macOS `.app` is not expected to run on Linux, and vice versa. The on-disk layout is **platform-specific** behind a **normalized API** — macOS uses its native `.app/Contents/` convention. Linux uses a common layout with `lib/` for shared libraries. Windows colocates DLLs directly beside each executable (no separate library directory). Multi-architecture support means bundling x86-64 and ARM64 binaries for the *same* OS, not cross-OS packaging.

### Architecture Naming Convention

Directory names under `bin/` and values in `Info.json.architectures` use the **platform-native** architecture identifier:

| Platform | 64-bit x86 | 64-bit ARM | Source |
|----------|-----------|-----------|--------|
| Linux | `x86_64` | `aarch64` | `uname -m` output |
| Windows | `x86_64` | `arm64` | Microsoft convention |
| macOS | n/a (universal binary) | n/a | handled by `lipo` |

The launcher and packaging tool use these exact strings for directory lookup. There is no cross-platform normalization — `aarch64` and `arm64` are distinct identifiers for distinct platforms. A Linux bundle uses `bin/aarch64/`, a Windows bundle uses `bin\arm64\`. `Info.json.architectures` lists the platform-native names.

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

**Launcher** — a small shell script or static binary that detects architecture, sets up the library search path, and exec's the right binary:

```bash
#!/bin/sh
BUNDLE_DIR="$(cd "$(dirname "$0")" && pwd)"
ARCH="$(uname -m)"
export LD_LIBRARY_PATH="$BUNDLE_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$BUNDLE_DIR/bin/$ARCH/MyApp" "$@"
```

**Library loading contract**: The launcher sets `LD_LIBRARY_PATH` to include the bundle's `lib/` directory before exec. Additionally, the packaging tool embeds `$ORIGIN/../../lib` as an rpath in each binary under `bin/<arch>/`, so the app also works when launched directly (without the launcher). Both mechanisms are required for reliable self-contained deployment.

**Desktop integration** — a `.desktop` file can point to the launcher for app menu integration.

**Single-arch shortcut** — if only one architecture is needed, the launcher can be the binary itself placed at the bundle root (no `bin/` subdirectory). The binary's rpath is set to `$ORIGIN/lib`.

#### Windows

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

**Launcher strategy (multi-arch only)**: A single x86-64 launcher `.exe` at the bundle root. It detects architecture via `IsWow64Process2()` / `GetNativeSystemInfo()` and spawns the native binary from `bin\<arch>\`. The x86-64 launcher runs on ARM64 via Windows' built-in x86 emulation (Prism), which is present on all Windows 11 ARM64. Windows 10 ARM64 IoT (no emulation) is not a supported target.

**`executableName` semantics**: `Info.json.executableName` always names the top-level entry point (`MyApp`). In a multi-arch bundle this is the launcher; in a single-arch bundle this is the real binary itself — the two cases are structurally different but `executableName` consistently identifies the file a user or OS would launch. `AppBundle.executablePath` returns the path of the currently running binary (i.e., the real `bin\<arch>\MyApp.exe` in multi-arch, or the root `MyApp.exe` in single-arch), resolved at runtime via `GetModuleFileNameW()`.

**DLL loading contract**: The packaging tool **colocates required DLLs with each real executable** in `bin\<arch>\`. This is the only reliable mechanism — Windows resolves import-time DLL dependencies from the directory containing the loading `.exe`, and APIs like `SetDllDirectoryW()` only affect the calling process, not a spawned child's image-load search. There is no separate `Frameworks\` directory in multi-arch bundles — DLLs exist only beside each executable. This avoids the risk of loading two different physical copies of the same DLL into one process (e.g., an import-time load from `bin\<arch>\` and a runtime `LoadLibrary()` from a separate directory), which can cause ABI/state-split issues on Windows.

**Single-arch shortcut** — skip `bin\` and make the top-level `.exe` the real binary with DLLs alongside it. No launcher needed, no separate library directory.

## Info.json / BundleInfo Mapping

`Info.json` is the portable metadata file for Linux and Windows bundles. macOS uses its native `Info.plist`. The `BundleInfo` struct exposes a **SwiftOpenUI-specific** set of fields, with a defined mapping from each source format.

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
public struct BundleInfo: Codable {
    public var bundleIdentifier: String
    public var bundleName: String?
    public var bundleVersion: String?
    public var executableName: String
    public var minimumSwiftOpenUIVersion: String?
    public var architectures: [String]?
    public var icon: String?
}
```

Only `bundleIdentifier` and `executableName` are required on all platforms. The remaining fields are optional to accommodate valid macOS bundles that omit `CFBundleName` or `CFBundleShortVersionString`. On Linux/Windows, `Info.json` is expected to populate all fields, but the struct does not enforce this at the type level.

### Key Mapping from Info.plist (macOS)

| BundleInfo field | Info.json key | Info.plist key (with fallback chain) |
|-----------------|---------------|--------------------------------------|
| `bundleIdentifier` | `bundleIdentifier` | `CFBundleIdentifier` |
| `bundleName` | `bundleName` | `CFBundleDisplayName` → `CFBundleName` |
| `bundleVersion` | `bundleVersion` | `CFBundleShortVersionString` → `CFBundleVersion` |
| `executableName` | `executableName` | `CFBundleExecutable` |
| `icon` | `icon` | `CFBundleIconFile` |

On macOS, `BundleInfo` is populated by reading the native `Info.plist` keys and mapping them to the SwiftOpenUI schema. The mapping uses a fallback chain: `bundleName` tries `CFBundleDisplayName` first, then `CFBundleName`; `bundleVersion` tries `CFBundleShortVersionString` first, then `CFBundleVersion`. If neither key exists, the field is nil. Fields not present in `Info.plist` (`architectures`, `minimumSwiftOpenUIVersion`) are nil by default. `architectures` may be eagerly derived from the binary via `lipo -archs` if needed, but this is an implementation choice — the API treats it as optional on all platforms. No lossy translation — the mapping is explicit and one-directional (plist → BundleInfo).

## AppBundle API

Platform-independent API for resource discovery at runtime. Lives in `Sources/SwiftOpenUI/App/`.

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

### Resource Access Examples

```swift
guard let bundle = AppBundle.main else {
    // Not running from a .app bundle (e.g., swift run, swift test)
    return
}

// Image by name and extension
let iconPath = bundle.path(forResource: "app-icon", ofType: "png")
// → <bundle>/Resources/app-icon.png

// Asset in a subdirectory
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

On macOS, `AppBundle.main` wraps `Foundation.Bundle.main`. The resource lookup methods delegate to Foundation's implementation for native localization fallback chains. Asset-catalog entries are not supported through this API — use `NSImage(named:)` or `UIImage(named:)` directly for compiled asset catalogs. The API surface is intentionally a subset — apps that need full `Foundation.Bundle` features can access it directly on macOS.

### Finding the Bundle Root

Each platform walks up from the executable to find the bundle root:

| Platform | Executable location | Method |
|----------|-------------------|--------|
| macOS | `Bundle.main.bundlePath` | Foundation (native) |
| Linux | `/proc/self/exe` → realpath | Walk up to find `Info.json` |
| Windows | `GetModuleFileNameW()` | Walk up to find `Info.json` |

**Heuristic**: from the executable's directory, walk up until a directory containing `Info.json` (or `Contents/Info.plist` on macOS) is found. That's the bundle root.

### Library Directory Normalization

The `librariesPath` property returns the platform-correct directory name:

| Platform | On-disk directory | `librariesPath` returns |
|----------|------------------|------------------------|
| macOS | `Contents/Frameworks/` | `<bundle>/Contents/Frameworks/` |
| Linux | `lib/` | `<bundle>/lib/` |
| Windows | DLLs beside executable | directory containing the running `.exe` |

On macOS and Linux, `librariesPath` points at a dedicated library directory. On Windows, DLLs are colocated with the executable (no separate library directory), so `librariesPath` returns the directory containing the running `.exe` — either the bundle root (single-arch) or `bin\<arch>\` (multi-arch). This ensures `librariesPath` always points where the process's libraries actually are, with no dual-directory ambiguity.

## Runtime Loader Contract

The bundle format must guarantee that shared libraries are found at process startup. The mechanism differs by platform — the launcher, the packaging tool, or the OS itself may be responsible.

### Linux

1. **Launcher sets `LD_LIBRARY_PATH`**: Prepends `<bundle>/lib/` before exec.
2. **Binaries embed rpath**: `$ORIGIN/../../lib` (for `bin/<arch>/MyApp`) or `$ORIGIN/lib` (for single-arch root binary). This allows direct execution without the launcher.
3. **Both mechanisms coexist**: rpath is the primary, `LD_LIBRARY_PATH` is the backup for edge cases (e.g., dlopen at runtime).

### Windows

1. **DLLs are colocated with each real executable**: The packaging tool copies required DLLs into each `bin\<arch>\` directory. Windows resolves import-time dependencies from the directory containing the loading `.exe`, so this is the only mechanism that works reliably at image-load time.
2. **Single-arch bundles**: DLLs sit alongside the root `.exe` (standard Windows convention).
3. **No separate library directory**: Unlike Linux (`lib/`) and macOS (`Frameworks/`), Windows bundles do not have a dedicated shared library directory. All DLLs live beside the executable that loads them, eliminating the risk of dual-loading two physical copies of the same DLL.

### macOS

No special handling needed — `@rpath` and `@executable_path` in Mach-O binaries, plus the native bundle structure, handle this automatically.

## Implementation Plan

### Phase 1: AppBundle API + Resource Discovery
- [ ] `AppBundle` struct in `Sources/SwiftOpenUI/App/AppBundle.swift`
- [ ] `BundleInfo` struct with `Codable` conformance for `Info.json`
- [ ] `BundleInfo` mapping from `Info.plist` keys on macOS
- [ ] macOS: wrap `Foundation.Bundle.main`
- [ ] Linux: `/proc/self/exe` + directory walk
- [ ] Windows: `GetModuleFileNameW()` + directory walk
- [ ] `librariesPath` per platform (dedicated dir on macOS/Linux, exe-local on Windows)
- [ ] Unit tests for path resolution and `BundleInfo` parsing

### Phase 2: Packaging Tool
- [ ] `swift-openui-package` CLI tool (or SPM plugin)
- [ ] Input manifest (`Bundle.json` or CLI flags):
  - Built binaries (one per architecture)
  - Resources directory
  - Shared libraries to bundle
  - `Info.json` metadata (or fields to generate it)
- [ ] Output: `.app/` bundle with correct structure
- [ ] `--architectures` flag for multi-arch bundles
- [ ] Platform launcher generation (shell script for Linux, shim .exe for Windows)
- [ ] rpath embedding for Linux binaries (`patchelf --set-rpath`)
- [ ] DLL colocation into each `bin\<arch>\` for Windows multi-arch bundles

### Phase 3: Multi-Architecture Support
- [ ] Linux launcher shim (static ELF, replaces shell script)
- [ ] Windows launcher shim (tiny x86-64 .exe, arch detection + `CreateProcessW`)
- [ ] Windows ARM64 support via x86 emulation (Prism) for the launcher
- [ ] Multi-arch build orchestration (`swift build` for each target, combine into bundle)

### Phase 4: Desktop Integration
- [ ] Linux: `.desktop` file generation, XDG icon installation
- [ ] Windows: shortcut creation, Start Menu integration, `.app` folder icon overlay (registry)
- [ ] macOS: already handled by native `.app` format

## Design Decisions

- **macOS stays native**: Don't reinvent `.app/Contents/` — wrap it. Developers who ship macOS-only can ignore this entirely.
- **Info.json over Info.plist**: JSON is simpler to parse without Foundation. macOS uses its native plist; `BundleInfo` maps explicitly.
- **Platform-specific library placement**: `lib/` on Linux, `Contents/Frameworks/` on macOS, colocated with executable on Windows. Each follows its platform's convention. `librariesPath` normalizes access.
- **Launcher is optional**: Single-arch apps can skip the launcher and `bin/` directory. The top-level executable IS the app.
- **Loader contract differs by platform**: Linux uses rpath (primary) + `LD_LIBRARY_PATH` (launcher backup). Windows colocates DLLs with each real executable — no inherited search path tricks. macOS uses native Mach-O loader.
- **No custom file format**: The bundle is a plain directory. No archive, no signature envelope. Tools like code signing can be layered on later.
- **Not a replacement for system packages**: This doesn't replace `.deb`, `.msi`, or Flatpak for system-level distribution. It's an app-level container for portable deployment.

## Open Questions

1. **Should we support Wasm bundles?** Web apps have their own packaging (HTML + JS + Wasm). A `.app` directory doesn't map well to web deployment.
2. **Code signing**: macOS has codesign. Should we define a signing format for Linux/Windows bundles?
3. **Auto-update**: Should the bundle format include provisions for delta updates?
4. **Compression**: Should we support a `.app.zip` or `.app.tar.gz` distribution format with a standard layout inside?
5. ~~**Windows 10 ARM64**~~: Resolved — single x86-64 launcher requires Prism (Windows 11 ARM64). Windows 10 ARM64 IoT is not a supported target.
