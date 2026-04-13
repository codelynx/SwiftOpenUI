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

    // Force layout
    hostingView.layout()
    hostingView.layoutSubtreeIfNeeded()

    // Walk the view tree
    let rootNode = captureNSViewTree(
        view: hostingView,
        rootView: hostingView,
        depth: 0
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

/// Recursively walk the NSView tree, converting to LayoutNode.
///
/// SwiftUI's NSHostingView creates a deep internal view hierarchy.
/// We apply heuristics to identify "meaningful" views (those that
/// correspond to SwiftUI views the user wrote) vs internal containers.
func captureNSViewTree(
    view: NSView,
    rootView: NSView,
    depth: Int
) -> LayoutNode {
    // Convert to root-relative coordinates (flip Y since AppKit is bottom-up)
    let frameInRoot: NSRect
    if view === rootView {
        frameInRoot = NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height)
    } else if let superview = view.superview {
        let converted = superview.convert(view.frame, to: rootView)
        // Flip Y: AppKit origin is bottom-left, we want top-left
        let flippedY = rootView.bounds.height - converted.maxY
        frameInRoot = NSRect(x: converted.origin.x, y: flippedY,
                           width: converted.width, height: converted.height)
    } else {
        frameInRoot = view.frame
    }

    let children = view.subviews.map { child in
        captureNSViewTree(view: child, rootView: rootView, depth: depth + 1)
    }

    return LayoutNode(
        tag: identifyView(view),
        viewType: classBaseName(view),
        x: Double(frameInRoot.origin.x),
        y: Double(frameInRoot.origin.y),
        width: Double(frameInRoot.size.width),
        height: Double(frameInRoot.size.height),
        children: children
    )
}

/// Try to identify a view with a human-readable tag.
private func identifyView(_ view: NSView) -> String {
    // 1. Accessibility identifier (best — we can set these explicitly)
    if let identifier = view.accessibilityIdentifier(), !identifier.isEmpty {
        return identifier
    }

    // 2. Check for text content (NSTextField used by SwiftUI Text)
    if let textField = view as? NSTextField {
        let text = textField.stringValue
        if !text.isEmpty {
            return "text:\(text.prefix(40))"
        }
    }

    // 3. Class name with depth hint
    return classBaseName(view)
}

/// Extract the unqualified class name.
private func classBaseName(_ obj: AnyObject) -> String {
    let full = String(describing: type(of: obj))
    // SwiftUI internal classes look like _NSHostingView, NSHostingView,
    // _TtC7SwiftUI... — extract just the last component
    if let lastDot = full.lastIndex(of: ".") {
        return String(full[full.index(after: lastDot)...])
    }
    return full
}

#endif // os(macOS)
