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

    // MARK: - Searchable Tests

    func testSearchableRendersSearchEntryAboveContent() throws {
        try requireGTK()

        var searchText = ""
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Content").searchable(text: Binding(get: { searchText }, set: { searchText = $0 }))
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkBox")

        // First child should be a search entry, second should be content
        let first = try unwrapFirstChild(of: widget)
        XCTAssertEqual(gtkWidgetTypeName(first), "GtkSearchEntry")

        let second = try unwrapNextSibling(of: first)
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: second)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Content")
    }

    func testSearchableWithPlacementRendersWithoutCrash() throws {
        try requireGTK()

        var searchText = ""
        // Non-default placement should still render (advisory in Batch A)
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Content").searchable(
                text: Binding(get: { searchText }, set: { searchText = $0 }),
                placement: .toolbar
            )
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkBox")

        let first = try unwrapFirstChild(of: widget)
        XCTAssertEqual(gtkWidgetTypeName(first), "GtkSearchEntry")
    }

    func testSearchableIsPresentedFalseHidesEntry() throws {
        try requireGTK()

        var searchText = ""
        var presented = false
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Content").searchable(
                text: Binding(get: { searchText }, set: { searchText = $0 }),
                isPresented: Binding(get: { presented }, set: { presented = $0 })
            )
        ))

        let entry = try unwrapFirstChild(of: widget)
        XCTAssertEqual(gtkWidgetTypeName(entry), "GtkSearchEntry")
        XCTAssertEqual(gtk_widget_get_visible(entry), 0, "Entry should be hidden when isPresented is false")
    }

    func testSearchableIsPresentedTrueShowsEntry() throws {
        try requireGTK()

        var searchText = ""
        var presented = true
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Content").searchable(
                text: Binding(get: { searchText }, set: { searchText = $0 }),
                isPresented: Binding(get: { presented }, set: { presented = $0 })
            )
        ))

        let entry = try unwrapFirstChild(of: widget)
        XCTAssertEqual(gtkWidgetTypeName(entry), "GtkSearchEntry")
        // Default visibility is true (GTK shows widgets by default)
        XCTAssertNotEqual(gtk_widget_get_visible(entry), 0, "Entry should be visible when isPresented is true")
    }

    func testSearchableExternalTextChangeTriggersDescriptorUpdate() throws {
        try requireGTK()

        var searchText = "old"
        let binding = Binding(get: { searchText }, set: { searchText = $0 })

        let host = GTKViewHost(buildBody: {
            gtkRenderView(Text("Content").searchable(text: binding))
        })
        host.describeBody = {
            gtkDescribeView(Text("Content").searchable(text: binding))
        }

        let previousHost = GTKViewHost.getCurrentRebuilding()
        GTKViewHost.setCurrentRebuilding(host)
        let widget = host.buildBodyWithTracking()
        GTKViewHost.setCurrentRebuilding(previousHost)

        let child = widgetFromOpaque(widget)
        gtk_box_append(boxPointer(host.container), child)

        let descriptor = gtkDescribeView(Text("Content").searchable(text: binding))
        let identified = gtkIdentifyDescriptorTree(descriptor)
        host.lastRetainedDescriptor = gtkRetainDescriptorTree(identified)
        var executor = gtkMakeExecutorTree(from: identified)
        executor = gtkCaptureSupportedNativeSlots(from: child, descriptorRoot: identified, executorRoot: executor)
        host.retainedExecutor = executor

        // Verify initial text descriptor includes "old"
        let oldDesc = gtkDescribeView(Text("Content").searchable(text: binding))

        // Change external text
        searchText = "new"
        let newDesc = gtkDescribeView(Text("Content").searchable(text: binding))

        // Descriptors should differ because text changed
        XCTAssertNotEqual(oldDesc, newDesc,
                          "Descriptor should change when bound text changes")

        // Verify the plan detects an update, not a reuse
        let oldId = gtkIdentifyDescriptorTree(oldDesc)
        let newId = gtkIdentifyDescriptorTree(newDesc)
        let retained = gtkRetainDescriptorTree(oldId)
        let plan = gtkPlanDescriptorTree(old: retained, new: newId)
        XCTAssertNotEqual(plan.kind, .reuse,
                          "Plan should not be .reuse when text changes")
    }

    // MARK: - Searchable Token Tests

    func testSearchableWithTokensRendersTokenRow() throws {
        try requireGTK()

        struct Tag: Identifiable { let id: String; let name: String }
        var searchText = ""
        var tags = [Tag(id: "a", name: "Alpha"), Tag(id: "b", name: "Beta")]
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Content").searchable(
                text: Binding(get: { searchText }, set: { searchText = $0 }),
                tokens: Binding(get: { tags }, set: { tags = $0 })
            ) { tag in
                Text(tag.name)
            }
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkBox")

        // First child: search entry, second: token row, third: content
        let entry = try unwrapFirstChild(of: widget)
        XCTAssertEqual(gtkWidgetTypeName(entry), "GtkSearchEntry")
        let tokenRow = try unwrapNextSibling(of: entry)
        XCTAssertEqual(gtkWidgetTypeName(tokenRow), "GtkBox")
        // Token row should have 2 labels
        let firstLabel = try unwrapFirstChild(of: tokenRow)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(firstLabel))), "Alpha")
        let secondLabel = try unwrapNextSibling(of: firstLabel)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(secondLabel))), "Beta")
    }

    func testSearchableWithEmptyTokensOmitsTokenRow() throws {
        try requireGTK()

        var searchText = ""
        struct Tag: Identifiable { let id: String; let name: String }
        var tags: [Tag] = []
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Content").searchable(
                text: Binding(get: { searchText }, set: { searchText = $0 }),
                tokens: Binding(get: { tags }, set: { tags = $0 })
            ) { tag in
                Text(tag.name)
            }
        ))

        // With no tokens: search entry then content directly, no token row
        let entry = try unwrapFirstChild(of: widget)
        XCTAssertEqual(gtkWidgetTypeName(entry), "GtkSearchEntry")
        let content = try unwrapNextSibling(of: entry)
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: content)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Content")
    }

    func testSearchableTokenDescriptorDetectsTokenChange() throws {
        try requireGTK()

        struct Tag: Identifiable { let id: String; let name: String }
        var searchText = ""
        var tags = [Tag(id: "a", name: "Alpha")]
        let binding = Binding(get: { searchText }, set: { searchText = $0 })
        let tagsBinding = Binding(get: { tags }, set: { tags = $0 })

        let oldDesc = gtkDescribeView(
            Text("X").searchable(text: binding, tokens: tagsBinding) { t in Text(t.name) }
        )

        tags = [Tag(id: "a", name: "Alpha"), Tag(id: "b", name: "Beta")]
        let newDesc = gtkDescribeView(
            Text("X").searchable(text: binding, tokens: tagsBinding) { t in Text(t.name) }
        )

        XCTAssertNotEqual(oldDesc, newDesc, "Descriptor should differ when tokens change")
    }

    // MARK: - Search Suggestion Tests

    func testSearchSuggestionsRenderButtonRows() throws {
        try requireGTK()

        var searchText = ""
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Content")
                .searchable(text: Binding(get: { searchText }, set: { searchText = $0 }))
                .searchSuggestions {
                    Text("Apple")
                    Text("Banana")
                }
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkBox")

        // Layout: entry, suggestion box, content
        let entry = try unwrapFirstChild(of: widget)
        XCTAssertEqual(gtkWidgetTypeName(entry), "GtkSearchEntry")
        let suggestionBox = try unwrapNextSibling(of: entry)
        XCTAssertEqual(gtkWidgetTypeName(suggestionBox), "GtkBox")
        // Suggestion box has 2 buttons
        let firstBtn = try unwrapFirstChild(of: suggestionBox)
        XCTAssertEqual(gtkWidgetTypeName(firstBtn), "GtkButton")
        let secondBtn = try unwrapNextSibling(of: firstBtn)
        XCTAssertEqual(gtkWidgetTypeName(secondBtn), "GtkButton")
    }

    func testSearchSuggestionsEmptyOmitsBox() throws {
        try requireGTK()

        var searchText = ""
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Content")
                .searchable(text: Binding(get: { searchText }, set: { searchText = $0 }))
                .searchSuggestions { }
        ))
        // With no suggestions: entry then content, no suggestion box
        let entry = try unwrapFirstChild(of: widget)
        XCTAssertEqual(gtkWidgetTypeName(entry), "GtkSearchEntry")
        let content = try unwrapNextSibling(of: entry)
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: content)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Content")
    }

    func testSearchSuggestionDescriptorDetectsChange() throws {
        try requireGTK()

        var searchText = ""
        let binding = Binding(get: { searchText }, set: { searchText = $0 })

        let oldDesc = gtkDescribeView(
            Text("X")
                .searchable(text: binding)
                .searchSuggestions { Text("A") }
        )
        let newDesc = gtkDescribeView(
            Text("X")
                .searchable(text: binding)
                .searchSuggestions { Text("A"); Text("B") }
        )

        XCTAssertNotEqual(oldDesc, newDesc, "Descriptor should differ when suggestions change")
    }

    func testSearchSuggestionsForRendersFilteredRows() throws {
        try requireGTK()

        var searchText = "an"
        let allSuggestions = [
            SearchSuggestionValue(id: "1", label: "Apple", completion: "Apple"),
            SearchSuggestionValue(id: "2", label: "Banana", completion: "Banana"),
            SearchSuggestionValue(id: "3", label: "Orange", completion: "Orange"),
        ]
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Content")
                .searchable(text: Binding(get: { searchText }, set: { searchText = $0 }))
                .searchSuggestions(allSuggestions, for: searchText)
        ))

        // Core filters case-insensitively with .contains — "an" matches "Banana" and "Orange"
        let entry = try unwrapFirstChild(of: widget)
        XCTAssertEqual(gtkWidgetTypeName(entry), "GtkSearchEntry")
        let suggestionBox = try unwrapNextSibling(of: entry)
        XCTAssertEqual(gtkWidgetTypeName(suggestionBox), "GtkBox")

        // Should have 2 buttons (Banana, Orange), not 3 — Apple excluded
        let firstBtn = try unwrapFirstChild(of: suggestionBox)
        XCTAssertEqual(gtkWidgetTypeName(firstBtn), "GtkButton")
        let firstLabel = try unwrapFirstDescendant(ofType: "GtkLabel", in: firstBtn)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(firstLabel))), "Banana")

        let secondBtn = try unwrapNextSibling(of: firstBtn)
        XCTAssertEqual(gtkWidgetTypeName(secondBtn), "GtkButton")
        let secondLabel = try unwrapFirstDescendant(ofType: "GtkLabel", in: secondBtn)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(secondLabel))), "Orange")

        XCTAssertNil(gtk_widget_get_next_sibling(secondBtn), "Apple should be excluded by filter")
    }

    func testSearchableDismissedHidesSuggestions() throws {
        try requireGTK()

        var searchText = ""
        var presented = false
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Content")
                .searchable(
                    text: Binding(get: { searchText }, set: { searchText = $0 }),
                    isPresented: Binding(get: { presented }, set: { presented = $0 })
                )
                .searchSuggestions {
                    Text("Hint")
                }
        ))

        // Entry should be hidden
        let entry = try unwrapFirstChild(of: widget)
        XCTAssertEqual(gtkWidgetTypeName(entry), "GtkSearchEntry")
        XCTAssertEqual(gtk_widget_get_visible(entry), 0, "Entry should be hidden when dismissed")

        // Suggestion box should be hidden
        let suggestionBox = try unwrapNextSibling(of: entry)
        XCTAssertEqual(gtk_widget_get_visible(suggestionBox), 0, "Suggestion box should be hidden when dismissed")
    }

    // MARK: - Search Scope Tests

    func testSearchScopesRenderToggleButtons() throws {
        try requireGTK()

        var searchText = ""
        var selection = "all"
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Content")
                .searchable(text: Binding(get: { searchText }, set: { searchText = $0 }))
                .searchScopes(
                    Binding(get: { selection }, set: { selection = $0 }),
                    scopes: ["all", "docs", "code"]
                ) { scope in
                    Text(scope)
                }
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkBox")

        // Layout: entry, scope row, content
        let entry = try unwrapFirstChild(of: widget)
        XCTAssertEqual(gtkWidgetTypeName(entry), "GtkSearchEntry")
        let scopeRow = try unwrapNextSibling(of: entry)
        XCTAssertEqual(gtkWidgetTypeName(scopeRow), "GtkBox")
        // Scope row has 3 toggle buttons
        let firstBtn = try unwrapFirstChild(of: scopeRow)
        XCTAssertEqual(gtkWidgetTypeName(firstBtn), "GtkToggleButton")
        let secondBtn = try unwrapNextSibling(of: firstBtn)
        XCTAssertEqual(gtkWidgetTypeName(secondBtn), "GtkToggleButton")
        let thirdBtn = try unwrapNextSibling(of: secondBtn)
        XCTAssertEqual(gtkWidgetTypeName(thirdBtn), "GtkToggleButton")
    }

    func testSegmentedPickerDoesNotFireCallbackDuringRender() throws {
        try requireGTK()

        var changedIndex: Int?
        var callbackCount = 0

        let widget = widgetFromOpaque(gtkRenderView(
            Picker(
                "Mode",
                selection: 0,
                options: ["Snapshot", "Compare", "Sync"],
                onChanged: { index in
                    changedIndex = index
                    callbackCount += 1
                }
            )
            .pickerStyle(.segmented)
            .labelsHidden()
        ))

        XCTAssertEqual(callbackCount, 0)
        XCTAssertNil(changedIndex)

        let firstButton = try unwrapFirstChild(of: widget)
        let secondButton = try unwrapNextSibling(of: firstButton)
        gtk_swift_toggle_button_set_active(secondButton, 1)

        XCTAssertEqual(callbackCount, 1)
        XCTAssertEqual(changedIndex, 1)
    }

    func testSearchScopeDescriptorDetectsSelectionChange() throws {
        try requireGTK()

        var searchText = ""
        var selection = "all"
        let textBinding = Binding(get: { searchText }, set: { searchText = $0 })
        let selBinding = Binding(get: { selection }, set: { selection = $0 })

        let oldDesc = gtkDescribeView(
            Text("X")
                .searchable(text: textBinding)
                .searchScopes(selBinding, scopes: ["all", "docs"]) { s in Text(s) }
        )

        selection = "docs"
        let newDesc = gtkDescribeView(
            Text("X")
                .searchable(text: textBinding)
                .searchScopes(selBinding, scopes: ["all", "docs"]) { s in Text(s) }
        )

        XCTAssertNotEqual(oldDesc, newDesc, "Descriptor should differ when scope selection changes")
    }

    // MARK: - Safe Area Padding Tests

    func testSafeAreaPaddingAllEdgesNilLengthUsesSyntheticDefault() throws {
        try requireGTK()

        // safeAreaPadding() with nil length should use synthetic default 16
        let desc = gtkDescribeView(Text("Hi").safeAreaPadding())
        guard case .safeAreaPadding(let props) = desc.props else {
            XCTFail("Expected .safeAreaPadding descriptor props")
            return
        }
        XCTAssertEqual(props.top, 16)
        XCTAssertEqual(props.bottom, 16)
        XCTAssertEqual(props.leading, 16)
        XCTAssertEqual(props.trailing, 16)
    }

    func testSafeAreaPaddingExplicitLength() throws {
        try requireGTK()

        let desc = gtkDescribeView(Text("Hi").safeAreaPadding(24))
        guard case .safeAreaPadding(let props) = desc.props else {
            XCTFail("Expected .safeAreaPadding descriptor props")
            return
        }
        XCTAssertEqual(props.top, 24)
        XCTAssertEqual(props.bottom, 24)
        XCTAssertEqual(props.leading, 24)
        XCTAssertEqual(props.trailing, 24)
    }

    func testSafeAreaPaddingSelectedEdges() throws {
        try requireGTK()

        let desc = gtkDescribeView(Text("Hi").safeAreaPadding([.top, .trailing], 10))
        guard case .safeAreaPadding(let props) = desc.props else {
            XCTFail("Expected .safeAreaPadding descriptor props")
            return
        }
        XCTAssertEqual(props.top, 10)
        XCTAssertEqual(props.bottom, 0)
        XCTAssertEqual(props.leading, 0)
        XCTAssertEqual(props.trailing, 10)
    }

    func testSafeAreaPaddingRenders() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Content").safeAreaPadding(8)
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkBox")

        let child = try unwrapFirstChild(of: widget)
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: child)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Content")
    }

    func testSafeAreaPaddingDescriptorDetectsLengthChange() throws {
        try requireGTK()

        let oldDesc = gtkDescribeView(Text("Hi").safeAreaPadding(8))
        let newDesc = gtkDescribeView(Text("Hi").safeAreaPadding(20))

        XCTAssertNotEqual(oldDesc, newDesc, "Descriptor should differ when length changes")

        let oldId = gtkIdentifyDescriptorTree(oldDesc)
        let newId = gtkIdentifyDescriptorTree(newDesc)
        let retained = gtkRetainDescriptorTree(oldId)
        let plan = gtkPlanDescriptorTree(old: retained, new: newId)
        XCTAssertNotEqual(plan.kind, .reuse, "Plan should not be .reuse when padding changes")
    }

    func testSafeAreaPaddingNegativeLengthClampsToZero() throws {
        try requireGTK()

        let desc = gtkDescribeView(Text("Hi").safeAreaPadding(-5))
        guard case .safeAreaPadding(let props) = desc.props else {
            XCTFail("Expected .safeAreaPadding descriptor props")
            return
        }
        XCTAssertEqual(props.top, 0)
        XCTAssertEqual(props.bottom, 0)
        XCTAssertEqual(props.leading, 0)
        XCTAssertEqual(props.trailing, 0)
    }

    // MARK: - Presentation Tests

    func testSheetWithOnDismissRendersContent() throws {
        try requireGTK()

        var presented = false
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Base").sheet(isPresented: Binding(get: { presented }, set: { presented = $0 }),
                               onDismiss: {}) {
                Text("Sheet")
            }
        ))
        // When not presented, should just render the base content
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Base")
    }

    func testSheetWithOnDismissPresentedRendersContent() throws {
        try requireGTK()

        var presented = true
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Base").sheet(isPresented: Binding(get: { presented }, set: { presented = $0 }),
                               onDismiss: {}) {
                Text("Sheet")
            }
        ))
        // Content widget is always returned (sheet is presented via g_idle_add)
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Base")
    }

    func testItemSheetNilItemRendersContent() throws {
        try requireGTK()

        struct TestItem: Identifiable { let id: Int; let name: String }
        var item: TestItem? = nil
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Base").sheet(
                item: Binding(get: { item }, set: { item = $0 })
            ) { i in
                Text(i.name)
            }
        ))
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Base")
    }

    func testItemSheetNonNilItemRendersContent() throws {
        try requireGTK()

        struct TestItem: Identifiable { let id: Int; let name: String }
        var item: TestItem? = TestItem(id: 1, name: "Hello")
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Base").sheet(
                item: Binding(get: { item }, set: { item = $0 })
            ) { i in
                Text(i.name)
            }
        ))
        // Content widget is returned; sheet presented via g_idle_add
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Base")
    }

    func testItemSheetReplacesOnIdentityChange() throws {
        try requireGTK()

        struct TestItem: Identifiable { let id: Int; let name: String }
        var item: TestItem? = TestItem(id: 1, name: "First")
        let itemBinding = Binding(get: { item }, set: { item = $0 })

        // Use a GTKViewHost so we can rebuild and observe anchor state
        let host = GTKViewHost(buildBody: {
            gtkRenderView(Text("Base").sheet(item: itemBinding) { i in Text(i.name) })
        })

        let previousHost = GTKViewHost.getCurrentRebuilding()
        GTKViewHost.setCurrentRebuilding(host)
        let widget = host.buildBodyWithTracking()
        GTKViewHost.setCurrentRebuilding(previousHost)

        let child = widgetFromOpaque(widget)
        gtk_box_append(boxPointer(host.container), child)

        let anchor = host.container
        let gobject = UnsafeMutableRawPointer(anchor).assumingMemoryBound(to: GObject.self)

        // After first render with item id=1, active flag and item-id should be set
        XCTAssertNotNil(g_object_get_data(gobject, "swift-sheet-active"),
                        "Sheet should be marked active after presenting item 1")
        let firstIdHash = Int(bitPattern: g_object_get_data(gobject, "swift-sheet-item-id"))
        XCTAssertEqual(firstIdHash, 1.hashValue, "Stored identity should match item 1")

        // Simulate the deferred g_idle_add having created a sheet window.
        // In headless GTK the idle callback never runs, so we place a dummy
        // window on the anchor to exercise the dismiss-and-replace branch.
        let dummyDialog = gtk_window_new()!
        g_object_set_data(gobject, "swift-sheet-window", gpointer(windowPointer(dummyDialog)))

        // Change to item with different identity
        item = TestItem(id: 2, name: "Second")

        // Rebuild — should detect identity change, dismiss old window, present new
        GTKViewHost.setCurrentRebuilding(host)
        _ = host.buildBodyWithTracking()
        GTKViewHost.setCurrentRebuilding(previousHost)

        // After rebuild, active flag should still be set (new sheet) but item-id should change
        XCTAssertNotNil(g_object_get_data(gobject, "swift-sheet-active"),
                        "Sheet should still be active after replacing with item 2")
        let secondIdHash = Int(bitPattern: g_object_get_data(gobject, "swift-sheet-item-id"))
        XCTAssertEqual(secondIdHash, 2.hashValue, "Stored identity should match item 2")
        XCTAssertNotEqual(firstIdHash, secondIdHash,
                          "Identity should have changed from item 1 to item 2")

        // The old swift-sheet-window should have been cleared by the replacement
        // branch before scheduling the new presentation (new window not yet created
        // since g_idle_add is deferred). Verify window ref was cleared.
        XCTAssertNil(g_object_get_data(gobject, "swift-sheet-window"),
                     "Old sheet window should have been cleared during replacement")
    }

    func testAlertWithActionsAndMessageRendersContent() throws {
        try requireGTK()

        var presented = false
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Base").alert("Title",
                               isPresented: Binding(get: { presented }, set: { presented = $0 }),
                               actions: [AlertButton("OK")],
                               message: "Details")
        ))
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Base")
    }

    func testAlertErrorBasedPresentedRendersContent() throws {
        try requireGTK()

        struct TestError: LocalizedError {
            var errorDescription: String? { "Something failed" }
            var failureReason: String? { "Bad input" }
        }

        var presented = true
        let error: TestError? = TestError()
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Base").alert(
                isPresented: Binding(get: { presented }, set: { presented = $0 }),
                error: error
            )
        ))
        // Error-based alert with isPresented=true and non-nil error takes the
        // presenting branch (alert scheduled via g_idle_add); content still renders
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Base")
    }

    func testAlertErrorNilSuppressesPresentation() throws {
        try requireGTK()

        struct TestError: LocalizedError {
            var errorDescription: String? { "Oops" }
        }

        var presented = true
        let error: TestError? = nil
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Base").alert(
                isPresented: Binding(get: { presented }, set: { presented = $0 }),
                error: error
            )
        ))
        // With nil error, effective isPresented is false — no alert should attempt presentation
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Base")
    }

    // MARK: - Confirmation Dialog Batch B Tests

    // Smoke tests: verify new overloads render without crash and return base content.
    // Actual dialog title/message rendering happens in deferred g_idle_add and is
    // not observable in headless GTK tests.

    func testConfirmationDialogWithTitleVisibilitySmoke() throws {
        try requireGTK()

        var presented = true
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Base").confirmationDialog(
                "Delete?",
                isPresented: Binding(get: { presented }, set: { presented = $0 }),
                titleVisibility: .visible,
                actions: [AlertButton("Delete", role: .destructive)]
            )
        ))
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Base")
    }

    func testConfirmationDialogWithHiddenTitleSmoke() throws {
        try requireGTK()

        var presented = true
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Base").confirmationDialog(
                "Hidden Title",
                isPresented: Binding(get: { presented }, set: { presented = $0 }),
                titleVisibility: .hidden,
                actions: [AlertButton("OK")]
            )
        ))
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Base")
    }

    func testConfirmationDialogWithMessageSmoke() throws {
        try requireGTK()

        var presented = true
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Base").confirmationDialog(
                "Confirm",
                isPresented: Binding(get: { presented }, set: { presented = $0 }),
                titleVisibility: .automatic,
                actions: [AlertButton("Yes"), AlertButton("No")],
                message: "Are you sure?"
            )
        ))
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Base")
    }

    func testDismissalConfirmationDialogSmoke() throws {
        try requireGTK()

        var presented = true
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Base").dismissalConfirmationDialog(
                "Discard changes?",
                shouldPresent: Binding(get: { presented }, set: { presented = $0 }),
                actions: [
                    AlertButton("Discard", role: .destructive),
                    AlertButton("Keep Editing", role: .cancel)
                ]
            )
        ))
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Base")
    }

    func testSheetWithDismissalInterceptionRendersContent() throws {
        try requireGTK()

        var presented = true
        var shouldConfirm = false
        // Sheet content carries dismissalConfirmationDialog
        let sheetContent = Text("Edit").dismissalConfirmationDialog(
            "Discard?",
            shouldPresent: Binding(get: { shouldConfirm }, set: { shouldConfirm = $0 }),
            actions: [AlertButton("Discard", role: .destructive)]
        )
        let widget = widgetFromOpaque(gtkRenderView(
            Text("Base").sheet(
                isPresented: Binding(get: { presented }, set: { presented = $0 })
            ) { sheetContent }
        ))
        // Base content renders normally; sheet is deferred
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Base")
    }

    // MARK: - Toolbar Tests

    func testToolbarMultiItemExtractsAllItems() throws {
        try requireGTK()

        let view = Text("Content").toolbar {
            ToolbarItem(placement: .leading) { Text("A") }
            ToolbarItem(placement: .trailing) { Text("B") }
            ToolbarItem(placement: .primaryAction) { Text("C") }
        }

        let items = gtkExtractToolbarItems(from: view)
        XCTAssertEqual(items.count, 3, "Should extract 3 toolbar items")
        XCTAssertEqual(items[0].placement, .leading)
        XCTAssertEqual(items[1].placement, .trailing)
        XCTAssertEqual(items[2].placement, .primaryAction)
    }

    func testToolbarWithIdExtractsItems() throws {
        try requireGTK()

        let view = Text("Content").toolbar(id: "my-toolbar") {
            ToolbarItem(placement: .leading) { Text("X") }
        }

        let items = gtkExtractToolbarItems(from: view)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].placement, .leading)
    }

    func testToolbarRendersContentPassthrough() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Main").toolbar {
                ToolbarItem(placement: .trailing) { Text("Action") }
            }
        ))
        // ToolbarView renders content; items extracted by NavigationStack
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Main")
    }

    // MARK: - Toolbar Batch B Tests

    func testToolbarConfigurationViewRendersContent() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Text("Content").toolbar(.hidden, for: .navigationBar)
        ))
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Content")
    }

    func testToolbarConfigurationExtractsHiddenVisibility() throws {
        try requireGTK()

        let view = Text("X").toolbar(.hidden, for: .navigationBar)
        let config = gtkExtractToolbarConfiguration(from: view)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.visibility, .hidden)
        XCTAssertEqual(config?.visibilityTarget, .navigationBar)
    }

    func testToolbarConfigurationRemovesPlacement() throws {
        try requireGTK()

        let view = Text("X")
            .toolbar {
                ToolbarItem(placement: .leading) { Text("A") }
                ToolbarItem(placement: .trailing) { Text("B") }
            }
            .toolbar(removing: .leading)

        let items = gtkExtractToolbarItems(from: view)
        let config = gtkExtractToolbarConfiguration(from: view)
        let (filtered, hidden) = gtkApplyToolbarConfiguration(items: items, configuration: config)

        XCTAssertFalse(hidden)
        XCTAssertEqual(filtered.count, 1, "Leading item should be removed")
        XCTAssertEqual(filtered[0].placement, .trailing)
    }

    func testToolbarHiddenForBottomBarDoesNotAffectGTK() throws {
        try requireGTK()

        let items = [
            AnyToolbarItem(ToolbarItem(placement: .leading) { Text("A") }),
        ]
        let config = ToolbarConfiguration(visibility: .hidden, visibilityTarget: .bottomBar)
        let (filtered, hidden) = gtkApplyToolbarConfiguration(items: items, configuration: config)
        XCTAssertFalse(hidden, "Hidden for .bottomBar should not suppress GTK navigation-bar toolbar")
        XCTAssertEqual(filtered.count, 1)
    }

    func testToolbarHiddenVisibilityFiltersAllItems() throws {
        try requireGTK()

        let items = [
            AnyToolbarItem(ToolbarItem(placement: .leading) { Text("A") }),
            AnyToolbarItem(ToolbarItem(placement: .trailing) { Text("B") }),
        ]
        let config = ToolbarConfiguration(visibility: .hidden, visibilityTarget: .navigationBar)
        let (_, hidden) = gtkApplyToolbarConfiguration(items: items, configuration: config)
        XCTAssertTrue(hidden, "Hidden visibility should suppress toolbar")
    }

    func testToolbarHiddenVisibilityWorksWhenAppliedAfterItems() throws {
        try requireGTK()

        let view = Text("X")
            .toolbar {
                ToolbarItem(placement: .trailing) { Text("A") }
            }
            .toolbar(.hidden, for: .navigationBar)

        let items = gtkExtractToolbarItems(from: view)
        let config = gtkExtractToolbarConfiguration(from: view)
        let (_, hidden) = gtkApplyToolbarConfiguration(items: items, configuration: config)

        XCTAssertTrue(hidden, "Hidden visibility should apply when configuration wraps toolbar items")
    }

    func testToolbarHiddenVisibilityWorksWhenAppliedBeforeItems() throws {
        try requireGTK()

        let view = Text("X")
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .trailing) { Text("A") }
            }

        let items = gtkExtractToolbarItems(from: view)
        let config = gtkExtractToolbarConfiguration(from: view)
        let (_, hidden) = gtkApplyToolbarConfiguration(items: items, configuration: config)

        XCTAssertTrue(hidden, "Hidden visibility should apply when toolbar items wrap configuration")
    }

    func testToolbarMixedVisibilityAndRemovalChainPreservesBothSettings() throws {
        try requireGTK()

        let view = Text("X")
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .leading) { Text("A") }
                ToolbarItem(placement: .trailing) { Text("B") }
            }
            .toolbar(removing: .leading)

        let items = gtkExtractToolbarItems(from: view)
        let config = gtkExtractToolbarConfiguration(from: view)
        let (filtered, hidden) = gtkApplyToolbarConfiguration(items: items, configuration: config)

        XCTAssertTrue(hidden, "Hidden visibility should survive the mixed chain")
        XCTAssertEqual(config?.removedPlacements, [.leading], "Removed placements should survive the mixed chain")
        XCTAssertEqual(filtered.count, 1, "Leading item should still be removed in the mixed chain")
        XCTAssertEqual(filtered[0].placement, .trailing)
    }

    // MARK: - ViewThatFits Tests

    func testViewThatFitsRendersAsGtkStack() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            ViewThatFits {
                Text("Wide layout with lots of text")
                Text("Compact")
            }
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkStack",
                       "ViewThatFits should render as a GtkStack")
    }

    func testViewThatFitsShowsFirstChildInitially() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            ViewThatFits {
                Text("First")
                Text("Second")
                Text("Third")
            }
        ))
        // Initial visible child should be vtf-0
        let visibleName = gtk_stack_get_visible_child_name(OpaquePointer(widget))
        XCTAssertNotNil(visibleName)
        if let name = visibleName {
            XCTAssertEqual(String(cString: name), "vtf-0",
                           "Should show first child initially")
        }
    }

    func testViewThatFitsEmptyContentRendersEmptyStack() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            ViewThatFits { }
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkStack")
        // No children — should not crash
        XCTAssertNil(gtk_widget_get_first_child(widget))
    }

    func testViewThatFitsSingleChildRendersIt() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            ViewThatFits {
                Text("Only child")
            }
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkStack")
        let label = try unwrapFirstDescendant(ofType: "GtkLabel", in: widget)
        XCTAssertEqual(String(cString: gtk_label_get_text(OpaquePointer(label))), "Only child")
    }

    // MARK: - Disabled Tests

    func testDisabledButtonIsSensitiveFalse() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Button("Tap") {}.disabled(true)
        ))
        XCTAssertEqual(gtk_widget_get_sensitive(widget), 0,
                       "Disabled button should have sensitivity = false")
    }

    func testEnabledButtonIsSensitiveTrue() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Button("Tap") {}.disabled(false)
        ))
        XCTAssertNotEqual(gtk_widget_get_sensitive(widget), 0,
                          "Enabled button should have sensitivity = true")
    }

    func testNestedDisabledCannotReEnable() throws {
        try requireGTK()

        // Parent disabled(true) wraps child disabled(false) — should still be disabled
        let widget = widgetFromOpaque(gtkRenderView(
            Button("Tap") {}.disabled(false).disabled(true)
        ))
        XCTAssertEqual(gtk_widget_get_sensitive(widget), 0,
                       "Ancestor disabled(true) should not be undone by child disabled(false)")
    }

    func testDisabledTextFieldIsSensitiveFalse() throws {
        try requireGTK()

        var text = ""
        let widget = widgetFromOpaque(gtkRenderView(
            TextField("Name", text: Binding(get: { text }, set: { text = $0 })).disabled(true)
        ))
        XCTAssertEqual(gtk_widget_get_sensitive(widget), 0,
                       "Disabled text field should have sensitivity = false")
    }

    // MARK: - Image.resizable()

    func testFileImageRendersAsGtkPicture() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Image(filePath: "/tmp/does-not-exist.jpg")
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkPicture",
                       "Image(filePath:) should render as GtkPicture, not GtkImage")
    }

    func testFileImageNonResizableHasNoExpandFlags() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Image(filePath: "/tmp/does-not-exist.jpg")
        ))
        XCTAssertEqual(gtk_widget_get_hexpand(widget), 0,
                       "Non-resizable image should not advertise horizontal expansion")
        XCTAssertEqual(gtk_widget_get_vexpand(widget), 0,
                       "Non-resizable image should not advertise vertical expansion")
    }

    func testFileImageResizableAdvertisesFillBehavior() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(
            Image(filePath: "/tmp/does-not-exist.jpg").resizable()
        ))
        XCTAssertEqual(gtkWidgetTypeName(widget), "GtkPicture",
                       "Resizable image should also render as GtkPicture")
        XCTAssertEqual(gtk_widget_get_hexpand(widget), 1,
                       "Resizable image must set hexpand so FrameView stretches it")
        XCTAssertEqual(gtk_widget_get_vexpand(widget), 1,
                       "Resizable image must set vexpand so FrameView stretches it")
        XCTAssertEqual(gtk_widget_get_halign(widget), GTK_ALIGN_FILL,
                       "Resizable image must use FILL alignment horizontally")
        XCTAssertEqual(gtk_widget_get_valign(widget), GTK_ALIGN_FILL,
                       "Resizable image must use FILL alignment vertically")
    }

    // MARK: - Deferred callback environment binding

    func testBindActionToCurrentEnvironmentCapturesAndRestores() throws {
        try requireGTK()

        let model = GTKDelayedEnvModel()
        var env = getCurrentEnvironment()
        env.setObject(model)

        let previousEnv = getCurrentEnvironment()
        setCurrentEnvironment(env)
        let bound = bindActionToCurrentEnvironment { model.count += 1 }
        setCurrentEnvironment(previousEnv)

        // The closure should still access the captured environment even though
        // the current environment no longer contains the model.
        bound()
        XCTAssertEqual(model.count, 1,
                       "Bound callback should execute with the captured render-time environment")
    }

    func testBindActionToCurrentEnvironmentGenericCapturesAndRestores() throws {
        try requireGTK()

        let model = GTKDelayedEnvModel()
        var env = getCurrentEnvironment()
        env.setObject(model)

        let previousEnv = getCurrentEnvironment()
        setCurrentEnvironment(env)
        let bound: (Int) -> Void = bindActionToCurrentEnvironment { value in
            model.count += value
        }
        setCurrentEnvironment(previousEnv)

        bound(5)
        XCTAssertEqual(model.count, 5,
                       "Generic bound callback should execute with the captured environment")
    }

    func testButtonRendersWithEnvironmentBinding() throws {
        try requireGTK()

        let model = GTKDelayedEnvModel()
        let widget = widgetFromOpaque(gtkRenderView(
            GTKDelayedEnvButtonView().environment(model)
        ))
        XCTAssertNotNil(widget,
                        "Button view with .environment(model) should render a widget")
    }

    func testOnAppearRendersWithEnvironmentBinding() throws {
        try requireGTK()

        let model = GTKDelayedEnvModel()
        let widget = widgetFromOpaque(gtkRenderView(
            GTKDelayedEnvOnAppearView().environment(model)
        ))
        XCTAssertNotNil(widget,
                        "onAppear view with .environment(model) should render a widget")
    }

    func testOnDisappearRendersWithEnvironmentBinding() throws {
        try requireGTK()

        let model = GTKDelayedEnvModel()
        let widget = widgetFromOpaque(gtkRenderView(
            GTKDelayedEnvOnDisappearView().environment(model)
        ))
        XCTAssertNotNil(widget,
                        "onDisappear view with .environment(model) should render a widget")
    }

    func testTapGestureRendersWithEnvironmentBinding() throws {
        try requireGTK()

        let model = GTKDelayedEnvModel()
        let widget = widgetFromOpaque(gtkRenderView(
            GTKDelayedEnvTapGestureView().environment(model)
        ))
        XCTAssertNotNil(widget,
                        "onTapGesture view with .environment(model) should render a widget")
    }

    func testLongPressGestureRendersWithEnvironmentBinding() throws {
        try requireGTK()

        let model = GTKDelayedEnvModel()
        let widget = widgetFromOpaque(gtkRenderView(
            GTKDelayedEnvLongPressView().environment(model)
        ))
        XCTAssertNotNil(widget,
                        "onLongPressGesture view with .environment(model) should render a widget")
    }

    func testDragGestureRendersWithEnvironmentBinding() throws {
        try requireGTK()

        let model = GTKDelayedEnvModel()
        let widget = widgetFromOpaque(gtkRenderView(
            GTKDelayedEnvDragView().environment(model)
        ))
        XCTAssertNotNil(widget,
                        "onDrag view with .environment(model) should render a widget")
    }

    func testDisclosureGroupRendersWithEnvironmentBinding() throws {
        try requireGTK()

        let model = GTKDelayedEnvModel()
        let widget = widgetFromOpaque(gtkRenderView(
            GTKDelayedEnvDisclosureGroupView().environment(model)
        ))
        XCTAssertNotNil(widget,
                        "DisclosureGroup with .environment(model) should render a widget")
    }

    func testMenuRendersWithEnvironmentBinding() throws {
        try requireGTK()

        let model = GTKDelayedEnvModel()
        let widget = widgetFromOpaque(gtkRenderView(
            GTKDelayedEnvMenuView().environment(model)
        ))
        XCTAssertNotNil(widget,
                        "Menu with .environment(model) should render a widget")
    }

    // MARK: - Layout parity regressions

    func testVStackDefaultSpacingIsZero() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            VStack {
                Text("A")
                Text("B")
            }
        ))
        let wrapperSize = measuredSize(of: wrapper)
        allocate(widget: wrapper, size: wrapperSize)

        let first = try unwrapFirstChild(of: wrapper)
        let second = try unwrapNextSibling(of: first)
        let firstSize = allocatedSize(of: first)
        let secondOrigin = translatedChildOrigin(child: second, in: wrapper)

        XCTAssertEqual(
            secondOrigin.y,
            firstSize.height,
            accuracy: 0.01,
            "Default VStack spacing must collapse to 0 to match macOS SwiftUI for text siblings."
        )
    }

    func testFixedWidthFrameAroundColorStaysFixedInHStack() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            HStack {
                Color.red.frame(width: 50, height: 20)
                Text("End")
            }
        ))
        allocate(widget: wrapper, size: ViewSize(width: 400, height: 40))

        let first = try unwrapFirstChild(of: wrapper)
        let firstSize = allocatedSize(of: first)

        XCTAssertEqual(
            firstSize.width,
            50,
            accuracy: 0.01,
            "Color inside a fixed-width frame must not bleed hexpand into the HStack."
        )
    }

    func testFrameMinHeightCenteringHelpersAreMarked() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            Text("Centered").frame(maxWidth: .infinity, minHeight: 120)
        ))
        let markerCount = gtkCountLayoutHelpers(in: wrapper)

        XCTAssertGreaterThan(
            markerCount,
            0,
            "FrameView vertical centering must mark its synthetic spacers so layout parity capture excludes them."
        )
    }

    func testMiddleTruncationFrameRendersScrolledWindowWithSingleLabel() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            Text("/home/kyoshikawa/Documents/projects/sync/very/long/path")
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 100)
        ))
        let scrolled = try unwrapFirstDescendant(ofType: "GtkScrolledWindow", in: wrapper)

        var labels: [UnsafeMutablePointer<GtkWidget>] = []
        gtkCollectLabels(in: scrolled, into: &labels)

        XCTAssertEqual(
            labels.count,
            1,
            "Middle-truncated text clipped by a fixed-width frame must render a single label inside the scroll clip."
        )
    }

    // MARK: - LayoutStress regressions (2026-04-17)

    /// Two VStacks wrapped in `.frame(maxWidth: .infinity)` inside an HStack
    /// must split the available width evenly — the LayoutStress "dashboard
    /// cards" pattern.
    func testTwoInfinityFramesInHStackSplitWidthEvenly() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            HStack(spacing: 12) {
                Text("A")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)

                Text("B")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        ))
        gtk_widget_set_halign(wrapper, GTK_ALIGN_FILL)
        gtk_widget_set_hexpand(wrapper, 1)
        allocate(widget: wrapper, size: ViewSize(width: 400, height: 80))

        let first = try unwrapFirstChild(of: wrapper)
        let second = try unwrapNextSibling(of: first)
        let firstSize = allocatedSize(of: first)
        let secondSize = allocatedSize(of: second)

        // Expected: (400 - 12 gap) / 2 ≈ 194 each.
        XCTAssertEqual(firstSize.width, 194, accuracy: 3,
                       "First card should take half the HStack width.")
        XCTAssertEqual(secondSize.width, 194, accuracy: 3,
                       "Second card should take half the HStack width.")
    }

    /// A fixed-width frame wrapping `HStack { Text; Spacer; Text }` must
    /// allocate both Text children's natural widths — the LayoutStress
    /// "sidebar item" pattern.
    func testFixedWidthFrameAllocatesBothTextsInInternalHStack() throws {
        try requireGTK()

        // Mirrors the LayoutStress sidebarItem layout: fixed-width outer
        // VStack containing an HStack { Text; Spacer; Text } wrapped in
        // padding + background.
        let wrapper = widgetFromOpaque(gtkRenderView(
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Inbox")
                    Spacer()
                    Text("12")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.clear)
            }
            .frame(width: 140)
        ))
        gtk_widget_set_halign(wrapper, GTK_ALIGN_FILL)
        gtk_widget_set_hexpand(wrapper, 1)
        allocate(widget: wrapper, size: ViewSize(width: 140, height: 40))

        // Walk descendants, collect Text labels (excluding Spacer-marked ones).
        var allLabels: [UnsafeMutablePointer<GtkWidget>] = []
        gtkCollectLabels(in: wrapper, into: &allLabels)
        let textLabels = allLabels.filter { w in
            let g = UnsafeMutableRawPointer(w).assumingMemoryBound(to: GObject.self)
            return g_object_get_data(g, gtkSwiftSpacerMarker) == nil
        }

        XCTAssertEqual(textLabels.count, 2,
                       "Both 'Inbox' and '12' labels must appear.")
        for label in textLabels {
            let size = allocatedSize(of: label)
            XCTAssertGreaterThan(size.width, 0,
                                 "Label must receive non-zero width inside a fixed-width HStack parent.")
        }
    }

    /// A ZStack with `.frame(width: 120, height: 100)` must report exactly
    /// that allocated size — the LayoutStress "nested alignment" pattern.
    func testZStackWithFixedFrameReportsRequestedSize() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            ZStack {
                Color.red
                Text("TL")
                    .frame(width: 80, height: 60, alignment: .bottomTrailing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: 120, height: 100)
        ))
        let wrapperSize = measuredSize(of: wrapper)
        allocate(widget: wrapper, size: wrapperSize)

        XCTAssertEqual(wrapperSize.width, 120, accuracy: 1,
                       "ZStack frame(width: 120) must measure 120 wide.")
        XCTAssertEqual(wrapperSize.height, 100, accuracy: 1,
                       "ZStack frame(height: 100) must measure 100 tall.")
    }

    /// Settings-row pattern: `HStack { Text; Spacer; Text }` inside a
    /// `VStack(alignment: .leading)` with a Color background. The trailing
    /// Text (value) must be pushed to the right edge of the allocated width,
    /// not left-clustered with the label.
    func testSettingsRowSpacerPushesValueToRightEdge() throws {
        try requireGTK()

        // Reproduce the exact LayoutStress SettingsSection: section header,
        // multiple rows with divider siblings, all under a ScrollView-
        // wrapped VStack(.leading, spacing: 16), which itself is under a
        // top-level VStack(spacing: 0) with a title bar.
        let wrapper = widgetFromOpaque(gtkRenderView(
            VStack(spacing: 0) {
                Text("Layout Stress Test")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.1, green: 0.1, blue: 0.1))

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("1. Settings Rows").padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("GENERAL")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            HStack {
                                Text("Username")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("kaz.yoshikawa")
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            Color.gray.frame(height: 0.5).padding(.leading, 16)
                            HStack {
                                Text("Email")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("kaz@example.com")
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                    }
                    .padding(.vertical, 16)
                }
            }
            .background(Color.black)
        ))
        // Use the backend's own helper so we match the real window bring-up.
        gtkConfigureRootContentToFillWindow(wrapper)
        allocate(widget: wrapper, size: ViewSize(width: 700, height: 600))

        var allLabels: [UnsafeMutablePointer<GtkWidget>] = []
        gtkCollectLabels(in: wrapper, into: &allLabels)
        let textLabels = allLabels.filter { w in
            let g = UnsafeMutableRawPointer(w).assumingMemoryBound(to: GObject.self)
            return g_object_get_data(g, gtkSwiftSpacerMarker) == nil
        }

        // Dump every non-Spacer label with its position to see what's happening.
        for label in textLabels {
            let ptr = gtk_label_get_text(OpaquePointer(label))
            let text = ptr.map { String(cString: $0) } ?? "?"
            let origin = translatedChildOrigin(child: label, in: wrapper)
            let size = allocatedSize(of: label)
            fputs("DBG label '\(text)' at x=\(origin.x) w=\(size.width) right=\(origin.x + size.width)\n", stderr)
        }

        guard let valueLabel = textLabels.first(where: { w in
            let ptr = gtk_label_get_text(OpaquePointer(w))
            return ptr.map { String(cString: $0) } == "kaz.yoshikawa"
        }) else {
            XCTFail("Could not locate kaz.yoshikawa label")
            return
        }

        let valueOrigin = translatedChildOrigin(child: valueLabel, in: wrapper)
        let valueSize = allocatedSize(of: valueLabel)
        let valueRightEdge = valueOrigin.x + valueSize.width

        // Inner right edge = 700 (allocated) - 16 (row padding) = 684.
        XCTAssertGreaterThan(
            valueRightEdge,
            670,
            "Spacer must push the value to the right padding edge (~684), got right edge at \(valueRightEdge)."
        )
    }

    /// A `.frame(height: 0.5)` (sub-pixel divider) must request at least
    /// 1 device-pixel of height. Truncating via `gint()` collapses 0.5 to 0
    /// and makes the divider invisible.
    func testSubPixelHeightFrameRendersAtLeastOnePixel() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            Color.gray.frame(height: 0.5)
        ))

        var widthMin: Int32 = 0; var widthNat: Int32 = 0
        var heightMin: Int32 = 0; var heightNat: Int32 = 0
        gtk_swift_widget_measure(wrapper, GTK_ORIENTATION_HORIZONTAL, -1, &widthMin, &widthNat)
        gtk_swift_widget_measure(wrapper, GTK_ORIENTATION_VERTICAL, -1, &heightMin, &heightNat)

        XCTAssertGreaterThanOrEqual(
            heightMin,
            1,
            "A 0.5pt divider's minimum height must be at least 1 device pixel, got \(heightMin)."
        )
        XCTAssertGreaterThanOrEqual(
            heightNat,
            1,
            "A 0.5pt divider's natural height must be at least 1 device pixel, got \(heightNat)."
        )
    }

    /// Three ZStacks with identical `.frame(width: 120, height: 100)` placed
    /// in an HStack must all allocate the same 120×100 size — the
    /// LayoutStress "nested alignment stress" pattern. The middle box uses
    /// a VStack with different-width children, which previously caused its
    /// ZStack to measure narrower than its siblings.
    func testThreeFramedZStacksInHStackAllReportSameSize() throws {
        try requireGTK()

        let wrapper = widgetFromOpaque(gtkRenderView(
            HStack(spacing: 12) {
                ZStack {
                    Color.red
                    Text("TL")
                }
                .frame(width: 120, height: 100)

                ZStack {
                    Color.green
                    VStack(alignment: .leading, spacing: 4) {
                        Text("A")
                        Text("BB")
                        Text("CCC")
                    }
                }
                .frame(width: 120, height: 100)

                ZStack {
                    Color.blue
                    Text("BR")
                }
                .frame(width: 120, height: 100)
            }
        ))
        gtk_widget_set_halign(wrapper, GTK_ALIGN_START)
        allocate(widget: wrapper, size: ViewSize(width: 400, height: 100))

        let first = try unwrapFirstChild(of: wrapper)
        let second = try unwrapNextSibling(of: first)
        let third = try unwrapNextSibling(of: second)

        let firstSize = allocatedSize(of: first)
        let secondSize = allocatedSize(of: second)
        let thirdSize = allocatedSize(of: third)

        XCTAssertEqual(firstSize.width, 120, accuracy: 1,
                       "Red ZStack must be 120 wide.")
        XCTAssertEqual(secondSize.width, 120, accuracy: 1,
                       "Green ZStack must be 120 wide.")
        XCTAssertEqual(thirdSize.width, 120, accuracy: 1,
                       "Blue ZStack must be 120 wide.")
        XCTAssertEqual(firstSize.height, 100, accuracy: 1,
                       "Red ZStack must be 100 tall.")
        XCTAssertEqual(secondSize.height, 100, accuracy: 1,
                       "Green ZStack must be 100 tall.")
        XCTAssertEqual(thirdSize.height, 100, accuracy: 1,
                       "Blue ZStack must be 100 tall.")
    }
}

