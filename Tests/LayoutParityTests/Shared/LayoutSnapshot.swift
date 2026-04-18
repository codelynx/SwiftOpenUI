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

/// Category of a layout diff — structural bugs vs expected font-metric variance.
public enum LeafDiffCategory: String, CustomStringConvertible {
    /// Layout engine placed something wrong (alignment, spacing, flex distribution).
    /// These are bugs to fix.
    case structural
    /// Font metrics differ across platforms (SF vs Pango vs DirectWrite).
    /// Expected and informational — not actionable in layout code.
    case textMetric

    public var description: String { rawValue }
}

/// Result of comparing two layout nodes.
public struct LayoutDiff: CustomStringConvertible {
    public var path: String
    public var message: String
    public var category: LeafDiffCategory

    public init(path: String, message: String, category: LeafDiffCategory = .structural) {
        self.path = path
        self.message = message
        self.category = category
    }

    public var description: String {
        "[\(category)] \(path): \(message)"
    }
}

/// Per-category tolerances for leaf-based comparison.
///
/// Separates font-metric variance (expected, generous tolerance) from
/// structural layout bugs (tight tolerance). This prevents a single
/// blanket tolerance from hiding real bugs.
public struct ParityTolerances {
    /// Structural position/size tolerance for non-text leaves (Color, Divider, etc.).
    /// Tight — catches alignment, spacing, and flex distribution bugs.
    public var structuralPosition: Double
    public var structuralSize: Double

    /// Text size tolerance — expected variance from different font engines.
    public var textSize: Double

    /// Text position tolerance — position shifts caused by text size differences.
    /// E.g., bottom-trailing alignment shifts x by the text width delta.
    public var textPosition: Double

    /// Inter-leaf gap tolerance — tight, applied to spacing between consecutive
    /// leaves regardless of whether they are text. Gaps are pure layout decisions
    /// (spacing, flex distribution) and do not depend on font metrics.
    public var gapTolerance: Double

    /// Alignment tolerance for single-leaf scenarios — how far a leaf's position
    /// within its container can drift. Tight, catches frame alignment bugs.
    public var alignmentTolerance: Double

    public init(
        structuralPosition: Double = 2.0,
        structuralSize: Double = 2.0,
        textSize: Double = 10.0,
        textPosition: Double = 10.0,
        gapTolerance: Double = 2.0,
        alignmentTolerance: Double = 2.0
    ) {
        self.structuralPosition = structuralPosition
        self.structuralSize = structuralSize
        self.textSize = textSize
        self.textPosition = textPosition
        self.gapTolerance = gapTolerance
        self.alignmentTolerance = alignmentTolerance
    }

