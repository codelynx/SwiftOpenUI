/// Layout test scenarios shared across platforms.
///
/// Each scenario defines a SwiftOpenUI view tree and the root size to render at.
/// macOS tests render these with real SwiftUI; GTK tests render with SwiftOpenUI+GTK.
///
/// IMPORTANT: On macOS, `import SwiftUI` is used. On Linux, `import SwiftOpenUI`.
/// The view code must compile under both. This file uses `#if os(macOS)` guards where needed.

#if os(macOS)
import SwiftUI
#else
import SwiftOpenUI
#endif

// MARK: - Scenario Registry

/// Standard root size for all layout parity tests (logical points).
let parityRootWidth: Double = 400
let parityRootHeight: Double = 600

/// All scenarios, keyed by name.
let allLayoutScenarios: [(name: String, view: AnyView)] = [
    // === Basic Views ===
    ("text-single", AnyView(scenario_textSingle)),
    ("text-long-wrap", AnyView(scenario_textLongWrap)),
    ("color-fill", AnyView(scenario_colorFill)),
    ("spacer-vertical", AnyView(scenario_spacerVertical)),

    // === VStack ===
    ("vstack-default", AnyView(scenario_vstackDefault)),
    ("vstack-leading", AnyView(scenario_vstackLeading)),
    ("vstack-trailing", AnyView(scenario_vstackTrailing)),
    ("vstack-spacing-20", AnyView(scenario_vstackSpacing20)),
    ("vstack-with-spacer", AnyView(scenario_vstackWithSpacer)),
    ("vstack-nested", AnyView(scenario_vstackNested)),

    // === HStack ===
    ("hstack-default", AnyView(scenario_hstackDefault)),
    ("hstack-top", AnyView(scenario_hstackTop)),
    ("hstack-bottom", AnyView(scenario_hstackBottom)),
    ("hstack-spacing-20", AnyView(scenario_hstackSpacing20)),
    ("hstack-with-spacer", AnyView(scenario_hstackWithSpacer)),

    // === ZStack ===
    ("zstack-default", AnyView(scenario_zstackDefault)),
    ("zstack-top-leading", AnyView(scenario_zstackTopLeading)),
    ("zstack-bottom-trailing", AnyView(scenario_zstackBottomTrailing)),

    // === Frame ===
    ("frame-fixed", AnyView(scenario_frameFixed)),
    ("frame-min-max", AnyView(scenario_frameMinMax)),
    ("frame-maxwidth-infinity", AnyView(scenario_frameMaxWidthInfinity)),
    ("frame-alignment-top-leading", AnyView(scenario_frameAlignmentTopLeading)),
    ("frame-alignment-bottom-trailing", AnyView(scenario_frameAlignmentBottomTrailing)),
    ("frame-alignment-center", AnyView(scenario_frameAlignmentCenter)),

    // === Padding ===
    ("padding-default", AnyView(scenario_paddingDefault)),
    ("padding-custom", AnyView(scenario_paddingCustom)),
    ("padding-horizontal", AnyView(scenario_paddingHorizontal)),
    ("padding-nested", AnyView(scenario_paddingNested)),

    // === Combined Layouts ===
    ("vstack-frame-padding", AnyView(scenario_vstackFramePadding)),
    ("hstack-in-vstack", AnyView(scenario_hstackInVstack)),
    ("complex-nested", AnyView(scenario_complexNested)),
    ("spacer-between-texts", AnyView(scenario_spacerBetweenTexts)),
    ("two-column-hstack", AnyView(scenario_twoColumnHstack)),

    // === Edge Cases ===
    ("empty-vstack", AnyView(scenario_emptyVstack)),
    ("single-child-vstack", AnyView(scenario_singleChildVstack)),
    ("deeply-nested-frames", AnyView(scenario_deeplyNestedFrames)),

    // === App Patterns (composition) ===
    ("app-header-content-footer", AnyView(scenario_appHeaderContentFooter)),
    ("sidebar-detail-split", AnyView(scenario_sidebarDetailSplit)),
    ("toolbar-content-layout", AnyView(scenario_toolbarContentLayout)),

    // === Modifier Composition ===
    ("frame-inside-padding", AnyView(scenario_frameInsidePadding)),
    ("padding-inside-frame", AnyView(scenario_paddingInsideFrame)),
    ("nested-alignment-override", AnyView(scenario_nestedAlignmentOverride)),
    ("stacked-frames-with-alignment", AnyView(scenario_stackedFramesWithAlignment)),

    // === Flex Distribution ===
    ("unequal-flex-spacers", AnyView(scenario_unequalFlexSpacers)),
    ("mixed-fixed-flexible-hstack", AnyView(scenario_mixedFixedFlexibleHstack)),

    // === Edge Cases (new) ===
    ("zero-spacing-vstack", AnyView(scenario_zeroSpacingVstack)),
    ("deeply-nested-padding-frame", AnyView(scenario_deeplyNestedPaddingFrame)),
]

