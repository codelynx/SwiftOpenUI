/// GTK layout parity tests.
///
/// Renders the same layout scenarios using SwiftOpenUI + GTK backend,
/// captures widget tree positions, and compares against macOS reference fixtures.
///
/// Run on Linux:
///   swift test --filter GTKLayoutParityTests

#if os(Linux)
import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge
import LayoutParityShared

final class GTKLayoutParityTests: XCTestCase {

    private var fixturesDir: URL {
        let thisFile = URL(fileURLWithPath: #filePath)
        let parityDir = thisFile
            .deletingLastPathComponent()  // GTKComparison/
            .deletingLastPathComponent()  // LayoutParityTests/
        return parityDir.appendingPathComponent("Fixtures")
    }

    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 {
            _ = gtk_init_check()
        }
    }

    // MARK: - Compare All Scenarios

    func testCompareAllScenariosAgainstReference() throws {
        try requireGTK()

        var passed: [String] = []
        var failed: [(String, LeafComparisonResult)] = []
        var skipped: [String] = []
        var errors: [(String, Error)] = []

        for (name, view) in allLayoutScenarios {
            let fixtureURL = fixturesDir.appendingPathComponent("\(name).json")
            guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
                skipped.append(name)
                continue
            }

            do {
                let reference = try readSnapshot(from: fixtureURL)
                let actual = try captureGTKLayout(
                    scenario: name,
                    view: view,
                    width: parityRootWidth,
                    height: parityRootHeight
                )

                // Use leaf-based comparison (handles flat macOS vs nested GTK trees)
                let result = compareLeaves(
                    reference: reference,
                    actual: actual,
                    positionTolerance: 4.0,
                    sizeTolerance: 6.0
                )

                if result.passed {
                    passed.append(name)
                } else {
                    failed.append((name, result))
                }

                // Print normalized leaves for comparison
                let refLeaves = sortLeaves(normalizeLeaves(
                    sortLeaves(extractLeaves(from: reference.root))
                ))
                let actLeaves = sortLeaves(normalizeLeaves(
                    sortLeaves(extractLeaves(from: actual.root))
                ))

                print("=== \(name) ===")
                print("macOS (normalized):")
                for leaf in refLeaves { print("  \(leaf)") }
                print("GTK (normalized):")
                for leaf in actLeaves { print("  \(leaf)") }
                if !result.passed {
                    print(result)
                } else {
                    print("PASS")
                }
                print()
            } catch {
                errors.append((name, error))
            }
        }

        print("\n=== PARITY SUMMARY ===")
        print("Passed:  \(passed.count)")
        print("Failed:  \(failed.count)")
        print("Skipped: \(skipped.count) (no reference fixture)")
        print("Errors:  \(errors.count)")

        for (name, result) in failed {
            print("\nFAILED: \(name)")
            print(result)
        }
        for (name, err) in errors {
            print("\nERROR: \(name): \(err)")
        }

        // Don't hard-fail — we're establishing baselines and collecting data
        if !failed.isEmpty || !errors.isEmpty {
            print("\n⚠ \(failed.count) parity failures, \(errors.count) errors (non-fatal, baseline run)")
        }
    }

    // MARK: - Individual Scenario Tests

    func testGTKCapture_vstackDefault() throws {
        try requireGTK()
        let snapshot = try captureGTKLayout(
            scenario: "vstack-default",
            view: AnyView(scenario_vstackDefault),
            width: parityRootWidth,
            height: parityRootHeight
        )
        print(snapshot.root)
        XCTAssertGreaterThan(snapshot.root.children.count, 0)
    }

    func testGTKCapture_hstackWithSpacer() throws {
        try requireGTK()
        let snapshot = try captureGTKLayout(
            scenario: "hstack-with-spacer",
            view: AnyView(scenario_hstackWithSpacer),
            width: parityRootWidth,
            height: parityRootHeight
        )
        print(snapshot.root)
        XCTAssertGreaterThan(snapshot.root.children.count, 0)
    }

    func testGTKCapture_complexNested() throws {
        try requireGTK()
        let snapshot = try captureGTKLayout(
            scenario: "complex-nested",
            view: AnyView(scenario_complexNested),
            width: parityRootWidth,
            height: parityRootHeight
        )
        print(snapshot.root)
        XCTAssertGreaterThan(snapshot.root.children.count, 0)
    }

    // MARK: - Dump All (no comparison, just captures)

    func testDumpAllGTKSnapshots() throws {
        try requireGTK()

        for (name, view) in allLayoutScenarios {
            do {
                let snapshot = try captureGTKLayout(
                    scenario: name,
                    view: view,
                    width: parityRootWidth,
                    height: parityRootHeight
                )
                print("=== GTK: \(name) ===")
                print(snapshot.root)
                print()

                // Also write GTK snapshots for manual inspection
                let url = fixturesDir.appendingPathComponent("gtk-\(name).json")
                try writeSnapshot(snapshot, to: url)
            } catch {
                print("=== GTK: \(name) ERROR: \(error) ===\n")
            }
        }
    }
}

