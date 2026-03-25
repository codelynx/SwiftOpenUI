import XCTest
@testable import SwiftOpenUI

final class LayoutTests: XCTestCase {

    // MARK: - Color

    func testColorHex6() {
        let color = Color(hex: "#FF0000")
        XCTAssertEqual(color.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.green, 0.0, accuracy: 0.01)
        XCTAssertEqual(color.blue, 0.0, accuracy: 0.01)
        XCTAssertEqual(color.alpha, 1.0)
    }

    func testColorHex8() {
        let color = Color(hex: "#FF000080")
        XCTAssertEqual(color.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.alpha, 128.0 / 255.0, accuracy: 0.01)
    }

    func testColorRGBFractional() {
        let color = Color(red: 0.5, green: 0.5, blue: 0.5)
        XCTAssertEqual(color.red, 0.5, accuracy: 0.01)
        XCTAssertEqual(color.alpha, 1.0)
    }

    func testColorRGBInteger() {
        let color = Color(red: 128, green: 0, blue: 255)
        XCTAssertEqual(color.red, 128.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(color.blue, 1.0, accuracy: 0.01)
    }

    func testColorOpacity() {
        let color = Color.red.opacity(0.5)
        XCTAssertEqual(color.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.alpha, 0.5, accuracy: 0.01)
    }

    func testColorEquality() {
        XCTAssertEqual(Color.red, Color.red)
        XCTAssertNotEqual(Color.red, Color.blue)
    }

    func testColorHexOutput() {
        let color = Color(red: 1.0, green: 0.0, blue: 0.0)
        XCTAssertEqual(color.hex, "#FF0000")
    }

    func testNamedColors() {
        // Ensure named colors don't crash
        _ = Color.red
        _ = Color.green
        _ = Color.blue
        _ = Color.orange
        _ = Color.purple
        _ = Color.yellow
        _ = Color.cyan
        _ = Color.gray
        _ = Color.white
        _ = Color.black
        _ = Color.clear
        _ = Color.pink
        _ = Color.brown
        _ = Color.mint
        _ = Color.teal
        _ = Color.indigo
    }

    // MARK: - Edge

    func testEdgeSetAll() {
        let all = Edge.Set.all
        XCTAssertTrue(all.contains(.top))
        XCTAssertTrue(all.contains(.bottom))
        XCTAssertTrue(all.contains(.leading))
        XCTAssertTrue(all.contains(.trailing))
    }

    func testEdgeSetHorizontal() {
        let h = Edge.Set.horizontal
        XCTAssertTrue(h.contains(.leading))
        XCTAssertTrue(h.contains(.trailing))
        XCTAssertFalse(h.contains(.top))
    }

    func testEdgeSetVertical() {
        let v = Edge.Set.vertical
        XCTAssertTrue(v.contains(.top))
        XCTAssertTrue(v.contains(.bottom))
        XCTAssertFalse(v.contains(.leading))
    }

    // MARK: - SafeAreaRegions

    func testSafeAreaRegionsAll() {
        let all = SafeAreaRegions.all
        XCTAssertTrue(all.contains(.container))
        XCTAssertTrue(all.contains(.keyboard))
    }

    func testSafeAreaRegionsCustomSet() {
        let regions: SafeAreaRegions = [.container]
        XCTAssertTrue(regions.contains(.container))
        XCTAssertFalse(regions.contains(.keyboard))
    }

    // MARK: - EdgeInsets

    func testEdgeInsetsDefault() {
        let insets = EdgeInsets()
        XCTAssertEqual(insets.top, 0)
        XCTAssertEqual(insets.leading, 0)
        XCTAssertEqual(insets.bottom, 0)
        XCTAssertEqual(insets.trailing, 0)
    }

    func testEdgeInsetsCustom() {
        let insets = EdgeInsets(top: 1, leading: 2, bottom: 3, trailing: 4)
        XCTAssertEqual(insets.top, 1)
        XCTAssertEqual(insets.leading, 2)
        XCTAssertEqual(insets.bottom, 3)
        XCTAssertEqual(insets.trailing, 4)
    }

    // MARK: - Alignment

    func testAlignmentEnumCases() {
        // Ensure all alignment cases exist
        _ = Alignment.topLeading
        _ = Alignment.top
        _ = Alignment.topTrailing
        _ = Alignment.leading
        _ = Alignment.center
        _ = Alignment.trailing
        _ = Alignment.bottomLeading
        _ = Alignment.bottom
        _ = Alignment.bottomTrailing
        _ = HorizontalAlignment.leading
        _ = HorizontalAlignment.center
        _ = HorizontalAlignment.trailing
        _ = VerticalAlignment.top
        _ = VerticalAlignment.center
        _ = VerticalAlignment.bottom
        _ = VerticalEdge.top
        _ = VerticalEdge.bottom
        _ = HorizontalEdge.leading
        _ = HorizontalEdge.trailing
    }

    // MARK: - ProposedViewSize / ViewSize

    func testViewSizeZero() {
        let size = ViewSize.zero
        XCTAssertEqual(size.width, 0)
        XCTAssertEqual(size.height, 0)
    }

    func testProposedViewSizeUnspecified() {
        let size = ProposedViewSize.unspecified
        XCTAssertNil(size.width)
        XCTAssertNil(size.height)
    }

    func testComputeFrameLayoutCentersChildInFixedFrame() {
        let result = computeFrameLayout(
            childNaturalSize: ViewSize(width: 20, height: 10),
            width: 56,
            height: 56,
            alignment: .center
        )

        XCTAssertEqual(result.containerSize, ViewSize(width: 56, height: 56))
        XCTAssertEqual(result.childPlacement.size, ViewSize(width: 20, height: 10))
        XCTAssertEqual(result.childPlacement.origin, ViewPoint(x: 18, y: 23))
    }

    func testComputeFrameLayoutAppliesMinAndMaxConstraints() {
        let result = computeFrameLayout(
            childNaturalSize: ViewSize(width: 40, height: 10),
            minWidth: 60,
            maxHeight: 8,
            alignment: .leading
        )

        XCTAssertEqual(result.containerSize, ViewSize(width: 60, height: 8))
        XCTAssertEqual(result.childPlacement.size, ViewSize(width: 40, height: 8))
        XCTAssertEqual(result.childPlacement.origin, ViewPoint(x: 0, y: 0))
    }

    func testComputeFrameLayoutExpandsChildWhenRequested() {
        let result = computeFrameLayout(
            childNaturalSize: ViewSize(width: 10, height: 12),
            width: 50,
            height: 24,
            alignment: .bottomTrailing,
            expandsToFillWidth: true,
            expandsToFillHeight: true
        )

        XCTAssertEqual(result.containerSize, ViewSize(width: 50, height: 24))
        XCTAssertEqual(result.childPlacement.size, ViewSize(width: 50, height: 24))
        XCTAssertEqual(result.childPlacement.origin, .zero)
    }

    func testComputeVStackLayoutTrailingAlignmentAndSpacing() {
        let result = computeVStackLayout(
            childSizes: [
                ViewSize(width: 40, height: 10),
                ViewSize(width: 20, height: 8),
            ],
            spacing: 4,
            alignment: .trailing
        )

        XCTAssertEqual(result.containerSize, ViewSize(width: 40, height: 22))
        XCTAssertEqual(result.childPlacements[0].origin, ViewPoint(x: 0, y: 0))
        XCTAssertEqual(result.childPlacements[1].origin, ViewPoint(x: 20, y: 14))
        XCTAssertEqual(result.childPlacements[1].size, ViewSize(width: 20, height: 8))
    }

    func testComputeVStackLayoutMeasuresSubviewsThroughContext() {
        var measuredSubviews: [LayoutSubview] = []
        var measuredProposals: [ProposedViewSize] = []
        let context = MockLayoutMeasureContext { subview, proposal in
            measuredSubviews.append(subview)
            measuredProposals.append(proposal)
            switch subview.index {
            case 0:
                return LayoutMeasurement(size: ViewSize(width: 40, height: 10))
            case 1:
                return LayoutMeasurement(size: ViewSize(width: 20, height: 8))
            default:
                XCTFail("Unexpected subview index \(subview.index)")
                return LayoutMeasurement(size: .zero)
            }
        }

        let result = computeVStackLayout(
            subviews: [LayoutSubview(index: 0), LayoutSubview(index: 1)],
            context: context,
            spacing: 4,
            alignment: .trailing
        )

        XCTAssertEqual(measuredSubviews, [LayoutSubview(index: 0), LayoutSubview(index: 1)])
        XCTAssertEqual(measuredProposals, [.unspecified, .unspecified])
        XCTAssertEqual(result.containerSize, ViewSize(width: 40, height: 22))
        XCTAssertEqual(result.childPlacements[1].origin, ViewPoint(x: 20, y: 14))
    }

    func testComputeHStackLayoutBottomAlignmentAndSpacing() {
        let result = computeHStackLayout(
            childSizes: [
                ViewSize(width: 10, height: 24),
                ViewSize(width: 8, height: 12),
            ],
            spacing: 6,
            alignment: .bottom
        )

        XCTAssertEqual(result.containerSize, ViewSize(width: 24, height: 24))
        XCTAssertEqual(result.childPlacements[0].origin, ViewPoint(x: 0, y: 0))
        XCTAssertEqual(result.childPlacements[1].origin, ViewPoint(x: 16, y: 12))
        XCTAssertEqual(result.childPlacements[1].size, ViewSize(width: 8, height: 12))
    }

    func testComputeHStackLayoutMeasuresSubviewsThroughContext() {
        var measuredSubviews: [LayoutSubview] = []
        var measuredProposals: [ProposedViewSize] = []
        let context = MockLayoutMeasureContext { subview, proposal in
            measuredSubviews.append(subview)
            measuredProposals.append(proposal)
            switch subview.index {
            case 0:
                return LayoutMeasurement(size: ViewSize(width: 10, height: 24))
            case 1:
                return LayoutMeasurement(size: ViewSize(width: 8, height: 12))
            default:
                XCTFail("Unexpected subview index \(subview.index)")
                return LayoutMeasurement(size: .zero)
            }
        }

        let result = computeHStackLayout(
            subviews: [LayoutSubview(index: 0), LayoutSubview(index: 1)],
            context: context,
            spacing: 6,
            alignment: .bottom
        )

        XCTAssertEqual(measuredSubviews, [LayoutSubview(index: 0), LayoutSubview(index: 1)])
        XCTAssertEqual(measuredProposals, [.unspecified, .unspecified])
        XCTAssertEqual(result.containerSize, ViewSize(width: 24, height: 24))
        XCTAssertEqual(result.childPlacements[1].origin, ViewPoint(x: 16, y: 12))
    }

    func testComputeZStackLayoutBottomTrailingAlignment() {
        let result = computeZStackLayout(
            childSizes: [
                ViewSize(width: 40, height: 24),
                ViewSize(width: 12, height: 10),
            ],
            alignment: .bottomTrailing
        )

        XCTAssertEqual(result.containerSize, ViewSize(width: 40, height: 24))
        XCTAssertEqual(result.childPlacements[0].origin, ViewPoint(x: 0, y: 0))
        XCTAssertEqual(result.childPlacements[1].origin, ViewPoint(x: 28, y: 14))
        XCTAssertEqual(result.childPlacements[1].size, ViewSize(width: 12, height: 10))
    }

    func testComputeZStackLayoutMeasuresSubviewsThroughContext() {
        var measuredSubviews: [LayoutSubview] = []
        var measuredProposals: [ProposedViewSize] = []
        let context = MockLayoutMeasureContext { subview, proposal in
            measuredSubviews.append(subview)
            measuredProposals.append(proposal)
            switch subview.index {
            case 0:
                return LayoutMeasurement(size: ViewSize(width: 40, height: 24))
            case 1:
                return LayoutMeasurement(size: ViewSize(width: 12, height: 10))
            default:
                XCTFail("Unexpected subview index \(subview.index)")
                return LayoutMeasurement(size: .zero)
            }
        }

        let result = computeZStackLayout(
            subviews: [LayoutSubview(index: 0), LayoutSubview(index: 1)],
            context: context,
            alignment: .bottomTrailing
        )

        XCTAssertEqual(measuredSubviews, [LayoutSubview(index: 0), LayoutSubview(index: 1)])
        XCTAssertEqual(measuredProposals, [.unspecified, .unspecified])
        XCTAssertEqual(result.containerSize, ViewSize(width: 40, height: 24))
        XCTAssertEqual(result.childPlacements[1].origin, ViewPoint(x: 28, y: 14))
    }

    func testComputeGridLayoutWrapsRowsUsingColumnWidthsAndRowHeights() {
        let result = computeGridLayout(
            childSizes: [
                ViewSize(width: 40, height: 10),
                ViewSize(width: 8, height: 12),
                ViewSize(width: 20, height: 6),
            ],
            columns: 2,
            hSpacing: 5,
            vSpacing: 4
        )

        XCTAssertEqual(result.containerSize, ViewSize(width: 53, height: 22))
        XCTAssertEqual(result.childPlacements[0].origin, ViewPoint(x: 0, y: 0))
        XCTAssertEqual(result.childPlacements[1].origin, ViewPoint(x: 45, y: 0))
        XCTAssertEqual(result.childPlacements[2].origin, ViewPoint(x: 0, y: 16))
        XCTAssertEqual(result.childPlacements[2].size, ViewSize(width: 20, height: 6))
    }

    func testComputeGridLayoutMeasuresSubviewsThroughContext() {
        var measuredSubviews: [LayoutSubview] = []
        var measuredProposals: [ProposedViewSize] = []
        let context = MockLayoutMeasureContext { subview, proposal in
            measuredSubviews.append(subview)
            measuredProposals.append(proposal)
            switch subview.index {
            case 0:
                return LayoutMeasurement(size: ViewSize(width: 40, height: 10))
            case 1:
                return LayoutMeasurement(size: ViewSize(width: 8, height: 12))
            case 2:
                return LayoutMeasurement(size: ViewSize(width: 20, height: 6))
            default:
                XCTFail("Unexpected subview index \(subview.index)")
                return LayoutMeasurement(size: .zero)
            }
        }

        let result = computeGridLayout(
            subviews: [
                LayoutSubview(index: 0),
                LayoutSubview(index: 1),
                LayoutSubview(index: 2),
            ],
            context: context,
            columns: 2,
            hSpacing: 5,
            vSpacing: 4
        )

        XCTAssertEqual(
            measuredSubviews,
            [LayoutSubview(index: 0), LayoutSubview(index: 1), LayoutSubview(index: 2)]
        )
        XCTAssertEqual(measuredProposals, [.unspecified, .unspecified, .unspecified])
        XCTAssertEqual(result.containerSize, ViewSize(width: 53, height: 22))
        XCTAssertEqual(result.childPlacements[2].origin, ViewPoint(x: 0, y: 16))
    }

    func testComputeExplicitGridLayoutUsesHomogeneousColumnsAndSpans() {
        let result = computeExplicitGridLayout(
            rows: [
                [
                    (size: ViewSize(width: 55, height: 10), columnSpan: 2),
                    (size: ViewSize(width: 18, height: 8), columnSpan: 1),
                ],
                [
                    (size: ViewSize(width: 20, height: 12), columnSpan: 1),
                    (size: ViewSize(width: 20, height: 6), columnSpan: 1),
                    (size: ViewSize(width: 20, height: 7), columnSpan: 1),
                ],
            ],
            hSpacing: 4,
            vSpacing: 5
        )

        XCTAssertEqual(result.containerSize, ViewSize(width: 84.5, height: 27))
        XCTAssertEqual(result.childPlacements[0].origin, ViewPoint(x: 0, y: 0))
        XCTAssertEqual(result.childPlacements[0].size, ViewSize(width: 55, height: 10))
        XCTAssertEqual(result.childPlacements[1].origin, ViewPoint(x: 59, y: 0))
        XCTAssertEqual(result.childPlacements[2].origin, ViewPoint(x: 0, y: 15))
        XCTAssertEqual(result.childPlacements[3].origin, ViewPoint(x: 29.5, y: 15))
        XCTAssertEqual(result.childPlacements[4].origin, ViewPoint(x: 59, y: 15))
    }

    func testComputeExplicitGridLayoutMeasuresSubviewsThroughContext() {
        var measuredSubviews: [LayoutSubview] = []
        var measuredProposals: [ProposedViewSize] = []
        let context = MockLayoutMeasureContext { subview, proposal in
            measuredSubviews.append(subview)
            measuredProposals.append(proposal)
            switch subview.index {
            case 0:
                return LayoutMeasurement(size: ViewSize(width: 55, height: 10))
            case 1:
                return LayoutMeasurement(size: ViewSize(width: 18, height: 8))
            case 2:
                return LayoutMeasurement(size: ViewSize(width: 20, height: 12))
            case 3:
                return LayoutMeasurement(size: ViewSize(width: 20, height: 6))
            case 4:
                return LayoutMeasurement(size: ViewSize(width: 20, height: 7))
            default:
                XCTFail("Unexpected subview index \(subview.index)")
                return LayoutMeasurement(size: .zero)
            }
        }

        let result = computeExplicitGridLayout(
            rows: [
                [
                    (subview: LayoutSubview(index: 0), columnSpan: 2),
                    (subview: LayoutSubview(index: 1), columnSpan: 1),
                ],
                [
                    (subview: LayoutSubview(index: 2), columnSpan: 1),
                    (subview: LayoutSubview(index: 3), columnSpan: 1),
                    (subview: LayoutSubview(index: 4), columnSpan: 1),
                ],
            ],
            context: context,
            hSpacing: 4,
            vSpacing: 5
        )

        XCTAssertEqual(
            measuredSubviews,
            [
                LayoutSubview(index: 0),
                LayoutSubview(index: 1),
                LayoutSubview(index: 2),
                LayoutSubview(index: 3),
                LayoutSubview(index: 4),
            ]
        )
        XCTAssertEqual(
            measuredProposals,
            [.unspecified, .unspecified, .unspecified, .unspecified, .unspecified]
        )
        XCTAssertEqual(result.containerSize, ViewSize(width: 84.5, height: 27))
        XCTAssertEqual(result.childPlacements[0].size, ViewSize(width: 55, height: 10))
        XCTAssertEqual(result.childPlacements[4].origin, ViewPoint(x: 59, y: 15))
    }

    func testComputeLazyGridConfigurationDefaultsWhenEmpty() {
        let result = computeLazyGridConfiguration(gridItems: [])

        XCTAssertEqual(
            result,
            LazyGridConfiguration(minColumns: 1, maxColumns: 7, adaptiveMinimum: 0)
        )
    }

    func testComputeLazyGridConfigurationUsesFixedCountForNonAdaptiveItems() {
        let result = computeLazyGridConfiguration(
            gridItems: [GridItem(.fixed), GridItem(.flexible), GridItem(.fixed)]
        )

        XCTAssertEqual(
            result,
            LazyGridConfiguration(minColumns: 3, maxColumns: 3, adaptiveMinimum: 0)
        )
    }

    func testComputeLazyGridConfigurationUsesAdaptiveBoundsAndMinimum() {
        let result = computeLazyGridConfiguration(
            gridItems: [GridItem(.fixed), GridItem(.adaptive(minimum: 80))]
        )

        XCTAssertEqual(
            result,
            LazyGridConfiguration(minColumns: 1, maxColumns: 100, adaptiveMinimum: 80)
        )
    }

    func testLayoutSubviewIsHashableByIndex() {
        let subviews: Set<LayoutSubview> = [LayoutSubview(index: 0), LayoutSubview(index: 1)]

        XCTAssertTrue(subviews.contains(LayoutSubview(index: 0)))
        XCTAssertEqual(subviews.count, 2)
    }

    func testLayoutMeasurementCapturesSizeAndFillFlags() {
        let measurement = LayoutMeasurement(
            size: ViewSize(width: 40, height: 12),
            expandsToFillWidth: true,
            expandsToFillHeight: false
        )

        XCTAssertEqual(measurement.size, ViewSize(width: 40, height: 12))
        XCTAssertTrue(measurement.expandsToFillWidth)
        XCTAssertFalse(measurement.expandsToFillHeight)
    }

    func testLayoutMeasureContextReceivesSubviewAndProposal() {
        let context = MockLayoutMeasureContext { subview, proposal in
            XCTAssertEqual(subview, LayoutSubview(index: 2))
            XCTAssertEqual(proposal, ProposedViewSize(width: 80, height: nil))
            return LayoutMeasurement(
                size: ViewSize(width: 12, height: 6),
                expandsToFillWidth: false,
                expandsToFillHeight: true
            )
        }

        let measurement = context.measure(
            LayoutSubview(index: 2),
            proposal: ProposedViewSize(width: 80, height: nil)
        )

        XCTAssertEqual(
            measurement,
            LayoutMeasurement(
                size: ViewSize(width: 12, height: 6),
                expandsToFillWidth: false,
                expandsToFillHeight: true
            )
        )
    }
}

private struct MockLayoutMeasureContext: LayoutMeasureContext {
    var measureImpl: (LayoutSubview, ProposedViewSize) -> LayoutMeasurement

    func measure(_ subview: LayoutSubview, proposal: ProposedViewSize) -> LayoutMeasurement {
        measureImpl(subview, proposal)
    }
}
