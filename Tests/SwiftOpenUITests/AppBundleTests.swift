import XCTest
import Foundation
@testable import SwiftOpenUI

final class AppBundleTests: XCTestCase {

    // MARK: - BundleInfo Codable

    func testBundleInfoDecodesFullJSON() throws {
        let json = """
        {
          "bundleIdentifier": "com.example.myapp",
          "bundleName": "MyApp",
          "bundleVersion": "1.0.0",
          "executableName": "MyApp",
          "minimumSwiftOpenUIVersion": "0.1.0",
          "architectures": ["x86_64", "aarch64"],
          "icon": "Resources/icons/app.png"
        }
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(BundleInfo.self, from: json)
        XCTAssertEqual(info.bundleIdentifier, "com.example.myapp")
        XCTAssertEqual(info.bundleName, "MyApp")
        XCTAssertEqual(info.bundleVersion, "1.0.0")
        XCTAssertEqual(info.executableName, "MyApp")
        XCTAssertEqual(info.minimumSwiftOpenUIVersion, "0.1.0")
        XCTAssertEqual(info.architectures, ["x86_64", "aarch64"])
        XCTAssertEqual(info.icon, "Resources/icons/app.png")
    }

    func testBundleInfoDecodesMinimalJSON() throws {
        let json = """
        {
          "bundleIdentifier": "com.example.minimal",
          "executableName": "Minimal"
        }
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(BundleInfo.self, from: json)
        XCTAssertEqual(info.bundleIdentifier, "com.example.minimal")
        XCTAssertEqual(info.executableName, "Minimal")
        XCTAssertNil(info.bundleName)
        XCTAssertNil(info.bundleVersion)
        XCTAssertNil(info.minimumSwiftOpenUIVersion)
        XCTAssertNil(info.architectures)
        XCTAssertNil(info.icon)
    }

    func testBundleInfoEncodesRoundTrip() throws {
        let original = BundleInfo(
            bundleIdentifier: "com.test.roundtrip",
            bundleName: "RoundTrip",
            bundleVersion: "2.0",
            executableName: "RoundTrip",
            minimumSwiftOpenUIVersion: nil,
            architectures: ["x86_64"],
            icon: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BundleInfo.self, from: data)
        XCTAssertEqual(decoded.bundleIdentifier, original.bundleIdentifier)
        XCTAssertEqual(decoded.bundleName, original.bundleName)
        XCTAssertEqual(decoded.bundleVersion, original.bundleVersion)
        XCTAssertEqual(decoded.executableName, original.executableName)
        XCTAssertEqual(decoded.architectures, original.architectures)
    }

    // MARK: - AppBundle path resolution

    func testResourcePathWithExtensionAndSubdirectory() throws {
        let tmpDir = NSTemporaryDirectory() + "AppBundleTest_\(ProcessInfo.processInfo.globallyUniqueString)"
        let fm = FileManager.default

        // Create a fake bundle structure (platform-appropriate)
        let bundleRoot = tmpDir + "/TestApp.app"
        #if canImport(Darwin)
        let resourcesDir = bundleRoot + "/Contents/Resources/sounds"
        #else
        let resourcesDir = bundleRoot + "/Resources/sounds"
        #endif
        try fm.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)
        fm.createFile(atPath: resourcesDir + "/click.wav", contents: Data([0x00]))
        fm.createFile(atPath: bundleRoot + "/Info.json", contents: Data())

        let bundle = AppBundle(
            bundlePath: bundleRoot,
            executablePath: bundleRoot + "/bin/x86_64/TestApp",
            info: BundleInfo(
                bundleIdentifier: "com.test.app",
                executableName: "TestApp"
            )
        )

        let found = bundle.path(forResource: "click", ofType: "wav", in: "sounds")
        XCTAssertNotNil(found)
        XCTAssertTrue(found!.hasSuffix("/Resources/sounds/click.wav"))

        let missing = bundle.path(forResource: "boom", ofType: "wav", in: "sounds")
        XCTAssertNil(missing)