// MARK: - Basic Views

var scenario_textSingle: some View {
    Text("Hello")
}

var scenario_textLongWrap: some View {
    Text("This is a longer piece of text that should wrap across multiple lines in the given width")
}

var scenario_colorFill: some View {
    Color.red
}

var scenario_spacerVertical: some View {
    VStack {
        Spacer()
    }
}

// MARK: - VStack Scenarios

var scenario_vstackDefault: some View {
    VStack {
        Text("First")
        Text("Second")
        Text("Third")
    }
}

var scenario_vstackLeading: some View {
    VStack(alignment: .leading) {
        Text("Short")
        Text("A longer text")
        Text("Mid")
    }
}

var scenario_vstackTrailing: some View {
    VStack(alignment: .trailing) {
        Text("Short")
        Text("A longer text")
        Text("Mid")
    }
}

var scenario_vstackSpacing20: some View {
    VStack(spacing: 20) {
        Text("First")
        Text("Second")
        Text("Third")
    }
}

var scenario_vstackWithSpacer: some View {
    VStack {
        Text("Top")
        Spacer()
        Text("Bottom")
    }
}

var scenario_vstackNested: some View {
    VStack(spacing: 10) {
        VStack(spacing: 4) {
            Text("Group 1 - A")
            Text("Group 1 - B")
        }
        VStack(spacing: 4) {
            Text("Group 2 - A")
            Text("Group 2 - B")
        }
    }
}

// MARK: - HStack Scenarios

var scenario_hstackDefault: some View {
    HStack {
        Text("Left")
        Text("Right")
    }
}

var scenario_hstackTop: some View {
    HStack(alignment: .top) {
        Text("Short")
        Text("Tall\nMultiline\nText")
    }
}

var scenario_hstackBottom: some View {
    HStack(alignment: .bottom) {
        Text("Short")
        Text("Tall\nMultiline\nText")
    }
}

var scenario_hstackSpacing20: some View {
    HStack(spacing: 20) {
        Text("Left")
        Text("Right")
    }
}

var scenario_hstackWithSpacer: some View {
    HStack {
        Text("Left")
        Spacer()
        Text("Right")
    }
}

// MARK: - ZStack Scenarios

var scenario_zstackDefault: some View {
    ZStack {
        Color.blue
            .frame(width: 200, height: 200)
        Text("Centered")
    }
}

var scenario_zstackTopLeading: some View {
    ZStack(alignment: .topLeading) {
        Color.blue
            .frame(width: 200, height: 200)
        Text("TopLeading")
    }
}

var scenario_zstackBottomTrailing: some View {
    ZStack(alignment: .bottomTrailing) {
        Color.blue
            .frame(width: 200, height: 200)
        Text("BottomTrailing")
    }
}

// MARK: - Frame Scenarios

var scenario_frameFixed: some View {
    Text("Framed")
        .frame(width: 200, height: 100)
}

var scenario_frameMinMax: some View {
    Text("Constrained")
        .frame(minWidth: 100, maxWidth: 300, minHeight: 50, maxHeight: 150)
}

var scenario_frameMaxWidthInfinity: some View {
    Text("Full Width")
        .frame(maxWidth: .infinity)
}

var scenario_frameAlignmentTopLeading: some View {
    Text("TL")
        .frame(width: 200, height: 200, alignment: .topLeading)
}

var scenario_frameAlignmentBottomTrailing: some View {
    Text("BR")
        .frame(width: 200, height: 200, alignment: .bottomTrailing)
}

var scenario_frameAlignmentCenter: some View {
    Text("C")
        .frame(width: 200, height: 200, alignment: .center)
}

// MARK: - Padding Scenarios

var scenario_paddingDefault: some View {
    Text("Padded")
        .padding()
}

var scenario_paddingCustom: some View {
    Text("Custom Pad")
        .padding(20)
}

