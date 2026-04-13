import Foundation

/// Parsed bundle metadata from `Info.json` (Linux/Windows) or `Info.plist` (macOS).
public struct BundleInfo: Codable {
    public var bundleIdentifier: String
    public var bundleName: String?
    public var bundleVersion: String?
    public var executableName: String
    public var minimumSwiftOpenUIVersion: String?
    public var architectures: [String]?
    public var icon: String?
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
         foundationBundle: Bundle? = nil) {
        self.bundlePath = bundlePath
        self.executablePath = executablePath
        self.info = info
        self.foundationBundle = foundationBundle
    }
    #else
    init(bundlePath: String, executablePath: String, info: BundleInfo) {
        self.bundlePath = bundlePath
        self.executablePath = executablePath
        self.info = info
    }
    #endif

    // MARK: - Derived paths

    /// Path to the `Resources/` directory.
    public var resourcesPath: String {
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
    return _discoverMacOSBundle()
    #elseif canImport(Glibc)
    return _discoverLinuxBundle()
    #elseif canImport(WinSDK)
    return _discoverWindowsBundle()
    #else
    return nil
    #endif
}

#if canImport(Darwin)
private func _discoverMacOSBundle() -> AppBundle? {
    let bundle = Bundle.main
    guard let bundlePath = bundle.bundlePath as String?,
          let execPath = bundle.executablePath else {
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

#if canImport(Glibc)
import Glibc

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
    var dir = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
    let fileManager = FileManager.default
    for _ in 0..<5 {
        let infoPath = dir.appendingPathComponent("Info.json").path
        if fileManager.fileExists(atPath: infoPath) {
            guard let data = fileManager.contents(atPath: infoPath),
                  let info = try? JSONDecoder().decode(BundleInfo.self, from: data) else {
                return nil
            }
            return AppBundle(
                bundlePath: dir.path,
                executablePath: executablePath,
                info: info
            )
        }
        let parent = dir.deletingLastPathComponent()
        if parent.path == dir.path { break }
        dir = parent
    }
    return nil
}
#endif
