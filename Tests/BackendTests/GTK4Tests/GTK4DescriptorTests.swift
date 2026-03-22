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
}
