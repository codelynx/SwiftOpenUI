import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge

final class GTK4RenderTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 {
            _ = gtk_init_check()
        }
    }

    func testFrameViewCentersTextUsingFixedChildPosition() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(Text("Hi").frame(width: 56, height: 56)))
        let child = try unwrapFirstChild(of: wrapper)

        let wrapperSize = measuredSize(of: wrapper)
        allocate(widget: wrapper, size: wrapperSize)
        let childSize = allocatedSize(of: child)
        let childOrigin = translatedChildOrigin(child: child, in: wrapper)

        XCTAssertEqual(wrapperSize.width, 56, accuracy: 0.01)
        XCTAssertEqual(wrapperSize.height, 56, accuracy: 0.01)
        XCTAssertEqual(childOrigin.x, (56 - childSize.width) / 2, accuracy: 0.01)
        XCTAssertEqual(childOrigin.y, (56 - childSize.height) / 2, accuracy: 0.01)
    }

    func testFrameViewExpandsColorToFillFixedFrame() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(Color.red.frame(width: 50, height: 24)))
        let child = try unwrapFirstChild(of: wrapper)

        let wrapperSize = measuredSize(of: wrapper)
        allocate(widget: wrapper, size: wrapperSize)
        let childSize = allocatedSize(of: child)
        let childOrigin = translatedChildOrigin(child: child, in: wrapper)

        XCTAssertEqual(wrapperSize.width, 50, accuracy: 0.01)
        XCTAssertEqual(wrapperSize.height, 24, accuracy: 0.01)
        XCTAssertEqual(childSize.width, 50, accuracy: 0.01)
        XCTAssertEqual(childSize.height, 24, accuracy: 0.01)
        XCTAssertEqual(childOrigin.x, 0, accuracy: 0.01)
        XCTAssertEqual(childOrigin.y, 0, accuracy: 0.01)
    }

    func testFrameViewClampsOversizedChildHeight() throws {
        try requireGTK()

        let childText = Text("Tall")
        let naturalChild = widgetFromOpaque(gtkRenderView(childText))
        let naturalSize = measuredSize(of: naturalChild)
        XCTAssertGreaterThan(naturalSize.height, 8)

        let wrapper = widgetFromOpaque(gtkRenderView(
            childText.frame(minWidth: 60, maxHeight: 8, alignment: .leading)
        ))
        let slot = try unwrapFirstChild(of: wrapper)
        let innerText = try unwrapFirstDescendant(
            ofType: "GtkLabel",
            in: slot
        )

        let wrapperSize = measuredSize(of: wrapper)
        allocate(widget: wrapper, size: wrapperSize)
        let slotSize = allocatedSize(of: slot)
        let innerTextSize = allocatedSize(of: innerText)
        let slotOrigin = translatedChildOrigin(child: slot, in: wrapper)

        XCTAssertEqual(wrapperSize.width, 60, accuracy: 0.01)
        XCTAssertEqual(wrapperSize.height, 8, accuracy: 0.01)
        XCTAssertEqual(slotSize.height, 8, accuracy: 0.01)
        XCTAssertGreaterThan(innerTextSize.height, 8)
        XCTAssertEqual(slotOrigin.x, 0, accuracy: 0.01)
        XCTAssertEqual(slotOrigin.y, 0, accuracy: 0.01)
        XCTAssertEqual(gtk_widget_get_overflow(wrapper), GTK_OVERFLOW_HIDDEN)
    }

    func testVStackSharedLayoutAppliesTrailingAlignmentAndSpacing() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            VStack(alignment: .trailing, spacing: 4) {
                Text("WWWWWW")
                Text("I")
            }
        ))
        let first = try unwrapFirstChild(of: wrapper)
        let second = try unwrapNextSibling(of: first)

        let wrapperSize = measuredSize(of: wrapper)
        allocate(widget: wrapper, size: wrapperSize)

        let firstSize = allocatedSize(of: first)
        let secondSize = allocatedSize(of: second)
        let firstOrigin = translatedChildOrigin(child: first, in: wrapper)
        let secondOrigin = translatedChildOrigin(child: second, in: wrapper)

        XCTAssertEqual(firstOrigin.x, 0, accuracy: 0.01)
        XCTAssertEqual(firstOrigin.y, 0, accuracy: 0.01)
        XCTAssertEqual(secondOrigin.x, wrapperSize.width - secondSize.width, accuracy: 0.01)
        XCTAssertEqual(secondOrigin.y, firstSize.height + 4, accuracy: 0.01)
    }

    func testHStackSharedLayoutAppliesBottomAlignmentAndSpacing() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            HStack(alignment: .bottom, spacing: 6) {
                Text("Tall")
                Text("I")
            }
        ))
        let first = try unwrapFirstChild(of: wrapper)
        let second = try unwrapNextSibling(of: first)

        let wrapperSize = measuredSize(of: wrapper)
        allocate(widget: wrapper, size: wrapperSize)

        let firstSize = allocatedSize(of: first)
        let secondSize = allocatedSize(of: second)
        let firstOrigin = translatedChildOrigin(child: first, in: wrapper)
        let secondOrigin = translatedChildOrigin(child: second, in: wrapper)

        XCTAssertEqual(firstOrigin.x, 0, accuracy: 0.01)
        XCTAssertEqual(firstOrigin.y, 0, accuracy: 0.01)
        XCTAssertEqual(secondOrigin.x, firstSize.width + 6, accuracy: 0.01)
        XCTAssertEqual(secondOrigin.y, wrapperSize.height - secondSize.height, accuracy: 0.01)
    }

    func testZStackSharedLayoutAppliesBottomTrailingAlignment() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            ZStack(alignment: .bottomTrailing) {
                Text("WWWWWW")
                Text("I")
            }
        ))
        let first = try unwrapFirstChild(of: wrapper)
        let second = try unwrapNextSibling(of: first)

        let wrapperSize = measuredSize(of: wrapper)
        allocate(widget: wrapper, size: wrapperSize)

        let firstOrigin = translatedChildOrigin(child: first, in: wrapper)
        let secondSize = allocatedSize(of: second)
        let secondOrigin = translatedChildOrigin(child: second, in: wrapper)

        XCTAssertEqual(firstOrigin.x, 0, accuracy: 0.01)
        XCTAssertEqual(firstOrigin.y, 0, accuracy: 0.01)
        XCTAssertEqual(secondOrigin.x, wrapperSize.width - secondSize.width, accuracy: 0.01)
        XCTAssertEqual(secondOrigin.y, wrapperSize.height - secondSize.height, accuracy: 0.01)
    }

    func testZStackFallbackAppliesBottomTrailingAlignment() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            ZStack(alignment: .bottomTrailing) {
                Text("WWWWWW")
                Color.red
                Text("I")
            }
        ))
        let base = try unwrapFirstChild(of: wrapper)
        let colorOverlay = try unwrapNextSibling(of: base)
        let trailingOverlay = try unwrapNextSibling(of: colorOverlay)

        let wrapperSize = measuredSize(of: wrapper)
        allocate(widget: wrapper, size: wrapperSize)

        let baseOrigin = translatedChildOrigin(child: base, in: wrapper)
        let trailingSize = allocatedSize(of: trailingOverlay)
        let trailingOrigin = translatedChildOrigin(child: trailingOverlay, in: wrapper)

        XCTAssertEqual(gtkWidgetTypeName(wrapper), "GtkOverlay")
        XCTAssertEqual(baseOrigin.x, 0, accuracy: 0.01)
        XCTAssertEqual(baseOrigin.y, 0, accuracy: 0.01)
        XCTAssertEqual(trailingOrigin.x, wrapperSize.width - trailingSize.width, accuracy: 0.01)
        XCTAssertEqual(trailingOrigin.y, wrapperSize.height - trailingSize.height, accuracy: 0.01)
    }

    func testGridSharedLayoutWrapsRowsUsingSharedPlacements() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            Grid(columns: 2, spacing: 5) {
                Text("WWWWWW")
                Text("I")
                Text("I")
            }
        ))
        let first = try unwrapFirstChild(of: wrapper)
        let second = try unwrapNextSibling(of: first)
        let third = try unwrapNextSibling(of: second)

        let wrapperSize = measuredSize(of: wrapper)
        allocate(widget: wrapper, size: wrapperSize)

        let firstSize = allocatedSize(of: first)
        let secondSize = allocatedSize(of: second)
        let firstOrigin = translatedChildOrigin(child: first, in: wrapper)
        let secondOrigin = translatedChildOrigin(child: second, in: wrapper)
        let thirdOrigin = translatedChildOrigin(child: third, in: wrapper)

        XCTAssertEqual(gtkWidgetTypeName(wrapper), "GtkFixed")
        XCTAssertEqual(firstOrigin.x, 0, accuracy: 0.01)
        XCTAssertEqual(firstOrigin.y, 0, accuracy: 0.01)
        XCTAssertEqual(secondOrigin.x, firstSize.width + 5, accuracy: 0.01)
        XCTAssertEqual(secondOrigin.y, 0, accuracy: 0.01)
        XCTAssertEqual(thirdOrigin.x, 0, accuracy: 0.01)
        XCTAssertEqual(thirdOrigin.y, max(firstSize.height, secondSize.height) + 5, accuracy: 0.01)
    }

    func testExplicitGridSharedLayoutAppliesHomogeneousSpanPlacements() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            Grid(horizontalSpacing: 4, verticalSpacing: 5) {
                GridRow {
                    Text("WWWWWW").gridCellColumns(2)
                    Text("I")
                }
                GridRow {
                    Text("I")
                    Text("I")
                    Text("I")
                }
            }
        ))
        let first = try unwrapFirstChild(of: wrapper)
        let second = try unwrapNextSibling(of: first)
        let third = try unwrapNextSibling(of: second)
        let fourth = try unwrapNextSibling(of: third)
        let fifth = try unwrapNextSibling(of: fourth)

        let wrapperSize = measuredSize(of: wrapper)
        allocate(widget: wrapper, size: wrapperSize)

        let firstSize = allocatedSize(of: first)
        let thirdSize = allocatedSize(of: third)
        let firstOrigin = translatedChildOrigin(child: first, in: wrapper)
        let secondOrigin = translatedChildOrigin(child: second, in: wrapper)
        let thirdOrigin = translatedChildOrigin(child: third, in: wrapper)
        let fourthOrigin = translatedChildOrigin(child: fourth, in: wrapper)
        let fifthOrigin = translatedChildOrigin(child: fifth, in: wrapper)

        XCTAssertEqual(gtkWidgetTypeName(wrapper), "GtkFixed")
        XCTAssertEqual(firstOrigin.x, 0, accuracy: 0.01)
        XCTAssertEqual(firstOrigin.y, 0, accuracy: 0.01)
        XCTAssertEqual(secondOrigin.y, 0, accuracy: 0.01)
        XCTAssertEqual(thirdOrigin.x, 0, accuracy: 0.01)
        XCTAssertEqual(fourthOrigin.x, thirdSize.width + 4, accuracy: 0.01)
        XCTAssertEqual(secondOrigin.x, fifthOrigin.x, accuracy: 0.01)
        XCTAssertEqual(firstSize.width, fifthOrigin.x - 4, accuracy: 0.01)
        XCTAssertEqual(thirdOrigin.y, max(firstSize.height, allocatedSize(of: second).height) + 5, accuracy: 0.01)
    }

    // MARK: - Descriptor mutation hooks

    func testTextMutationHookChangesLabelContent() throws {
        try requireGTK()

        // Render initial text and capture slot
        let label = widgetFromOpaque(gtkRenderView(Text("Old")))
        XCTAssertEqual(gtkHostedNodeKind(of: label), .text)

        let slotID = gtkNativeSlotID(for: label)

        // Mutate via hook helper
        let success = gtkSetTextContent(slotID: slotID, text: "New")
        XCTAssertTrue(success)

        // Verify the label text changed
        let cStr = gtk_label_get_text(OpaquePointer(label))!
        XCTAssertEqual(String(cString: cStr), "New")
    }

    func testColorMutationHookChangesBackground() throws {
        try requireGTK()

        // Render initial color and capture slot
        let box = widgetFromOpaque(gtkRenderView(Color.red))
        XCTAssertEqual(gtkHostedNodeKind(of: box), .color)

        let slotID = gtkNativeSlotID(for: box)

        // Mutate via hook helper
        let newColor = GTK4ColorDescriptor(red: 0, green: 1, blue: 0, opacity: 1)
        let success = gtkSetColorFill(slotID: slotID, color: newColor)
        XCTAssertTrue(success)

        // Verify the CSS provider was installed (widget should have the class)
        let className = "gtk-swift-color-\(slotID)"
        XCTAssertTrue(gtk_widget_has_css_class(box, className) != 0)
    }

    func testTextMutationFailsWithInvalidSlot() throws {
        try requireGTK()
        let success = gtkSetTextContent(slotID: 0, text: "Nope")
        XCTAssertFalse(success)
    }

    // MARK: - Host-level mutation path tests

    func testHostTextMutationSkipsRebuild() throws {
        try requireGTK()

        // Create a ViewHost with a describable text body
        var textContent = "Old"
        let host = GTKViewHost(buildBody: {
            gtkRenderView(Text(textContent))
        })
        host.describeBody = {
            gtkDescribeView(Text(textContent))
        }

        // Initial build
        let previousHost = GTKViewHost.getCurrentRebuilding()
        GTKViewHost.setCurrentRebuilding(host)
        let widget = host.buildBodyWithTracking()
        GTKViewHost.setCurrentRebuilding(previousHost)

        let child = widgetFromOpaque(widget)
        gtk_box_append(boxPointer(host.container), child)

        // Capture initial descriptor state (simulating what rebuild does after full build)
        let descriptor = gtkDescribeView(Text(textContent))
        let identified = gtkIdentifyDescriptorTree(descriptor)
        host.lastRetainedDescriptor = gtkRetainDescriptorTree(identified)
        var executor = gtkMakeExecutorTree(from: identified)
        executor = gtkCaptureSupportedNativeSlots(from: child, descriptorRoot: identified, executorRoot: executor)
        host.retainedExecutor = executor

        // Capture the label widget pointer
        let label = gtk_widget_get_first_child(host.container)!
        let labelBefore = UnsafeRawPointer(label)

        // Change state and rebuild
        textContent = "New"
        host.rebuild()

        // Verify: same widget (no destroy/recreate), updated content
        let labelAfter = gtk_widget_get_first_child(host.container)!
        XCTAssertEqual(UnsafeRawPointer(labelAfter), labelBefore, "Widget should be same (in-place mutation)")
        let cStr = gtk_label_get_text(OpaquePointer(labelAfter))!
        XCTAssertEqual(String(cString: cStr), "New")
    }

    func testHostColorMutationSkipsRebuild() throws {
        try requireGTK()

        var currentColor = Color.red
        let host = GTKViewHost(buildBody: {
            gtkRenderView(currentColor)
        })
        host.describeBody = {
            gtkDescribeView(currentColor)
        }

        let previousHost = GTKViewHost.getCurrentRebuilding()
        GTKViewHost.setCurrentRebuilding(host)
        let widget = host.buildBodyWithTracking()
        GTKViewHost.setCurrentRebuilding(previousHost)

        let child = widgetFromOpaque(widget)
        gtk_box_append(boxPointer(host.container), child)

        let descriptor = gtkDescribeView(currentColor)
        let identified = gtkIdentifyDescriptorTree(descriptor)
        host.lastRetainedDescriptor = gtkRetainDescriptorTree(identified)
        var executor = gtkMakeExecutorTree(from: identified)
        executor = gtkCaptureSupportedNativeSlots(from: child, descriptorRoot: identified, executorRoot: executor)
        host.retainedExecutor = executor

        let boxBefore = UnsafeRawPointer(gtk_widget_get_first_child(host.container)!)

        currentColor = Color.green
        host.rebuild()

        let boxAfter = gtk_widget_get_first_child(host.container)!
        XCTAssertEqual(UnsafeRawPointer(boxAfter), boxBefore, "Widget should be same (in-place color mutation)")
    }

    func testHostStructuralChangeTriggersFullRebuild() throws {
        try requireGTK()

        // Create a ViewHost that can switch between Text and Color
        var showText = true
        let host = GTKViewHost(buildBody: {
            if showText {
                return gtkRenderView(Text("Hello"))
            } else {
                return gtkRenderView(Color.red)
            }
        })
        host.describeBody = {
            if showText {
                return gtkDescribeView(Text("Hello"))
            } else {
                return gtkDescribeView(Color.red)
            }
        }

        // Initial build
        let previousHost = GTKViewHost.getCurrentRebuilding()
        GTKViewHost.setCurrentRebuilding(host)
        let widget = host.buildBodyWithTracking()
        GTKViewHost.setCurrentRebuilding(previousHost)

        let child = widgetFromOpaque(widget)
        gtk_box_append(boxPointer(host.container), child)

        // Capture descriptor state
        let descriptor = gtkDescribeView(Text("Hello"))
        let identified = gtkIdentifyDescriptorTree(descriptor)
        host.lastRetainedDescriptor = gtkRetainDescriptorTree(identified)
        var executor = gtkMakeExecutorTree(from: identified)
        executor = gtkCaptureSupportedNativeSlots(from: child, descriptorRoot: identified, executorRoot: executor)
        host.retainedExecutor = executor

        let labelBefore = UnsafeRawPointer(gtk_widget_get_first_child(host.container)!)

        // Structural change: Text → Color
        showText = false
        host.rebuild()

        // Verify: different widget (full rebuild happened)
        let childAfter = gtk_widget_get_first_child(host.container)!
        XCTAssertNotEqual(UnsafeRawPointer(childAfter), labelBefore, "Widget should be different (full rebuild)")
    }

    func testFullPipelineColorMutation() throws {
        try requireGTK()

        // Render and describe old state
        let box = widgetFromOpaque(gtkRenderView(Color.red))
        let slotID = gtkNativeSlotID(for: box)
        let className = "gtk-swift-color-\(slotID)"

        let oldDesc = gtkDescribeView(Color.red)
        let newDesc = gtkDescribeView(Color.green)
        let oldId = gtkIdentifyDescriptorTree(oldDesc)
        let newId = gtkIdentifyDescriptorTree(newDesc)
        let retained = gtkRetainDescriptorTree(oldId)
        let executor = gtkMakeExecutorTree(from: oldId, nativeSlotID: slotID)

        // Plan
        let plan = gtkPlanDescriptorTree(old: retained, new: newId)
        XCTAssertTrue(gtkCanApplyTextColorHostMutation(plan: plan))
        XCTAssertEqual(plan.updateIntent, .colorFill)

        // Execute + mutate (first mutation — creates provider)
        let action = gtkExecuteDescriptorPlan(old: executor, plan: plan)
        let result = gtkApplyHookMutation(action: action)
        XCTAssertTrue(gtkHookMutationSucceeded(result))
        XCTAssertTrue(gtk_widget_has_css_class(box, className) != 0)

        // Second mutation on same widget — reuses provider (replace-in-place)
        let blueDesc = gtkDescribeView(Color.blue)
        let blueId = gtkIdentifyDescriptorTree(blueDesc)
        let retained2 = gtkRetainDescriptorTree(newId)
        let executor2 = action.resultingNode
        let plan2 = gtkPlanDescriptorTree(old: retained2, new: blueId)
        let action2 = gtkExecuteDescriptorPlan(old: executor2, plan: plan2)
        let result2 = gtkApplyHookMutation(action: action2)
        XCTAssertTrue(gtkHookMutationSucceeded(result2))

        // Same widget, same class — provider was reused, not stacked
        XCTAssertTrue(gtk_widget_has_css_class(box, className) != 0)
    }

    func testFullPipelineTextMutation() throws {
        try requireGTK()

        // Render and describe old state
        let label = widgetFromOpaque(gtkRenderView(Text("Old")))
        let slotID = gtkNativeSlotID(for: label)

        let oldDesc = gtkDescribeView(Text("Old"))
        let newDesc = gtkDescribeView(Text("New"))
        let oldId = gtkIdentifyDescriptorTree(oldDesc)
        let newId = gtkIdentifyDescriptorTree(newDesc)
        let retained = gtkRetainDescriptorTree(oldId)
        let executor = gtkMakeExecutorTree(from: oldId, nativeSlotID: slotID)

        // Plan
        let plan = gtkPlanDescriptorTree(old: retained, new: newId)
        XCTAssertTrue(gtkCanApplyTextColorHostMutation(plan: plan))

        // Execute + mutate
        let action = gtkExecuteDescriptorPlan(old: executor, plan: plan)
        let result = gtkApplyHookMutation(action: action)
        XCTAssertTrue(gtkHookMutationSucceeded(result))

        // Verify label changed
        let cStr = gtk_label_get_text(OpaquePointer(label))!
        XCTAssertEqual(String(cString: cStr), "New")
    }

    // MARK: - Safe Area Tests

    func testIgnoresSafeAreaPassthroughRendersContent() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Hello").ignoresSafeArea()
        ))
        // Passthrough — the result should contain a label with the text
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Hello")
    }

    func testSafeAreaInsetTopCreatesVerticalBox() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Main").safeAreaInset(edge: VerticalEdge.top) {
                Text("Header")
            }
        ))
        // Should be a GtkBox with vertical orientation
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkBox")

        // First child is the inset (top = inset first), second is content
        let first = try unwrapFirstChild(of: widget)
        let second = try unwrapNextSibling(of: first)

        let firstLabel = try unwrapFirstDescendant(ofType: "GtkLabel", in: first)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(firstLabel))), "Header")

        let secondLabel = try unwrapFirstDescendant(ofType: "GtkLabel", in: second)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(secondLabel))), "Main")
    }

    func testSafeAreaInsetBottomCreatesVerticalBox() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Main").safeAreaInset(edge: VerticalEdge.bottom) {
                Text("Footer")
            }
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkBox")

        // Bottom: content first, then inset
        let first = try unwrapFirstChild(of: widget)
        let second = try unwrapNextSibling(of: first)

        let firstLabel = try unwrapFirstDescendant(ofType: "GtkLabel", in: first)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(firstLabel))), "Main")

        let secondLabel = try unwrapFirstDescendant(ofType: "GtkLabel", in: second)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(secondLabel))), "Footer")
    }

    func testSafeAreaInsetTrailingCreatesHorizontalBox() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Main").safeAreaInset(edge: HorizontalEdge.trailing) {
                Text("Side")
            }
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkBox")

        // Trailing: content first, then inset
        let first = try unwrapFirstChild(of: widget)
        let second = try unwrapNextSibling(of: first)

        let firstLabel = try unwrapFirstDescendant(ofType: "GtkLabel", in: first)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(firstLabel))), "Main")

        let secondLabel = try unwrapFirstDescendant(ofType: "GtkLabel", in: second)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(secondLabel))), "Side")
    }

    func testSafeAreaInsetTopDescriptorOrderMatchesWidgetOrder() throws {
        try requireGTK()

        // Build a view with safeAreaInset(edge: .top) wrapping a Text
        var textContent = "Old"
        let host = GTKViewHost(buildBody: {
            gtkRenderView(Text(textContent).safeAreaInset(edge: VerticalEdge.top) {
                Text("Header")
            })
        })
        host.describeBody = {
            gtkDescribeView(Text(textContent).safeAreaInset(edge: VerticalEdge.top) {
                Text("Header")
            })
        }

        // Initial build
        let previousHost = GTKViewHost.getCurrentRebuilding()
        GTKViewHost.setCurrentRebuilding(host)
        let widget = host.buildBodyWithTracking()
        GTKViewHost.setCurrentRebuilding(previousHost)

        let child = widgetFromOpaque(widget)
        gtk_box_append(boxPointer(host.container), child)

        // Capture descriptor state
        let descriptor = gtkDescribeView(Text(textContent).safeAreaInset(edge: VerticalEdge.top) {
            Text("Header")
        })
        let identified = gtkIdentifyDescriptorTree(descriptor)
        host.lastRetainedDescriptor = gtkRetainDescriptorTree(identified)
        var executor = gtkMakeExecutorTree(from: identified)
        executor = gtkCaptureSupportedNativeSlots(from: child, descriptorRoot: identified, executorRoot: executor)
        host.retainedExecutor = executor

        // The box has two children: [Header(inset), Old(content)]
        // Find the content label (second child for .top inset)
        let insetLabel = gtk_widget_get_first_child(child)!
        let contentLabel = gtk_widget_get_next_sibling(insetLabel)!
        let contentBefore = UnsafeRawPointer(contentLabel)

        // Change state and rebuild
        textContent = "New"
        host.rebuild()

        // Verify in-place mutation: same widget pointer, updated text
        let insetLabelAfter = gtk_widget_get_first_child(gtk_widget_get_first_child(host.container)!)!
        let contentLabelAfter = gtk_widget_get_next_sibling(insetLabelAfter)!
        XCTAssertEqual(UnsafeRawPointer(contentLabelAfter), contentBefore,
                       "Content widget should be same (in-place mutation, not teardown/rebuild)")
        let cStr = gtk_label_get_text(OpaquePointer(contentLabelAfter))!
        XCTAssertEqual(String(cString: cStr), "New")
    }

    func testSafeAreaInsetLeadingDescriptorOrderMatchesWidgetOrder() throws {
        try requireGTK()

        var textContent = "Old"
        let host = GTKViewHost(buildBody: {
            gtkRenderView(Text(textContent).safeAreaInset(edge: HorizontalEdge.leading) {
                Text("Side")
            })
        })
        host.describeBody = {
            gtkDescribeView(Text(textContent).safeAreaInset(edge: HorizontalEdge.leading) {
                Text("Side")
            })
        }

        let previousHost = GTKViewHost.getCurrentRebuilding()
        GTKViewHost.setCurrentRebuilding(host)
        let widget = host.buildBodyWithTracking()
        GTKViewHost.setCurrentRebuilding(previousHost)

        let child = widgetFromOpaque(widget)
        gtk_box_append(boxPointer(host.container), child)

        let descriptor = gtkDescribeView(Text(textContent).safeAreaInset(edge: HorizontalEdge.leading) {
            Text("Side")
        })
        let identified = gtkIdentifyDescriptorTree(descriptor)
        host.lastRetainedDescriptor = gtkRetainDescriptorTree(identified)
        var executor = gtkMakeExecutorTree(from: identified)
        executor = gtkCaptureSupportedNativeSlots(from: child, descriptorRoot: identified, executorRoot: executor)
        host.retainedExecutor = executor

        // Leading: [inset, content] — content is the second child
        let insetLabel = gtk_widget_get_first_child(child)!
        let contentLabel = gtk_widget_get_next_sibling(insetLabel)!
        let contentBefore = UnsafeRawPointer(contentLabel)

        textContent = "New"
        host.rebuild()

        let insetLabelAfter = gtk_widget_get_first_child(gtk_widget_get_first_child(host.container)!)!
        let contentLabelAfter = gtk_widget_get_next_sibling(insetLabelAfter)!
        XCTAssertEqual(UnsafeRawPointer(contentLabelAfter), contentBefore,
                       "Content widget should be same (in-place mutation, not teardown/rebuild)")
        let cStr = gtk_label_get_text(OpaquePointer(contentLabelAfter))!
        XCTAssertEqual(String(cString: cStr), "New")
    }

    func testSafeAreaInsetWithSpacing() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Main").safeAreaInset(edge: VerticalEdge.top, spacing: 12) {
                Text("Header")
            }
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkBox")

        // Verify the box has spacing=12
        let boxSpacing = gtk_box_get_spacing(boxPointer(widget))
        XCTAssertEqual(boxSpacing, 12)
    }
}

