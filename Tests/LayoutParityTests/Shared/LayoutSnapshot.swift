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

// MARK: - Leaf-Based Comparison

/// A leaf node extracted from a layout tree — the actual visible content.
public struct LayoutLeaf: CustomStringConvertible {
    public var tag: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(tag: String, x: Double, y: Double, width: Double, height: Double) {
        self.tag = tag
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var description: String {
        String(format: "%@ (%.1f, %.1f, %.1f, %.1f)", tag, x, y, width, height)
    }
}

/// Extract leaf nodes from a layout tree.
/// Leaves are nodes with no children (actual rendered content).
/// Skips zero-size nodes and spacer placeholders.
public func extractLeaves(from node: LayoutNode, skipSpacers: Bool = true) -> [LayoutLeaf] {
    if node.children.isEmpty {
        // Skip zero-size nodes
        if node.width <= 0 && node.height <= 0 { return [] }
        // Skip spacer nodes (GTK renders spacers as empty 0-width labels)
        if skipSpacers && (node.width == 0 || node.height == 0) { return [] }
        return [LayoutLeaf(
            tag: node.tag, x: node.x, y: node.y,
            width: node.width, height: node.height
        )]
    }
    return node.children.flatMap { extractLeaves(from: $0, skipSpacers: skipSpacers) }
}

/// Sort leaves by position: top-to-bottom (y), then left-to-right (x).
/// Uses a threshold to group leaves on the same "row".
public func sortLeaves(_ leaves: [LayoutLeaf], rowThreshold: Double = 4.0) -> [LayoutLeaf] {
    leaves.sorted { a, b in
        if abs(a.y - b.y) > rowThreshold {
            return a.y < b.y
        }
        return a.x < b.x
    }
}

/// Result of a leaf-based comparison between two layouts.
public struct LeafComparisonResult: CustomStringConvertible {
    public var rootDiffs: [LayoutDiff]
    public var leafDiffs: [LayoutDiff]
    public var referenceLeafCount: Int
    public var actualLeafCount: Int
    public var matchedCount: Int

    public var allDiffs: [LayoutDiff] { rootDiffs + leafDiffs }
    public var passed: Bool { allDiffs.isEmpty }

