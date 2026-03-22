import XCTest
@testable import SwiftOpenUI
@testable import BackendGTK4

final class GTK4DescriptorTests: XCTestCase {

    // MARK: - Describe

    func testDescribeText() {
        let node = gtkDescribeView(Text("Hello"))
        XCTAssertEqual(node.kind, .text)
        if case let .text(desc) = node.props {
            XCTAssertEqual(desc.content, "Hello")
        } else {
            XCTFail("Expected text props")
        }
    }

    func testDescribeColor() {
        let node = gtkDescribeView(Color.red)
        XCTAssertEqual(node.kind, .color)
        if case let .color(desc) = node.props {
            XCTAssertEqual(desc.red, 1.0)
            XCTAssertEqual(desc.green, 0.0)
            XCTAssertEqual(desc.blue, 0.0)
        } else {
            XCTFail("Expected color props")
        }
    }

    func testDescribeVStackWithChildren() {
        let node = gtkDescribeView(VStack {
            Text("A")
            Text("B")
        })
        XCTAssertEqual(node.kind, .vStack)
        XCTAssertEqual(node.children.count, 2)
        XCTAssertEqual(node.children[0].kind, .text)
        XCTAssertEqual(node.children[1].kind, .text)
    }

    // MARK: - Identify

    func testIdentifyAssignsPaths() {
        let node = GTK4DescriptorNode(kind: .vStack, typeName: "VStack", children: [
            GTK4DescriptorNode(kind: .text, typeName: "Text", props: .text(GTK4TextDescriptor(content: "A"))),
            GTK4DescriptorNode(kind: .text, typeName: "Text", props: .text(GTK4TextDescriptor(content: "B"))),
        ])
        let identified = gtkIdentifyDescriptorTree(node)
        XCTAssertEqual(identified.identity.path, [])
        XCTAssertEqual(identified.children[0].identity.path, [0])
        XCTAssertEqual(identified.children[1].identity.path, [1])
    }

    // MARK: - Match