private func requireGTK(
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    guard gtk_is_initialized() != 0 else {
        throw XCTSkip("GTK could not initialize in this environment.", file: file, line: line)
    }
}

private func unwrapFirstChild(
    of widget: UnsafeMutablePointer<GtkWidget>,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> UnsafeMutablePointer<GtkWidget> {
    guard let child = gtk_widget_get_first_child(widget) else {
        XCTFail("Expected widget to have a child.", file: file, line: line)
        throw XCTSkip()
    }
    return child
}

private func unwrapFirstDescendant(
    ofType typeName: String,
    in widget: UnsafeMutablePointer<GtkWidget>,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> UnsafeMutablePointer<GtkWidget> {
    if gtkWidgetTypeName(widget) == typeName {
        return widget
    }

    var child = gtk_widget_get_first_child(widget)
    while let current = child {
        if let found = try? unwrapFirstDescendant(ofType: typeName, in: current, file: file, line: line) {
            return found
        }
        child = gtk_widget_get_next_sibling(current)
    }

    XCTFail("Expected widget tree to contain \(typeName).", file: file, line: line)
    throw XCTSkip()
}

private func unwrapNextSibling(
    of widget: UnsafeMutablePointer<GtkWidget>,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> UnsafeMutablePointer<GtkWidget> {
    guard let sibling = gtk_widget_get_next_sibling(widget) else {
        XCTFail("Expected widget to have a next sibling.", file: file, line: line)
        throw XCTSkip()
    }
    return sibling
}

private func measuredSize(of widget: UnsafeMutablePointer<GtkWidget>) -> ViewSize {
    var widthMin: Int32 = 0
    var widthNat: Int32 = 0
    var heightMin: Int32 = 0
    var heightNat: Int32 = 0
    gtk_swift_widget_measure(widget, GTK_ORIENTATION_HORIZONTAL, -1, &widthMin, &widthNat)
    gtk_swift_widget_measure(widget, GTK_ORIENTATION_VERTICAL, -1, &heightMin, &heightNat)
    return ViewSize(
        width: Double(max(widthMin, widthNat)),
        height: Double(max(heightMin, heightNat))
    )
}

private func allocate(widget: UnsafeMutablePointer<GtkWidget>, size: ViewSize) {
    gtk_widget_allocate(widget, Int32(size.width), Int32(size.height), -1, nil)
}

private func allocatedSize(of widget: UnsafeMutablePointer<GtkWidget>) -> ViewSize {
    ViewSize(
        width: Double(gtk_widget_get_width(widget)),
        height: Double(gtk_widget_get_height(widget))
    )
}

private func translatedChildOrigin(
    child: UnsafeMutablePointer<GtkWidget>,
    in wrapper: UnsafeMutablePointer<GtkWidget>
) -> ViewPoint {
    var sourcePoint = graphene_point_t()
    graphene_point_init(&sourcePoint, 0, 0)
    var translatedPoint = graphene_point_t()
    _ = gtk_widget_compute_point(child, wrapper, &sourcePoint, &translatedPoint)
    return ViewPoint(x: Double(translatedPoint.x), y: Double(translatedPoint.y))
}

private func gtkWidgetTypeName(_ widget: UnsafeMutablePointer<GtkWidget>) -> String {
    String(cString: g_type_name(gtk_swift_get_widget_type(widget)))
}