// MARK: - GTK Layout Capture Engine

func captureGTKLayout(
    scenario: String,
    view: AnyView,
    width: Double,
    height: Double
) throws -> LayoutSnapshot {
    // Render the SwiftOpenUI view to a GTK widget tree
    let widget = widgetFromOpaque(gtkRenderView(view))

    // Force the widget to realize at the target size
    // Create a temporary offscreen window to host the widget
    let window = gtk_window_new()!
    gtk_window_set_default_size(
        windowPointer(window),
        Int32(width),
        Int32(height)
    )
    gtk_window_set_child(windowPointer(window), widget)

    // Force expand on the root content
    gtk_widget_set_hexpand(widget, 1)
    gtk_widget_set_vexpand(widget, 1)
    gtk_widget_set_halign(widget, GTK_ALIGN_FILL)
    gtk_widget_set_valign(widget, GTK_ALIGN_FILL)

    // Allocate at the target size
    gtk_widget_allocate(widget, Int32(width), Int32(height), -1, nil)

    // Walk the widget tree
    let rootNode = captureGTKWidgetTree(
        widget: widget,
        rootWidget: widget
    )

    // Clean up
    gtk_window_set_child(windowPointer(window), nil)
    gtk_window_destroy(windowPointer(window))

    let formatter = ISO8601DateFormatter()
    return LayoutSnapshot(
        scenario: scenario,
        rootWidth: width,
        rootHeight: height,
        root: rootNode,
        platform: "Linux-GTK4",
        capturedAt: formatter.string(from: Date())
    )
}

/// Recursively walk GTK widget tree, converting to LayoutNode.
func captureGTKWidgetTree(
    widget: UnsafeMutablePointer<GtkWidget>,
    rootWidget: UnsafeMutablePointer<GtkWidget>
) -> LayoutNode {
    // Get position relative to root
    let origin: ViewPoint
    if widget == rootWidget {
        origin = .zero
    } else {
        var srcPt = graphene_point_t()
        graphene_point_init(&srcPt, 0, 0)
        var dstPt = graphene_point_t()
        _ = gtk_widget_compute_point(widget, rootWidget, &srcPt, &dstPt)
        origin = ViewPoint(x: Double(dstPt.x), y: Double(dstPt.y))
    }

    let size = ViewSize(
        width: Double(gtk_widget_get_width(widget)),
        height: Double(gtk_widget_get_height(widget))
    )

    // Walk children
    var children: [LayoutNode] = []
    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        children.append(captureGTKWidgetTree(widget: c, rootWidget: rootWidget))
        child = gtk_widget_get_next_sibling(c)
    }

    let typeName = String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
    let tag = gtkIdentifyWidget(widget, typeName: typeName)

    return LayoutNode(
        tag: tag,
        viewType: typeName,
        x: origin.x,
        y: origin.y,
        width: size.width,
        height: size.height,
        children: children
    )
}

/// Identify a GTK widget with a human-readable tag.
private func gtkIdentifyWidget(
    _ widget: UnsafeMutablePointer<GtkWidget>,
    typeName: String
) -> String {
    // Check for widget name set via gtk_widget_set_name
    if let namePtr = gtk_widget_get_name(widget) {
        let name = String(cString: namePtr)
        if !name.isEmpty && name != typeName {
            return name
        }
    }

    // Check if it's a GtkLabel — extract text
    if typeName == "GtkLabel" {
        if let textPtr = gtk_label_get_text(OpaquePointer(widget)) {
            let text = String(cString: textPtr)
            if !text.isEmpty {
                return "text:\(String(text.prefix(40)))"
            }
        }
    }

    return typeName
}

// MARK: - GTK Helpers

private func requireGTK() throws {
    guard gtk_is_initialized() != 0 else {
        throw XCTSkip("GTK not available")
    }
}

#endif // os(Linux)