var scenario_paddingHorizontal: some View {
    Text("H-Padded")
        .padding(.horizontal, 24)
}

var scenario_paddingNested: some View {
    Text("Double Padded")
        .padding(8)
        .padding(16)
}

// MARK: - Combined Layout Scenarios

var scenario_vstackFramePadding: some View {
    VStack(spacing: 8) {
        Text("Title")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
        Text("Subtitle")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }
    .padding(.vertical, 12)
}

var scenario_hstackInVstack: some View {
    VStack(spacing: 12) {
        HStack {
            Text("Label")
            Spacer()
            Text("Value")
        }
        .padding(.horizontal, 16)
        HStack {
            Text("Another")
            Spacer()
            Text("Data")
        }
        .padding(.horizontal, 16)
    }
}

var scenario_complexNested: some View {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            Color.red
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                Text("Subtitle")
            }
            Spacer()
        }
        .padding(.horizontal, 16)

        Divider()

        HStack(spacing: 12) {
            Color.green
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("Item 2")
                Text("Description")
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

var scenario_spacerBetweenTexts: some View {
    VStack {
        Text("Header")
        Spacer()
        Text("Content")
        Spacer()
        Text("Footer")
    }
}

var scenario_twoColumnHstack: some View {
    HStack(spacing: 0) {
        Color.blue
            .frame(width: 120)
        VStack(alignment: .leading, spacing: 8) {
            Text("Main content")
            Text("Second line")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}

// MARK: - Edge Cases

var scenario_emptyVstack: some View {
    VStack {
        // empty
    }
}

var scenario_singleChildVstack: some View {
    VStack {
        Text("Only child")
    }
}

var scenario_deeplyNestedFrames: some View {
    Text("Deep")
        .frame(width: 100, height: 40)
        .frame(width: 200, height: 100)
        .frame(width: 300, height: 200)
}

// MARK: - App Pattern Scenarios

var scenario_appHeaderContentFooter: some View {
    VStack(spacing: 0) {
        Text("Header")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        Spacer()
        HStack {
            Text("Status")
            Spacer()
            Text("v1.0")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

var scenario_sidebarDetailSplit: some View {
    HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Item 1")
            Text("Item 2")
            Text("Item 3")
            Text("Item 4")
            Text("Item 5")
        }
        .frame(width: 120)
        .padding(.vertical, 8)

        Color.gray
            .frame(width: 1)

        VStack(alignment: .leading) {
            Text("Detail")
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }
}

var scenario_toolbarContentLayout: some View {
    VStack(spacing: 0) {
        HStack {
            Text("Back")
            Spacer()
            Text("Title")
            Spacer()
            Text("Done")
        }
        .padding(8)
        .frame(maxWidth: .infinity)

        Color.gray
            .frame(height: 1)

        Spacer()
    }
}

// MARK: - Modifier Composition Scenarios

var scenario_frameInsidePadding: some View {
    Text("X")
        .frame(width: 100, height: 50)
        .padding(20)
}

var scenario_paddingInsideFrame: some View {
    Text("X")
        .padding(20)
        .frame(width: 200, height: 100)
}

var scenario_nestedAlignmentOverride: some View {
    VStack(alignment: .leading) {
        HStack {
            Text("A")
            Spacer()
        }
        .frame(maxWidth: .infinity)

        Text("B")
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

var scenario_stackedFramesWithAlignment: some View {
    Text("Z")
        .frame(width: 50, height: 30, alignment: .bottomTrailing)
        .frame(width: 150, height: 80, alignment: .topLeading)
}

// MARK: - Flex Distribution Scenarios

var scenario_unequalFlexSpacers: some View {
    VStack {
        Text("Top")
        Spacer()
        Text("Mid")
        Spacer()
        Spacer()
        Text("Bottom")
    }
}

var scenario_mixedFixedFlexibleHstack: some View {
    HStack(spacing: 0) {
        Text("Fixed")
            .frame(width: 80)
        Color.blue
        Spacer()
        Text("End")
            .frame(width: 60)
    }
}

// MARK: - Edge Cases (new)

var scenario_zeroSpacingVstack: some View {
    VStack(spacing: 0) {
        Text("A")
        Text("B")
        Text("C")
    }
}

var scenario_deeplyNestedPaddingFrame: some View {
    Text("X")
        .padding(4)
        .frame(width: 80, height: 40)
        .padding(8)
        .frame(width: 150, height: 80)
        .padding(12)
}
