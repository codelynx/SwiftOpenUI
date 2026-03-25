import XCTest
@testable import SwiftOpenUI
@testable import BackendWeb

final class WebDescriptorTests: XCTestCase {

    // MARK: - Describe

    func testDescribeText() {
        let node = webDescribeView(Text("Hello"))
        XCTAssertEqual(node.kind, .text)
        if case let .text(desc) = node.props {
            XCTAssertEqual(desc.content, "Hello")
        } else {
            XCTFail("Expected text props")
        }
    }

    func testDescribeColor() {
        let node = webDescribeView(Color.red)
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
        let node = webDescribeView(VStack {
            Text("A")
            Text("B")
        })
        XCTAssertEqual(node.kind, .vStack)
        XCTAssertEqual(node.children.count, 2)
        XCTAssertEqual(node.children[0].kind, .text)
        XCTAssertEqual(node.children[1].kind, .text)
    }

    func testDescribeIgnoresSafeAreaCarriesConfiguration() {
        let node = webDescribeView(
            Text("Hello").ignoresSafeArea([.container], edges: .horizontal)
        )

        XCTAssertEqual(node.kind, .composite)
        XCTAssertEqual(node.typeName, "IgnoresSafeAreaView")
        XCTAssertEqual(
            node.props,
            .ignoresSafeArea(
                WebIgnoresSafeAreaDescriptor(
                    regionsRawValue: SafeAreaRegions.container.rawValue,
                    edgesRawValue: Edge.Set.horizontal.rawValue
                )
            )
        )
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].kind, .text)
    }

    func testDescribeSafeAreaInsetCarriesEdgeAlignmentAndSpacing() {
        let node = webDescribeView(
            Text("Body").safeAreaInset(edge: .trailing, alignment: .bottom, spacing: 12) {
                Text("Inset")
            }
        )

        XCTAssertEqual(node.kind, .composite)
        XCTAssertEqual(node.typeName, "SafeAreaInsetView")
        XCTAssertEqual(
            node.props,
            .safeAreaInset(
                WebSafeAreaInsetDescriptor(
                    edge: .trailing,
                    horizontalAlignment: nil,
                    verticalAlignment: .bottom,
                    spacing: 12
                )
            )
        )
        XCTAssertEqual(node.children.count, 2)
        XCTAssertEqual(node.children[0].kind, .text)
        XCTAssertEqual(node.children[1].kind, .text)
    }

    func testDescribeSafeAreaInsetTopMatchesDOMChildOrder() {
        let node = webDescribeView(
            Text("Body").safeAreaInset(edge: .top) {
                Text("Inset")
            }
        )

        XCTAssertEqual(node.typeName, "SafeAreaInsetView")
        XCTAssertEqual(node.children.count, 2)
        if case let .text(desc) = node.children[0].props {
            XCTAssertEqual(desc.content, "Inset")
        } else {
            XCTFail("Expected inset text first")
        }
        if case let .text(desc) = node.children[1].props {
            XCTAssertEqual(desc.content, "Body")
        } else {
            XCTFail("Expected content text second")
        }
    }

    func testDescribeSafeAreaInsetLeadingMatchesDOMChildOrder() {
        let node = webDescribeView(
            Text("Body").safeAreaInset(edge: .leading) {
                Text("Inset")
            }
        )

        XCTAssertEqual(node.typeName, "SafeAreaInsetView")
        XCTAssertEqual(node.children.count, 2)
        if case let .text(desc) = node.children[0].props {
            XCTAssertEqual(desc.content, "Inset")
        } else {
            XCTFail("Expected inset text first")
        }
        if case let .text(desc) = node.children[1].props {
            XCTAssertEqual(desc.content, "Body")
        } else {
            XCTFail("Expected content text second")
        }
    }

    func testSafeAreaContainerStyleClampsNegativeGap() {
        let style = webSafeAreaContainerStyle(edge: .top, spacing: -8)
        XCTAssertTrue(style.contains("gap: 0px"))
    }

    func testSafeAreaContentWrapperStyleUsesNegativeMarginForTopOverlap() {
        let style = webSafeAreaContentWrapperStyle(edge: .top, spacing: -8)
        XCTAssertTrue(style.contains("margin-top: -8px"))
    }

    func testSafeAreaInsetWrapperStyleUsesNegativeMarginForTrailingOverlap() {
        let style = webSafeAreaInsetWrapperStyle(edge: .trailing, alignment: .vertical(.bottom), spacing: -6)
        XCTAssertTrue(style.contains("margin-left: -6px"))
        XCTAssertTrue(style.contains("align-items: flex-end"))
    }

    // MARK: - Identify

    func testIdentifyAssignsPaths() {
        let node = WebDescriptorNode(kind: .vStack, typeName: "VStack", children: [
            WebDescriptorNode(kind: .text, typeName: "Text", props: .text(WebTextDescriptor(content: "A"))),
            WebDescriptorNode(kind: .text, typeName: "Text", props: .text(WebTextDescriptor(content: "B"))),
        ])
        let identified = webIdentifyDescriptorTree(node)
        XCTAssertEqual(identified.identity.path, [])
        XCTAssertEqual(identified.children[0].identity.path, [0])
        XCTAssertEqual(identified.children[1].identity.path, [1])
    }

    // MARK: - Match

    func testMatchSameStructure() {
        let desc = WebDescriptorNode(kind: .text, typeName: "Text",
                                       props: .text(WebTextDescriptor(content: "Hello")))
        let old = webRetainDescriptorTree(webIdentifyDescriptorTree(desc))
        let new = webIdentifyDescriptorTree(desc)
        let match = webMatchDescriptorTree(old: old, new: new)
        XCTAssertEqual(match.kind, .reuse)
    }

    func testMatchDifferentKind() {
        let oldDesc = WebDescriptorNode(kind: .text, typeName: "Text")
        let newDesc = WebDescriptorNode(kind: .color, typeName: "Color")
        let old = webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc))
        let new = webIdentifyDescriptorTree(newDesc)
        let match = webMatchDescriptorTree(old: old, new: new)
        XCTAssertEqual(match.kind, .replace)
    }

    // MARK: - Plan

    func testPlanTextChange() {
        let oldDesc = WebDescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(WebTextDescriptor(content: "Old")))
        let newDesc = WebDescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(WebTextDescriptor(content: "New")))
        let old = webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc))
        let new = webIdentifyDescriptorTree(newDesc)
        let plan = webPlanDescriptorTree(old: old, new: new)
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .textContent)
    }

    func testPlanColorChange() {
        let oldDesc = WebDescriptorNode(kind: .color, typeName: "Color",
                                          props: .color(WebColorDescriptor(red: 1, green: 0, blue: 0, opacity: 1)))
        let newDesc = WebDescriptorNode(kind: .color, typeName: "Color",
                                          props: .color(WebColorDescriptor(red: 0, green: 1, blue: 0, opacity: 1)))
        let old = webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc))
        let new = webIdentifyDescriptorTree(newDesc)
        let plan = webPlanDescriptorTree(old: old, new: new)
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .colorFill)
    }

    func testPlanStructuralChange() {
        let oldDesc = WebDescriptorNode(kind: .text, typeName: "Text")
        let newDesc = WebDescriptorNode(kind: .color, typeName: "Color")
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc)
        )
        XCTAssertEqual(plan.kind, .replace)
    }

    func testPlanNoChange() {
        let desc = WebDescriptorNode(kind: .text, typeName: "Text",
                                       props: .text(WebTextDescriptor(content: "Same")))
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(desc)),
            new: webIdentifyDescriptorTree(desc)
        )
        XCTAssertEqual(plan.kind, .reuse)
        XCTAssertEqual(plan.updateIntent, .none)
    }

    // MARK: - Execute

    func testExecuteTextUpdate() {
        let oldDesc = WebDescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(WebTextDescriptor(content: "Old")))
        let newDesc = WebDescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(WebTextDescriptor(content: "New")))
        let oldId = webIdentifyDescriptorTree(oldDesc)
        let newId = webIdentifyDescriptorTree(newDesc)
        let executor = webMakeExecutorTree(from: oldId)
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(oldId),
            new: newId
        )
        let action = webExecuteDescriptorPlan(old: executor, plan: plan)
        XCTAssertEqual(action.kind, .update)
        XCTAssertEqual(action.updateIntent, .textContent)
    }

    // MARK: - Hook

    func testHookTextContent() {
        let oldDesc = WebDescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(WebTextDescriptor(content: "Old")))
        let newDesc = WebDescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(WebTextDescriptor(content: "New")))
        let oldId = webIdentifyDescriptorTree(oldDesc)
        let newId = webIdentifyDescriptorTree(newDesc)
        let executor = webMakeExecutorTree(from: oldId)
        let plan = webPlanDescriptorTree(old: webRetainDescriptorTree(oldId), new: newId)
        let action = webExecuteDescriptorPlan(old: executor, plan: plan)
        let result = webApplyHook(action: action)
        XCTAssertEqual(result.kind, .updated)
        XCTAssertEqual(result.updateIntent, .textContent)
        XCTAssertTrue(result.mutationSucceeded)
    }

    // MARK: - Eligibility

    func testCanApplyTextColorMutation() {
        let oldDesc = WebDescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(WebTextDescriptor(content: "Old")))
        let newDesc = WebDescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(WebTextDescriptor(content: "New")))
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc)
        )
        XCTAssertTrue(webCanApplyTextColorHostMutation(plan: plan))
    }

    func testCannotApplyLayoutMutation() {
        let oldDesc = WebDescriptorNode(kind: .vStack, typeName: "VStack",
                                          props: .vStack(WebVStackDescriptor(spacing: 0, alignment: .center)))
        let newDesc = WebDescriptorNode(kind: .vStack, typeName: "VStack",
                                          props: .vStack(WebVStackDescriptor(spacing: 8, alignment: .center)))
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc)
        )
        XCTAssertFalse(webCanApplyTextColorHostMutation(plan: plan))
    }

    func testCanApplyMixedTextColorMutation() {
        let oldDesc = WebDescriptorNode(kind: .vStack, typeName: "VStack", children: [
            WebDescriptorNode(kind: .text, typeName: "Text",
                               props: .text(WebTextDescriptor(content: "Old"))),
            WebDescriptorNode(kind: .color, typeName: "Color",
                               props: .color(WebColorDescriptor(red: 1, green: 0, blue: 0, opacity: 1))),
        ])
        let newDesc = WebDescriptorNode(kind: .vStack, typeName: "VStack", children: [
            WebDescriptorNode(kind: .text, typeName: "Text",
                               props: .text(WebTextDescriptor(content: "New"))),
            WebDescriptorNode(kind: .color, typeName: "Color",
                               props: .color(WebColorDescriptor(red: 0, green: 1, blue: 0, opacity: 1))),
        ])
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc)
        )
        XCTAssertTrue(webCanApplyTextColorHostMutation(plan: plan))
    }

    func testOpaqueCompositeRejectsNarrowPath() {
        // An opaque composite (Body = Never, no describable conformance) with
        // no described children is rejected — child content is not captured
        // in the descriptor, so we can't prove nothing changed inside.
        let desc = WebDescriptorNode(kind: .composite, typeName: "TextField")
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(desc)),
            new: webIdentifyDescriptorTree(desc)
        )
        XCTAssertEqual(plan.kind, .reuse)
        XCTAssertFalse(webCanApplyTextColorHostMutation(plan: plan))
    }

    func testOpaqueCompositeInsideVStackRejectsNarrowPath() {
        // A VStack with an opaque composite child should also reject.
        let desc = WebDescriptorNode(kind: .vStack, typeName: "VStack", children: [
            WebDescriptorNode(kind: .text, typeName: "Text",
                               props: .text(WebTextDescriptor(content: "Hello"))),
            WebDescriptorNode(kind: .composite, typeName: "TextField"),
        ])
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(desc)),
            new: webIdentifyDescriptorTree(desc)
        )
        XCTAssertFalse(webCanApplyTextColorHostMutation(plan: plan))
    }

    // MARK: - Slot assignment and validation

    func testSlotAssignment() {
        let desc = WebDescriptorNode(kind: .vStack, typeName: "VStack", children: [
            WebDescriptorNode(kind: .text, typeName: "Text",
                               props: .text(WebTextDescriptor(content: "A"))),
            WebDescriptorNode(kind: .color, typeName: "Color",
                               props: .color(WebColorDescriptor(red: 1, green: 0, blue: 0, opacity: 1))),
        ])
        let identified = webIdentifyDescriptorTree(desc)
        let executor = webMakeExecutorTree(from: identified)

        // Simulate slot capture
        let slotsByIdentity: [WebDescriptorIdentity: Int] = [
            WebDescriptorIdentity(path: [0]): 42,
            WebDescriptorIdentity(path: [1]): 43,
        ]
        let assigned = webAssignNativeSlots(executor, slotsByIdentity: slotsByIdentity)

        XCTAssertNil(assigned.nativeSlotID) // VStack root has no slot
        XCTAssertEqual(assigned.children[0].nativeSlotID, 42) // Text
        XCTAssertEqual(assigned.children[1].nativeSlotID, 43) // Color
    }

    func testExecutePlanWithSlots() {
        let oldDesc = WebDescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(WebTextDescriptor(content: "Old")))
        let newDesc = WebDescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(WebTextDescriptor(content: "New")))
        let oldId = webIdentifyDescriptorTree(oldDesc)
        let newId = webIdentifyDescriptorTree(newDesc)

        // Create executor with a pre-assigned slot
        var executor = webMakeExecutorTree(from: oldId)
        executor = webAssignNativeSlots(executor,
            slotsByIdentity: [WebDescriptorIdentity(path: []): 99])

        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(oldId), new: newId)
        let action = webExecuteDescriptorPlan(old: executor, plan: plan)

        XCTAssertEqual(action.kind, .update)
        XCTAssertEqual(action.updateIntent, .textContent)
        // Slot should propagate through to resulting node
        XCTAssertEqual(action.resultingNode.nativeSlotID, 99)
    }

    func testAllSlotsValidWithNilSlot() {
        let oldDesc = WebDescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(WebTextDescriptor(content: "Old")))
        let newDesc = WebDescriptorNode(kind: .text, typeName: "Text",
                                          props: .text(WebTextDescriptor(content: "New")))
        let oldId = webIdentifyDescriptorTree(oldDesc)
        let newId = webIdentifyDescriptorTree(newDesc)
        // No slot assigned — executor has nil nativeSlotID
        let executor = webMakeExecutorTree(from: oldId)
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(oldId), new: newId)
        let action = webExecuteDescriptorPlan(old: executor, plan: plan)

        // Without a slot, validation should fail for text update
        XCTAssertFalse(webAllSlotsValid(action: action))
    }

    func testFontModifiedViewDescribedAsFont() {
        // FontModifiedView now has WebDescribable — produces .font kind with child.
        let node = webDescribeView(
            VStack {
                Text("Hello").font(.title)
            }
        )
        XCTAssertEqual(node.kind, .vStack)
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].kind, .font)
        XCTAssertEqual(node.children[0].children.count, 1)
        XCTAssertEqual(node.children[0].children[0].kind, .text)

        // Plan against itself — reuse, font wrapper is transparent → passes
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(node)),
            new: webIdentifyDescriptorTree(node)
        )
        XCTAssertTrue(webCanApplyTextColorHostMutation(plan: plan))
    }

    // MARK: - Slider descriptor tests

    func testDescribeSlider() {
        let slider = Slider(value: .constant(0.5), in: 0...1, step: 0.1)
        let node = webDescribeView(slider)
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
        let oldDesc = WebDescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(WebSliderDescriptor(value: 0.3, range: 0...1, step: 0.01)))
        let newDesc = WebDescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(WebSliderDescriptor(value: 0.7, range: 0...1, step: 0.01)))
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc)
        )
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .sliderValue)
    }

    func testPlanSliderConfigurationChange() {
        let oldDesc = WebDescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(WebSliderDescriptor(value: 0.5, range: 0...1, step: 0.01)))
        let newDesc = WebDescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(WebSliderDescriptor(value: 0.5, range: 0...10, step: 0.1)))
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc)
        )
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .sliderConfiguration)
    }

    func testCanApplySliderValueMutation() {
        let oldDesc = WebDescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(WebSliderDescriptor(value: 0.3, range: 0...1, step: 0.01)))
        let newDesc = WebDescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(WebSliderDescriptor(value: 0.7, range: 0...1, step: 0.01)))
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc)
        )
        XCTAssertTrue(webCanApplyTextColorHostMutation(plan: plan))
    }

    func testCannotApplySliderConfigurationMutation() {
        let oldDesc = WebDescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(WebSliderDescriptor(value: 0.5, range: 0...1, step: 0.01)))
        let newDesc = WebDescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(WebSliderDescriptor(value: 0.5, range: 0...10, step: 0.1)))
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc)
        )
        XCTAssertFalse(webCanApplyTextColorHostMutation(plan: plan))
    }

    func testMixedTextSliderMutation() {
        let oldDesc = WebDescriptorNode(kind: .vStack, typeName: "VStack", children: [
            WebDescriptorNode(kind: .text, typeName: "Text",
                               props: .text(WebTextDescriptor(content: "Old"))),
            WebDescriptorNode(kind: .slider, typeName: "Slider",
                               props: .slider(WebSliderDescriptor(value: 0.3, range: 0...1, step: 0.01))),
        ])
        let newDesc = WebDescriptorNode(kind: .vStack, typeName: "VStack", children: [
            WebDescriptorNode(kind: .text, typeName: "Text",
                               props: .text(WebTextDescriptor(content: "New"))),
            WebDescriptorNode(kind: .slider, typeName: "Slider",
                               props: .slider(WebSliderDescriptor(value: 0.7, range: 0...1, step: 0.01))),
        ])
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc)
        )
        XCTAssertTrue(webCanApplyTextColorHostMutation(plan: plan))
    }

    func testSliderSlotSurvivesValueUpdate() {
        let oldDesc = WebDescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(WebSliderDescriptor(value: 0.3, range: 0...1, step: 0.01)))
        let newDesc = WebDescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(WebSliderDescriptor(value: 0.7, range: 0...1, step: 0.01)))
        let oldId = webIdentifyDescriptorTree(oldDesc)
        let newId = webIdentifyDescriptorTree(newDesc)

        // Create executor with a pre-assigned slider slot
        var executor = webMakeExecutorTree(from: oldId)
        executor = webAssignNativeSlots(executor,
            slotsByIdentity: [WebDescriptorIdentity(path: []): 42])

        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(oldId), new: newId)
        let action = webExecuteDescriptorPlan(old: executor, plan: plan)

        // Slot should propagate through to resulting node
        XCTAssertEqual(action.resultingNode.nativeSlotID, 42)
        XCTAssertEqual(action.kind, .update)
        XCTAssertEqual(action.updateIntent, .sliderValue)
    }

    func testSliderHookMutationWithSlot() {
        let oldDesc = WebDescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(WebSliderDescriptor(value: 0.3, range: 0...1, step: 0.01)))
        let newDesc = WebDescriptorNode(kind: .slider, typeName: "Slider",
                                          props: .slider(WebSliderDescriptor(value: 0.7, range: 0...1, step: 0.01)))
        let oldId = webIdentifyDescriptorTree(oldDesc)
        let newId = webIdentifyDescriptorTree(newDesc)
        let executor = webMakeExecutorTree(from: oldId)
        let plan = webPlanDescriptorTree(old: webRetainDescriptorTree(oldId), new: newId)
        let action = webExecuteDescriptorPlan(old: executor, plan: plan)

        // Descriptive hook (no live DOM) should succeed
        let result = webApplyHook(action: action)
        XCTAssertEqual(result.kind, .updated)
        XCTAssertEqual(result.updateIntent, .sliderValue)
        XCTAssertTrue(result.mutationSucceeded)
    }

    // MARK: - Wrapper mutation tests

    func testPlanBackgroundColorChange() {
        let oldDesc = WebDescriptorNode(kind: .background, typeName: "BackgroundView",
                                         props: .background(WebColorDescriptor(red: 1, green: 0, blue: 0, opacity: 1)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let newDesc = WebDescriptorNode(kind: .background, typeName: "BackgroundView",
                                         props: .background(WebColorDescriptor(red: 0, green: 1, blue: 0, opacity: 1)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc))
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .backgroundColor)
    }

    func testPlanForegroundColorChange() {
        let oldDesc = WebDescriptorNode(kind: .foregroundColor, typeName: "ForegroundColorView",
                                         props: .foregroundColor(WebColorDescriptor(red: 0, green: 0, blue: 0, opacity: 1)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let newDesc = WebDescriptorNode(kind: .foregroundColor, typeName: "ForegroundColorView",
                                         props: .foregroundColor(WebColorDescriptor(red: 1, green: 0, blue: 0, opacity: 1)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc))
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .foregroundColor)
    }

    func testPlanPaddingChange() {
        let oldDesc = WebDescriptorNode(kind: .padding, typeName: "PaddedView",
                                         props: .padding(WebPaddingDescriptor(top: 8, bottom: 8, leading: 8, trailing: 8)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let newDesc = WebDescriptorNode(kind: .padding, typeName: "PaddedView",
                                         props: .padding(WebPaddingDescriptor(top: 16, bottom: 16, leading: 16, trailing: 16)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc))
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .paddingLayout)
    }

    func testCanApplyBackgroundColorMutation() {
        let oldDesc = WebDescriptorNode(kind: .background, typeName: "BackgroundView",
                                         props: .background(WebColorDescriptor(red: 1, green: 0, blue: 0, opacity: 1)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let newDesc = WebDescriptorNode(kind: .background, typeName: "BackgroundView",
                                         props: .background(WebColorDescriptor(red: 0, green: 1, blue: 0, opacity: 1)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc))
        XCTAssertTrue(webCanApplyTextColorHostMutation(plan: plan))
    }

    func testCanApplyForegroundColorMutation() {
        let oldDesc = WebDescriptorNode(kind: .foregroundColor, typeName: "ForegroundColorView",
                                         props: .foregroundColor(WebColorDescriptor(red: 0, green: 0, blue: 0, opacity: 1)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let newDesc = WebDescriptorNode(kind: .foregroundColor, typeName: "ForegroundColorView",
                                         props: .foregroundColor(WebColorDescriptor(red: 1, green: 0, blue: 0, opacity: 1)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc))
        XCTAssertTrue(webCanApplyTextColorHostMutation(plan: plan))
    }

    func testCanApplyPaddingMutation() {
        let oldDesc = WebDescriptorNode(kind: .padding, typeName: "PaddedView",
                                         props: .padding(WebPaddingDescriptor(top: 8, bottom: 8, leading: 8, trailing: 8)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let newDesc = WebDescriptorNode(kind: .padding, typeName: "PaddedView",
                                         props: .padding(WebPaddingDescriptor(top: 16, bottom: 16, leading: 16, trailing: 16)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc))
        XCTAssertTrue(webCanApplyTextColorHostMutation(plan: plan))
    }

    func testWrapperSlotSurvivesUpdate() {
        let oldDesc = WebDescriptorNode(kind: .background, typeName: "BackgroundView",
                                         props: .background(WebColorDescriptor(red: 1, green: 0, blue: 0, opacity: 1)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let newDesc = WebDescriptorNode(kind: .background, typeName: "BackgroundView",
                                         props: .background(WebColorDescriptor(red: 0, green: 1, blue: 0, opacity: 1)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let oldId = webIdentifyDescriptorTree(oldDesc)
        let newId = webIdentifyDescriptorTree(newDesc)
        var executor = webMakeExecutorTree(from: oldId)
        executor = webAssignNativeSlots(executor, slotsByIdentity: [
            WebDescriptorIdentity(path: []): 60,
            WebDescriptorIdentity(path: [0]): 61,
        ])

        let plan = webPlanDescriptorTree(old: webRetainDescriptorTree(oldId), new: newId)
        let action = webExecuteDescriptorPlan(old: executor, plan: plan)

        XCTAssertEqual(action.resultingNode.nativeSlotID, 60)
        XCTAssertEqual(action.resultingNode.children[0].nativeSlotID, 61)
    }

    func testMixedWrapperAndLeafMutation() {
        let oldDesc = WebDescriptorNode(kind: .background, typeName: "BackgroundView",
                                         props: .background(WebColorDescriptor(red: 1, green: 0, blue: 0, opacity: 1)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "Old")))])
        let newDesc = WebDescriptorNode(kind: .background, typeName: "BackgroundView",
                                         props: .background(WebColorDescriptor(red: 0, green: 1, blue: 0, opacity: 1)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "New")))])
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc))
        XCTAssertTrue(webCanApplyTextColorHostMutation(plan: plan))
    }

    // MARK: - Phase 9: ColorMixer proof tests

    func testDescribeFontModifiedView() {
        let node = webDescribeView(Text("Hello").font(.title))
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
        let node = webDescribeView(SwiftOpenUI.Divider())
        XCTAssertEqual(node.kind, .divider)
        XCTAssertTrue(node.children.isEmpty)
    }

    func testDescribeSpacer() {
        let node = webDescribeView(Spacer())
        XCTAssertEqual(node.kind, .spacer)
        XCTAssertTrue(node.children.isEmpty)
    }

    func testFontChangeRejectsNarrowPath() {
        let oldDesc = WebDescriptorNode(kind: .font, typeName: "FontModifiedView",
                                         props: .font(WebFontDescriptor(font: .title)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let newDesc = WebDescriptorNode(kind: .font, typeName: "FontModifiedView",
                                         props: .font(WebFontDescriptor(font: .body)),
                                         children: [WebDescriptorNode(kind: .text, typeName: "Text",
                                                                       props: .text(WebTextDescriptor(content: "A")))])
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldDesc)),
            new: webIdentifyDescriptorTree(newDesc))
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .fontStyle)
        XCTAssertFalse(webCanApplyTextColorHostMutation(plan: plan))
    }

    func testColorMixerSliderSubtreeEligible() {
        // Model the ColorMixer slider-dependent subtree (header, swatch, sliders).
        // Excludes opaque siblings (Button, TapGestureView+ForEach swatches)
        // which still block the narrow path and require full describability.
        func text(_ s: String) -> WebDescriptorNode {
            WebDescriptorNode(kind: .text, typeName: "Text", props: .text(WebTextDescriptor(content: s)))
        }
        func color(_ r: Double, _ g: Double, _ b: Double) -> WebDescriptorNode {
            WebDescriptorNode(kind: .color, typeName: "Color",
                              props: .color(WebColorDescriptor(red: r, green: g, blue: b, opacity: 1)))
        }
        func font(_ child: WebDescriptorNode) -> WebDescriptorNode {
            WebDescriptorNode(kind: .font, typeName: "FontModifiedView",
                              props: .font(WebFontDescriptor(font: .headline)), children: [child])
        }
        func fg(_ child: WebDescriptorNode) -> WebDescriptorNode {
            WebDescriptorNode(kind: .foregroundColor, typeName: "ForegroundColorView",
                              props: .foregroundColor(WebColorDescriptor(red: 0.5, green: 0.5, blue: 0.5, opacity: 1)),
                              children: [child])
        }
        func slider(_ val: Double) -> WebDescriptorNode {
            WebDescriptorNode(kind: .slider, typeName: "Slider",
                              props: .slider(WebSliderDescriptor(value: val, range: 0...255, step: 1)))
        }

        func tree(hex: String, rgb: String, r: Double, g: Double, b: Double) -> WebDescriptorNode {
            WebDescriptorNode(kind: .vStack, typeName: "VStack", children: [
                // Header
                fg(font(text("Color Studio"))),
                // Swatch + values
                WebDescriptorNode(kind: .hStack, typeName: "HStack", children: [
                    color(r / 255, g / 255, b / 255),
                    WebDescriptorNode(kind: .vStack, typeName: "VStack", children: [
                        fg(font(text(hex))),
                        fg(font(text(rgb))),
                    ]),
                    WebDescriptorNode(kind: .spacer, typeName: "Spacer"),
                ]),
                WebDescriptorNode(kind: .divider, typeName: "Divider"),
                // Sliders
                WebDescriptorNode(kind: .vStack, typeName: "VStack", children: [
                    WebDescriptorNode(kind: .hStack, typeName: "HStack", children: [
                        fg(font(text("R"))), slider(r), fg(font(text("\(Int(r))"))),
                    ]),
                    WebDescriptorNode(kind: .hStack, typeName: "HStack", children: [
                        fg(font(text("G"))), slider(g), fg(font(text("\(Int(g))"))),
                    ]),
                    WebDescriptorNode(kind: .hStack, typeName: "HStack", children: [
                        fg(font(text("B"))), slider(b), fg(font(text("\(Int(b))"))),
                    ]),
                ]),
                WebDescriptorNode(kind: .divider, typeName: "Divider"),
                WebDescriptorNode(kind: .spacer, typeName: "Spacer"),
            ])
        }

        let oldTree = tree(hex: "#5080DC", rgb: "R: 80  G: 128  B: 220", r: 80, g: 128, b: 220)
        let newTree = tree(hex: "#5082DC", rgb: "R: 80  G: 130  B: 220", r: 80, g: 130, b: 220)

        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(oldTree)),
            new: webIdentifyDescriptorTree(newTree))

        // The narrow path should pass: only text content, color fill, and slider value changed.
        // Font, divider, spacer, and button nodes are all reused.
        XCTAssertTrue(webCanApplyTextColorHostMutation(plan: plan))
    }

    // MARK: - Searchable Descriptor Tests

    func testDescribeSearchableDefault() {
        @SwiftOpenUI.State var query = ""
        let view = Text("Content").searchable(text: $query)
        let node = webDescribeView(view)

        XCTAssertEqual(node.kind, .composite)
        XCTAssertEqual(node.typeName, "SearchableView")
        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Search",
                    placement: "automatic",
                    isPresented: nil,
                    tokens: [],
                    tokenMode: nil,
                    suggestions: [],
                    scopes: [],
                    selectedScopeID: nil
                )
            )
        )
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].kind, .text)
    }

    func testDescribeSearchableWithPlacement() {
        @SwiftOpenUI.State var query = ""
        let view = Text("Content").searchable(
            text: $query,
            placement: .toolbar,
            prompt: "Find items"
        )
        let node = webDescribeView(view)

        XCTAssertEqual(node.kind, .composite)
        XCTAssertEqual(node.typeName, "SearchableView")
        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Find items",
                    placement: "toolbar",
                    isPresented: nil,
                    tokens: [],
                    tokenMode: nil,
                    suggestions: [],
                    scopes: [],
                    selectedScopeID: nil
                )
            )
        )
    }

    func testDescribeSearchableWithIsPresented() {
        @SwiftOpenUI.State var query = ""
        @SwiftOpenUI.State var presented = true
        let view = Text("Content").searchable(
            text: $query,
            isPresented: $presented
        )
        let node = webDescribeView(view)

        XCTAssertEqual(node.kind, .composite)
        XCTAssertEqual(node.typeName, "SearchableView")
        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Search",
                    placement: "automatic",
                    isPresented: true,
                    tokens: [],
                    tokenMode: nil,
                    suggestions: [],
                    scopes: [],
                    selectedScopeID: nil
                )
            )
        )
    }

    func testDescribeSearchableIsPresentedFalse() {
        @SwiftOpenUI.State var query = ""
        @SwiftOpenUI.State var presented = false
        let view = Text("Content").searchable(
            text: $query,
            isPresented: $presented
        )
        let node = webDescribeView(view)

        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Search",
                    placement: "automatic",
                    isPresented: false,
                    tokens: [],
                    tokenMode: nil,
                    suggestions: [],
                    scopes: [],
                    selectedScopeID: nil
                )
            )
        )
    }

    func testDescribeSearchableNavigationBarDrawerPlacement() {
        @SwiftOpenUI.State var query = ""
        let view = Text("Content").searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        let node = webDescribeView(view)

        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Search",
                    placement: "navigationBarDrawerAlways",
                    isPresented: nil,
                    tokens: [],
                    tokenMode: nil,
                    suggestions: [],
                    scopes: [],
                    selectedScopeID: nil
                )
            )
        )
    }

    func testDescribeSearchableSidebarPlacement() {
        @SwiftOpenUI.State var query = ""
        let view = Text("Content").searchable(
            text: $query,
            placement: .sidebar
        )
        let node = webDescribeView(view)

        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Search",
                    placement: "sidebar",
                    isPresented: nil,
                    tokens: [],
                    tokenMode: nil,
                    suggestions: [],
                    scopes: [],
                    selectedScopeID: nil
                )
            )
        )
    }

    // MARK: - Safe Area Padding Descriptor Tests

    func testDescribeSafeAreaPaddingDefault() {
        let view = Text("Content").safeAreaPadding()
        let node = webDescribeView(view)

        XCTAssertEqual(node.kind, .composite)
        XCTAssertEqual(node.typeName, "SafeAreaPaddingView")
        // nil length → synthetic default 16 on all edges
        XCTAssertEqual(
            node.props,
            .safeAreaPadding(
                WebSafeAreaPaddingDescriptor(top: 16, bottom: 16, leading: 16, trailing: 16)
            )
        )
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].kind, .text)
    }

    func testDescribeSafeAreaPaddingExplicitLength() {
        let view = Text("Content").safeAreaPadding(24)
        let node = webDescribeView(view)

        XCTAssertEqual(
            node.props,
            .safeAreaPadding(
                WebSafeAreaPaddingDescriptor(top: 24, bottom: 24, leading: 24, trailing: 24)
            )
        )
    }

    func testDescribeSafeAreaPaddingSelectedEdgesExplicit() {
        let view = Text("Content").safeAreaPadding(.horizontal, 10)
        let node = webDescribeView(view)

        XCTAssertEqual(
            node.props,
            .safeAreaPadding(
                WebSafeAreaPaddingDescriptor(top: 0, bottom: 0, leading: 10, trailing: 10)
            )
        )
    }

    func testDescribeSafeAreaPaddingSelectedEdgesNilLength() {
        let view = Text("Content").safeAreaPadding(.vertical)
        let node = webDescribeView(view)

        // nil length → synthetic default 16 on vertical edges only
        XCTAssertEqual(
            node.props,
            .safeAreaPadding(
                WebSafeAreaPaddingDescriptor(top: 16, bottom: 16, leading: 0, trailing: 0)
            )
        )
    }

    func testDescribeSafeAreaPaddingTopOnly() {
        let view = Text("Content").safeAreaPadding(.top, 8)
        let node = webDescribeView(view)

        XCTAssertEqual(
            node.props,
            .safeAreaPadding(
                WebSafeAreaPaddingDescriptor(top: 8, bottom: 0, leading: 0, trailing: 0)
            )
        )
    }

    func testDescribeSafeAreaPaddingNegativeClampsToZero() {
        let view = Text("Content").safeAreaPadding(-8)
        let node = webDescribeView(view)

        // Negative lengths clamp to 0 — CSS padding cannot be negative
        XCTAssertEqual(
            node.props,
            .safeAreaPadding(
                WebSafeAreaPaddingDescriptor(top: 0, bottom: 0, leading: 0, trailing: 0)
            )
        )
    }

    // MARK: - Sheet Dismiss Transition Tracking Tests
    //
    // These test the transition detection algorithm directly using plain
    // dictionaries, matching the logic in WebViewHost.rebuild(). We cannot
    // instantiate WebViewHost in unit tests (requires JavaScriptKit runtime).

    func testSheetTransitionTrackingPresentedThenDismissed() {
        var previousState: [Int: (() -> Void)?] = [:]
        var currentState: [Int: (() -> Void)?] = [:]
        var counter = 0

        // First render: sheet presenting at key 0
        var dismissed = false
        currentState[counter] = { dismissed = true }
        counter += 1

        // Swap for next render
        previousState = currentState
        currentState = [:]
        counter = 0

        // Second render: sheet not presenting (key 0 not registered)
        counter += 1 // still consume the key slot

        // Detect transition
        for (k, callback) in previousState {
            if currentState[k] == nil, let dismiss = callback {
                dismiss()
            }
        }

        XCTAssertTrue(dismissed, "onDismiss should fire on presented→dismissed transition")
    }

    func testSheetTransitionTrackingStaysPresented() {
        var previousState: [Int: (() -> Void)?] = [:]
        var currentState: [Int: (() -> Void)?] = [:]

        // First render: sheet presenting at key 0
        currentState[0] = { XCTFail("onDismiss should not fire while still presented") }

        // Swap
        previousState = currentState
        currentState = [:]

        // Second render: sheet still presenting at key 0
        currentState[0] = { XCTFail("onDismiss should not fire") }

        // Detect transition — should NOT fire
        for (k, callback) in previousState {
            if currentState[k] == nil, let dismiss = callback {
                dismiss()
            }
        }
    }

    func testSheetTransitionTrackingNeverPresented() {
        let previousState: [Int: (() -> Void)?] = [:]
        let currentState: [Int: (() -> Void)?] = [:]

        // Detect transition — should NOT fire (empty dictionaries)
        for (k, callback) in previousState {
            if currentState[k] == nil, let dismiss = callback {
                dismiss()
            }
        }
    }

    func testSheetTransitionTrackingNoCrossTalkBetweenSiblings() {
        var previousState: [Int: (() -> Void)?] = [:]
        var currentState: [Int: (() -> Void)?] = [:]

        // First render: sheet A (key 0) presenting, sheet B (key 1) not
        var aDismissed = false
        currentState[0] = { aDismissed = true }

        // Swap
        previousState = currentState
        currentState = [:]

        // Second render: A still presenting, B still not
        currentState[0] = { XCTFail("A is still presenting") }

        // Detect transition
        for (k, callback) in previousState {
            if currentState[k] == nil, let dismiss = callback {
                dismiss()
            }
        }

        XCTAssertFalse(aDismissed, "Sheet A should not have onDismiss fired — it's still presenting")
    }

    func testSheetTransitionTrackingOnlyDismissedSheetFires() {
        var previousState: [Int: (() -> Void)?] = [:]
        var currentState: [Int: (() -> Void)?] = [:]

        // First render: both sheets presenting
        var aDismissed = false
        var bDismissed = false
        currentState[0] = { aDismissed = true }
        currentState[1] = { bDismissed = true }

        // Swap
        previousState = currentState
        currentState = [:]

        // Second render: A dismissed, B still presenting
        currentState[1] = { XCTFail("B is still presenting") }

        // Detect transition
        for (k, callback) in previousState {
            if currentState[k] == nil, let dismiss = callback {
                dismiss()
            }
        }

        XCTAssertTrue(aDismissed, "Sheet A should have onDismiss fired")
        XCTAssertFalse(bDismissed, "Sheet B should NOT have onDismiss fired — still presenting")
    }

    // MARK: - Searchable Token Descriptor Tests

    private struct TestToken: Identifiable {
        let id: String
        let name: String
    }

    func testDescribeSearchableWithTokens() {
        @SwiftOpenUI.State var query = ""
        @SwiftOpenUI.State var tokens = [
            TestToken(id: "1", name: "Swift"),
            TestToken(id: "2", name: "Rust"),
        ]
        let view = Text("Content").searchable(
            text: $query,
            tokens: $tokens,
            prompt: "Search"
        ) { token in
            Text(token.name)
        }
        let node = webDescribeView(view)

        XCTAssertEqual(node.kind, .composite)
        XCTAssertEqual(node.typeName, "SearchableView")
        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Search",
                    placement: "automatic",
                    isPresented: nil,
                    tokens: [
                        WebSearchTokenDescriptor(id: "1", label: "Swift"),
                        WebSearchTokenDescriptor(id: "2", label: "Rust"),
                    ],
                    tokenMode: "tokens",
                    suggestions: [],
                    scopes: [],
                    selectedScopeID: nil
                )
            )
        )
    }

    func testDescribeSearchableWithEditableTokens() {
        @SwiftOpenUI.State var query = ""
        @SwiftOpenUI.State var tokens = [
            TestToken(id: "a", name: "Tag A"),
        ]
        let view = Text("Content").searchable(
            text: $query,
            editableTokens: $tokens,
            prompt: "Filter"
        ) { token in
            Text(token.name)
        }
        let node = webDescribeView(view)

        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Filter",
                    placement: "automatic",
                    isPresented: nil,
                    tokens: [
                        WebSearchTokenDescriptor(id: "a", label: "Tag A"),
                    ],
                    tokenMode: "editableTokens",
                    suggestions: [],
                    scopes: [],
                    selectedScopeID: nil
                )
            )
        )
    }

    func testDescribeSearchableWithEmptyTokens() {
        @SwiftOpenUI.State var query = ""
        @SwiftOpenUI.State var tokens: [TestToken] = []
        let view = Text("Content").searchable(
            text: $query,
            tokens: $tokens,
            prompt: "Search"
        ) { token in
            Text(token.name)
        }
        let node = webDescribeView(view)

        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Search",
                    placement: "automatic",
                    isPresented: nil,
                    tokens: [],
                    tokenMode: "tokens",
                    suggestions: [],
                    scopes: [],
                    selectedScopeID: nil
                )
            )
        )
    }

    // MARK: - Search Suggestions Descriptor Tests

    func testDescribeSearchableWithSuggestions() {
        @SwiftOpenUI.State var query = ""
        let view = Text("Content")
            .searchable(text: $query)
            .searchSuggestions {
                Text("Apple")
                Text("Banana")
            }
        let node = webDescribeView(view)

        XCTAssertEqual(node.kind, .composite)
        XCTAssertEqual(node.typeName, "SearchableView")
        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Search",
                    placement: "automatic",
                    isPresented: nil,
                    tokens: [],
                    tokenMode: nil,
                    suggestions: [
                        WebSearchSuggestionDescriptor(id: "Apple", label: "Apple", completion: nil),
                        WebSearchSuggestionDescriptor(id: "Banana", label: "Banana", completion: nil),
                    ],
                    scopes: [],
                    selectedScopeID: nil
                )
            )
        )
    }

    func testDescribeSearchableWithSearchCompletion() {
        @SwiftOpenUI.State var query = ""
        let view = Text("Content")
            .searchable(text: $query)
            .searchSuggestions {
                Text("Show me apples").searchCompletion("apple")
            }
        let node = webDescribeView(view)

        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Search",
                    placement: "automatic",
                    isPresented: nil,
                    tokens: [],
                    tokenMode: nil,
                    suggestions: [
                        WebSearchSuggestionDescriptor(id: "Show me apples|apple", label: "Show me apples", completion: "apple"),
                    ],
                    scopes: [],
                    selectedScopeID: nil
                )
            )
        )
    }

    func testDescribeSearchableWithEmptySuggestions() {
        @SwiftOpenUI.State var query = ""
        let view = Text("Content")
            .searchable(text: $query)
            .searchSuggestions { }
        let node = webDescribeView(view)

        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Search",
                    placement: "automatic",
                    isPresented: nil,
                    tokens: [],
                    tokenMode: nil,
                    suggestions: [],
                    scopes: [],
                    selectedScopeID: nil
                )
            )
        )
    }

    // MARK: - Search Scopes Descriptor Tests

    private enum TestScope: String, Hashable, CaseIterable {
        case all = "All"
        case books = "Books"
        case music = "Music"
    }

    func testDescribeSearchableWithScopes() {
        @SwiftOpenUI.State var query = ""
        @SwiftOpenUI.State var scope = TestScope.all
        let view = Text("Content")
            .searchable(text: $query)
            .searchScopes($scope, scopes: TestScope.allCases) { s in
                Text(s.rawValue)
            }
        let node = webDescribeView(view)

        XCTAssertEqual(node.kind, .composite)
        XCTAssertEqual(node.typeName, "SearchableView")
        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Search",
                    placement: "automatic",
                    isPresented: nil,
                    tokens: [],
                    tokenMode: nil,
                    suggestions: [],
                    scopes: [
                        WebSearchScopeDescriptor(id: "all", label: "All"),
                        WebSearchScopeDescriptor(id: "books", label: "Books"),
                        WebSearchScopeDescriptor(id: "music", label: "Music"),
                    ],
                    selectedScopeID: "all"
                )
            )
        )
    }

    func testDescribeSearchableWithScopesAndSuggestions() {
        @SwiftOpenUI.State var query = ""
        @SwiftOpenUI.State var scope = TestScope.books
        let view = Text("Content")
            .searchable(text: $query)
            .searchSuggestions {
                Text("Swift")
            }
            .searchScopes($scope, scopes: [TestScope.all, TestScope.books]) { s in
                Text(s.rawValue)
            }
        let node = webDescribeView(view)

        XCTAssertEqual(
            node.props,
            .searchable(
                WebSearchableDescriptor(
                    prompt: "Search",
                    placement: "automatic",
                    isPresented: nil,
                    tokens: [],
                    tokenMode: nil,
                    suggestions: [
                        WebSearchSuggestionDescriptor(id: "Swift", label: "Swift", completion: nil),
                    ],
                    scopes: [
                        WebSearchScopeDescriptor(id: "all", label: "All"),
                        WebSearchScopeDescriptor(id: "books", label: "Books"),
                    ],
                    selectedScopeID: "books"
                )
            )
        )
    }

}
