import Foundation

/// Parsed bundle metadata from `Info.json` (Linux/Windows) or `Info.plist` (macOS).
public struct BundleInfo: Codable, Equatable {
    public var bundleIdentifier: String
    public var bundleName: String?
    public var bundleVersion: String?
    public var executableName: String
    public var minimumSwiftOpenUIVersion: String?
    public var architectures: [String]?
    public var icon: String?

    public init(
        bundleIdentifier: String,
        bundleName: String? = nil,
        bundleVersion: String? = nil,
        executableName: String,
        minimumSwiftOpenUIVersion: String? = nil,
        architectures: [String]? = nil,
        icon: String? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.bundleName = bundleName
        self.bundleVersion = bundleVersion
        self.executableName = executableName
        self.minimumSwiftOpenUIVersion = minimumSwiftOpenUIVersion
        self.architectures = architectures
        self.icon = icon
    }
}

/// Platform-independent API for app bundle resource discovery.
///
/// Each SwiftOpenUI application can be packaged as a `.app` bundle with a
/// standard directory layout. `AppBundle` provides a normalized API to locate
/// the bundle root, resources, shared libraries, and metadata regardless of
/// the host platform.
public struct AppBundle {

    /// Root directory of the bundle (e.g., `/path/to/MyApp.app/`).
    public let bundlePath: String

    /// Path to the running executable.
    public let executablePath: String

    /// Parsed bundle metadata.
    public let info: BundleInfo

    /// `true` when running in development mode (via `swift run`) without
    /// an actual `.app` bundle. Resource lookup uses the package root's
    /// `Resources/` directory instead of the platform-specific bundle layout.
    public let isDevelopment: Bool

    #if canImport(Darwin)
    /// The underlying Foundation bundle (macOS only). Resource lookup
    /// delegates to this for native localization fallback.
    let foundationBundle: Bundle?
    #endif

    // MARK: - Main bundle

    /// The main application bundle, discovered once at first access from the
    /// running executable's location. Returns `nil` if no bundle structure is
    /// found (e.g., running via `swift run`). The value is cached for the
    /// lifetime of the process.
    public private(set) static var main: AppBundle? = {
        return _discoverMainBundle()
    }()

    // MARK: - Initializers

    #if canImport(Darwin)
    init(bundlePath: String, executablePath: String, info: BundleInfo,
         isDevelopment: Bool = false, foundationBundle: Bundle? = nil) {
        self.bundlePath = bundlePath
        self.executablePath = executablePath
        self.info = info
        self.isDevelopment = isDevelopment
        self.foundationBundle = foundationBundle
    }
    #else
    init(bundlePath: String, executablePath: String, info: BundleInfo,
         isDevelopment: Bool = false) {
        self.bundlePath = bundlePath
        self.executablePath = executablePath
        self.info = info
        self.isDevelopment = isDevelopment
    }
    #endif

    // MARK: - Derived paths

    /// Path to the `Resources/` directory.
    public var resourcesPath: String {
        if isDevelopment {
            return bundlePath + "/Resources"
        }
        #if canImport(Darwin)
        return bundlePath + "/Contents/Resources"
        #else
        return bundlePath + "/Resources"
        #endif
    }

    /// Path to the directory containing shared libraries for the running process.
    /// - macOS: `Contents/Frameworks/`
    /// - Linux: `lib/`
    /// - Windows: directory containing the running `.exe` (DLLs colocated)
    public var librariesPath: String {
        #if canImport(Darwin)
        return bundlePath + "/Contents/Frameworks"
        #elseif canImport(WinSDK)
        let url = URL(fileURLWithPath: executablePath)
        return url.deletingLastPathComponent().path
        #else
        return bundlePath + "/lib"
        #endif
    }

    // MARK: - Resource lookup

