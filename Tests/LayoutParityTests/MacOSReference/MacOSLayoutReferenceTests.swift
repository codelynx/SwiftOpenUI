/// macOS layout reference test runner.
///
/// Renders each layout scenario using real SwiftUI in an NSHostingView,
/// forces layout at the standard root size, walks the NSView tree,
/// and exports LayoutSnapshot JSON fixtures.
///
/// Run on macOS:
///   swift test --filter MacOSLayoutReferenceTests
///
/// After running, copy the generated JSON from the Fixtures directory
/// into the repo so GTK/Win32 tests can compare against them.

#if os(macOS)
import XCTest
import SwiftUI
import AppKit
import LayoutParityShared

final class MacOSLayoutReferenceTests: XCTestCase {

    /// Directory where reference JSON files are written.
    /// Uses the repo's Fixtures directory so files can be committed.
    private var fixturesDir: URL {
        // Walk up from the test bundle to find the repo root.
        // Fallback: use a known relative path from the source file.
        let thisFile = URL(fileURLWithPath: #filePath)
        let parityDir = thisFile
            .deletingLastPathComponent()  // MacOSReference/
            .deletingLastPathComponent()  // LayoutParityTests/
        return parityDir.appendingPathComponent("Fixtures")
    }

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(
            at: fixturesDir,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Generate All References

    func testGenerateAllReferenceSnapshots() throws {
        var generated: [String] = []
        var failed: [String] = []

        for (name, view) in allLayoutScenarios {
            do {
                let snapshot = try captureSwiftUILayout(
                    scenario: name,
                    view: view,
                    width: parityRootWidth,
                    height: parityRootHeight
                )
                let url = fixturesDir.appendingPathComponent("\(name).json")
                try writeSnapshot(snapshot, to: url)
                generated.append(name)

                // Print tree for debugging
                print("=== \(name) ===")
                print(snapshot.root)
                print()
            } catch {
                failed.append("\(name): \(error)")
            }
        }

        print("\n=== SUMMARY ===")
        print("Generated: \(generated.count)")
        print("Failed: \(failed.count)")
        for f in failed {
            print("  FAIL: \(f)")
        }

        // We expect all to succeed
        XCTAssertEqual(failed.count, 0, "Some scenarios failed: \(failed)")
    }

    // MARK: - Individual Scenario Tests (for debugging)

    func testCapture_vstackDefault() throws {
        let snapshot = try captureAndSave("vstack-default", AnyView(scenario_vstackDefault))
        XCTAssertGreaterThan(snapshot.root.children.count, 0)
        print(snapshot.root)
    }

    func testCapture_hstackWithSpacer() throws {
        let snapshot = try captureAndSave("hstack-with-spacer", AnyView(scenario_hstackWithSpacer))
        XCTAssertGreaterThan(snapshot.root.children.count, 0)
        print(snapshot.root)
    }

    func testCapture_complexNested() throws {
        let snapshot = try captureAndSave("complex-nested", AnyView(scenario_complexNested))
        XCTAssertGreaterThan(snapshot.root.children.count, 0)
        print(snapshot.root)
    }

    func testCapture_frameAlignmentTopLeading() throws {
        let snapshot = try captureAndSave("frame-alignment-top-leading", AnyView(scenario_frameAlignmentTopLeading))
        print(snapshot.root)
    }

    func testCapture_deeplyNestedFrames() throws {
        let snapshot = try captureAndSave("deeply-nested-frames", AnyView(scenario_deeplyNestedFrames))
        print(snapshot.root)
    }

    // MARK: - Capture Helpers

    private func captureAndSave(_ name: String, _ view: AnyView) throws -> LayoutSnapshot {
        let snapshot = try captureSwiftUILayout(
            scenario: name,
            view: view,
            width: parityRootWidth,
            height: parityRootHeight
        )
        let url = fixturesDir.appendingPathComponent("\(name).json")
        try writeSnapshot(snapshot, to: url)
        return snapshot
    }
}

// MARK: - SwiftUI Layout Capture Engine

/// Renders a SwiftUI view in an off-screen NSHostingView and captures the layout tree.
func captureSwiftUILayout(
    scenario: String,
    view: AnyView,
    width: Double,
    height: Double
) throws -> LayoutSnapshot {
    let hostingView = NSHostingView(rootView: view)
    let rootFrame = NSRect(x: 0, y: 0, width: width, height: height)
    hostingView.frame = rootFrame

    // NSHostingView needs a window to build its internal view hierarchy.
    // Create an off-screen window so SwiftUI actually lays out subviews.
    let window = NSWindow(
        contentRect: rootFrame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = hostingView

    // Force layout
    hostingView.layout()
    hostingView.layoutSubtreeIfNeeded()

    // Give SwiftUI a run-loop tick to finish building the view tree
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    hostingView.layoutSubtreeIfNeeded()

    // SwiftUI renders via CALayer, not NSView subviews.
    // Walk the layer tree to capture actual layout positions.
    hostingView.wantsLayer = true
    hostingView.layout()

    guard let rootLayer = hostingView.layer else {
        throw NSError(domain: "LayoutCapture", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "No layer on hosting view"])
    }

    let rootNode = captureLayerTree(
        layer: rootLayer,
        rootLayer: rootLayer
    )

    let formatter = ISO8601DateFormatter()
    return LayoutSnapshot(
        scenario: scenario,
        rootWidth: width,
        rootHeight: height,
        root: rootNode,
        platform: "macOS-SwiftUI",
        capturedAt: formatter.string(from: Date())
    )
}

/// Recursively walk the CALayer tree, converting to LayoutNode.
///
/// SwiftUI renders via Core Animation layers, not NSView subviews.
/// The root NSHostingView has 0 subviews; all content is in sublayers.
/// Container views (VStack, HStack) don't produce intermediate layers —
/// the tree is typically flat: root layer -> drawing layers for each leaf.
func captureLayerTree(
    layer: CALayer,
    rootLayer: CALayer
) -> LayoutNode {
    // Convert to root-relative coordinates
    // CALayer frames are in parent coordinates; convert to root.
    let frameInRoot: CGRect
    if layer === rootLayer {
        frameInRoot = CGRect(x: 0, y: 0, width: layer.bounds.width, height: layer.bounds.height)
    } else {
        frameInRoot = layer.convert(layer.bounds, to: rootLayer)
    }

    let children = (layer.sublayers ?? []).map { child in
        captureLayerTree(layer: child, rootLayer: rootLayer)
    }

    return LayoutNode(
        tag: identifyLayer(layer),
        viewType: layerTypeName(layer),
        x: Double(frameInRoot.origin.x),
        y: Double(frameInRoot.origin.y),
        width: Double(frameInRoot.size.width),
        height: Double(frameInRoot.size.height),
        children: children
    )
}

/// Identify a layer with a human-readable tag.
private func identifyLayer(_ layer: CALayer) -> String {
    // Layer name (set by SwiftUI internals, sometimes contains type info)
    if let name = layer.name, !name.isEmpty {
        return name
    }
    return layerTypeName(layer)
}

/// Extract the unqualified class name of a layer.
private func layerTypeName(_ layer: CALayer) -> String {
    let full = String(describing: type(of: layer))
    if let lastDot = full.lastIndex(of: ".") {
        return String(full[full.index(after: lastDot)...])
    }
    return full
}

#endif // os(macOS)