    func testMatchSameStructure() {
        let desc = GTK4DescriptorNode(kind: .text, typeName: "Text",
                                       props: .text(GTK4TextDescriptor(content: "Hello")))
        let old = gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(desc))
        let new = gtkIdentifyDescriptorTree(desc)
        let match = gtkMatchDescriptorTree(old: old, new: new)
        XCTAssertEqual(match.kind, .reuse)
    }

    func testMatchDifferentKind() {
        let oldDesc = GTK4DescriptorNode(kind: .text, typeName: "Text")
        let newDesc = GTK4DescriptorNode(kind: .color, typeName: "Color")
        let old = gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc))
        let new = gtkIdentifyDescriptorTree(newDesc)
        let match = gtkMatchDescriptorTree(old: old, new: new)
        XCTAssertEqual(match.kind, .replace)
    }

    // MARK: - Plan

    func testPlanTextChange() {
        let oldDesc = GTK4DescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(GTK4TextDescriptor(content: "Old")))
        let newDesc = GTK4DescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(GTK4TextDescriptor(content: "New")))
        let old = gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc))
        let new = gtkIdentifyDescriptorTree(newDesc)
        let plan = gtkPlanDescriptorTree(old: old, new: new)
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .textContent)
    }

    func testPlanColorChange() {
        let oldDesc = GTK4DescriptorNode(kind: .color, typeName: "Color",
                                          props: .color(GTK4ColorDescriptor(red: 1, green: 0, blue: 0, opacity: 1)))
        let newDesc = GTK4DescriptorNode(kind: .color, typeName: "Color",
                                          props: .color(GTK4ColorDescriptor(red: 0, green: 1, blue: 0, opacity: 1)))
        let old = gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc))
        let new = gtkIdentifyDescriptorTree(newDesc)
        let plan = gtkPlanDescriptorTree(old: old, new: new)
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .colorFill)
    }

    func testPlanStructuralChange() {
        let oldDesc = GTK4DescriptorNode(kind: .text, typeName: "Text")
        let newDesc = GTK4DescriptorNode(kind: .color, typeName: "Color")
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc)),
            new: gtkIdentifyDescriptorTree(newDesc)
        )
        XCTAssertEqual(plan.kind, .replace)
    }

    func testPlanNoChange() {
        let desc = GTK4DescriptorNode(kind: .text, typeName: "Text",
                                       props: .text(GTK4TextDescriptor(content: "Same")))
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(desc)),
            new: gtkIdentifyDescriptorTree(desc)
        )
        XCTAssertEqual(plan.kind, .reuse)
        XCTAssertEqual(plan.updateIntent, .none)
    }

    // MARK: - Execute

    func testExecuteTextUpdate() {
        let oldDesc = GTK4DescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(GTK4TextDescriptor(content: "Old")))
        let newDesc = GTK4DescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(GTK4TextDescriptor(content: "New")))
        let oldId = gtkIdentifyDescriptorTree(oldDesc)
        let newId = gtkIdentifyDescriptorTree(newDesc)
        let executor = gtkMakeExecutorTree(from: oldId)
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(oldId),
            new: newId
        )
        let action = gtkExecuteDescriptorPlan(old: executor, plan: plan)
        XCTAssertEqual(action.kind, .update)
        XCTAssertEqual(action.updateIntent, .textContent)
    }

    // MARK: - Hook

    func testHookTextContent() {
        let oldDesc = GTK4DescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(GTK4TextDescriptor(content: "Old")))
        let newDesc = GTK4DescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(GTK4TextDescriptor(content: "New")))
        let oldId = gtkIdentifyDescriptorTree(oldDesc)
        let newId = gtkIdentifyDescriptorTree(newDesc)
        let executor = gtkMakeExecutorTree(from: oldId)
        let plan = gtkPlanDescriptorTree(old: gtkRetainDescriptorTree(oldId), new: newId)
        let action = gtkExecuteDescriptorPlan(old: executor, plan: plan)
        let result = gtkApplyHook(action: action)
        XCTAssertEqual(result.kind, .updated)
        XCTAssertEqual(result.updateIntent, .textContent)
        XCTAssertTrue(result.mutationSucceeded)
    }

    // MARK: - Eligibility

    func testCanApplyTextColorMutation() {
        let oldDesc = GTK4DescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(GTK4TextDescriptor(content: "Old")))
        let newDesc = GTK4DescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(GTK4TextDescriptor(content: "New")))
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc)),
            new: gtkIdentifyDescriptorTree(newDesc)
        )
        XCTAssertTrue(gtkCanApplyTextColorHostMutation(plan: plan))
    }

    func testCannotApplyLayoutMutation() {
        let oldDesc = GTK4DescriptorNode(kind: .vStack, typeName: "VStack",
                                          props: .vStack(GTK4VStackDescriptor(spacing: 0, alignment: .center)))
        let newDesc = GTK4DescriptorNode(kind: .vStack, typeName: "VStack",
                                          props: .vStack(GTK4VStackDescriptor(spacing: 8, alignment: .center)))
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc)),
            new: gtkIdentifyDescriptorTree(newDesc)
        )
        XCTAssertFalse(gtkCanApplyTextColorHostMutation(plan: plan))
    }

    func testCanApplyMixedTextColorMutation() {
        let oldDesc = GTK4DescriptorNode(kind: .vStack, typeName: "VStack", children: [
            GTK4DescriptorNode(kind: .text, typeName: "Text",
                               props: .text(GTK4TextDescriptor(content: "Old"))),
            GTK4DescriptorNode(kind: .color, typeName: "Color",
                               props: .color(GTK4ColorDescriptor(red: 1, green: 0, blue: 0, opacity: 1))),
        ])
        let newDesc = GTK4DescriptorNode(kind: .vStack, typeName: "VStack", children: [
            GTK4DescriptorNode(kind: .text, typeName: "Text",
                               props: .text(GTK4TextDescriptor(content: "New"))),
            GTK4DescriptorNode(kind: .color, typeName: "Color",
                               props: .color(GTK4ColorDescriptor(red: 0, green: 1, blue: 0, opacity: 1))),
        ])
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc)),
            new: gtkIdentifyDescriptorTree(newDesc)
        )
        XCTAssertTrue(gtkCanApplyTextColorHostMutation(plan: plan))
    }

    func testOpaqueCompositeRejectsNarrowPath() {
        // A composite node with no described children is opaque —
        // we can't prove nothing changed inside, so the narrow path
        // must reject it and fall back to full rebuild.
        let desc = GTK4DescriptorNode(kind: .composite, typeName: "TextField")
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(desc)),
            new: gtkIdentifyDescriptorTree(desc)
        )
        XCTAssertEqual(plan.kind, .reuse)
        XCTAssertFalse(gtkCanApplyTextColorHostMutation(plan: plan))
    }

    func testOpaqueCompositeInsideVStackRejectsNarrowPath() {
        // A VStack with an opaque composite child should also reject.
        let desc = GTK4DescriptorNode(kind: .vStack, typeName: "VStack", children: [
            GTK4DescriptorNode(kind: .text, typeName: "Text",
                               props: .text(GTK4TextDescriptor(content: "Hello"))),
            GTK4DescriptorNode(kind: .composite, typeName: "TextField"),
        ])
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(desc)),
            new: gtkIdentifyDescriptorTree(desc)
        )
        XCTAssertFalse(gtkCanApplyTextColorHostMutation(plan: plan))
    }

    // MARK: - Slider descriptor tests

    func testDescribeSlider() {
        let slider = Slider(value: .constant(0.5), in: 0...1, step: 0.1)
        let node = gtkDescribeView(slider)
        XCTAssertEqual(node.kind, .slider)
        if case let .slider(desc) = node.props {
            XCTAssertEqual(desc.value, 0.5)
            XCTAssertEqual(desc.range, 0...1)
            XCTAssertEqual(desc.step, 0.1)
        } else {
            XCTFail("Expected slider props")
        }
    }

    func testPlanSliderValueChange() {
        let oldDesc = GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(GTK4SliderDescriptor(value: 0.3, range: 0...1, step: 0.01)))
        let newDesc = GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(GTK4SliderDescriptor(value: 0.7, range: 0...1, step: 0.01)))
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc)),
            new: gtkIdentifyDescriptorTree(newDesc)
        )
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .sliderValue)
    }

    func testPlanSliderConfigurationChange() {
        let oldDesc = GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(GTK4SliderDescriptor(value: 0.5, range: 0...1, step: 0.01)))
        let newDesc = GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(GTK4SliderDescriptor(value: 0.5, range: 0...10, step: 0.1)))
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc)),
            new: gtkIdentifyDescriptorTree(newDesc)
        )
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .sliderConfiguration)
    }

    func testCanApplySliderValueMutation() {
        let oldDesc = GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(GTK4SliderDescriptor(value: 0.3, range: 0...1, step: 0.01)))
        let newDesc = GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(GTK4SliderDescriptor(value: 0.7, range: 0...1, step: 0.01)))
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc)),
            new: gtkIdentifyDescriptorTree(newDesc)
        )
        XCTAssertTrue(gtkCanApplyTextColorHostMutation(plan: plan))
    }

    func testCannotApplySliderConfigurationMutation() {
        let oldDesc = GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(GTK4SliderDescriptor(value: 0.5, range: 0...1, step: 0.01)))
        let newDesc = GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(GTK4SliderDescriptor(value: 0.5, range: 0...10, step: 0.1)))
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc)),
            new: gtkIdentifyDescriptorTree(newDesc)
        )
        XCTAssertFalse(gtkCanApplyTextColorHostMutation(plan: plan))
    }

    func testMixedTextSliderMutation() {
        let oldDesc = GTK4DescriptorNode(kind: .vStack, typeName: "VStack", children: [
            GTK4DescriptorNode(kind: .text, typeName: "Text",
                               props: .text(GTK4TextDescriptor(content: "Old"))),
            GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                               props: .slider(GTK4SliderDescriptor(value: 0.3, range: 0...1, step: 0.01))),
        ])
        let newDesc = GTK4DescriptorNode(kind: .vStack, typeName: "VStack", children: [
            GTK4DescriptorNode(kind: .text, typeName: "Text",
                               props: .text(GTK4TextDescriptor(content: "New"))),
            GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                               props: .slider(GTK4SliderDescriptor(value: 0.7, range: 0...1, step: 0.01))),
        ])
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc)),
            new: gtkIdentifyDescriptorTree(newDesc)
        )
        XCTAssertTrue(gtkCanApplyTextColorHostMutation(plan: plan))
    }

    func testSliderSlotSurvivesValueUpdate() {
        let oldDesc = GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(GTK4SliderDescriptor(value: 0.3, range: 0...1, step: 0.01)))
        let newDesc = GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(GTK4SliderDescriptor(value: 0.7, range: 0...1, step: 0.01)))
        let oldId = gtkIdentifyDescriptorTree(oldDesc)
        let newId = gtkIdentifyDescriptorTree(newDesc)

        // Create executor with a pre-assigned slider slot
        var executor = gtkMakeExecutorTree(from: oldId)
        executor = GTK4RetainedExecutorNode(
            identity: executor.identity, kind: executor.kind,
            lastDescriptor: executor.lastDescriptor, nativeSlotID: 42)

        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(oldId), new: newId)
        let action = gtkExecuteDescriptorPlan(old: executor, plan: plan)

        // Slot should propagate through to resulting node
        XCTAssertEqual(action.resultingNode.nativeSlotID, 42)
        XCTAssertEqual(action.kind, .update)
        XCTAssertEqual(action.updateIntent, .sliderValue)
    }

    func testSliderHookMutationWithSlot() {
        let oldDesc = GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(GTK4SliderDescriptor(value: 0.3, range: 0...1, step: 0.01)))
        let newDesc = GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(GTK4SliderDescriptor(value: 0.7, range: 0...1, step: 0.01)))
        let oldId = gtkIdentifyDescriptorTree(oldDesc)
        let newId = gtkIdentifyDescriptorTree(newDesc)
        let executor = gtkMakeExecutorTree(from: oldId)
        let plan = gtkPlanDescriptorTree(old: gtkRetainDescriptorTree(oldId), new: newId)
        let action = gtkExecuteDescriptorPlan(old: executor, plan: plan)

        // Descriptive hook (no live widget) should succeed
        let result = gtkApplyHook(action: action)
        XCTAssertEqual(result.kind, .updated)
        XCTAssertEqual(result.updateIntent, .sliderValue)
        XCTAssertTrue(result.mutationSucceeded)
    }

    // MARK: - Wrapper mutation tests (padding only on GTK4)

    func testDescribePaddedView() {
        let node = gtkDescribeView(Text("Hello").padding(12))
        XCTAssertEqual(node.kind, .padding)
        if case let .padding(desc) = node.props {
            XCTAssertEqual(desc.top, 12)
            XCTAssertEqual(desc.bottom, 12)
            XCTAssertEqual(desc.leading, 12)
            XCTAssertEqual(desc.trailing, 12)
        } else {
            XCTFail("Expected padding props")
        }
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].kind, .text)
    }

    func testPlanPaddingChange() {
        let oldDesc = GTK4DescriptorNode(kind: .padding, typeName: "PaddedView",
                                          props: .padding(GTK4PaddingDescriptor(top: 8, bottom: 8, leading: 8, trailing: 8)),
                                          children: [GTK4DescriptorNode(kind: .text, typeName: "Text",
                                                                         props: .text(GTK4TextDescriptor(content: "A")))])
        let newDesc = GTK4DescriptorNode(kind: .padding, typeName: "PaddedView",
                                          props: .padding(GTK4PaddingDescriptor(top: 16, bottom: 16, leading: 16, trailing: 16)),
                                          children: [GTK4DescriptorNode(kind: .text, typeName: "Text",
                                                                         props: .text(GTK4TextDescriptor(content: "A")))])
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc)),
            new: gtkIdentifyDescriptorTree(newDesc)
        )
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .paddingLayout)
    }

    func testCanApplyPaddingMutation() {
        let oldDesc = GTK4DescriptorNode(kind: .padding, typeName: "PaddedView",
                                          props: .padding(GTK4PaddingDescriptor(top: 8, bottom: 8, leading: 8, trailing: 8)),
                                          children: [GTK4DescriptorNode(kind: .text, typeName: "Text",
                                                                         props: .text(GTK4TextDescriptor(content: "A")))])
        let newDesc = GTK4DescriptorNode(kind: .padding, typeName: "PaddedView",
                                          props: .padding(GTK4PaddingDescriptor(top: 16, bottom: 16, leading: 16, trailing: 16)),
                                          children: [GTK4DescriptorNode(kind: .text, typeName: "Text",
                                                                         props: .text(GTK4TextDescriptor(content: "A")))])
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc)),
            new: gtkIdentifyDescriptorTree(newDesc)
        )
        XCTAssertTrue(gtkCanApplyTextColorHostMutation(plan: plan))
    }

    func testMixedPaddingAndTextMutation() {
        let oldDesc = GTK4DescriptorNode(kind: .padding, typeName: "PaddedView",
                                          props: .padding(GTK4PaddingDescriptor(top: 8, bottom: 8, leading: 8, trailing: 8)),
                                          children: [GTK4DescriptorNode(kind: .text, typeName: "Text",
                                                                         props: .text(GTK4TextDescriptor(content: "Old")))])
        let newDesc = GTK4DescriptorNode(kind: .padding, typeName: "PaddedView",
                                          props: .padding(GTK4PaddingDescriptor(top: 16, bottom: 16, leading: 16, trailing: 16)),
                                          children: [GTK4DescriptorNode(kind: .text, typeName: "Text",
                                                                         props: .text(GTK4TextDescriptor(content: "New")))])
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc)),
            new: gtkIdentifyDescriptorTree(newDesc)
        )
        XCTAssertTrue(gtkCanApplyTextColorHostMutation(plan: plan))
    }

    func testPaddingSlotSurvivesUpdate() {
        let oldDesc = GTK4DescriptorNode(kind: .padding, typeName: "PaddedView",
                                          props: .padding(GTK4PaddingDescriptor(top: 8, bottom: 8, leading: 8, trailing: 8)),
                                          children: [GTK4DescriptorNode(kind: .text, typeName: "Text",
                                                                         props: .text(GTK4TextDescriptor(content: "A")))])
        let newDesc = GTK4DescriptorNode(kind: .padding, typeName: "PaddedView",
                                          props: .padding(GTK4PaddingDescriptor(top: 16, bottom: 16, leading: 16, trailing: 16)),
                                          children: [GTK4DescriptorNode(kind: .text, typeName: "Text",
                                                                         props: .text(GTK4TextDescriptor(content: "A")))])
        let oldId = gtkIdentifyDescriptorTree(oldDesc)
        let newId = gtkIdentifyDescriptorTree(newDesc)
        var executor = gtkMakeExecutorTree(from: oldId)
        let slotsByIdentity: [GTK4DescriptorIdentity: Int] = [
            GTK4DescriptorIdentity(path: []): 50,
            GTK4DescriptorIdentity(path: [0]): 51,
        ]
        executor = gtkAssignNativeSlots(executor, slotsByIdentity: slotsByIdentity)

        let plan = gtkPlanDescriptorTree(old: gtkRetainDescriptorTree(oldId), new: newId)
        let action = gtkExecuteDescriptorPlan(old: executor, plan: plan)

        XCTAssertEqual(action.resultingNode.nativeSlotID, 50)
        XCTAssertEqual(action.resultingNode.children[0].nativeSlotID, 51)
    }

    // MARK: - Phase 9: ColorMixer proof tests

    func testDescribeHStack() {
        let node = gtkDescribeView(HStack {
            Text("A")
            Text("B")
        })
        XCTAssertEqual(node.kind, .hStack)
        XCTAssertEqual(node.children.count, 2)
        XCTAssertEqual(node.children[0].kind, .text)
        XCTAssertEqual(node.children[1].kind, .text)
    }

    func testDescribeFontModifiedView() {
        let node = gtkDescribeView(Text("Hello").font(.title))
        XCTAssertEqual(node.kind, .font)
        if case let .font(desc) = node.props {
            XCTAssertEqual(desc.font, .title)
        } else {
            XCTFail("Expected font props")
        }
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].kind, .text)
    }

    func testDescribeDivider() {
        let node = gtkDescribeView(SwiftOpenUI.Divider())
        XCTAssertEqual(node.kind, .divider)
    }

    func testDescribeSpacer() {
        let node = gtkDescribeView(Spacer())
        XCTAssertEqual(node.kind, .spacer)
    }

    func testFontChangeRejectsNarrowPath() {
        let oldDesc = GTK4DescriptorNode(kind: .font, typeName: "FontModifiedView",
                                          props: .font(GTK4FontDescriptor(font: .title)),
                                          children: [GTK4DescriptorNode(kind: .text, typeName: "Text",
                                                                         props: .text(GTK4TextDescriptor(content: "A")))])
        let newDesc = GTK4DescriptorNode(kind: .font, typeName: "FontModifiedView",
                                          props: .font(GTK4FontDescriptor(font: .body)),
                                          children: [GTK4DescriptorNode(kind: .text, typeName: "Text",
                                                                         props: .text(GTK4TextDescriptor(content: "A")))])
        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldDesc)),
            new: gtkIdentifyDescriptorTree(newDesc))
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .fontStyle)
        XCTAssertFalse(gtkCanApplyTextColorHostMutation(plan: plan))
    }

    func testColorMixerSliderSubtreeEligible() {
        func text(_ s: String) -> GTK4DescriptorNode {
            GTK4DescriptorNode(kind: .text, typeName: "Text", props: .text(GTK4TextDescriptor(content: s)))
        }
        func color(_ r: Double, _ g: Double, _ b: Double) -> GTK4DescriptorNode {
            GTK4DescriptorNode(kind: .color, typeName: "Color",
                                props: .color(GTK4ColorDescriptor(red: r, green: g, blue: b, opacity: 1)))
        }
        func font(_ child: GTK4DescriptorNode) -> GTK4DescriptorNode {
            GTK4DescriptorNode(kind: .font, typeName: "FontModifiedView",
                                props: .font(GTK4FontDescriptor(font: .headline)), children: [child])
        }
        func fg(_ child: GTK4DescriptorNode) -> GTK4DescriptorNode {
            GTK4DescriptorNode(kind: .foregroundColor, typeName: "ForegroundColorView",
                                props: .foregroundColor(GTK4ColorDescriptor(red: 0.5, green: 0.5, blue: 0.5, opacity: 1)),
                                children: [child])
        }
        func slider(_ val: Double) -> GTK4DescriptorNode {
            GTK4DescriptorNode(kind: .slider, typeName: "Slider",
                                props: .slider(GTK4SliderDescriptor(value: val, range: 0...255, step: 1)))
        }

        func tree(hex: String, rgb: String, r: Double, g: Double, b: Double) -> GTK4DescriptorNode {
            GTK4DescriptorNode(kind: .vStack, typeName: "VStack", children: [
                fg(font(text("Color Studio"))),
                GTK4DescriptorNode(kind: .hStack, typeName: "HStack", children: [
                    color(r / 255, g / 255, b / 255),
                    GTK4DescriptorNode(kind: .vStack, typeName: "VStack", children: [
                        fg(font(text(hex))),
                        fg(font(text(rgb))),
                    ]),
                    GTK4DescriptorNode(kind: .spacer, typeName: "Spacer"),
                ]),
                GTK4DescriptorNode(kind: .divider, typeName: "Divider"),
                GTK4DescriptorNode(kind: .vStack, typeName: "VStack", children: [
                    GTK4DescriptorNode(kind: .hStack, typeName: "HStack", children: [
                        fg(font(text("R"))), slider(r), fg(font(text("\(Int(r))"))),
                    ]),
                    GTK4DescriptorNode(kind: .hStack, typeName: "HStack", children: [
                        fg(font(text("G"))), slider(g), fg(font(text("\(Int(g))"))),
                    ]),
                    GTK4DescriptorNode(kind: .hStack, typeName: "HStack", children: [
                        fg(font(text("B"))), slider(b), fg(font(text("\(Int(b))"))),
                    ]),
                ]),
                GTK4DescriptorNode(kind: .divider, typeName: "Divider"),
                GTK4DescriptorNode(kind: .spacer, typeName: "Spacer"),
            ])
        }

        let oldTree = tree(hex: "#5080DC", rgb: "R: 80  G: 128  B: 220", r: 80, g: 128, b: 220)
        let newTree = tree(hex: "#5082DC", rgb: "R: 80  G: 130  B: 220", r: 80, g: 130, b: 220)

        let plan = gtkPlanDescriptorTree(
            old: gtkRetainDescriptorTree(gtkIdentifyDescriptorTree(oldTree)),
            new: gtkIdentifyDescriptorTree(newTree))

        XCTAssertTrue(gtkCanApplyTextColorHostMutation(plan: plan))
    }
}
