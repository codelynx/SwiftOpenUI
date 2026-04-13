# App Bundle Packaging Guide

How to build and package a SwiftOpenUI application as a `.app` bundle on Linux and Windows.

## Overview

A `.app` bundle is a directory containing your executable, metadata, and resources in a standard layout. The `AppBundle` API discovers this structure at runtime, giving your app access to its own resources, metadata, and library paths.

macOS uses its native `.app/Contents/` format — no custom SwiftOpenUI-specific packaging is needed, but the app must still be built as a `.app` bundle (via Xcode or `swift build` + standard macOS tooling) for `AppBundle.main` to resolve. This guide covers Linux and Windows only.

## Quick Start: SPM Plugin

The fastest way to create a bundle for same-machine, single-architecture builds:

```bash
swift package create-bundle <product> --allow-writing-to-package-directory
```

This builds the product (release by default), creates `.build/bundles/<product>.app/` with the correct layout, generates `Info.json`, and copies `Resources/` from the package root if present.

**Limitation**: The plugin derives `architectures` in `Info.json` from the build host. For cross-compiled binaries, edit `Info.json` manually after bundling. Multi-architecture bundles are not supported by the plugin — use the manual steps below.

Options:
- `-c debug` — use debug build configuration
- `--help` — show usage

## Linux

### Single-Architecture Bundle

The simplest layout — one executable at the bundle root.

```bash
# 1. Build your app
swift build --product MyApp -c release

# 2. Create the bundle structure
BUNDLE="MyApp.app"
ARCH="x86_64"        # set to match the binary: x86_64 or aarch64
mkdir -p "$BUNDLE/Resources" "$BUNDLE/lib"

# 3. Copy the executable
cp .build/release/MyApp "$BUNDLE/"

# 4. Set rpath so the executable finds bundled libraries
patchelf --set-rpath '$ORIGIN/lib' "$BUNDLE/MyApp"

# 5. Bundle shared libraries (if any)
# cp /path/to/libMyLib.so "$BUNDLE/lib/"

# 6. Create Info.json
cat > "$BUNDLE/Info.json" << EOF
{
  "bundleIdentifier": "com.example.myapp",
  "bundleName": "MyApp",
  "bundleVersion": "1.0.0",
  "executableName": "MyApp",
  "architectures": ["$ARCH"]
}
EOF

# 7. Add resources (optional)
# cp -r assets/* "$BUNDLE/Resources/"
```

Result:

```
MyApp.app/
├── MyApp              ← executable (launch this)
├── Info.json
├── Resources/
│   └── ...
└── lib/               ← bundled shared libraries
    └── ...
```

Run with `./MyApp.app/MyApp`.

### Multi-Architecture Bundle

Supports both x86_64 and aarch64 from one bundle directory.

```bash
# 1. Build for each architecture (on respective machines or via cross-compilation)
swift build --product MyApp -c release  # on x86_64 machine
swift build --product MyApp -c release  # on aarch64 machine

# 2. Create the bundle structure
BUNDLE="MyApp.app"
mkdir -p "$BUNDLE/bin/x86_64" "$BUNDLE/bin/aarch64" "$BUNDLE/Resources" "$BUNDLE/lib"

# 3. Copy architecture-specific binaries
cp /path/to/x86_64/MyApp "$BUNDLE/bin/x86_64/"
cp /path/to/aarch64/MyApp "$BUNDLE/bin/aarch64/"

# 4. Create the launcher script
cat > "$BUNDLE/MyApp" << 'LAUNCHER'
#!/bin/sh
BUNDLE_DIR="$(cd "$(dirname "$0")" && pwd)"
ARCH="$(uname -m)"
export LD_LIBRARY_PATH="$BUNDLE_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$BUNDLE_DIR/bin/$ARCH/MyApp" "$@"
LAUNCHER
chmod +x "$BUNDLE/MyApp"

# 5. Create Info.json
cat > "$BUNDLE/Info.json" << 'EOF'
{
  "bundleIdentifier": "com.example.myapp",
  "bundleName": "MyApp",
  "bundleVersion": "1.0.0",
  "executableName": "MyApp",
  "architectures": ["x86_64", "aarch64"]
}
EOF

# 6. Bundle shared libraries (if any)
cp /path/to/libMyLib.so "$BUNDLE/lib/"

# 7. Set rpath so binaries find bundled libraries without the launcher
patchelf --set-rpath '$ORIGIN/../../lib' "$BUNDLE/bin/x86_64/MyApp"
patchelf --set-rpath '$ORIGIN/../../lib' "$BUNDLE/bin/aarch64/MyApp"
```

Result:

```
MyApp.app/
├── MyApp              ← launcher script
├── Info.json
├── bin/
│   ├── x86_64/MyApp
│   └── aarch64/MyApp
├── Resources/
└── lib/
    └── libMyLib.so
```

Run with `./MyApp.app/MyApp`. The launcher detects the architecture and runs the correct binary.

### Desktop Integration

Create a `.desktop` file for app menu integration:

```bash
cat > ~/.local/share/applications/myapp.desktop << EOF
[Desktop Entry]
Name=MyApp
Exec=/opt/MyApp.app/MyApp
Icon=/opt/MyApp.app/Resources/icons/app.png
Type=Application
Categories=Utility;
EOF
```

### Architecture Naming

Linux uses `uname -m` output for directory names:
- `x86_64` for 64-bit Intel/AMD
- `aarch64` for 64-bit ARM

This differs from Windows, which uses `arm64` instead of `aarch64`.

## Windows

### Single-Architecture Bundle