        // Data loading
        let data = bundle.data(forResource: "click", ofType: "wav", in: "sounds")
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.count, 1)

        try fm.removeItem(atPath: tmpDir)
    }

    func testResourcePathWithoutExtension() throws {
        let tmpDir = NSTemporaryDirectory() + "AppBundleTest_\(ProcessInfo.processInfo.globallyUniqueString)"
        let fm = FileManager.default

        let bundleRoot = tmpDir + "/TestApp.app"
        #if canImport(Darwin)
        let resourcesDir = bundleRoot + "/Contents/Resources"
        #else
        let resourcesDir = bundleRoot + "/Resources"
        #endif
        try fm.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)
        fm.createFile(atPath: resourcesDir + "/LICENSE", contents: Data())

        let bundle = AppBundle(
            bundlePath: bundleRoot,
            executablePath: bundleRoot + "/TestApp",
            info: BundleInfo(
                bundleIdentifier: "com.test.app",
                executableName: "TestApp"
            )
        )

        let found = bundle.path(forResource: "LICENSE")
        XCTAssertNotNil(found)
        XCTAssertTrue(found!.hasSuffix("/Resources/LICENSE"))
    }

    // MARK: - Derived paths

    func testLibrariesPathLinux() {
        let bundle = AppBundle(
            bundlePath: "/opt/MyApp.app",
            executablePath: "/opt/MyApp.app/bin/x86_64/MyApp",
            info: BundleInfo(
                bundleIdentifier: "com.test.app",
                executableName: "MyApp"
            )
        )

        #if canImport(Glibc)
        XCTAssertEqual(bundle.librariesPath, "/opt/MyApp.app/lib")
        #endif
    }

    func testLibrariesPathWindowsSingleArch() throws {
        #if !canImport(WinSDK)
        throw XCTSkip("Windows-specific test")
        #else
        // Single-arch: exe at bundle root → librariesPath is the bundle root
        let bundle = AppBundle(
            bundlePath: "C:\\Apps\\MyApp.app",
            executablePath: "C:\\Apps\\MyApp.app\\MyApp.exe",
            info: BundleInfo(
                bundleIdentifier: "com.test.app",
                executableName: "MyApp"
            )
        )
        // librariesPath should be the directory containing the exe
        let libs = bundle.librariesPath
        XCTAssertTrue(libs.contains("MyApp.app"), "Expected librariesPath in bundle root, got: \(libs)")
        XCTAssertFalse(libs.contains("bin"), "Single-arch should not include bin/")
        #endif
    }

    func testLibrariesPathWindowsMultiArch() throws {
        #if !canImport(WinSDK)
        throw XCTSkip("Windows-specific test")
        #else
        // Multi-arch: exe in bin\arm64\ → librariesPath is bin\arm64\
        let bundle = AppBundle(
            bundlePath: "C:\\Apps\\MyApp.app",
            executablePath: "C:\\Apps\\MyApp.app\\bin\\arm64\\MyApp.exe",
            info: BundleInfo(
                bundleIdentifier: "com.test.app",
                executableName: "MyApp"
            )
        )
        let libs = bundle.librariesPath
        XCTAssertTrue(libs.contains("arm64"), "Expected librariesPath in bin\\arm64, got: \(libs)")
        #endif
    }

    func testResourcesPath() {
        let bundle = AppBundle(
            bundlePath: "/opt/MyApp.app",
            executablePath: "/opt/MyApp.app/bin/x86_64/MyApp",
            info: BundleInfo(
                bundleIdentifier: "com.test.app",
                executableName: "MyApp"
            )
        )

        #if canImport(Darwin)
        XCTAssertEqual(bundle.resourcesPath, "/opt/MyApp.app/Contents/Resources")
        #else
        XCTAssertEqual(bundle.resourcesPath, "/opt/MyApp.app/Resources")
        #endif
    }

    // MARK: - Bundle discovery

    func testDiscoveryWalksUpToFindInfoJson() throws {
        // Tests that _findBundleRoot walks up from a nested directory
        // and finds Info.json at the bundle root.
        #if canImport(Darwin)
        throw XCTSkip("_findBundleRoot is not available on macOS")
        #else
        let tmpDir = NSTemporaryDirectory() + "AppBundleDiscovery_\(ProcessInfo.processInfo.globallyUniqueString)"
        let fm = FileManager.default
        let bundleRoot = tmpDir + "/FakeApp.app"
        let nestedDir = bundleRoot + "/bin/x86_64"
        try fm.createDirectory(atPath: nestedDir, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: bundleRoot + "/Resources", withIntermediateDirectories: true)

        let info = BundleInfo(
            bundleIdentifier: "com.test.fake",
            bundleName: "FakeApp",
            bundleVersion: "0.1",
            executableName: "FakeApp",
            architectures: ["x86_64"]
        )
        let data = try JSONEncoder().encode(info)
        fm.createFile(atPath: bundleRoot + "/Info.json", contents: data)

        // Start from bin/x86_64/ — the discovery should walk up 2 levels
        let startDir = URL(fileURLWithPath: nestedDir)
        let result = _findBundleRoot(from: startDir)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.info.bundleIdentifier, "com.test.fake")
        XCTAssertEqual(result?.info.bundleName, "FakeApp")
        XCTAssertEqual(result?.info.architectures, ["x86_64"])

        try fm.removeItem(atPath: tmpDir)
        #endif
    }

    func testDiscoveryReturnsNilWithNoInfoJson() throws {
        #if canImport(Darwin)
        throw XCTSkip("_findBundleRoot is not available on macOS")
        #else
        let tmpDir = NSTemporaryDirectory() + "AppBundleNoInfo_\(ProcessInfo.processInfo.globallyUniqueString)"
        let fm = FileManager.default
        let nestedDir = tmpDir + "/a/b/c"
        try fm.createDirectory(atPath: nestedDir, withIntermediateDirectories: true)

        let startDir = URL(fileURLWithPath: nestedDir)
        let result = _findBundleRoot(from: startDir)
        XCTAssertNil(result)

        try fm.removeItem(atPath: tmpDir)
        #endif
    }

    func testResolveExecutablePathReturnsNonNil() throws {
        #if !canImport(Glibc)
        throw XCTSkip("Linux-specific test")
        #else
        // /proc/self/exe should always resolve when running tests on Linux
        let path = _resolveExecutablePath()
        XCTAssertNotNil(path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path!))
        #endif
    }

    // MARK: - Development mode discovery

    func testDevDiscoveryFindsPackageRootWithResources() throws {
        let tmpDir = NSTemporaryDirectory() + "AppBundleDev_\(ProcessInfo.processInfo.globallyUniqueString)"
        let fm = FileManager.default

        // Package root with Package.swift + Resources/
        let nestedDir = tmpDir + "/.build/debug"
        try fm.createDirectory(atPath: nestedDir, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: tmpDir + "/Resources", withIntermediateDirectories: true)
        fm.createFile(atPath: tmpDir + "/Package.swift", contents: Data())
        fm.createFile(atPath: tmpDir + "/Resources/hello.txt", contents: "Hello".data(using: .utf8))

        let execPath = nestedDir + "/TestApp"
        let bundle = _findDevelopmentBundle(
            from: URL(fileURLWithPath: nestedDir),
            executablePath: execPath
        )

        XCTAssertNotNil(bundle)
        XCTAssertTrue(bundle!.isDevelopment)
        // Normalize paths through URL to avoid separator mismatches on Windows
        let expectedRoot = URL(fileURLWithPath: tmpDir).path
        XCTAssertEqual(bundle!.bundlePath, expectedRoot)
        XCTAssertEqual(bundle!.executablePath, execPath)
        XCTAssertEqual(bundle!.info.executableName, "TestApp")
        XCTAssertEqual(bundle!.info.bundleIdentifier, "dev.swiftopenui.testapp")
        XCTAssertEqual(bundle!.resourcesPath, expectedRoot + "/Resources")

        // Resource lookup works
        let found = bundle!.path(forResource: "hello", ofType: "txt")
        XCTAssertNotNil(found)
        XCTAssertTrue(found!.hasSuffix("/Resources/hello.txt"))

        try fm.removeItem(atPath: tmpDir)
    }

    func testDevDiscoveryReturnsNilWithoutResources() throws {
        let tmpDir = NSTemporaryDirectory() + "AppBundleDevNoRes_\(ProcessInfo.processInfo.globallyUniqueString)"
        let fm = FileManager.default

        // Package.swift exists but no Resources/ directory
        let nestedDir = tmpDir + "/.build/debug"
        try fm.createDirectory(atPath: nestedDir, withIntermediateDirectories: true)
        fm.createFile(atPath: tmpDir + "/Package.swift", contents: Data())

        let bundle = _findDevelopmentBundle(
            from: URL(fileURLWithPath: nestedDir),
            executablePath: nestedDir + "/TestApp"
        )

        XCTAssertNil(bundle)

        try fm.removeItem(atPath: tmpDir)
    }

    func testDevDiscoveryReturnsNilWithoutPackageSwift() throws {
        let tmpDir = NSTemporaryDirectory() + "AppBundleDevNoPkg_\(ProcessInfo.processInfo.globallyUniqueString)"
        let fm = FileManager.default

        // Resources/ exists but no Package.swift
        let nestedDir = tmpDir + "/.build/debug"
        try fm.createDirectory(atPath: nestedDir, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: tmpDir + "/Resources", withIntermediateDirectories: true)

        let bundle = _findDevelopmentBundle(
            from: URL(fileURLWithPath: nestedDir),
            executablePath: nestedDir + "/TestApp"
        )

        XCTAssertNil(bundle)

        try fm.removeItem(atPath: tmpDir)
    }

    func testNonDevelopmentBundleResourcesPath() {
        let bundle = AppBundle(
            bundlePath: "/opt/MyApp.app",
            executablePath: "/opt/MyApp.app/bin/x86_64/MyApp",
            info: BundleInfo(
                bundleIdentifier: "com.test.app",
                executableName: "MyApp"
            ),
            isDevelopment: false
        )

        XCTAssertFalse(bundle.isDevelopment)
        #if canImport(Darwin)
        XCTAssertEqual(bundle.resourcesPath, "/opt/MyApp.app/Contents/Resources")
        #else
        XCTAssertEqual(bundle.resourcesPath, "/opt/MyApp.app/Resources")
        #endif
    }
}