// MARK: - Deferred callback environment test fixtures

private final class GTKDelayedEnvModel {
    var count: Int = 0
}

private struct GTKDelayedEnvButtonView: View {
    @Environment(GTKDelayedEnvModel.self) var model

    var body: some View {
        Button("Increment") { model.count += 1 }
    }
}

private struct GTKDelayedEnvOnAppearView: View {
    @Environment(GTKDelayedEnvModel.self) var model

    var body: some View {
        Text("appear").onAppear { model.count += 1 }
    }
}

private struct GTKDelayedEnvOnDisappearView: View {
    @Environment(GTKDelayedEnvModel.self) var model

    var body: some View {
        Text("disappear").onDisappear { model.count += 1 }
    }
}

private struct GTKDelayedEnvTapGestureView: View {
    @Environment(GTKDelayedEnvModel.self) var model

    var body: some View {
        Text("Tap").onTapGesture { model.count += 1 }
    }
}

private struct GTKDelayedEnvLongPressView: View {
    @Environment(GTKDelayedEnvModel.self) var model

    var body: some View {
        Text("Hold").onLongPressGesture(minimumDuration: 0) { model.count += 1 }
    }
}

private struct GTKDelayedEnvDragView: View {
    @Environment(GTKDelayedEnvModel.self) var model