```powershell
# 1. Build your app
swift build --product MyApp -c release

# 2. Set architecture to match the binary being bundled: x86_64 or arm64
$ARCH = "x86_64"

# 3. Create the bundle structure
$BUNDLE = "MyApp.app"
New-Item -ItemType Directory -Path "$BUNDLE\Resources" -Force

# 4. Copy the executable and its DLLs
Copy-Item .build\release\MyApp.exe "$BUNDLE\"
Copy-Item .build\release\*.dll "$BUNDLE\"   # colocate DLLs with the exe

# 5. Create Info.json
@"
{
  "bundleIdentifier": "com.example.myapp",
  "bundleName": "MyApp",
  "bundleVersion": "1.0.0",
  "executableName": "MyApp",
  "architectures": ["$ARCH"]
}
"@ | Out-File -Encoding utf8 "$BUNDLE\Info.json"
```

Result:

```
MyApp.app\
├── MyApp.exe          ← executable (launch this)
├── SwiftOpenUI.dll    ← DLLs colocated with exe
├── Info.json
└── Resources\
    └── ...
```

Run with `.\MyApp.app\MyApp.exe`.

### Multi-Architecture Bundle

```powershell
# 1. Create the bundle structure
$BUNDLE = "MyApp.app"
New-Item -ItemType Directory -Path "$BUNDLE\bin\x86_64", "$BUNDLE\bin\arm64", "$BUNDLE\Resources" -Force

# 2. Copy architecture-specific binaries with their DLLs
Copy-Item C:\builds\x86_64\MyApp.exe "$BUNDLE\bin\x86_64\"
Copy-Item C:\builds\x86_64\*.dll "$BUNDLE\bin\x86_64\"
Copy-Item C:\builds\arm64\MyApp.exe "$BUNDLE\bin\arm64\"
Copy-Item C:\builds\arm64\*.dll "$BUNDLE\bin\arm64\"

# 3. Build or copy the launcher shim to the bundle root
# The launcher is a small x86-64 exe that detects architecture
# and spawns bin\<arch>\MyApp.exe via CreateProcessW.
Copy-Item launcher\MyApp.exe "$BUNDLE\"

# 4. Create Info.json
@"
{
  "bundleIdentifier": "com.example.myapp",
  "bundleName": "MyApp",
  "bundleVersion": "1.0.0",
  "executableName": "MyApp",
  "architectures": ["x86_64", "arm64"]
}
"@ | Out-File -Encoding utf8 "$BUNDLE\Info.json"
```

Result:

```
MyApp.app\
├── MyApp.exe              ← launcher shim (x86-64)
├── Info.json
├── bin\
│   ├── x86_64\
│   │   ├── MyApp.exe
│   │   └── SwiftOpenUI.dll
│   └── arm64\
│       ├── MyApp.exe
│       └── SwiftOpenUI.dll
└── Resources\
```

### DLL Placement

Windows resolves import-time DLL dependencies from the directory containing the loading `.exe`. DLLs must be colocated with each architecture's executable — there is no shared library directory.

- **Single-arch**: DLLs beside the root `.exe`
- **Multi-arch**: DLLs in each `bin\<arch>\` directory

### Architecture Naming

Windows uses Microsoft convention for directory names:
- `x86_64` for 64-bit Intel/AMD
- `arm64` for 64-bit ARM

This differs from Linux, which uses `aarch64` instead of `arm64`.

## Accessing Resources at Runtime

Once packaged, use the `AppBundle` API to locate resources:

```swift
guard let bundle = AppBundle.main else {
    // Not running from a .app bundle
    return
}

// Find a resource
if let configPath = bundle.path(forResource: "config", ofType: "json") {
    // ...
}

// Load resource data
if let data = bundle.data(forResource: "icon", ofType: "png", in: "icons") {
    // ...
}

// Bundle metadata
print(bundle.info.bundleIdentifier)  // "com.example.myapp"
print(bundle.info.bundleVersion)     // Optional("1.0.0")

// Derived paths (platform-dependent)
print(bundle.bundlePath)      // /path/to/MyApp.app
print(bundle.resourcesPath)   // Linux/Windows: <bundle>/Resources
                               // macOS: <bundle>/Contents/Resources
print(bundle.librariesPath)   // Linux: <bundle>/lib
                               // Windows: directory containing the .exe
                               // macOS: <bundle>/Contents/Frameworks
print(bundle.executablePath)  // path to the running binary
```

## Verification

After packaging, verify the bundle works by launching it and checking that `AppBundle.main` resolves. Add a debug print to your app's startup or check the output:

### Linux

```bash
# Single-arch
./MyApp.app/MyApp

# Multi-arch (launcher auto-detects architecture)
./MyApp.app/MyApp

# Expected AppBundle.main output:
#   bundlePath: /path/to/MyApp.app
#   resourcesPath: /path/to/MyApp.app/Resources
#   librariesPath: /path/to/MyApp.app/lib
#   bundleIdentifier: com.example.myapp
```

### Windows

```powershell
# Single-arch
.\MyApp.app\MyApp.exe

# Multi-arch (launcher detects architecture)
.\MyApp.app\MyApp.exe

# Expected AppBundle.main output:
#   bundlePath: C:\path\to\MyApp.app
#   resourcesPath: C:\path\to\MyApp.app\Resources
#   librariesPath: C:\path\to\MyApp.app (single-arch) or C:\path\to\MyApp.app\bin\<arch> (multi-arch)
#   bundleIdentifier: com.example.myapp
```

## See Also

- [App Bundle Format](../architecture/app-bundle-format.md) — format specification, design decisions, runtime contracts
- [Getting Started](getting-started.md) — build and run on all platforms
