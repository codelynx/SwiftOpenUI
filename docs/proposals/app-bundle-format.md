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

The on-disk layout is intentionally **platform-specific** behind a **normalized API**. macOS uses its native `.app/Contents/` convention. Linux and Windows share a common layout with one difference: the shared library directory name follows each platform's convention (`lib/` on Linux, `Frameworks/` on Windows), matching what developers and toolchains expect on each OS.

### Canonical Layout (Linux / Windows)

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
└── lib/  (Linux) or Frameworks/  (Windows)
    └── <shared libraries>
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
├── MyApp.exe                  ← launcher shim (see below for arch strategy)
├── Info.json
├── bin\
│   ├── x86_64\MyApp.exe
│   └── arm64\MyApp.exe
├── Resources\
└── Frameworks\
    └── SwiftOpenUI.dll
```

**Launcher architecture strategy**: The top-level launcher must be launchable on all target architectures. Two options:

1. **Dual launcher (recommended for multi-arch)**: Ship both `MyApp.exe` (x86-64) and `MyApp_arm64.exe` (ARM64) at the bundle root. A `.lnk` shortcut or installer picks the right one, or the user double-clicks the one matching their system. The x86-64 launcher also works on ARM64 via Windows' built-in x86 emulation (Prism), so a single x86-64 launcher is acceptable when x86 emulation is guaranteed (Windows 11 ARM64).
2. **Single x86-64 launcher with emulation requirement**: Ship only an x86-64 launcher. Document that Windows ARM64 systems require x86 emulation support (present on all Windows 11 ARM64, but absent on Windows 10 ARM64 IoT). The launcher detects architecture via `IsWow64Process2()` / `GetNativeSystemInfo()` and spawns the native `bin\arm64\MyApp.exe` for full performance.

**DLL loading contract**: The launcher calls `SetDllDirectoryW()` or `AddDllDirectory()` to add the bundle's `Frameworks\` directory to the DLL search path before spawning the real executable. For single-arch bundles (no launcher), DLLs are colocated with the executable in `bin\<arch>\` or the packaging tool places copies there.

**Single-arch shortcut** — same as Linux; skip `bin\` and make the top-level `.exe` the real binary with DLLs alongside it.

## Info.json / BundleInfo Mapping

`Info.json` is the portable metadata file for Linux and Windows bundles. macOS uses its native `Info.plist`. The `BundleInfo` struct exposes a **SwiftOpenUI-specific** set of fields, with a defined mapping from each source format.

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

### BundleInfo Struct

```swift
public struct BundleInfo: Codable {
    public var bundleIdentifier: String
    public var bundleName: String
    public var bundleVersion: String
    public var executableName: String
    public var minimumSwiftOpenUIVersion: String?
    public var architectures: [String]
    public var icon: String?
}
```

### Key Mapping from Info.plist (macOS)

| BundleInfo field | Info.json key | Info.plist key |
|-----------------|---------------|----------------|
| `bundleIdentifier` | `bundleIdentifier` | `CFBundleIdentifier` |
| `bundleName` | `bundleName` | `CFBundleName` |
| `bundleVersion` | `bundleVersion` | `CFBundleShortVersionString` |
| `executableName` | `executableName` | `CFBundleExecutable` |
| `icon` | `icon` | `CFBundleIconFile` |

On macOS, `BundleInfo` is populated by reading the native `Info.plist` keys and mapping them to the SwiftOpenUI schema. Fields not present in `Info.plist` (like `architectures`, `minimumSwiftOpenUIVersion`) are left nil or derived from the binary (e.g., `lipo -archs`). No lossy translation — the mapping is explicit and one-directional (plist → BundleInfo).

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

    /// Path to the shared libraries directory.
    /// Returns the platform-appropriate path:
    /// - macOS: Contents/Frameworks/
    /// - Linux: lib/
    /// - Windows: Frameworks\
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
| Windows | `Frameworks\` | `<bundle>\Frameworks\` |

This is intentional: each platform uses its conventional name. The API normalizes access so application code never needs to know which name is used.

## Runtime Loader Contract

The bundle format must guarantee that shared libraries are found at process startup. This is the launcher's responsibility.

### Linux

1. **Launcher sets `LD_LIBRARY_PATH`**: Prepends `<bundle>/lib/` before exec.
2. **Binaries embed rpath**: `$ORIGIN/../../lib` (for `bin/<arch>/MyApp`) or `$ORIGIN/lib` (for single-arch root binary). This allows direct execution without the launcher.
3. **Both mechanisms coexist**: rpath is the primary, `LD_LIBRARY_PATH` is the backup for edge cases (e.g., dlopen at runtime).

### Windows

1. **Launcher calls `SetDllDirectoryW()`**: Adds `<bundle>\Frameworks\` to the search path before spawning the real binary.
2. **Single-arch bundles**: DLLs are colocated with the executable (standard Windows convention — DLLs next to `.exe` are found automatically).
3. **Multi-arch bundles**: The launcher handles DLL path setup. Alternatively, the packaging tool places DLL copies in each `bin\<arch>\` directory (trades disk space for simplicity).

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
- [ ] `librariesPath` normalization per platform
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
- [ ] DLL colocation or `Frameworks\` setup for Windows

### Phase 3: Universal Binary Support
- [ ] Linux launcher shim (static ELF, replaces shell script)
- [ ] Windows launcher shim (tiny .exe, arch detection + exec, `SetDllDirectoryW`)
- [ ] Dual-launcher option for Windows ARM64 (x86-64 + ARM64 launchers)
- [ ] Multi-arch build orchestration (`swift build` for each target, combine into bundle)

### Phase 4: Desktop Integration
- [ ] Linux: `.desktop` file generation, XDG icon installation
- [ ] Windows: shortcut creation, Start Menu integration, `.app` folder icon overlay (registry)
- [ ] macOS: already handled by native `.app` format

## Design Decisions

- **macOS stays native**: Don't reinvent `.app/Contents/` — wrap it. Developers who ship macOS-only can ignore this entirely.
- **Info.json over Info.plist**: JSON is simpler to parse without Foundation. macOS uses its native plist; `BundleInfo` maps explicitly.
- **Platform-specific library directories**: `lib/` on Linux, `Frameworks/` on Windows/macOS. Follows each platform's convention rather than forcing a single name. The API normalizes this.
- **Launcher is optional**: Single-arch apps can skip the launcher and `bin/` directory. The top-level executable IS the app.
- **Loader contract is the launcher's job**: The launcher sets up library search paths. Binaries also embed rpath/DLL-dir as a fallback for direct execution.
- **No custom file format**: The bundle is a plain directory. No archive, no signature envelope. Tools like code signing can be layered on later.
- **Not a replacement for system packages**: This doesn't replace `.deb`, `.msi`, or Flatpak for system-level distribution. It's an app-level container for portable deployment.

## Open Questions

1. **Should we support Wasm bundles?** Web apps have their own packaging (HTML + JS + Wasm). A `.app` directory doesn't map well to web deployment.
2. **Code signing**: macOS has codesign. Should we define a signing format for Linux/Windows bundles?
3. **Auto-update**: Should the bundle format include provisions for delta updates?
4. **Compression**: Should we support a `.app.zip` or `.app.tar.gz` distribution format with a standard layout inside?
5. **Windows 10 ARM64**: Do we require x86 emulation for the launcher, or mandate dual launchers for full ARM64 support?