    /// Locate a named resource file within the bundle.
    ///
    /// On macOS, delegates to `Foundation.Bundle` for native localization
    /// fallback. On Linux/Windows, performs direct filesystem lookup under
    /// `Resources/`. Asset-catalog entries are not supported through this
    /// API — use platform-native APIs for compiled asset catalogs.
    ///
    /// - Parameters:
    ///   - name: The resource file name (without extension).
    ///   - ext: Optional file extension.
    ///   - subdirectory: Optional subdirectory within `Resources/`.
    /// - Returns: The full path if the resource exists, otherwise `nil`.
    public func path(forResource name: String,
                     ofType ext: String? = nil,
                     in subdirectory: String? = nil) -> String? {
        #if canImport(Darwin)
        if let fb = foundationBundle {
            return fb.path(forResource: name, ofType: ext, inDirectory: subdirectory)
        }
        #endif
        return _filesystemPath(forResource: name, ofType: ext, in: subdirectory)
    }

    /// Load raw data for a named resource.
    ///
    /// On macOS, delegates to `Foundation.Bundle` for native localization
    /// fallback. On Linux/Windows, reads from the filesystem path under
    /// `Resources/`.
    ///
    /// - Parameters:
    ///   - name: The resource file name (without extension).
    ///   - ext: Optional file extension.
    ///   - subdirectory: Optional subdirectory within `Resources/`.
    /// - Returns: The file contents as `Data`, or `nil` if not found.
    public func data(forResource name: String,
                     ofType ext: String? = nil,
                     in subdirectory: String? = nil) -> Data? {
        guard let resourcePath = path(forResource: name, ofType: ext, in: subdirectory) else {
            return nil
        }
        return FileManager.default.contents(atPath: resourcePath)
    }

    // MARK: - Private

    private func _filesystemPath(forResource name: String,
                                 ofType ext: String?,
                                 in subdirectory: String?) -> String? {
        var components = [resourcesPath]
        if let subdirectory = subdirectory {
            components.append(subdirectory)
        }
        let filename: String
        if let ext = ext {
            filename = "\(name).\(ext)"
        } else {
            filename = name
        }
        components.append(filename)
        let fullPath = components.joined(separator: "/")
        return FileManager.default.fileExists(atPath: fullPath) ? fullPath : nil
    }
}

// MARK: - Bundle discovery

private func _discoverMainBundle() -> AppBundle? {
    #if canImport(Darwin)
    if let bundle = _discoverMacOSBundle() { return bundle }
    #elseif canImport(Glibc)
    if let bundle = _discoverLinuxBundle() { return bundle }
    #elseif canImport(WinSDK)
    if let bundle = _discoverWindowsBundle() { return bundle }
    #endif
    return _discoverDevelopmentBundle()
}

/// Development-mode fallback: walk up from the executable looking for
/// `Package.swift`, then use that directory as a pseudo-bundle root.
/// Resources are resolved from `<packageRoot>/Resources/`.
private func _discoverDevelopmentBundle() -> AppBundle? {
    let execPath: String
    #if canImport(Darwin)
    guard let path = Bundle.main.executablePath else { return nil }
    execPath = path
    #elseif canImport(Glibc) || os(Android)
    guard let path = _resolveExecutablePath() else { return nil }
    execPath = path
    #elseif canImport(WinSDK)
    guard let path = _resolveWindowsExecutablePath() else { return nil }
    execPath = path
    #else
    return nil
    #endif

    let startDir = URL(fileURLWithPath: execPath).deletingLastPathComponent()
    return _findDevelopmentBundle(from: startDir, executablePath: execPath)
}

/// Walk up from `startDir` looking for a directory containing both
/// `Package.swift` and `Resources/`. Returns a development-mode
/// `AppBundle` if found. Exposed internally for testing.
func _findDevelopmentBundle(from startDir: URL,
                            executablePath: String) -> AppBundle? {
    let fileManager = FileManager.default
    var dir = startDir

    for _ in 0..<10 {
        let packageSwift = dir.appendingPathComponent("Package.swift").path
        let resourcesDir = dir.appendingPathComponent("Resources").path
        if fileManager.fileExists(atPath: packageSwift),
           fileManager.fileExists(atPath: resourcesDir) {
            let execName = URL(fileURLWithPath: executablePath).lastPathComponent
            let info = BundleInfo(
                bundleIdentifier: "dev.swiftopenui.\(execName.lowercased())",
                executableName: execName
            )
            return AppBundle(bundlePath: dir.path, executablePath: executablePath,
                             info: info, isDevelopment: true)
        }
        let parent = dir.deletingLastPathComponent()
        if parent.path == dir.path { break }
        dir = parent
    }
    return nil
}