    var body: some View {
        Text("Drag").onDrag(onChanged: { _ in model.count += 1 }, onEnded: { _ in model.count += 1 })
    }
}

private struct GTKDelayedEnvDisclosureGroupView: View {
    @Environment(GTKDelayedEnvModel.self) var model

    var body: some View {
        DisclosureGroup(
            "Toggle",
            isExpanded: Binding(
                get: { false },
                set: { _ in model.count += 1 }
            )
        ) {
            Text("Hidden")
        }
    }
}

private struct GTKDelayedEnvMenuView: View {
    @Environment(GTKDelayedEnvModel.self) var model

    var body: some View {
        Menu("Actions") {
            MenuItem("Increment") { model.count += 1 }
        }
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

private func gtkCountLayoutHelpers(in widget: UnsafeMutablePointer<GtkWidget>) -> Int {
    var count = 0
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    if g_object_get_data(gobject, gtkSwiftLayoutHelperMarker) != nil {
        count += 1
    }
    var child = gtk_widget_get_first_child(widget)
    while let current = child {
        count += gtkCountLayoutHelpers(in: current)
        child = gtk_widget_get_next_sibling(current)
    }
    return count
}

private func gtkCollectLabels(
    in widget: UnsafeMutablePointer<GtkWidget>,
    into labels: inout [UnsafeMutablePointer<GtkWidget>]
) {
    if gtkWidgetTypeName(widget) == "GtkLabel" {
        labels.append(widget)
        return
    }
    var child = gtk_widget_get_first_child(widget)
    while let current = child {
        gtkCollectLabels(in: current, into: &labels)
        child = gtk_widget_get_next_sibling(current)
    }
}
