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
        // A composite node with no described children is opaque —
        // we can't prove nothing changed inside, so the narrow path
        // must reject it and fall back to full rebuild.
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

    func testOpaqueWrapperBlocksNarrowPath() {
        // FontModifiedView is not WebDescribable, so webDescribeView falls through
        // to the Body == Never case and produces an opaque composite.
        let node = webDescribeView(
            VStack {
                Text("Hello").font(.title)
            }
        )
        // The VStack should be described, but FontModifiedView becomes opaque
        XCTAssertEqual(node.kind, .vStack)
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].kind, .composite)
        XCTAssertEqual(node.children[0].typeName, "FontModifiedView<Text>")

        // Plan against itself — reuse, but opaque composite blocks narrow path
        let plan = webPlanDescriptorTree(
            old: webRetainDescriptorTree(webIdentifyDescriptorTree(node)),
            new: webIdentifyDescriptorTree(node)
        )
        XCTAssertFalse(webCanApplyTextColorHostMutation(plan: plan))
    }
}