// MARK: - Shared helpers (Linux + Windows)

#if !canImport(Darwin)
/// Walk up from a directory looking for `Info.json`. Checks `startDir` and
/// up to `maxLevels` parent directories (default 5, so 6 directories total).
/// Exposed internally for testing.
func _findBundleRoot(from startDir: URL, maxLevels: Int = 5) -> (bundlePath: String, info: BundleInfo)? {
    var dir = startDir
    let fileManager = FileManager.default
    for _ in 0...maxLevels {
        let infoPath = dir.appendingPathComponent("Info.json").path
        if fileManager.fileExists(atPath: infoPath) {
            guard let data = fileManager.contents(atPath: infoPath),
                  let info = try? JSONDecoder().decode(BundleInfo.self, from: data) else {
                return nil
            }
            return (dir.path, info)
        }
        let parent = dir.deletingLastPathComponent()
        if parent.path == dir.path { break }
        dir = parent
    }
    return nil
}
#endif

#if canImport(Darwin)
private func _discoverMacOSBundle() -> AppBundle? {
    let bundle = Bundle.main
    let bundlePath = bundle.bundlePath

    // Only recognize actual .app bundles, not test runners or CLI tools
    // that happen to have a plist.
    guard bundlePath.hasSuffix(".app") else {
        return nil
    }

    guard let execPath = bundle.executablePath else {
        return nil
    }

    let plist = bundle.infoDictionary
    guard let identifier = plist?["CFBundleIdentifier"] as? String,
          let execName = plist?["CFBundleExecutable"] as? String else {
        return nil
    }

    let displayName = plist?["CFBundleDisplayName"] as? String
    let cfBundleName = plist?["CFBundleName"] as? String
    let shortVersion = plist?["CFBundleShortVersionString"] as? String
    let cfBundleVersion = plist?["CFBundleVersion"] as? String

    let info = BundleInfo(
        bundleIdentifier: identifier,
        bundleName: displayName ?? cfBundleName,
        bundleVersion: shortVersion ?? cfBundleVersion,
        executableName: execName,
        minimumSwiftOpenUIVersion: nil,
        architectures: nil,
        icon: plist?["CFBundleIconFile"] as? String
    )

    return AppBundle(bundlePath: bundlePath, executablePath: execPath,
                     info: info, foundationBundle: bundle)
}
#endif

#if canImport(Glibc) || os(Android)
#if canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#endif

/// Resolve the running executable path via `/proc/self/exe`.
/// Exposed internally for testing.
func _resolveExecutablePath() -> String? {
    guard let resolved = realpath("/proc/self/exe", nil) else {
        return nil
    }
    let path = String(cString: resolved)
    free(resolved)
    return path
}

private func _discoverLinuxBundle() -> AppBundle? {
    guard let executablePath = _resolveExecutablePath() else {
        return nil
    }
    let exeDir = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
    guard let result = _findBundleRoot(from: exeDir) else {
        return nil
    }
    return AppBundle(
        bundlePath: result.bundlePath,
        executablePath: executablePath,
        info: result.info
    )
}
#endif

#if canImport(WinSDK)
import WinSDK

private func _resolveWindowsExecutablePath() -> String? {
    var bufferSize: DWORD = 512
    while true {
        var buffer = [WCHAR](repeating: 0, count: Int(bufferSize))
        let len = GetModuleFileNameW(nil, &buffer, bufferSize)
        guard len > 0 else { return nil }
        // If len < bufferSize, the path fit. If len == bufferSize,
        // the path may have been truncated — grow and retry.
        if len < bufferSize {
            return String(decodingCString: buffer, as: UTF16.self)
        }
        bufferSize *= 2
        // Safety cap at 64K characters
        if bufferSize > 65536 { return nil }
    }
}

private func _discoverWindowsBundle() -> AppBundle? {
    guard let executablePath = _resolveWindowsExecutablePath() else {
        return nil
    }
    let exeDir = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
    guard let result = _findBundleRoot(from: exeDir) else {
        return nil
    }
    return AppBundle(
        bundlePath: result.bundlePath,
        executablePath: executablePath,
        info: result.info
    )
}
#endif