    public var description: String {
        var lines: [String] = []
        lines.append("Leaves: ref=\(referenceLeafCount) actual=\(actualLeafCount) matched=\(matchedCount)")
        if !rootDiffs.isEmpty {
            lines.append("Root diffs:")
            for d in rootDiffs { lines.append("  \(d)") }
        }
        if !leafDiffs.isEmpty {
            lines.append("Leaf diffs:")
            for d in leafDiffs { lines.append("  \(d)") }
        }
        if passed { lines.append("PASS") }
        return lines.joined(separator: "\n")
    }
}

/// Compute the bounding box of an array of leaves.
public func leafBoundingBox(_ leaves: [LayoutLeaf]) -> (x: Double, y: Double, width: Double, height: Double) {
    guard !leaves.isEmpty else { return (0, 0, 0, 0) }
    let minX = leaves.map(\.x).min()!
    let minY = leaves.map(\.y).min()!
    let maxX = leaves.map { $0.x + $0.width }.max()!
    let maxY = leaves.map { $0.y + $0.height }.max()!
    return (minX, minY, maxX - minX, maxY - minY)
}

/// Normalize leaf positions relative to the content bounding box origin.
/// This removes the effect of different root container sizes.
public func normalizeLeaves(_ leaves: [LayoutLeaf]) -> [LayoutLeaf] {
    let bbox = leafBoundingBox(leaves)
    return leaves.map { leaf in
        LayoutLeaf(
            tag: leaf.tag,
            x: leaf.x - bbox.x,
            y: leaf.y - bbox.y,
            width: leaf.width,
            height: leaf.height
        )
    }
}

/// Compare two layout snapshots using leaf-to-leaf matching.
///
/// This handles the structural mismatch between backends:
/// - macOS SwiftUI renders as flat CALayer tree (tightly wrapped root)
/// - GTK renders as nested GtkWidget tree (root fills window)
///
/// Both are flattened to leaves, normalized to content-relative coordinates,
/// sorted by position, and compared. Root size differences are reported
/// separately and don't cause leaf comparison failures.
///
/// Parameters:
///   - positionTolerance: Max allowed difference in x/y position (default 4pt)
///   - sizeTolerance: Max allowed difference in width/height (default 6pt, generous for font differences)
public func compareLeaves(
    reference: LayoutSnapshot,
    actual: LayoutSnapshot,
    positionTolerance: Double = 4.0,
    sizeTolerance: Double = 6.0
) -> LeafComparisonResult {
    var rootDiffs: [LayoutDiff] = []

    // Report root size differences as info (not failures)
    let refBBox = leafBoundingBox(sortLeaves(extractLeaves(from: reference.root)))
    let actBBox = leafBoundingBox(sortLeaves(extractLeaves(from: actual.root)))
    let contentWidthDiff = abs(refBBox.width - actBBox.width)
    let contentHeightDiff = abs(refBBox.height - actBBox.height)
    if contentWidthDiff > sizeTolerance {
        rootDiffs.append(LayoutDiff(
            path: "content-bbox",
            message: String(format: "content width: %.1f vs %.1f (delta %.1f)",
                          refBBox.width, actBBox.width, contentWidthDiff)
        ))
    }
    if contentHeightDiff > sizeTolerance {
        rootDiffs.append(LayoutDiff(
            path: "content-bbox",
            message: String(format: "content height: %.1f vs %.1f (delta %.1f)",
                          refBBox.height, actBBox.height, contentHeightDiff)
        ))
    }

    // Extract leaves, normalize to content-relative coordinates, sort
    let refLeaves = sortLeaves(normalizeLeaves(
        sortLeaves(extractLeaves(from: reference.root))
    ))
    let actLeaves = sortLeaves(normalizeLeaves(
        sortLeaves(extractLeaves(from: actual.root))
    ))

    var leafDiffs: [LayoutDiff] = []
    let matchCount = min(refLeaves.count, actLeaves.count)

    if refLeaves.count != actLeaves.count {
        leafDiffs.append(LayoutDiff(
            path: "leaves",
            message: "leaf count: \(refLeaves.count) vs \(actLeaves.count)"
        ))
    }

    // Compare matched leaves (positions are now content-relative)
    for i in 0..<matchCount {
        let ref = refLeaves[i]
        let act = actLeaves[i]
        let label = "leaf[\(i)] ref=\(ref.tag) act=\(act.tag)"

        let dx = abs(ref.x - act.x)
        let dy = abs(ref.y - act.y)
        let dw = abs(ref.width - act.width)
        let dh = abs(ref.height - act.height)

        if dx > positionTolerance {
            leafDiffs.append(LayoutDiff(
                path: label,
                message: String(format: "x: %.1f vs %.1f (delta %.1f)", ref.x, act.x, dx)
            ))
        }
        if dy > positionTolerance {
            leafDiffs.append(LayoutDiff(
                path: label,
                message: String(format: "y: %.1f vs %.1f (delta %.1f)", ref.y, act.y, dy)
            ))
        }
        if dw > sizeTolerance {
            leafDiffs.append(LayoutDiff(
                path: label,
                message: String(format: "width: %.1f vs %.1f (delta %.1f)", ref.width, act.width, dw)
            ))
        }
        if dh > sizeTolerance {
            leafDiffs.append(LayoutDiff(
                path: label,
                message: String(format: "height: %.1f vs %.1f (delta %.1f)", ref.height, act.height, dh)
            ))
        }
    }

    return LeafComparisonResult(
        rootDiffs: rootDiffs,
        leafDiffs: leafDiffs,
        referenceLeafCount: refLeaves.count,
        actualLeafCount: actLeaves.count,
        matchedCount: matchCount
    )
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