    /// Legacy blanket tolerance (for migration).
    public static func blanket(_ tolerance: Double) -> ParityTolerances {
        ParityTolerances(
            structuralPosition: tolerance,
            structuralSize: tolerance,
            textSize: tolerance,
            textPosition: tolerance,
            gapTolerance: tolerance,
            alignmentTolerance: tolerance
        )
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
    public var viewType: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(tag: String, viewType: String = "", x: Double, y: Double, width: Double, height: Double) {
        self.tag = tag
        self.viewType = viewType
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Whether this leaf represents text content (uses generous font-metric tolerances).
    public var isTextLeaf: Bool {
        tag.hasPrefix("text:") || viewType == "CGDrawingLayer" || viewType == "GtkLabel"
    }

    public var description: String {
        String(format: "%@ (%.1f, %.1f, %.1f, %.1f)", tag, x, y, width, height)
    }
}

/// Known visible content view types that should always be extracted as leaves,
/// even if they have a zero dimension (e.g., Color with constrained width but no height).
private let visibleContentTypes: Set<String> = ["Color", "CALayer"]

/// Extract leaf nodes from a layout tree.
/// Leaves are nodes with no children (actual rendered content).
/// Skips zero-size nodes and spacer placeholders.
public func extractLeaves(from node: LayoutNode, skipSpacers: Bool = true) -> [LayoutLeaf] {
    // Skip spacer nodes entirely (including their children)
    if skipSpacers && node.viewType == "Spacer" { return [] }

    if node.children.isEmpty {
        // Skip completely invisible nodes (both dimensions zero)
        if node.width <= 0 && node.height <= 0 { return [] }
        // Skip nodes with zero in either dimension, unless they are known
        // visible content (e.g., Color fills that didn't get height allocated)
        let isVisibleContent = visibleContentTypes.contains(node.viewType)
        if skipSpacers && !isVisibleContent && (node.width == 0 || node.height == 0) { return [] }
        return [LayoutLeaf(
            tag: node.tag, viewType: node.viewType, x: node.x, y: node.y,
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

    /// Only structural diffs count as failures. Text-metric diffs are informational.
    public var structuralDiffs: [LayoutDiff] { allDiffs.filter { $0.category == .structural } }
    public var textMetricDiffs: [LayoutDiff] { allDiffs.filter { $0.category == .textMetric } }

    /// Pass if no structural failures. Text-metric diffs are expected and allowed.
    public var passed: Bool { structuralDiffs.isEmpty }

    public var description: String {
        var lines: [String] = []
        lines.append("Leaves: ref=\(referenceLeafCount) actual=\(actualLeafCount) matched=\(matchedCount)")
        if !structuralDiffs.isEmpty {
            lines.append("Structural failures (\(structuralDiffs.count)):")
            for d in structuralDiffs { lines.append("  \(d)") }
        }
        if !textMetricDiffs.isEmpty {
            lines.append("Text-metric info (\(textMetricDiffs.count)):")
            for d in textMetricDiffs { lines.append("  \(d)") }
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
            viewType: leaf.viewType,
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
/// Per-leaf tolerance: text leaves (font-metric dependent) get generous
/// tolerances; structural leaves (Color, Divider) get tight tolerances
/// that catch real layout bugs.
public func compareLeaves(
    reference: LayoutSnapshot,
    actual: LayoutSnapshot,
    tolerances: ParityTolerances = ParityTolerances()
) -> LeafComparisonResult {
    var rootDiffs: [LayoutDiff] = []

    // Report root size differences as info (not failures)
    let refBBox = leafBoundingBox(sortLeaves(extractLeaves(from: reference.root)))
    let actBBox = leafBoundingBox(sortLeaves(extractLeaves(from: actual.root)))
    let contentWidthDiff = abs(refBBox.width - actBBox.width)
    let contentHeightDiff = abs(refBBox.height - actBBox.height)
    if contentWidthDiff > tolerances.textSize {
        rootDiffs.append(LayoutDiff(
            path: "content-bbox",
            message: String(format: "content width: %.1f vs %.1f (delta %.1f)",
                          refBBox.width, actBBox.width, contentWidthDiff),
            category: .textMetric
        ))
    }
    if contentHeightDiff > tolerances.textSize {
        rootDiffs.append(LayoutDiff(
            path: "content-bbox",
            message: String(format: "content height: %.1f vs %.1f (delta %.1f)",
                          refBBox.height, actBBox.height, contentHeightDiff),
            category: .textMetric
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
            message: "leaf count: \(refLeaves.count) vs \(actLeaves.count)",
            category: .structural
        ))
    }

    // Compare matched leaves with per-leaf tolerance selection.
    //
    // Key distinction: text *size* (width/height) differs due to font metrics
    // (SF vs Pango vs DirectWrite) — these are informational (.textMetric).
    // Text *position* (x/y) reflects layout engine decisions (alignment,
    // spacing, flex distribution) — these are bugs (.structural) even for
    // text leaves. Only the text position tolerance is more generous to
    // account for cascaded size differences (e.g., centered text shifts
    // when its width changes).
    for i in 0..<matchCount {
        let ref = refLeaves[i]
        let act = actLeaves[i]
        let label = "leaf[\(i)] ref=\(ref.tag) act=\(act.tag)"

        let isText = ref.isTextLeaf || act.isTextLeaf
        let posTol = isText ? tolerances.textPosition : tolerances.structuralPosition
        let sizTol = isText ? tolerances.textSize : tolerances.structuralSize

        let dx = abs(ref.x - act.x)
        let dy = abs(ref.y - act.y)
        let dw = abs(ref.width - act.width)
        let dh = abs(ref.height - act.height)

        // Text leading-edge position can shift by the text size delta under
        // trailing/bottom alignment while the aligned far edge remains correct
        // (for example ZStack bottomTrailing). Classify as font-metric info only
        // when the anchoring far edge (ref.x+ref.width vs act.x+act.width) is
        // stable — matching deltas on their own don't prove the text stayed
        // anchored. Without that check, a leaf that moved and grew in the same
        // direction would also satisfy |dx - dw| == 0.
        if dx > posTol {
            let trailingEdgeDrift = abs((ref.x + ref.width) - (act.x + act.width))
            let category: LeafDiffCategory = isText && trailingEdgeDrift <= tolerances.structuralPosition
                ? .textMetric
                : .structural
            leafDiffs.append(LayoutDiff(
                path: label,
                message: String(format: "x: %.1f vs %.1f (delta %.1f)", ref.x, act.x, dx),
                category: category
            ))
        }
        if dy > posTol {
            let bottomEdgeDrift = abs((ref.y + ref.height) - (act.y + act.height))
            let category: LeafDiffCategory = isText && bottomEdgeDrift <= tolerances.structuralPosition
                ? .textMetric
                : .structural
            leafDiffs.append(LayoutDiff(
                path: label,
                message: String(format: "y: %.1f vs %.1f (delta %.1f)", ref.y, act.y, dy),
                category: category
            ))
        }
        // Size diffs: structural for non-text, textMetric for text
        if dw > sizTol {
            leafDiffs.append(LayoutDiff(
                path: label,
                message: String(format: "width: %.1f vs %.1f (delta %.1f)", ref.width, act.width, dw),
                category: isText ? .textMetric : .structural
            ))
        }
        if dh > sizTol {
            leafDiffs.append(LayoutDiff(
                path: label,
                message: String(format: "height: %.1f vs %.1f (delta %.1f)", ref.height, act.height, dh),
                category: isText ? .textMetric : .structural
            ))
        }
    }

    // Inter-leaf gap checks: compare the spacing between consecutive leaves.
    // Most gap differences are layout decisions. When the gap drift is paired
    // with text-size drift, report it as text-metric info: flexible space is
    // computed from remaining area, so wider/taller Pango text legitimately
    // reduces adjacent Spacer gaps.
    if matchCount >= 2 {
        for i in 1..<matchCount {
            let refPrev = refLeaves[i - 1]
            let refCurr = refLeaves[i]
            let actPrev = actLeaves[i - 1]
            let actCurr = actLeaves[i]

            let refSameRow = abs(refPrev.y - refCurr.y) <= 4.0
            let actSameRow = abs(actPrev.y - actCurr.y) <= 4.0

            // Vertical gap: only for vertically-stacked pairs (different rows).
            // Same-row pairs (HStack children) have meaningless vertical gaps
            // that vary with font height across platforms.
            if !refSameRow && !actSameRow {
                let refGapY = refCurr.y - (refPrev.y + refPrev.height)
                let actGapY = actCurr.y - (actPrev.y + actPrev.height)
                let gapDeltaY = abs(refGapY - actGapY)

                if gapDeltaY > tolerances.gapTolerance {
                    let textHeightDelta = abs(refPrev.height - actPrev.height) + abs(refCurr.height - actCurr.height)
                    // Only absorb the portion of the gap drift explainable by
                    // the text-height delta. A 1pt font difference cannot
                    // account for an 8pt gap insertion/removal.
                    let textMetricGap = textHeightDelta > 0
                        && (refPrev.isTextLeaf || actPrev.isTextLeaf || refCurr.isTextLeaf || actCurr.isTextLeaf)
                        && gapDeltaY <= textHeightDelta + tolerances.structuralPosition
                    leafDiffs.append(LayoutDiff(
                        path: "gap[\(i-1)->\(i)]",
                        message: String(format: "vertical gap: %.1f vs %.1f (delta %.1f)",
                                      refGapY, actGapY, gapDeltaY),
                        category: textMetricGap ? .textMetric : .structural
                    ))
                }
            }

            // Horizontal gap (for leaves on the same row)
            if refSameRow && actSameRow {
                let refGapX = refCurr.x - (refPrev.x + refPrev.width)
                let actGapX = actCurr.x - (actPrev.x + actPrev.width)
                let gapDeltaX = abs(refGapX - actGapX)

                if gapDeltaX > tolerances.gapTolerance {
                    let textWidthDelta = abs(refPrev.width - actPrev.width) + abs(refCurr.width - actCurr.width)
                    let textMetricGap = textWidthDelta > 0
                        && (refPrev.isTextLeaf || actPrev.isTextLeaf || refCurr.isTextLeaf || actCurr.isTextLeaf)
                        && gapDeltaX <= textWidthDelta + tolerances.structuralPosition
                    leafDiffs.append(LayoutDiff(
                        path: "gap[\(i-1)->\(i)]",
                        message: String(format: "horizontal gap: %.1f vs %.1f (delta %.1f)",
                                      refGapX, actGapX, gapDeltaX),
                        category: textMetricGap ? .textMetric : .structural
                    ))
                }
            }
        }
    }

    // Single-leaf alignment check: for scenarios with exactly one leaf,
    // normalization collapses position to (0,0) on both sides, hiding
    // alignment bugs. Compare the leaf's raw position relative to the
    // captured root container dimensions (not the requested render size,
    // since macOS root is content-sized while GTK/Win32 roots fill the window).
    if matchCount == 1 {
        let refRaw = sortLeaves(extractLeaves(from: reference.root))
        let actRaw = sortLeaves(extractLeaves(from: actual.root))
        if refRaw.count == 1 && actRaw.count == 1 {
            let ref = refRaw[0]
            let act = actRaw[0]

            // Use the captured root node dimensions, not snapshot.rootWidth/Height
            let refRootW = reference.root.width
            let refRootH = reference.root.height
            let actRootW = actual.root.width
            let actRootH = actual.root.height

            // Use center-point fraction, not leading-edge fraction.
            // Leading-edge shifts when text width differs (font metrics),
            // but center stays stable for centered alignment. For
            // top-leading or bottom-trailing alignment the center still
            // detects the bug (large fractional shift).
            let refCenterX = refRootW > 0 ? (ref.x + ref.width / 2) / refRootW : 0
            let actCenterX = actRootW > 0 ? (act.x + act.width / 2) / actRootW : 0
            let refCenterY = refRootH > 0 ? (ref.y + ref.height / 2) / refRootH : 0
            let actCenterY = actRootH > 0 ? (act.y + act.height / 2) / actRootH : 0

            // Convert fractional difference to pixel drift at the reference scale.
            // For text leaves, use the text-position tolerance since center
            // shifts slightly with font-metric width changes.
            let fracDX = abs(refCenterX - actCenterX) * refRootW
            let fracDY = abs(refCenterY - actCenterY) * refRootH
            let isText = ref.isTextLeaf || act.isTextLeaf
            let alignTol = isText ? tolerances.textPosition : tolerances.alignmentTolerance

            if fracDX > alignTol {
                leafDiffs.append(LayoutDiff(
                    path: "alignment",
                    message: String(format: "x alignment center: ref=%.3f act=%.3f (drift %.1fpt)",
                                  refCenterX, actCenterX, fracDX),
                    category: .structural
                ))
            }
            if fracDY > alignTol {
                leafDiffs.append(LayoutDiff(
                    path: "alignment",
                    message: String(format: "y alignment center: ref=%.3f act=%.3f (drift %.1fpt)",
                                  refCenterY, actCenterY, fracDY),
                    category: .structural
                ))
            }
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

/// Legacy convenience — calls the new tolerances-based API.
public func compareLeaves(
    reference: LayoutSnapshot,
    actual: LayoutSnapshot,
    positionTolerance: Double,
    sizeTolerance: Double
) -> LeafComparisonResult {
    compareLeaves(
        reference: reference,
        actual: actual,
        tolerances: .blanket(max(positionTolerance, sizeTolerance))
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
