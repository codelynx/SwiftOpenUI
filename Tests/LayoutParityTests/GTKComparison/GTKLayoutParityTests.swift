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

    /// Scenarios with a known residual that the per-pair text-metric rule in
    /// `compareLeaves` cannot absorb, where the drift is nevertheless a pure
    /// font-metric cascade rather than a layout bug. Tracked so failures on
    /// genuinely new scenarios still fail the suite loudly.
    ///
    /// - `sidebar-detail-split`: a 5-item VStack is vertically centered next
    ///   to a detail pane. GTK's 18pt Pango line height (vs macOS 16pt)
    ///   cumulates across the sidebar, shifting the centered origin by ~5pt
    ///   while the adjacent Detail leaf adds its own 2pt height delta. The
    ///   resulting 7pt gap drift is pure text metric but is not explainable
    ///   from the two adjacent leaves alone. Broadening the rule to a
    ///   cumulative-snapshot allowance was rejected in review as too easy to
    ///   abuse. Left as a known residual to either fix via font matching or
    ///   re-score under a future column-scoped rule.
    static let knownStructuralResiduals: Set<String> = [
        "sidebar-detail-split",
    ]

    func testCompareAllScenariosAgainstReference() throws {
        try requireGTK()

        var passed: [(String, LeafComparisonResult)] = []
        var failed: [(String, LeafComparisonResult)] = []
        var knownResiduals: [(String, LeafComparisonResult)] = []
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

                let result = compareLeaves(
                    reference: reference,
                    actual: actual,
                    tolerances: ParityTolerances()
                )

                if result.passed {
                    passed.append((name, result))
                } else if Self.knownStructuralResiduals.contains(name) {
                    knownResiduals.append((name, result))
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

        // Collect text-metric diffs from ALL scenarios (passed + failed + known residuals)
        let allResults = passed + failed + knownResiduals
        let totalStructuralFailures = failed.flatMap { $0.1.structuralDiffs }.count
        let totalTextMetricInfo = allResults.flatMap { $0.1.textMetricDiffs }.count

        print("\n=== PARITY SUMMARY ===")
        print("Passed:         \(passed.count) (no structural failures)")
        print("Failed:         \(failed.count) (structural layout bugs)")
        print("Known residual: \(knownResiduals.count) (tracked, non-fatal)")
        print("Skipped:        \(skipped.count) (no reference fixture)")
        print("Errors:         \(errors.count)")
        print("")
        print("Structural failures: \(totalStructuralFailures) diffs across \(failed.count) scenarios")
        print("Text-metric info:    \(totalTextMetricInfo) diffs across \(allResults.count) scenarios (expected, not bugs)")

        for (name, result) in failed {
            print("\nFAILED: \(name)")
            print(result)
        }
        for (name, result) in knownResiduals {
            print("\nKNOWN RESIDUAL: \(name)")
            print(result)
        }
        for (name, err) in errors {
            print("\nERROR: \(name): \(err)")
        }

        // A residual that unexpectedly passed should also fail the suite so
        // the exemption gets removed instead of silently rotting.
        let unexpectedlyPassing = passed
            .map { $0.0 }
            .filter { Self.knownStructuralResiduals.contains($0) }
        for name in unexpectedlyPassing {
            XCTFail("\(name): listed as knownStructuralResiduals but now passes — remove it from the set.")
        }

        // Hard-fail the test on structural failures or errors
        for (name, result) in failed {
            XCTFail("\(name): \(result.structuralDiffs.count) structural layout failure(s)")
        }
        for (name, err) in errors {
            XCTFail("\(name): capture error: \(err)")
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

    // MARK: - Dump All (gated, not run by default)

    /// Dumps all GTK snapshots to the fixtures directory for manual inspection.
    /// Skipped unless DUMP_PARITY_SNAPSHOTS=1 is set — avoids dirtying the
    /// working tree during normal test runs.
    ///
    /// Usage: DUMP_PARITY_SNAPSHOTS=1 swift test --filter testDumpAllGTKSnapshots
    func testDumpAllGTKSnapshots() throws {
        try requireGTK()
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["DUMP_PARITY_SNAPSHOTS"] == "1",
            "Set DUMP_PARITY_SNAPSHOTS=1 to run snapshot dumps"
        )

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

    // Match GTK4Backend root behavior: non-expanding content gets centered,
    // expanding content fills. This mirrors GTK4Backend.swift lines 99-109.
    if gtk_widget_get_hexpand(widget) == 0 {
        gtk_widget_set_halign(widget, GTK_ALIGN_CENTER)
        gtk_widget_set_hexpand(widget, 1)
    } else {
        gtk_widget_set_halign(widget, GTK_ALIGN_FILL)
    }
    if gtk_widget_get_vexpand(widget) == 0 {
        gtk_widget_set_valign(widget, GTK_ALIGN_CENTER)
        gtk_widget_set_vexpand(widget, 1)
    } else {
        gtk_widget_set_valign(widget, GTK_ALIGN_FILL)
    }

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
        let childGObject = UnsafeMutableRawPointer(c).assumingMemoryBound(to: GObject.self)
        if g_object_get_data(childGObject, gtkSwiftLayoutHelperMarker) == nil {
            children.append(captureGTKWidgetTree(widget: c, rootWidget: rootWidget))
        }
        child = gtk_widget_get_next_sibling(c)
    }

    let typeName = String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
    if typeName == "GtkScrolledWindow",
       let clippedLabel = gtkSingleLabelDescendant(in: widget) {
        let tag = gtkIdentifyWidget(clippedLabel, typeName: "GtkLabel")
        return LayoutNode(
            tag: tag,
            viewType: "GtkLabel",
            x: origin.x,
            y: origin.y,
            width: size.width,
            height: size.height,
            children: []
        )
    }
    let tag = gtkIdentifyWidget(widget, typeName: typeName)

    // Map hosted node kinds to semantic view types for leaf extraction
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    let isSpacer = g_object_get_data(gobject, "gtk-swift-spacer") != nil
    let hostedKind = gtkHostedNodeKind(of: widget)
    let effectiveViewType: String
    if isSpacer {
        effectiveViewType = "Spacer"
    } else if hostedKind == .color {
        effectiveViewType = "Color"
    } else {
        effectiveViewType = typeName
    }

    return LayoutNode(
        tag: tag,
        viewType: effectiveViewType,
        x: origin.x,
        y: origin.y,
        width: size.width,
        height: size.height,
        children: children
    )
}

private func gtkSingleLabelDescendant(
    in widget: UnsafeMutablePointer<GtkWidget>
) -> UnsafeMutablePointer<GtkWidget>? {
    var labels: [UnsafeMutablePointer<GtkWidget>] = []
    gtkCollectLabelDescendants(in: widget, into: &labels)
    return labels.count == 1 ? labels[0] : nil
}

private func gtkCollectLabelDescendants(
    in widget: UnsafeMutablePointer<GtkWidget>,
    into labels: inout [UnsafeMutablePointer<GtkWidget>]
) {
    let typeName = String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
    if typeName == "GtkLabel" {
        labels.append(widget)
        return
    }
    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        gtkCollectLabelDescendants(in: c, into: &labels)
        child = gtk_widget_get_next_sibling(c)
    }
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
