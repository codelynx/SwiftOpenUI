/// Shared layout snapshot model for cross-platform layout parity testing.
///
/// Workflow:
/// 1. macOS tests render real SwiftUI views via NSHostingView at a fixed size
/// 2. Each view tree is walked and captured as a `LayoutSnapshot`
/// 3. Snapshots are exported as JSON fixtures
/// 4. GTK (and Win32) tests render the same SwiftOpenUI views
/// 5. Platform snapshots are compared against the macOS reference with tolerances
///
/// The model is Codable and platform-independent.

import Foundation

// MARK: - Snapshot Model

/// A single node in a captured layout tree.
public struct LayoutNode: Codable, Equatable, CustomStringConvertible {
    /// Identifier tag for matching across backends.
    /// On macOS: accessibility identifier, or view type name.
    /// On GTK: widget name (gtk_widget_set_name), or widget type name.
    public var tag: String

    /// The SwiftOpenUI view type that produced this node (e.g. "Text", "VStack", "Button").
    /// Used for semantic matching when tags are ambiguous.
    public var viewType: String

    /// Frame origin relative to the root of the snapshot tree.
    public var x: Double
    public var y: Double

    /// Allocated size.
    public var width: Double
    public var height: Double

    /// Children in tree order.
    public var children: [LayoutNode]

    public init(tag: String, viewType: String, x: Double, y: Double,
                width: Double, height: Double, children: [LayoutNode] = []) {
        self.tag = tag
        self.viewType = viewType
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.children = children
    }

    public var description: String {
        descriptionLines().joined(separator: "\n")
    }

    func descriptionLines(indent: String = "") -> [String] {
        let frame = String(format: "(%.1f, %.1f, %.1f, %.1f)", x, y, width, height)
        let line = "\(indent)\(tag) [\(viewType)] \(frame)"
        return [line] + children.flatMap { $0.descriptionLines(indent: indent + "  ") }
    }
}

/// A complete layout snapshot for one test scenario.
public struct LayoutSnapshot: Codable, Equatable {
    /// Human-readable name for this scenario (e.g. "vstack-3-texts-center").
    public var scenario: String

    /// The root size at which layout was computed (window/hosting view size).
    public var rootWidth: Double
    public var rootHeight: Double

    /// The captured layout tree.
    public var root: LayoutNode

    /// Platform that produced this snapshot.
    public var platform: String

    /// ISO-8601 timestamp of capture.
    public var capturedAt: String

    public init(scenario: String, rootWidth: Double, rootHeight: Double,
                root: LayoutNode, platform: String, capturedAt: String) {
        self.scenario = scenario
        self.rootWidth = rootWidth
        self.rootHeight = rootHeight
        self.root = root
        self.platform = platform
        self.capturedAt = capturedAt
    }
}

// MARK: - Comparison

/// Result of comparing two layout nodes.
public struct LayoutDiff: CustomStringConvertible {
    public var path: String
    public var message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }

    public var description: String {
        "\(path): \(message)"
    }
}

/// Compare two layout trees with configurable tolerance.
public func compareLayouts(
    reference: LayoutNode,
    actual: LayoutNode,
    tolerance: Double = 2.0,
    path: String = "root"
) -> [LayoutDiff] {
    var diffs: [LayoutDiff] = []

    // Compare tags
    if reference.tag != actual.tag {
        diffs.append(LayoutDiff(
            path: path,
            message: "tag mismatch: '\(reference.tag)' vs '\(actual.tag)'"
        ))
    }

    // Compare frame with tolerance
    let dx = abs(reference.x - actual.x)
    let dy = abs(reference.y - actual.y)
    let dw = abs(reference.width - actual.width)
    let dh = abs(reference.height - actual.height)

    if dx > tolerance {
        diffs.append(LayoutDiff(
            path: path,
            message: String(format: "x: %.1f vs %.1f (delta %.1f > %.1f)",
                          reference.x, actual.x, dx, tolerance)
        ))
    }
    if dy > tolerance {
        diffs.append(LayoutDiff(
            path: path,
            message: String(format: "y: %.1f vs %.1f (delta %.1f > %.1f)",
                          reference.y, actual.y, dy, tolerance)
        ))
    }
    if dw > tolerance {
        diffs.append(LayoutDiff(
            path: path,
            message: String(format: "width: %.1f vs %.1f (delta %.1f > %.1f)",
                          reference.width, actual.width, dw, tolerance)
        ))
    }
    if dh > tolerance {
        diffs.append(LayoutDiff(
            path: path,
            message: String(format: "height: %.1f vs %.1f (delta %.1f > %.1f)",
                          reference.height, actual.height, dh, tolerance)
        ))
    }

    // Compare children count
    let minCount = min(reference.children.count, actual.children.count)
    if reference.children.count != actual.children.count {
        diffs.append(LayoutDiff(
            path: path,
            message: "child count: \(reference.children.count) vs \(actual.children.count)"
        ))
    }

    // Recursively compare matched children
    for i in 0..<minCount {
        let childPath = "\(path)/\(reference.children[i].tag)[\(i)]"
        diffs += compareLayouts(
            reference: reference.children[i],
            actual: actual.children[i],
            tolerance: tolerance,
            path: childPath
        )
    }

    return diffs
}

// MARK: - JSON I/O

public func writeSnapshot(_ snapshot: LayoutSnapshot, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(snapshot)
    try data.write(to: url)
}

public func readSnapshot(from url: URL) throws -> LayoutSnapshot {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(LayoutSnapshot.self, from: data)
}

/// Read a snapshot from a named fixture file relative to a fixtures directory.
public func readFixture(named name: String, in fixturesDir: URL) throws -> LayoutSnapshot {
    let url = fixturesDir.appendingPathComponent("\(name).json")
    return try readSnapshot(from: url)
}
