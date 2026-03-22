import XCTest
@testable import SwiftOpenUI
@testable import BackendWin32
import WinSDK
import CWin32
import Foundation

// MARK: - Test harness

/// Hidden top-level window used as parent for test HWNDs.
/// Created once per test suite; child windows are destroyed between tests.
private var testWindow: HWND!
private var testHInstance: HINSTANCE!

private let testClassName: [WCHAR] = Array("SwiftUITestWindow".utf16) + [0]
private var testClassRegistered = false

private func ensureTestWindow() {
    guard testWindow == nil else { return }
    testHInstance = GetModuleHandleW(nil)!

    if !testClassRegistered {
        testClassRegistered = true
        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.lpfnWndProc = DefWindowProcW
        wc.hInstance = testHInstance
        wc.hbrBackground = GetSysColorBrush(COLOR_WINDOW)
        testClassName.withUnsafeBufferPointer { ptr in
            wc.lpszClassName = ptr.baseAddress!
            RegisterClassExW(&wc)
        }
    }

    testWindow = testClassName.withUnsafeBufferPointer { ptr in
        CreateWindowExW(
            0, ptr.baseAddress!, nil,
            DWORD(WS_OVERLAPPEDWINDOW),
            0, 0, 400, 300,
            nil, nil, testHInstance, nil
        )
    }
}

private func testContext() -> RenderContext {
    ensureTestWindow()
    return RenderContext(parent: testWindow, hInstance: testHInstance)
}

/// Destroy all child windows of the test parent between tests.
private func cleanupChildren() {
    guard let parent = testWindow else { return }
    while let child = GetWindow(parent, UINT(GW_CHILD)) {
        DestroyWindow(child)
    }
}

private func className(of hwnd: HWND) -> String {
    let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
    defer { buffer.deallocate() }
    let length = GetClassNameW(hwnd, buffer, 64)
    guard length > 0 else { return "" }
    return String(decodingCString: buffer, as: UTF16.self)
}

// MARK: - Tests

final class Win32RenderTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        cleanupChildren()
    }

    // MARK: - HWND creation

    func testTextCreatesHWND() {
        let ctx = testContext()
        let hwnd = winRenderView(Text("Hello"), in: ctx)
        XCTAssertNotNil(hwnd)

        // Verify the text is set on the HWND
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
        defer { buf.deallocate() }
        GetWindowTextW(hwnd!, buf, 64)
        let text = String(decodingCString: buf, as: UTF16.self)
        XCTAssertEqual(text, "Hello")
    }

    func testDescribeTextNode() {
        let node = winDescribeView(Text("Hello"))
        XCTAssertEqual(node.kind, .text)
        XCTAssertEqual(node.typeName, "Text")
        XCTAssertEqual(node.props, .text(Win32TextDescriptor(content: "Hello")))
        XCTAssertTrue(node.children.isEmpty)
    }

    func testDescribeColorNode() {
        let node = winDescribeView(Color(red: 0.25, green: 0.5, blue: 0.75, opacity: 0.8))
        XCTAssertEqual(node.kind, .color)
        XCTAssertEqual(
            node.props,
            .color(Win32ColorDescriptor(red: 0.25, green: 0.5, blue: 0.75, opacity: 0.8))
        )
        XCTAssertTrue(node.children.isEmpty)
    }

    func testDescribeSliderNode() {
        let binding = Binding<Double>(
            get: { 42.0 },
            set: { _ in }
        )
        let node = winDescribeView(Slider(value: binding, in: 0...255, step: 5))
        XCTAssertEqual(node.kind, .slider)
        XCTAssertEqual(
            node.props,
            .slider(Win32SliderDescriptor(value: 42.0, range: 0...255, step: 5))
        )
        XCTAssertTrue(node.children.isEmpty)
    }

    func testDescribeFontModifiedView() {
        let node = winDescribeView(Text("Hello").font(.headline))
        XCTAssertEqual(node.kind, .font)
        XCTAssertEqual(node.props, .font(Win32FontDescriptor(font: .headline)))
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].kind, .text)
    }

    func testDescribeDivider() {
        let node = winDescribeView(Divider())
        XCTAssertEqual(node.kind, .divider)
        XCTAssertTrue(node.children.isEmpty)
    }

    func testDescribeSpacer() {
        let node = winDescribeView(Spacer())
        XCTAssertEqual(node.kind, .spacer)
        XCTAssertTrue(node.children.isEmpty)
    }

    func testFontChangeRejectsNarrowPath() {
        let oldDesc = winDescribeView(Text("Hi").font(.body))
        let newDesc = winDescribeView(Text("Hi").font(.headline))
        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDesc))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDesc))
        // fontStyle is recognized but NOT eligible for narrow mutation path
        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .fontStyle)
        XCTAssertFalse(winCanApplyTextColorHostMutation(plan: plan))
    }

    func testOpaqueCompositeRejectsNarrowPath() {
        let old = Win32DescriptorNode(kind: .composite, typeName: "SomeView", children: [])
        let new = Win32DescriptorNode(kind: .composite, typeName: "SomeView", children: [])
        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(old))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(new))
        // Opaque composite with no children — can't prove nothing changed
        XCTAssertFalse(winCanApplyTextColorHostMutation(plan: plan))
    }

    func testDescribeCompositeLeafSubtree() {
        let binding = Binding<Double>(
            get: { 128.0 },
            set: { _ in }
        )

        let node = winDescribeView(VStack {
            Text("Hex")
            Color(red: 1, green: 0, blue: 0)
            Slider(value: binding, in: 0...255, step: 1)
        })

        XCTAssertEqual(node.kind, .vStack)
        XCTAssertEqual(
            node.props,
            .vStack(Win32VStackDescriptor(spacing: 0, alignment: .center))
        )
        XCTAssertEqual(node.children.map(\.kind), [.text, .color, .slider])
    }

    func testDescribeVStackCarriesSpacingAndAlignment() {
        let node = winDescribeView(VStack(alignment: .leading, spacing: 12) {
            Text("A")
            Text("B")
        })

        XCTAssertEqual(node.kind, .vStack)
        XCTAssertEqual(
            node.props,
            .vStack(Win32VStackDescriptor(spacing: 12, alignment: .leading))
        )
        XCTAssertEqual(node.children.map(\.kind), [.text, .text])
    }

    func testDescribeHStackCarriesSpacingAndAlignment() {
        let node = winDescribeView(HStack(alignment: .bottom, spacing: 7) {
            Text("A")
            Text("B")
        })

        XCTAssertEqual(node.kind, .hStack)
        XCTAssertEqual(
            node.props,
            .hStack(Win32HStackDescriptor(spacing: 7, alignment: .bottom))
        )
    }

    func testDescribeZStackCarriesAlignment() {
        let node = winDescribeView(ZStack(alignment: .topTrailing) {
            Text("A")
            Color(red: 1, green: 0, blue: 0)
        })

        XCTAssertEqual(node.kind, .zStack)
        XCTAssertEqual(
            node.props,
            .zStack(Win32ZStackDescriptor(alignment: .topTrailing))
        )
    }

    func testDescribePaddingWrapsChild() {
        let node = winDescribeView(Text("pad").padding(top: 1, bottom: 2, leading: 3, trailing: 4))
        XCTAssertEqual(node.kind, .padding)
        XCTAssertEqual(
            node.props,
            .padding(Win32PaddingDescriptor(top: 1, bottom: 2, leading: 3, trailing: 4))
        )
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].kind, .text)
    }

    func testDescribeFrameWrapsChild() {
        let node = winDescribeView(Color(red: 1, green: 0, blue: 0).frame(width: 120, height: 80))
        XCTAssertEqual(node.kind, .frame)
        XCTAssertEqual(
            node.props,
            .frame(
                Win32FrameDescriptor(
                    width: 120,
                    height: 80,
                    minWidth: nil,
                    minHeight: nil,
                    maxWidth: nil,
                    maxHeight: nil,
                    alignment: .center
                )
            )
        )
        XCTAssertEqual(node.children.map(\.kind), [.color])
    }

    func testDescribeBackgroundWrapsChild() {
        let node = winDescribeView(Text("bg").background(.red))
        XCTAssertEqual(node.kind, .background)
        XCTAssertEqual(
            node.props,
            .background(Win32ColorDescriptor(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0))
        )
        XCTAssertEqual(node.children.map(\.kind), [.text])
    }

    func testDescribeForegroundColorWrapsChild() {
        let node = winDescribeView(Text("fg").foregroundColor(.blue))
        XCTAssertEqual(node.kind, .foregroundColor)
        XCTAssertEqual(
            node.props,
            .foregroundColor(Win32ColorDescriptor(red: 0.0, green: 0.0, blue: 1.0, opacity: 1.0))
        )
        XCTAssertEqual(node.children.map(\.kind), [.text])
    }

    func testDescribeBorderWrapsChild() {
        let node = winDescribeView(
            Color(red: 0.2, green: 0.4, blue: 0.6).border(Color(red: 0.3, green: 0.3, blue: 0.3), width: 2)
        )
        XCTAssertEqual(node.kind, .border)
        XCTAssertEqual(
            node.props,
            .border(
                Win32BorderDescriptor(
                    color: Win32ColorDescriptor(red: 0.3, green: 0.3, blue: 0.3, opacity: 1.0),
                    width: 2
                )
            )
        )
        XCTAssertEqual(node.children.map(\.kind), [.color])
    }

    func testDescribeColorMixerStyleSwatchChain() {
        let node = winDescribeView(
            Color(red: 0.2, green: 0.4, blue: 0.6)
                .frame(width: 120, height: 80)
                .border(Color(red: 0.3, green: 0.3, blue: 0.3))
        )

        XCTAssertEqual(node.kind, .border)
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].kind, .frame)
        XCTAssertEqual(node.children[0].children.map(\.kind), [.color])
    }

    func testIdentifyDescriptorTreeAssignsStructuralPaths() {
        let descriptor = winDescribeView(VStack {
            Text("A")
            Color(red: 1, green: 0, blue: 0)
        }.padding(6))

        let identified = winIdentifyDescriptorTree(descriptor)
        XCTAssertEqual(identified.identity.path, [])
        XCTAssertEqual(identified.children.map(\.identity.path), [[0]])
        XCTAssertEqual(identified.children[0].descriptor.kind, .vStack)
        XCTAssertEqual(identified.children[0].children.map(\.identity.path), [[0, 0], [0, 1]])
    }

    func testMatchDescriptorTreeReusesSameStructure() {
        let oldDescriptor = winDescribeView(
            Color(red: 0.2, green: 0.4, blue: 0.6)
                .frame(width: 120, height: 80)
                .border(Color(red: 0.3, green: 0.3, blue: 0.3))
        )
        let newDescriptor = winDescribeView(
            Color(red: 0.4, green: 0.5, blue: 0.7)
                .frame(width: 120, height: 80)
                .border(Color(red: 0.3, green: 0.3, blue: 0.3))
        )

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let match = winMatchDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(match.kind, .reuse)
        XCTAssertEqual(match.children.count, 1)
        XCTAssertEqual(match.children[0].kind, .reuse)
        XCTAssertEqual(match.children[0].children[0].kind, .reuse)
    }

    func testMatchDescriptorTreeReusesVStackWhenOnlyPropsChange() {
        let oldDescriptor = winDescribeView(VStack(alignment: .leading, spacing: 4) {
            Text("A")
            Text("B")
        })
        let newDescriptor = winDescribeView(VStack(alignment: .trailing, spacing: 12) {
            Text("A")
            Text("B")
        })

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let match = winMatchDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(match.kind, .reuse)
        XCTAssertEqual(match.oldDescriptor?.props, .vStack(Win32VStackDescriptor(spacing: 4, alignment: .leading)))
        XCTAssertEqual(match.newDescriptor.props, .vStack(Win32VStackDescriptor(spacing: 12, alignment: .trailing)))
    }

    func testMatchDescriptorTreeReplacesOnStackKindChangeAtSamePath() {
        let oldDescriptor = winDescribeView(VStack {
            Text("A")
            Text("B")
        })
        let newDescriptor = winDescribeView(HStack {
            Text("A")
            Text("B")
        })

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let match = winMatchDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(match.kind, .replace)
    }

    func testMatchDescriptorTreeReplacesOnChildCountChange() {
        let oldDescriptor = winDescribeView(VStack {
            Text("A")
            Text("B")
        })
        let newDescriptor = winDescribeView(VStack {
            Text("A")
        })

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let match = winMatchDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(match.kind, .replace)
    }

    func testMatchDescriptorTreeReplacesOnKindChangeAtPosition() {
        let oldDescriptor = winDescribeView(VStack {
            Text("A")
            Color(red: 1, green: 0, blue: 0)
        })
        let newDescriptor = winDescribeView(VStack {
            Text("A")
            Slider(value: Binding<Double>(get: { 0.5 }, set: { _ in }))
        })

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let match = winMatchDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(match.kind, .reuse)
        XCTAssertEqual(match.children.count, 2)
        XCTAssertEqual(match.children[0].kind, .reuse)
        XCTAssertEqual(match.children[1].kind, .replace)
    }

    func testPlanDescriptorTreeCreatesWhenNoRetainedTreeExists() {
        let descriptor = winDescribeView(Text("Hello"))
        let plan = winPlanDescriptorTree(old: nil, new: winIdentifyDescriptorTree(descriptor))

        XCTAssertEqual(plan.kind, .create)
        XCTAssertEqual(plan.updateIntent, .none)
        XCTAssertNil(plan.oldDescriptor)
        XCTAssertEqual(plan.newDescriptor.kind, .text)
    }

    func testPlanDescriptorTreeReusesWhenPropsAreEqual() {
        let oldDescriptor = winDescribeView(Text("Same"))
        let newDescriptor = winDescribeView(Text("Same"))

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(plan.kind, .reuse)
        XCTAssertEqual(plan.updateIntent, .none)
        XCTAssertEqual(plan.oldDescriptor?.props, plan.newDescriptor.props)
    }

    func testPlanDescriptorTreeUpdatesWhenLeafPropsChange() {
        let oldDescriptor = winDescribeView(Text("Old"))
        let newDescriptor = winDescribeView(Text("New"))

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .textContent)
        XCTAssertEqual(plan.oldDescriptor?.props, .text(Win32TextDescriptor(content: "Old")))
        XCTAssertEqual(plan.newDescriptor.props, .text(Win32TextDescriptor(content: "New")))
    }

    func testPlanDescriptorTreeUsesColorFillIntentForColorPropChange() {
        let oldDescriptor = winDescribeView(Color(red: 0.2, green: 0.4, blue: 0.6))
        let newDescriptor = winDescribeView(Color(red: 0.8, green: 0.1, blue: 0.3))

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .colorFill)
    }

    func testPlanDescriptorTreeUsesSliderValueIntentForValueOnlyChange() {
        let oldDescriptor = winDescribeView(Slider(
            value: Binding<Double>(get: { 10 }, set: { _ in }),
            in: 0...255,
            step: 1
        ))
        let newDescriptor = winDescribeView(Slider(
            value: Binding<Double>(get: { 42 }, set: { _ in }),
            in: 0...255,
            step: 1
        ))

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .sliderValue)
    }

    func testPlanDescriptorTreeUsesSliderConfigurationIntentForRangeChange() {
        let oldDescriptor = winDescribeView(Slider(
            value: Binding<Double>(get: { 10 }, set: { _ in }),
            in: 0...100,
            step: 1
        ))
        let newDescriptor = winDescribeView(Slider(
            value: Binding<Double>(get: { 10 }, set: { _ in }),
            in: 0...255,
            step: 1
        ))

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .sliderConfiguration)
    }

    func testPlanDescriptorTreeUsesSliderConfigurationIntentForStepChange() {
        let oldDescriptor = winDescribeView(Slider(
            value: Binding<Double>(get: { 10 }, set: { _ in }),
            in: 0...255,
            step: 1
        ))
        let newDescriptor = winDescribeView(Slider(
            value: Binding<Double>(get: { 10 }, set: { _ in }),
            in: 0...255,
            step: 5
        ))

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .sliderConfiguration)
    }

    func testPlanDescriptorTreeUpdatesWhenStackPropsChange() {
        let oldDescriptor = winDescribeView(VStack(alignment: .leading, spacing: 4) {
            Text("A")
            Text("B")
        })
        let newDescriptor = winDescribeView(VStack(alignment: .trailing, spacing: 12) {
            Text("A")
            Text("B")
        })

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .vStackLayout)
        XCTAssertEqual(plan.children.map(\.kind), [.reuse, .reuse])
    }

    func testPlanDescriptorTreeUsesFrameLayoutIntentForFramePropChange() {
        let oldDescriptor = winDescribeView(Text("A").frame(width: 100, height: 40))
        let newDescriptor = winDescribeView(Text("A").frame(width: 140, height: 60))

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .frameLayout)
        XCTAssertEqual(plan.children.map(\.kind), [.reuse])
    }

    func testPlanDescriptorTreeKeepsParentReuseWhenOnlyChildPropsChange() {
        let oldDescriptor = winDescribeView(VStack {
            Text("A")
            Text("B")
        })
        let newDescriptor = winDescribeView(VStack {
            Text("A")
            Text("C")
        })

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(plan.kind, .reuse)
        XCTAssertEqual(plan.updateIntent, .none)
        XCTAssertEqual(plan.children.count, 2)
        XCTAssertEqual(plan.children[0].kind, .reuse)
        XCTAssertEqual(plan.children[1].kind, .update)
        XCTAssertEqual(plan.children[1].updateIntent, .textContent)
    }

    func testPlanDescriptorTreeReplacesWhenKindChangesAtSamePath() {
        let oldDescriptor = winDescribeView(VStack {
            Text("A")
            Text("B")
        })
        let newDescriptor = winDescribeView(HStack {
            Text("A")
            Text("B")
        })

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(plan.kind, .replace)
        XCTAssertEqual(plan.updateIntent, .none)
        XCTAssertEqual(plan.oldDescriptor?.kind, .vStack)
        XCTAssertEqual(plan.newDescriptor.kind, .hStack)
    }

    func testPlanDescriptorTreeReusesGenericWrapperWhenOnlyChildKindChanges() {
        let oldDescriptor = winDescribeView(Text("A").padding(8))
        let newDescriptor = winDescribeView(Color(red: 1, green: 0, blue: 0).padding(8))

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(plan.kind, .reuse)
        XCTAssertEqual(plan.updateIntent, .none)
        XCTAssertEqual(plan.newDescriptor.kind, .padding)
        XCTAssertEqual(plan.children.count, 1)
        XCTAssertEqual(plan.children[0].kind, .replace)
        XCTAssertEqual(plan.children[0].updateIntent, .none)
        XCTAssertEqual(plan.children[0].oldDescriptor?.kind, .text)
        XCTAssertEqual(plan.children[0].newDescriptor.kind, .color)
    }

    func testPlanDescriptorTreeUsesHStackLayoutIntentForHStackPropChange() {
        let oldDescriptor = winDescribeView(HStack(alignment: .top, spacing: 2) {
            Text("A")
            Text("B")
        })
        let newDescriptor = winDescribeView(HStack(alignment: .bottom, spacing: 8) {
            Text("A")
            Text("B")
        })

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .hStackLayout)
    }

    func testPlanDescriptorTreeUsesZStackLayoutIntentForAlignmentChange() {
        let oldDescriptor = winDescribeView(ZStack(alignment: .center) {
            Text("A")
            Color(red: 1, green: 0, blue: 0)
        })
        let newDescriptor = winDescribeView(ZStack(alignment: .topLeading) {
            Text("A")
            Color(red: 1, green: 0, blue: 0)
        })

        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDescriptor))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDescriptor))

        XCTAssertEqual(plan.kind, .update)
        XCTAssertEqual(plan.updateIntent, .zStackLayout)
    }

    func testExecuteDescriptorPlanCreatesExecutorNodeTree() {
        let identified = winIdentifyDescriptorTree(winDescribeView(VStack {
            Text("A")
            Text("B")
        }))
        let plan = winPlanDescriptorTree(old: nil, new: identified)
        let action = winExecuteDescriptorPlan(old: nil, plan: plan)

        XCTAssertEqual(action.kind, .create)
        XCTAssertEqual(action.updateIntent, .none)
        XCTAssertEqual(action.resultingNode.kind, .vStack)
        XCTAssertEqual(action.resultingNode.children.map(\.kind), [.text, .text])
        XCTAssertEqual(action.children.map(\.kind), [.create, .create])
    }

    func testExecuteDescriptorPlanUpdatesLeafAndRewritesRetainedMetadata() {
        let oldIdentified = winIdentifyDescriptorTree(winDescribeView(Text("Old")))
        let oldExecutor = winMakeExecutorTree(from: oldIdentified, nativeSlotID: 42)
        let newPlan = winPlanDescriptorTree(
            old: winRetainDescriptorTree(oldIdentified),
            new: winIdentifyDescriptorTree(winDescribeView(Text("New")))
        )
        let action = winExecuteDescriptorPlan(old: oldExecutor, plan: newPlan)

        XCTAssertEqual(action.kind, .update)
        XCTAssertEqual(action.updateIntent, .textContent)
        XCTAssertEqual(action.previousNode?.nativeSlotID, 42)
        XCTAssertEqual(action.resultingNode.nativeSlotID, 42)
        XCTAssertEqual(action.resultingNode.lastDescriptor.props, .text(Win32TextDescriptor(content: "New")))
    }

    func testExecuteDescriptorPlanKeepsParentAndReplacesChildUnderWrapper() {
        let oldIdentified = winIdentifyDescriptorTree(winDescribeView(Text("A").padding(8)))
        let oldExecutor = winMakeExecutorTree(from: oldIdentified, nativeSlotID: 7)
        let newPlan = winPlanDescriptorTree(
            old: winRetainDescriptorTree(oldIdentified),
            new: winIdentifyDescriptorTree(winDescribeView(Color(red: 1, green: 0, blue: 0).padding(8)))
        )
        let action = winExecuteDescriptorPlan(old: oldExecutor, plan: newPlan)

        XCTAssertEqual(action.kind, .keep)
        XCTAssertEqual(action.updateIntent, .none)
        XCTAssertEqual(action.resultingNode.nativeSlotID, 7)
        XCTAssertEqual(action.children.count, 1)
        XCTAssertEqual(action.children[0].kind, .replace)
        XCTAssertEqual(action.children[0].previousNode?.kind, .text)
        XCTAssertEqual(action.children[0].resultingNode.kind, .color)
    }

    func testExecuteDescriptorPlanUsesFrameLayoutUpdateIntent() {
        let oldIdentified = winIdentifyDescriptorTree(winDescribeView(Text("A").frame(width: 100, height: 40)))
        let oldExecutor = winMakeExecutorTree(from: oldIdentified, nativeSlotID: 3)
        let newPlan = winPlanDescriptorTree(
            old: winRetainDescriptorTree(oldIdentified),
            new: winIdentifyDescriptorTree(winDescribeView(Text("A").frame(width: 140, height: 60)))
        )
        let action = winExecuteDescriptorPlan(old: oldExecutor, plan: newPlan)

        XCTAssertEqual(action.kind, .update)
        XCTAssertEqual(action.updateIntent, .frameLayout)
        XCTAssertEqual(action.children.map(\.kind), [.keep])
        XCTAssertEqual(action.resultingNode.lastDescriptor.props, .frame(
            Win32FrameDescriptor(
                width: 140,
                height: 60,
                minWidth: nil,
                minHeight: nil,
                maxWidth: nil,
                maxHeight: nil,
                alignment: .center
            )
        ))
    }

    func testExecuteDescriptorPlanPreservesSliderIntentDistinction() {
        let oldIdentified = winIdentifyDescriptorTree(winDescribeView(Slider(
            value: Binding<Double>(get: { 10 }, set: { _ in }),
            in: 0...255,
            step: 1
        )))
        let oldExecutor = winMakeExecutorTree(from: oldIdentified, nativeSlotID: 9)

        let valuePlan = winPlanDescriptorTree(
            old: winRetainDescriptorTree(oldIdentified),
            new: winIdentifyDescriptorTree(winDescribeView(Slider(
                value: Binding<Double>(get: { 20 }, set: { _ in }),
                in: 0...255,
                step: 1
            )))
        )
        let configPlan = winPlanDescriptorTree(
            old: winRetainDescriptorTree(oldIdentified),
            new: winIdentifyDescriptorTree(winDescribeView(Slider(
                value: Binding<Double>(get: { 10 }, set: { _ in }),
                in: 0...100,
                step: 5
            )))
        )

        let valueAction = winExecuteDescriptorPlan(old: oldExecutor, plan: valuePlan)
        let configAction = winExecuteDescriptorPlan(old: oldExecutor, plan: configPlan)

        XCTAssertEqual(valueAction.kind, .update)
        XCTAssertEqual(valueAction.updateIntent, .sliderValue)
        XCTAssertEqual(configAction.kind, .update)
        XCTAssertEqual(configAction.updateIntent, .sliderConfiguration)
    }

    func testExecuteDescriptorPlanCarriesFullSubtreeForNonLeafReplace() {
        let oldIdentified = winIdentifyDescriptorTree(winDescribeView(VStack {
            Text("A")
            Text("B")
        }))
        let oldExecutor = winMakeExecutorTree(from: oldIdentified, nativeSlotID: 11)
        let newPlan = winPlanDescriptorTree(
            old: winRetainDescriptorTree(oldIdentified),
            new: winIdentifyDescriptorTree(winDescribeView(HStack {
                Text("A")
                Text("B")
            }))
        )

        let action = winExecuteDescriptorPlan(old: oldExecutor, plan: newPlan)

        XCTAssertEqual(action.kind, .replace)
        XCTAssertEqual(action.previousNode?.kind, .vStack)
        XCTAssertEqual(action.resultingNode.kind, .hStack)
        XCTAssertEqual(action.children.map(\.kind), [.create, .create])
        XCTAssertEqual(action.resultingNode.children.map(\.kind), [.text, .text])
    }

    func testApplyHookReturnsCreatedForCreateAction() {
        let identified = winIdentifyDescriptorTree(winDescribeView(VStack {
            Text("A")
            Text("B")
        }))
        let action = winExecuteDescriptorPlan(
            old: nil,
            plan: winPlanDescriptorTree(old: nil, new: identified)
        )

        let result = winApplyHook(action: action)

        XCTAssertEqual(result.kind, .created)
        XCTAssertEqual(result.updateIntent, .none)
        XCTAssertEqual(result.children.map(\.kind), [.created, .created])
    }

    func testApplyHookReturnsNoOpForKeepAction() {
        let oldIdentified = winIdentifyDescriptorTree(winDescribeView(VStack {
            Text("A")
            Text("B")
        }))
        let action = winExecuteDescriptorPlan(
            old: winMakeExecutorTree(from: oldIdentified, nativeSlotID: 1),
            plan: winPlanDescriptorTree(
                old: winRetainDescriptorTree(oldIdentified),
                new: winIdentifyDescriptorTree(winDescribeView(VStack {
                    Text("A")
                    Text("B")
                }))
            )
        )

        let result = winApplyHook(action: action)

        XCTAssertEqual(result.kind, .noOp)
        XCTAssertEqual(result.updateIntent, .none)
        XCTAssertEqual(result.children.map(\.kind), [.noOp, .noOp])
    }

    func testApplyHookDispatchesTextContentIntent() {
        let oldIdentified = winIdentifyDescriptorTree(winDescribeView(Text("Old")))
        let action = winExecuteDescriptorPlan(
            old: winMakeExecutorTree(from: oldIdentified, nativeSlotID: 2),
            plan: winPlanDescriptorTree(
                old: winRetainDescriptorTree(oldIdentified),
                new: winIdentifyDescriptorTree(winDescribeView(Text("New")))
            )
        )

        let result = winApplyHook(action: action)

        XCTAssertEqual(result.kind, .updated)
        XCTAssertEqual(result.updateIntent, .textContent)
    }

    func testApplyHookDispatchesColorFillIntent() {
        let oldIdentified = winIdentifyDescriptorTree(winDescribeView(Color(red: 0.1, green: 0.2, blue: 0.3)))
        let action = winExecuteDescriptorPlan(
            old: winMakeExecutorTree(from: oldIdentified, nativeSlotID: 3),
            plan: winPlanDescriptorTree(
                old: winRetainDescriptorTree(oldIdentified),
                new: winIdentifyDescriptorTree(winDescribeView(Color(red: 0.7, green: 0.8, blue: 0.9)))
            )
        )

        let result = winApplyHook(action: action)

        XCTAssertEqual(result.kind, .updated)
        XCTAssertEqual(result.updateIntent, .colorFill)
    }

    func testApplyHookDispatchesSliderValueAndConfigurationSeparately() {
        let oldIdentified = winIdentifyDescriptorTree(winDescribeView(Slider(
            value: Binding<Double>(get: { 10 }, set: { _ in }),
            in: 0...255,
            step: 1
        )))
        let oldExecutor = winMakeExecutorTree(from: oldIdentified, nativeSlotID: 4)

        let valueResult = winApplyHook(action: winExecuteDescriptorPlan(
            old: oldExecutor,
            plan: winPlanDescriptorTree(
                old: winRetainDescriptorTree(oldIdentified),
                new: winIdentifyDescriptorTree(winDescribeView(Slider(
                    value: Binding<Double>(get: { 20 }, set: { _ in }),
                    in: 0...255,
                    step: 1
                )))
            )
        ))

        let configResult = winApplyHook(action: winExecuteDescriptorPlan(
            old: oldExecutor,
            plan: winPlanDescriptorTree(
                old: winRetainDescriptorTree(oldIdentified),
                new: winIdentifyDescriptorTree(winDescribeView(Slider(
                    value: Binding<Double>(get: { 10 }, set: { _ in }),
                    in: 0...100,
                    step: 5
                )))
            )
        ))

        XCTAssertEqual(valueResult.kind, .updated)
        XCTAssertEqual(valueResult.updateIntent, .sliderValue)
        XCTAssertEqual(configResult.kind, .updated)
        XCTAssertEqual(configResult.updateIntent, .sliderConfiguration)
    }

    func testApplyHookReturnsReplacedWithCreatedChildrenForNonLeafReplace() {
        let oldIdentified = winIdentifyDescriptorTree(winDescribeView(VStack {
            Text("A")
            Text("B")
        }))
        let action = winExecuteDescriptorPlan(
            old: winMakeExecutorTree(from: oldIdentified, nativeSlotID: 5),
            plan: winPlanDescriptorTree(
                old: winRetainDescriptorTree(oldIdentified),
                new: winIdentifyDescriptorTree(winDescribeView(HStack {
                    Text("A")
                    Text("B")
                }))
            )
        )

        let result = winApplyHook(action: action)

        XCTAssertEqual(result.kind, .replaced)
        XCTAssertEqual(result.updateIntent, .none)
        XCTAssertEqual(result.children.map(\.kind), [.created, .created])
    }

    func testWinSetTextContentUpdatesRealStaticControl() {
        let ctx = testContext()
        let hwnd = winRenderView(Text("Old"), in: ctx)!

        XCTAssertTrue(winSetTextContent(hwnd: hwnd, text: "New"))

        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
        defer { buf.deallocate() }
        GetWindowTextW(hwnd, buf, 64)
        XCTAssertEqual(String(decodingCString: buf, as: UTF16.self), "New")
    }

    func testApplyHookMutationUpdatesRealStaticControlForTextContent() {
        let ctx = testContext()
        let hwnd = winRenderView(Text("Old"), in: ctx)!
        let oldIdentified = winIdentifyDescriptorTree(winDescribeView(Text("Old")))
        let oldExecutor = winMakeExecutorTree(from: oldIdentified, nativeSlotID: winNativeSlotID(for: hwnd))
        let action = winExecuteDescriptorPlan(
            old: oldExecutor,
            plan: winPlanDescriptorTree(
                old: winRetainDescriptorTree(oldIdentified),
                new: winIdentifyDescriptorTree(winDescribeView(Text("New")))
            )
        )

        let result = winApplyHookMutation(action: action)

        XCTAssertEqual(result.kind, .updated)
        XCTAssertEqual(result.updateIntent, .textContent)

        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
        defer { buf.deallocate() }
        GetWindowTextW(hwnd, buf, 64)
        XCTAssertEqual(String(decodingCString: buf, as: UTF16.self), "New")
    }

    func testApplyHookMutationReportsFailureForMissingTextNativeSlot() {
        let oldIdentified = winIdentifyDescriptorTree(winDescribeView(Text("Old")))
        let oldRetained = winRetainDescriptorTree(oldIdentified)
        let oldExecutor = winMakeExecutorTree(from: oldIdentified)
        let action = winExecuteDescriptorPlan(
            old: oldExecutor,
            plan: winPlanDescriptorTree(
                old: oldRetained,
                new: winIdentifyDescriptorTree(winDescribeView(Text("New")))
            )
        )

        let result = winApplyHookMutation(action: action)

        XCTAssertEqual(result.kind, .updated)
        XCTAssertEqual(result.updateIntent, .textContent)
        XCTAssertFalse(result.mutationSucceeded)
        XCTAssertFalse(winHookMutationSucceeded(result))
    }

    func testWinSetColorFillUpdatesRealColorControlState() {
        let ctx = testContext()
        let hwnd = winRenderView(Color(red: 0.1, green: 0.2, blue: 0.3), in: ctx)!
        let nativeSlotID = winNativeSlotID(for: hwnd)

        XCTAssertEqual(
            winCurrentColorFill(nativeSlotID: nativeSlotID),
            Win32ColorDescriptor(red: 0.1, green: 0.2, blue: 0.3, opacity: 1.0)
        )
        XCTAssertTrue(
            winSetColorFill(
                nativeSlotID: nativeSlotID,
                color: Win32ColorDescriptor(red: 0.7, green: 0.8, blue: 0.9, opacity: 0.6)
            )
        )
        XCTAssertEqual(
            winCurrentColorFill(nativeSlotID: nativeSlotID),
            Win32ColorDescriptor(red: 0.7, green: 0.8, blue: 0.9, opacity: 0.6)
        )
    }

    func testWinSetColorFillRejectsNonColorControl() {
        let ctx = testContext()
        let hwnd = winRenderView(Text("Not color"), in: ctx)!

        XCTAssertFalse(
            winSetColorFill(
                nativeSlotID: winNativeSlotID(for: hwnd),
                color: Win32ColorDescriptor(red: 1, green: 0, blue: 0, opacity: 1)
            )
        )
    }

    func testApplyHookMutationUpdatesRealColorControlForColorFill() {
        let ctx = testContext()
        let hwnd = winRenderView(Color(red: 0.1, green: 0.2, blue: 0.3), in: ctx)!
        let oldIdentified = winIdentifyDescriptorTree(winDescribeView(Color(red: 0.1, green: 0.2, blue: 0.3)))
        let oldExecutor = winMakeExecutorTree(from: oldIdentified, nativeSlotID: winNativeSlotID(for: hwnd))
        let action = winExecuteDescriptorPlan(
            old: oldExecutor,
            plan: winPlanDescriptorTree(
                old: winRetainDescriptorTree(oldIdentified),
                new: winIdentifyDescriptorTree(winDescribeView(Color(red: 0.7, green: 0.8, blue: 0.9, opacity: 0.6)))
            )
        )

        let result = winApplyHookMutation(action: action)

        XCTAssertEqual(result.kind, .updated)
        XCTAssertEqual(result.updateIntent, .colorFill)
        XCTAssertEqual(
            winCurrentColorFill(nativeSlotID: winNativeSlotID(for: hwnd)),
            Win32ColorDescriptor(red: 0.7, green: 0.8, blue: 0.9, opacity: 0.6)
        )
    }

    func testButtonCreatesHWND() {
        let ctx = testContext()
        let hwnd = winRenderView(Button("Click Me", action: {}), in: ctx)
        XCTAssertNotNil(hwnd)

        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
        defer { buf.deallocate() }
        GetWindowTextW(hwnd!, buf, 64)
        let text = String(decodingCString: buf, as: UTF16.self)
        XCTAssertEqual(text, "Click Me")
    }

    func testSpacerIsMarkedAsSpacer() {
        let ctx = testContext()
        let hwnd = winRenderView(Spacer(), in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertTrue(isSpacerHwnd(hwnd!), "Spacer HWND should be detected by isSpacerHwnd")
    }

    func testVStackCreatesContainerWithChildren() {
        let ctx = testContext()
        let hwnd = winRenderView(VStack {
            Text("A")
            Text("B")
        }, in: ctx)
        XCTAssertNotNil(hwnd)

        // Count children
        var count = 0
        var child = GetWindow(hwnd!, UINT(GW_CHILD))
        while child != nil {
            count += 1
            child = GetWindow(child!, UINT(GW_HWNDNEXT))
        }
        XCTAssertEqual(count, 2, "VStack with 2 Text children should have 2 child HWNDs")
    }

    func testHStackCreatesContainerWithChildren() {
        let ctx = testContext()
        let hwnd = winRenderView(HStack(spacing: 4) {
            Text("X")
            Text("Y")
            Text("Z")
        }, in: ctx)
        XCTAssertNotNil(hwnd)

        var count = 0
        var child = GetWindow(hwnd!, UINT(GW_CHILD))
        while child != nil {
            count += 1
            child = GetWindow(child!, UINT(GW_HWNDNEXT))
        }
        XCTAssertEqual(count, 3)
    }

    func testForEachRendersMultipleChildren() {
        let ctx = testContext()
        let forEach = ForEach(0..<4) { i in Text("Item \(i)") }
        let hwnd = winRenderView(forEach, in: ctx)
        XCTAssertNotNil(hwnd)

        var count = 0
        var child = GetWindow(hwnd!, UINT(GW_CHILD))
        while child != nil {
            count += 1
            child = GetWindow(child!, UINT(GW_HWNDNEXT))
        }
        XCTAssertEqual(count, 4, "ForEach(0..<4) should produce 4 child HWNDs")
    }

    // MARK: - Modifier HWND tests

    func testPaddingWrapsInContainer() {
        let ctx = testContext()
        let hwnd = winRenderView(Text("pad me").padding(10), in: ctx)
        XCTAssertNotNil(hwnd)

        // The padding wrapper should contain a child
        let child = GetWindow(hwnd!, UINT(GW_CHILD))
        XCTAssertNotNil(child, "PaddedView should have a child HWND inside the container")
    }

    func testFrameSetsSize() {
        let ctx = testContext()
        let hwnd = winRenderView(Text("framed").frame(width: 150, height: 80), in: ctx)
        XCTAssertNotNil(hwnd)

        var rect = RECT()
        GetWindowRect(hwnd!, &rect)
        let w = rect.right - rect.left
        let h = rect.bottom - rect.top
        XCTAssertEqual(w, 150, "Frame width should be 150")
        XCTAssertEqual(h, 80, "Frame height should be 80")
    }

    func testOffsetPositionsChildWithinWrapper() {
        let ctx = testContext()
        let plain = winRenderView(Text("offset"), in: ctx)!
        var plainRect = RECT()
        GetWindowRect(plain, &plainRect)
        let plainW = plainRect.right - plainRect.left
        let plainH = plainRect.bottom - plainRect.top

        let hwnd = winRenderView(Text("offset").offset(x: 12, y: 8), in: ctx)
        XCTAssertNotNil(hwnd)

        guard let wrapper = hwnd else { return }
        guard let child = GetWindow(wrapper, UINT(GW_CHILD)) else {
            XCTFail("OffsetView should wrap its content in a container")
            return
        }

        var wrapperRect = RECT()
        var childRect = RECT()
        GetWindowRect(wrapper, &wrapperRect)
        GetWindowRect(child, &childRect)

        XCTAssertEqual(wrapperRect.right - wrapperRect.left, plainW,
                       "Offset wrapper should preserve the original layout width")
        XCTAssertEqual(wrapperRect.bottom - wrapperRect.top, plainH,
                       "Offset wrapper should preserve the original layout height")
        XCTAssertEqual(childRect.left - wrapperRect.left, 12, "Offset child x should be preserved")
        XCTAssertEqual(childRect.top - wrapperRect.top, 8, "Offset child y should be preserved")
    }

    func testForegroundColorWrapsChild() {
        let ctx = testContext()
        let hwnd = winRenderView(Text("blue").foregroundColor(.blue), in: ctx)
        XCTAssertNotNil(hwnd)

        // foregroundColor wraps the child in a container
        let child = GetWindow(hwnd!, UINT(GW_CHILD))
        XCTAssertNotNil(child, "ForegroundColorView should wrap child in container")
    }

    func testForegroundColorMakesButtonsOwnerDrawn() {
        let ctx = testContext()
        let hwnd = winRenderView(Button("Tinted", action: {}).foregroundColor(.blue), in: ctx)
        XCTAssertNotNil(hwnd)

        guard let button = GetWindow(hwnd!, UINT(GW_CHILD)) else {
            return XCTFail("ForegroundColor button wrapper should contain the button child")
        }

        XCTAssertEqual(className(of: button), "Button")
        let style = win32_GetWindowLongPtrW(button, GWL_STYLE)
        XCTAssertNotEqual(style & LONG_PTR(BS_OWNERDRAW), 0,
                          "ForegroundColor should switch Win32 buttons to owner-draw")
    }

    func testBackgroundWrapsChild() {
        let ctx = testContext()
        let hwnd = winRenderView(Text("bg").background(.red), in: ctx)
        XCTAssertNotNil(hwnd)

        let child = GetWindow(hwnd!, UINT(GW_CHILD))
        XCTAssertNotNil(child, "BackgroundView should wrap child in container")
    }

    func testFontChangesTextSize() {
        let ctx = testContext()

        // Render text without font
        let plain = winRenderView(Text("ABC"), in: ctx)!
        var plainRect = RECT()
        GetWindowRect(plain, &plainRect)
        let plainH = plainRect.bottom - plainRect.top

        // Render text with large title font
        let fonted = winRenderView(Text("ABC").font(.largeTitle), in: ctx)!
        // Font is applied recursively — find the actual STATIC control
        var fontedH: Int32 = 0
        func findStaticHeight(_ hwnd: HWND) {
            let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
            defer { buf.deallocate() }
            let len = GetClassNameW(hwnd, buf, 64)
            if len > 0 {
                let cls = String(decodingCString: buf, as: UTF16.self)
                if cls == "Static" {
                    var r = RECT()
                    GetWindowRect(hwnd, &r)
                    fontedH = r.bottom - r.top
                    return
                }
            }
            var child = GetWindow(hwnd, UINT(GW_CHILD))
            while let c = child {
                findStaticHeight(c)
                if fontedH > 0 { return }
                child = GetWindow(c, UINT(GW_HWNDNEXT))
            }
        }
        findStaticHeight(fonted)

        XCTAssertGreaterThan(fontedH, plainH,
            "Text with .largeTitle should be taller than plain text")
    }

    func testFontChangesButtonSize() {
        let ctx = testContext()

        let plain = winRenderView(Button("Resize Me", action: {}), in: ctx)!
        var plainRect = RECT()
        GetWindowRect(plain, &plainRect)
        let plainH = plainRect.bottom - plainRect.top

        let fonted = winRenderView(Button("Resize Me", action: {}).font(.largeTitle), in: ctx)!
        let button = className(of: fonted) == "Button" ? fonted : GetWindow(fonted, UINT(GW_CHILD))
        XCTAssertNotNil(button)

        var fontedRect = RECT()
        GetWindowRect(button!, &fontedRect)
        let fontedH = fontedRect.bottom - fontedRect.top

        XCTAssertGreaterThan(fontedH, plainH,
            "Button with .largeTitle should be taller than plain button")
    }

    // MARK: - Command dispatch

    func testCommandHandlerRegistrationAndDispatch() {
        var called = false
        let id = nextControlID()
        registerCommandHandler(controlID: id, action: { called = true })

        let wParam = WPARAM(id)
        XCTAssertTrue(dispatchCommand(wParam: wParam))
        XCTAssertTrue(called)

        unregisterCommandHandler(controlID: id)
        XCTAssertFalse(dispatchCommand(wParam: wParam))
    }

    func testControlIDsAreUnique() {
        let id1 = nextControlID()
        let id2 = nextControlID()
        XCTAssertNotEqual(id1, id2)
    }

    func testButtonClickDispatchesAction() {
        var clicked = false
        let ctx = testContext()
        let hwnd = winRenderView(Button("Test", action: { clicked = true }), in: ctx)
        XCTAssertNotNil(hwnd)

        // Simulate BN_CLICKED: the button's control ID is in LOWORD(wParam)
        let controlID = WORD(GetDlgCtrlID(hwnd!))
        let wParam = WPARAM(controlID) // HIWORD=0 means BN_CLICKED
        let handled = dispatchCommand(wParam: wParam)
        XCTAssertTrue(handled)
        XCTAssertTrue(clicked, "Button action should fire via dispatchCommand")
    }

    // MARK: - Stateful view rendering

    func testStatefulViewCreatesViewHostContainer() {
        let ctx = testContext()
        struct CounterView: View {
            @State var count = 0
            var body: some View {
                Text("Count: \(count)")
            }
        }
        let hwnd = winRenderView(CounterView(), in: ctx)
        XCTAssertNotNil(hwnd, "Stateful view should produce an HWND")

        // The ViewHost container should have a child
        let child = GetWindow(hwnd!, UINT(GW_CHILD))
        XCTAssertNotNil(child, "ViewHost container should contain the rendered body")
    }

    // MARK: - Focus suppression

    func testWin32ViewHostSuppressFocusRestore() {
        let ctx = testContext()
        let host = Win32ViewHost(
            context: ctx,
            buildBody: { ctx in
                winRenderView(Text("test"), in: ctx)
            },
            describeBody: {
                winDescribeView(Text("test"))
            }
        )

        // Initially no suppression
        host.suppressNextFocusRestore()
        // The flag is consumed during rebuild — verify it doesn't crash
        // (We can't fully test focus without a message loop, but we verify
        // the host is functional and doesn't assert/crash)
        let child = host.buildBody(RenderContext(parent: host.container, hInstance: ctx.hInstance))
        if let c = child { host.addChild(c) }
        host.rebuild()
        // If we get here without crash, the suppression path works
    }

    func testWin32ViewHostBuildDescriptorWithTracking() {
        let ctx = testContext()
        let host = Win32ViewHost(
            context: ctx,
            buildBody: { ctx in
                winRenderView(Text("tracked"), in: ctx)
            },
            describeBody: {
                winDescribeView(Text("tracked"))
            }
        )

        let descriptor = host.buildDescriptorWithTracking()

        XCTAssertEqual(descriptor.kind, .text)
        XCTAssertEqual(descriptor.props, .text(Win32TextDescriptor(content: "tracked")))
    }

    func testWin32ViewHostCapturesNestedTextAndColorSlotsAfterRebuild() {
        let ctx = testContext()
        let view = VStack {
            Text("Label").padding(top: 1, bottom: 2, leading: 3, trailing: 4)
            Color(red: 0.2, green: 0.4, blue: 0.6).frame(width: 80, height: 40)
        }

        let host = Win32ViewHost(
            context: ctx,
            buildBody: { ctx in
                winRenderView(view, in: ctx)
            },
            describeBody: {
                winDescribeView(view)
            }
        )

        let child = host.buildBody(RenderContext(parent: host.container, hInstance: ctx.hInstance))
        if let c = child { host.addChild(c) }
        host.rebuild()

        guard let executorRoot = host.retainedExecutorRoot else {
            XCTFail("Expected retained executor root after rebuild")
            return
        }

        XCTAssertEqual(executorRoot.kind, .vStack)
        XCTAssertNil(executorRoot.nativeSlotID)
        XCTAssertEqual(executorRoot.children.count, 2)

        let paddedText = executorRoot.children[0]
        XCTAssertEqual(paddedText.kind, .padding)
        XCTAssertNil(paddedText.nativeSlotID)
        XCTAssertEqual(paddedText.children.count, 1)
        XCTAssertEqual(paddedText.children[0].kind, .text)
        XCTAssertNotNil(paddedText.children[0].nativeSlotID)

        let framedColor = executorRoot.children[1]
        XCTAssertEqual(framedColor.kind, .frame)
        XCTAssertNil(framedColor.nativeSlotID)
        XCTAssertEqual(framedColor.children.count, 1)
        XCTAssertEqual(framedColor.children[0].kind, .color)
        XCTAssertNotNil(framedColor.children[0].nativeSlotID)
    }

    func testWin32ViewHostLeavesUnsupportedWrapperSlotsNil() {
        let ctx = testContext()
        let view = Text("Styled")
            .foregroundColor(.blue)
            .padding(top: 4, bottom: 4, leading: 8, trailing: 8)

        let host = Win32ViewHost(
            context: ctx,
            buildBody: { ctx in
                winRenderView(view, in: ctx)
            },
            describeBody: {
                winDescribeView(view)
            }
        )

        let child = host.buildBody(RenderContext(parent: host.container, hInstance: ctx.hInstance))
        if let c = child { host.addChild(c) }

        guard let executorRoot = host.retainedExecutorRoot else {
            XCTFail("Expected retained executor root after initial build")
            return
        }

        XCTAssertEqual(executorRoot.kind, .padding)
        XCTAssertNil(executorRoot.nativeSlotID)
        XCTAssertEqual(executorRoot.children.count, 1)

        let foreground = executorRoot.children[0]
        XCTAssertEqual(foreground.kind, .foregroundColor)
        XCTAssertNil(foreground.nativeSlotID)
        XCTAssertEqual(foreground.children.count, 1)
        XCTAssertEqual(foreground.children[0].kind, .text)
        XCTAssertNotNil(foreground.children[0].nativeSlotID)
    }

    func testWin32ViewHostMutatesTextInPlaceForSupportedUpdate() {
        let ctx = testContext()
        var content = "Old"
        let host = Win32ViewHost(
            context: ctx,
            buildBody: { ctx in
                winRenderView(Text(content), in: ctx)
            },
            describeBody: {
                winDescribeView(Text(content))
            }
        )

        let child = host.buildBody(RenderContext(parent: host.container, hInstance: ctx.hInstance))
        if let c = child { host.addChild(c) }

        let originalChild = GetWindow(host.container, UINT(GW_CHILD))
        let originalSlot = host.retainedExecutorRoot?.nativeSlotID

        content = "New"
        host.rebuild()

        let rebuiltChild = GetWindow(host.container, UINT(GW_CHILD))
        XCTAssertEqual(originalChild, rebuiltChild)
        XCTAssertEqual(originalSlot, host.retainedExecutorRoot?.nativeSlotID)

        let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
        defer { buffer.deallocate() }
        GetWindowTextW(rebuiltChild!, buffer, 64)
        XCTAssertEqual(String(decodingCString: buffer, as: UTF16.self), "New")
    }

    func testWin32ViewHostMutatesColorInPlaceForSupportedUpdate() {
        let ctx = testContext()
        var fill = Color(red: 0.1, green: 0.2, blue: 0.3)
        let host = Win32ViewHost(
            context: ctx,
            buildBody: { ctx in
                winRenderView(fill, in: ctx)
            },
            describeBody: {
                winDescribeView(fill)
            }
        )

        let child = host.buildBody(RenderContext(parent: host.container, hInstance: ctx.hInstance))
        if let c = child { host.addChild(c) }

        let originalChild = GetWindow(host.container, UINT(GW_CHILD))
        let originalSlot = host.retainedExecutorRoot?.nativeSlotID

        fill = Color(red: 0.8, green: 0.4, blue: 0.2)
        host.rebuild()

        let rebuiltChild = GetWindow(host.container, UINT(GW_CHILD))
        XCTAssertEqual(originalChild, rebuiltChild)
        XCTAssertEqual(originalSlot, host.retainedExecutorRoot?.nativeSlotID)
        XCTAssertEqual(
            winCurrentColorFill(nativeSlotID: host.retainedExecutorRoot!.nativeSlotID!),
            Win32ColorDescriptor(red: 0.8, green: 0.4, blue: 0.2, opacity: 1.0)
        )
    }

    func testWin32ViewHostMutatesMixedTextAndColorLeavesInPlace() {
        let ctx = testContext()
        var title = "Before"
        var swatch = Color(red: 0.2, green: 0.3, blue: 0.4)

        let host = Win32ViewHost(
            context: ctx,
            buildBody: { ctx in
                winRenderView(VStack {
                    Text(title)
                    swatch
                }, in: ctx)
            },
            describeBody: {
                winDescribeView(VStack {
                    Text(title)
                    swatch
                })
            }
        )

        let child = host.buildBody(RenderContext(parent: host.container, hInstance: ctx.hInstance))
        if let c = child { host.addChild(c) }

        let originalRoot = GetWindow(host.container, UINT(GW_CHILD))
        let originalTextSlot = host.retainedExecutorRoot?.children[0].nativeSlotID
        let originalColorSlot = host.retainedExecutorRoot?.children[1].nativeSlotID

        title = "After"
        swatch = Color(red: 0.9, green: 0.1, blue: 0.2)
        host.rebuild()

        let rebuiltRoot = GetWindow(host.container, UINT(GW_CHILD))
        XCTAssertEqual(originalRoot, rebuiltRoot)
        XCTAssertEqual(originalTextSlot, host.retainedExecutorRoot?.children[0].nativeSlotID)
        XCTAssertEqual(originalColorSlot, host.retainedExecutorRoot?.children[1].nativeSlotID)

        let textHwnd = HWND(bitPattern: originalTextSlot!)
        let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
        defer { buffer.deallocate() }
        GetWindowTextW(textHwnd!, buffer, 64)
        XCTAssertEqual(String(decodingCString: buffer, as: UTF16.self), "After")
        XCTAssertEqual(
            winCurrentColorFill(nativeSlotID: originalColorSlot!),
            Win32ColorDescriptor(red: 0.9, green: 0.1, blue: 0.2, opacity: 1.0)
        )
    }

    func testWin32ViewHostFallsBackToFullRebuildForUnsupportedIntent() {
        let ctx = testContext()
        var padding = 4
        let host = Win32ViewHost(
            context: ctx,
            buildBody: { ctx in
                winRenderView(Text("Pad").padding(top: padding, bottom: padding, leading: padding, trailing: padding), in: ctx)
            },
            describeBody: {
                winDescribeView(Text("Pad").padding(top: padding, bottom: padding, leading: padding, trailing: padding))
            }
        )

        let child = host.buildBody(RenderContext(parent: host.container, hInstance: ctx.hInstance))
        if let c = child { host.addChild(c) }

        let originalRoot = GetWindow(host.container, UINT(GW_CHILD))
        let originalTextSlot = host.retainedExecutorRoot?.children[0].nativeSlotID

        padding = 12
        host.rebuild()

        let rebuiltRoot = GetWindow(host.container, UINT(GW_CHILD))
        XCTAssertNotEqual(originalRoot, rebuiltRoot)
        XCTAssertNotEqual(originalTextSlot, host.retainedExecutorRoot?.children[0].nativeSlotID)
    }

    // MARK: - Win32Backend

    func testWin32BackendInstantiates() {
        _ = Win32Backend()
    }

    // MARK: - Color view

    func testColorViewCreatesHWND() {
        let ctx = testContext()
        let hwnd = winRenderView(Color.red, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    // MARK: - ZStack

    func testZStackCreatesOverlaidChildren() {
        let ctx = testContext()
        let hwnd = winRenderView(ZStack {
            Color.blue
            Text("Over")
        }, in: ctx)
        XCTAssertNotNil(hwnd)

        var count = 0
        var child = GetWindow(hwnd!, UINT(GW_CHILD))
        while child != nil {
            count += 1
            child = GetWindow(child!, UINT(GW_HWNDNEXT))
        }
        XCTAssertEqual(count, 2, "ZStack with 2 children should have 2 child HWNDs")
    }

    // MARK: - TextField

    func testTextFieldCreatesEditControl() {
        let ctx = testContext()
        let binding = Binding<String>(get: { "hello" }, set: { _ in })
        let hwnd = winRenderView(TextField("Placeholder", text: binding), in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertEqual(className(of: hwnd!), "Edit", "TextField should create a Win32 EDIT control")
    }

    func testTextFieldInitialText() {
        let ctx = testContext()
        let binding = Binding<String>(get: { "initial" }, set: { _ in })
        let hwnd = winRenderView(TextField("", text: binding), in: ctx)!

        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
        defer { buf.deallocate() }
        GetWindowTextW(hwnd, buf, 64)
        let text = String(decodingCString: buf, as: UTF16.self)
        XCTAssertEqual(text, "initial")
    }

    func testTextFieldBindingUpdatesOnChange() {
        let ctx = testContext()
        var value = "start"
        let binding = Binding<String>(get: { value }, set: { value = $0 })
        let hwnd = winRenderView(TextField("", text: binding), in: ctx)!

        // Simulate user typing by setting the edit text and sending EN_CHANGE
        let newText: [WCHAR] = Array("typed".utf16) + [0]
        _ = newText.withUnsafeBufferPointer { ptr in
            SetWindowTextW(hwnd, ptr.baseAddress!)
        }
        // EN_CHANGE is sent to the parent via WM_COMMAND
        // The SubclassHandler on the edit control intercepts this
        let controlID = WPARAM(GetDlgCtrlID(hwnd))
        let enChange = WPARAM(controlID | (WPARAM(EN_CHANGE) << 16))
        SendMessageW(hwnd, UINT(WM_COMMAND), enChange, LPARAM(Int(bitPattern: hwnd)))

        XCTAssertEqual(value, "typed", "Binding should update when EDIT text changes")
    }

    func testTextFieldPlaceholder() {
        let ctx = testContext()
        let binding = Binding<String>(get: { "" }, set: { _ in })
        let hwnd = winRenderView(TextField("Enter name", text: binding), in: ctx)!

        // EM_GETCUEBANNER retrieves the placeholder text
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
        defer { buf.deallocate() }
        let result = SendMessageW(hwnd, UINT(EM_GETCUEBANNER), WPARAM(UInt(bitPattern: buf)), 64)
        if result != 0 {
            let placeholder = String(decodingCString: buf, as: UTF16.self)
            XCTAssertEqual(placeholder, "Enter name")
        }
        // Note: EM_GETCUEBANNER may not be available on all Windows versions,
        // so we don't fail if it returns 0
    }

    func testTextFieldHasTabStop() {
        let ctx = testContext()
        let binding = Binding<String>(get: { "" }, set: { _ in })
        let hwnd = winRenderView(TextField("", text: binding), in: ctx)!

        let style = win32_GetWindowLongPtrW(hwnd, GWL_STYLE)
        XCTAssertNotEqual(style & LONG_PTR(WS_TABSTOP), 0,
                          "TextField should have WS_TABSTOP for keyboard navigation")
    }

    // MARK: - FocusedView (@FocusState<Bool>)

    func testFocusedViewCreatesHWND() {
        let ctx = testContext()
        let binding = Binding<String>(get: { "" }, set: { _ in })
        let focusState = FocusState<Bool>()

        let view = TextField("", text: binding).focused(focusState)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "FocusedView should produce an HWND")
        XCTAssertEqual(className(of: hwnd!), "Edit", "FocusedView wrapping TextField should still be an Edit")
    }

    func testFocusedViewUpdatesStateOnFocus() {
        let ctx = testContext()
        let binding = Binding<String>(get: { "" }, set: { _ in })
        let focus = FocusState<Bool>()

        let view = TextField("", text: binding).focused(focus)
        let hwnd = winRenderView(view, in: ctx)!

        XCTAssertEqual(focus.wrappedValue, false, "Initially not focused")

        // Simulate gaining focus
        SendMessageW(hwnd, UINT(WM_SETFOCUS), 0, 0)
        // The subclass proc fires onGainFocus → storage.setValue(true)
        // But since setValue only triggers rebuild when programmatic, we
        // check the storage value directly
        XCTAssertEqual(focus.storage.value, true, "@FocusState should be true after WM_SETFOCUS")

        // Simulate losing focus
        SendMessageW(hwnd, UINT(WM_KILLFOCUS), 0, 0)
        XCTAssertEqual(focus.storage.value, false, "@FocusState should be false after WM_KILLFOCUS")
    }

    // MARK: - FocusedEqualsView (@FocusState<Value?>)

    func testMultipleFocusedFieldsShareStorage() {
        let ctx = testContext()
        enum Field: Hashable { case name, email }
        let focus = FocusState<Field?>()

        let nameBinding = Binding<String>(get: { "" }, set: { _ in })
        let emailBinding = Binding<String>(get: { "" }, set: { _ in })

        let nameField = TextField("Name", text: nameBinding).focused(focus, equals: .name)
        let emailField = TextField("Email", text: emailBinding).focused(focus, equals: .email)

        let nameHwnd = winRenderView(nameField, in: ctx)!
        let emailHwnd = winRenderView(emailField, in: ctx)!

        // Initially no focus
        XCTAssertNil(focus.storage.value as Any?)

        // Focus name field
        SendMessageW(nameHwnd, UINT(WM_SETFOCUS), 0, 0)
        XCTAssertEqual(focus.storage.value, .name, "Focusing name field should set storage to .name")

        // Focus email field (name loses focus first)
        SendMessageW(nameHwnd, UINT(WM_KILLFOCUS), 0, 0)
        SendMessageW(emailHwnd, UINT(WM_SETFOCUS), 0, 0)
        XCTAssertEqual(focus.storage.value, .email, "Focusing email field should set storage to .email")

        // Lose focus entirely
        SendMessageW(emailHwnd, UINT(WM_KILLFOCUS), 0, 0)
        XCTAssertNil(focus.storage.value as Any?, "Losing focus should clear storage to nil")
    }

    func testFocusedEqualsDoesNotClearWhenOtherFieldTakesFocus() {
        let ctx = testContext()
        enum Field: Hashable { case a, b }
        let focus = FocusState<Field?>()

        let bindingA = Binding<String>(get: { "" }, set: { _ in })
        let bindingB = Binding<String>(get: { "" }, set: { _ in })

        let fieldA = TextField("A", text: bindingA).focused(focus, equals: .a)
        let fieldB = TextField("B", text: bindingB).focused(focus, equals: .b)

        let hwndA = winRenderView(fieldA, in: ctx)!
        let hwndB = winRenderView(fieldB, in: ctx)!

        // Focus A
        SendMessageW(hwndA, UINT(WM_SETFOCUS), 0, 0)
        XCTAssertEqual(focus.storage.value, .a)

        // B gets focus — A's onLoseFocus fires, but by then storage is .a
        // which matches A, so it clears. Then B's onGainFocus sets .b
        SendMessageW(hwndA, UINT(WM_KILLFOCUS), 0, 0)
        SendMessageW(hwndB, UINT(WM_SETFOCUS), 0, 0)
        XCTAssertEqual(focus.storage.value, .b,
                       "Storage should be .b, not nil — B's gain should override A's clear")
    }

    // MARK: - Input state preservation

    func testSaveRestoreEditCursorPosition() {
        let ctx = testContext()
        let host = Win32ViewHost(
            context: ctx,
            buildBody: { ctx in
                let binding = Binding<String>(get: { "Hello World" }, set: { _ in })
                return winRenderView(TextField("", text: binding), in: ctx)
            },
            describeBody: {
                Win32DescriptorNode(kind: .composite, typeName: "TextFieldHost")
            }
        )

        let child = host.buildBody(RenderContext(parent: host.container, hInstance: ctx.hInstance))
        if let c = child { host.addChild(c) }

        // Find the Edit control and set cursor to position 5
        var edits: [HWND] = []
        collectEditControls(in: host.container, into: &edits)
        guard let edit = edits.first else {
            XCTFail("Should have an Edit control")
            return
        }
        SendMessageW(edit, UINT(EM_SETSEL), 5, 5)

        // Save state
        let snapshot = saveInputState(in: host.container)
        XCTAssertEqual(snapshot.editStates.count, 1)
        XCTAssertEqual(snapshot.editStates[0].selStart, 5)
        XCTAssertEqual(snapshot.editStates[0].selEnd, 5)
    }

    func testMultipleEditsCursorPreservation() {
        let ctx = testContext()

        // Create two TextFields in a VStack
        let binding1 = Binding<String>(get: { "First" }, set: { _ in })
        let binding2 = Binding<String>(get: { "Second" }, set: { _ in })
        let hwnd = winRenderView(VStack {
            TextField("A", text: binding1)
            TextField("B", text: binding2)
        }, in: ctx)!

        // Find all Edit controls
        var edits: [HWND] = []
        collectEditControls(in: hwnd, into: &edits)
        XCTAssertEqual(edits.count, 2, "Should have 2 Edit controls")

        // Set different cursor positions
        SendMessageW(edits[0], UINT(EM_SETSEL), 3, 3) // cursor at position 3
        SendMessageW(edits[1], UINT(EM_SETSEL), 1, 4) // selection from 1 to 4

        // Save state
        let snapshot = saveInputState(in: hwnd)
        XCTAssertEqual(snapshot.editStates.count, 2)
        XCTAssertEqual(snapshot.editStates[0].selStart, 3)
        XCTAssertEqual(snapshot.editStates[0].selEnd, 3)
        XCTAssertEqual(snapshot.editStates[1].selStart, 1)
        XCTAssertEqual(snapshot.editStates[1].selEnd, 4)
    }

    func testSuppressFocusDoesNotSuppressEditState() {
        let ctx = testContext()
        let host = Win32ViewHost(
            context: ctx,
            buildBody: { ctx in
                let binding = Binding<String>(get: { "Test" }, set: { _ in })
                return winRenderView(TextField("", text: binding), in: ctx)
            },
            describeBody: {
                Win32DescriptorNode(kind: .composite, typeName: "TextFieldHost")
            }
        )

        let child = host.buildBody(RenderContext(parent: host.container, hInstance: ctx.hInstance))
        if let c = child { host.addChild(c) }

        // Set cursor position
        var edits: [HWND] = []
        collectEditControls(in: host.container, into: &edits)
        if let edit = edits.first {
            SetFocus(edit)
            SendMessageW(edit, UINT(EM_SETSEL), 2, 2)
        }

        // Suppress focus restore and rebuild
        host.suppressNextFocusRestore()
        host.rebuild()

        // After rebuild, Edit cursor should still be restored even though focus was suppressed
        var newEdits: [HWND] = []
        collectEditControls(in: host.container, into: &newEdits)
        if let edit = newEdits.first {
            let sel = SendMessageW(edit, UINT(EM_GETSEL), 0, 0)
            let selStart = Int(win32_LOWORD(DWORD_PTR(sel)))
            XCTAssertEqual(selStart, 2,
                "Edit cursor should be preserved even when focus restore is suppressed")
        }
    }
    // MARK: - Gesture views

    func testTapGestureViewCreatesHWND() {
        let ctx = testContext()
        let view = Text("Tap me").onTapGesture { }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testTapGestureFiresOnClick() {
        let ctx = testContext()
        var tapped = false
        let hwnd = winRenderView(Text("Tap").onTapGesture { tapped = true }, in: ctx)!

        // Simulate click: LBUTTONDOWN then LBUTTONUP
        SendMessageW(hwnd, UINT(WM_LBUTTONDOWN), 0, 0)
        SendMessageW(hwnd, UINT(WM_LBUTTONUP), 0, 0)
        XCTAssertTrue(tapped, "Tap gesture should fire on mouse click")
    }

    func testLongPressGestureViewCreatesHWND() {
        let ctx = testContext()
        let view = Text("Hold me").onLongPressGesture { }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testDragGestureViewCreatesHWND() {
        let ctx = testContext()
        let view = Text("Drag me").onDrag(onChanged: { _ in }, onEnded: { _ in })
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testDragGestureFiresOnChanged() {
        let ctx = testContext()
        var lastTranslation: (width: Double, height: Double)?
        let hwnd = winRenderView(
            Text("Drag").onDrag(
                onChanged: { value in lastTranslation = value.translation },
                onEnded: nil
            ),
            in: ctx
        )!

        // Simulate drag: LBUTTONDOWN at (10,10), MOUSEMOVE to (30,20)
        let startLP = LPARAM(Int16(10)) | (LPARAM(Int16(10)) << 16)
        let moveLP = LPARAM(Int16(30)) | (LPARAM(Int16(20)) << 16)
        SendMessageW(hwnd, UINT(WM_LBUTTONDOWN), 0, startLP)
        SendMessageW(hwnd, UINT(WM_MOUSEMOVE), 0, moveLP)

        XCTAssertNotNil(lastTranslation)
        XCTAssertEqual(lastTranslation!.width, 20, accuracy: 0.1)
        XCTAssertEqual(lastTranslation!.height, 10, accuracy: 0.1)

        // Release
        SendMessageW(hwnd, UINT(WM_LBUTTONUP), 0, moveLP)
    }

    func testTapGestureRequiresDownThenUp() {
        let ctx = testContext()
        var tapped = false
        let hwnd = winRenderView(
            Text("Tap").onTapGesture { tapped = true },
            in: ctx
        )!

        // Mouse-down alone should NOT fire
        SendMessageW(hwnd, UINT(WM_LBUTTONDOWN), 0, 0)
        XCTAssertFalse(tapped, "Tap should not fire on mouse-down alone")

        // Mouse-up after mouse-down fires the tap
        SendMessageW(hwnd, UINT(WM_LBUTTONUP), 0, 0)
        XCTAssertTrue(tapped, "Tap should fire on mouse-up after mouse-down")
    }

    func testTapGestureIgnoresStrayMouseUp() {
        let ctx = testContext()
        var tapped = false
        let hwnd = winRenderView(
            Text("Tap").onTapGesture { tapped = true },
            in: ctx
        )!

        // Stray mouse-up without preceding mouse-down should NOT fire
        SendMessageW(hwnd, UINT(WM_LBUTTONUP), 0, 0)
        XCTAssertFalse(tapped, "Stray WM_LBUTTONUP without press should not fire tap")
    }

    func testDragGestureFiresOnEnded() {
        let ctx = testContext()
        var ended = false
        let hwnd = winRenderView(
            Text("Drag").onDrag(onChanged: nil, onEnded: { _ in ended = true }),
            in: ctx
        )!

        // Must exceed minimumDistance (default 10) before onEnded fires
        let startLP = LPARAM(Int16(5)) | (LPARAM(Int16(5)) << 16)
        let moveLP = LPARAM(Int16(50)) | (LPARAM(Int16(50)) << 16)
        SendMessageW(hwnd, UINT(WM_LBUTTONDOWN), 0, startLP)
        SendMessageW(hwnd, UINT(WM_MOUSEMOVE), 0, moveLP)  // exceeds threshold
        SendMessageW(hwnd, UINT(WM_LBUTTONUP), 0, moveLP)
        XCTAssertTrue(ended, "Drag gesture should fire onEnded after exceeding minimumDistance")
    }

    func testTapGestureFiresThroughNestedContainers() {
        let ctx = testContext()
        var tapped = false
        // Gesture on outer VStack, click target is Text inside padding inside frame
        let view = VStack {
            Text("Deep")
                .padding(8)
                .frame(width: 100, height: 50)
        }.onTapGesture { tapped = true }

        let hwnd = winRenderView(view, in: ctx)!

        // Find the deepest STATIC (Text) control
        func findDeepestStatic(_ parent: HWND) -> HWND? {
            var child = GetWindow(parent, UINT(GW_CHILD))
            while let c = child {
                if let found = findDeepestStatic(c) { return found }
                if className(of: c) == "Static" { return c }
                child = GetWindow(c, UINT(GW_HWNDNEXT))
            }
            return nil
        }

        guard let staticHwnd = findDeepestStatic(hwnd) else {
            XCTFail("Should find a STATIC control in the nested hierarchy")
            return
        }

        // With recursive subclassing, the tap gesture proc is installed on every
        // descendant HWND including this deeply nested STATIC. A full
        // mouse-down + mouse-up sequence on it fires the shared handler.
        SendMessageW(staticHwnd, UINT(WM_LBUTTONDOWN), 0, 0)
        SendMessageW(staticHwnd, UINT(WM_LBUTTONUP), 0, 0)
        XCTAssertTrue(tapped, "Tap gesture should fire on deeply nested descendant via recursive subclassing")
    }
    // MARK: - Phase 3 views

    func testToggleCreatesCheckbox() {
        let ctx = testContext()
        let binding = Binding<Bool>(get: { false }, set: { _ in })
        let hwnd = winRenderView(Toggle("Dark Mode", isOn: binding), in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertEqual(className(of: hwnd!), "Button", "Toggle should create a Button control")
    }

    func testToggleInitialState() {
        let ctx = testContext()
        let binding = Binding<Bool>(get: { true }, set: { _ in })
        let hwnd = winRenderView(Toggle("On", isOn: binding), in: ctx)!
        let checked = SendMessageW(hwnd, UINT(BM_GETCHECK), 0, 0)
        XCTAssertEqual(checked, LRESULT(BST_CHECKED), "Toggle with true binding should be checked")
    }

    func testToggleClickUpdatesBinding() {
        let ctx = testContext()
        var value = false
        let binding = Binding<Bool>(get: { value }, set: { value = $0 })
        let hwnd = winRenderView(Toggle("Test", isOn: binding), in: ctx)!

        // Simulate click: set check state then send BN_CLICKED via WM_COMMAND
        SendMessageW(hwnd, UINT(BM_SETCHECK), WPARAM(BST_CHECKED), 0)
        let controlID = WPARAM(GetDlgCtrlID(hwnd))
        let handled = dispatchCommand(wParam: controlID)
        XCTAssertTrue(handled)
        XCTAssertTrue(value, "Toggle click should set binding to true")
    }

    func testSliderCreatesD2DSurface() {
        let ctx = testContext()
        let binding = Binding<Double>(get: { 0.5 }, set: { _ in })
        let hwnd = winRenderView(Slider(value: binding), in: ctx)
        XCTAssertNotNil(hwnd)
        // D2D slider renders as a SwiftUID2DSurface HWND
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface")
        var rect = RECT()
        GetWindowRect(hwnd!, &rect)
        XCTAssertGreaterThan(rect.right - rect.left, 0)
    }

    func testScrollViewCreatesContainer() {
        let ctx = testContext()
        let hwnd = winRenderView(ScrollView { Text("scrollable") }, in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertEqual(className(of: hwnd!), "SwiftUIScrollView")
    }

    func testListCreatesScrollView() {
        let ctx = testContext()
        let hwnd = winRenderView(List {
            ForEach(0..<3) { i in Text("Item \(i)") }
        }, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testImageCreatesSystemIcon() {
        let ctx = testContext()
        let hwnd = winRenderView(Image(systemName: "gear"), in: ctx)
        XCTAssertNotNil(hwnd)
        // System icon renders as a container with an icon child, not text fallback
        var rect = RECT()
        GetWindowRect(hwnd!, &rect)
        let w = rect.right - rect.left
        let h = rect.bottom - rect.top
        XCTAssertGreaterThan(w, 0)
        XCTAssertGreaterThan(h, 0)
    }

    // MARK: - Phase 4A views

    func testSecureFieldCreatesPasswordEdit() {
        let ctx = testContext()
        let binding = Binding<String>(get: { "" }, set: { _ in })
        let hwnd = winRenderView(SecureField("Password", text: binding), in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertEqual(className(of: hwnd!), "Edit")
        let style = win32_GetWindowLongPtrW(hwnd!, GWL_STYLE)
        XCTAssertNotEqual(style & LONG_PTR(ES_PASSWORD), 0, "SecureField should have ES_PASSWORD")
    }

    func testTextEditorCreatesMultilineEdit() {
        let ctx = testContext()
        let binding = Binding<String>(get: { "hello\nworld" }, set: { _ in })
        let hwnd = winRenderView(TextEditor(text: binding), in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertEqual(className(of: hwnd!), "Edit")
        let style = win32_GetWindowLongPtrW(hwnd!, GWL_STYLE)
        XCTAssertNotEqual(style & LONG_PTR(ES_MULTILINE), 0, "TextEditor should have ES_MULTILINE")
    }

    func testStepperCreatesContainer() {
        let ctx = testContext()
        let binding = Binding<Double>(get: { 5 }, set: { _ in })
        let hwnd = winRenderView(Stepper("Count", value: binding), in: ctx)
        XCTAssertNotNil(hwnd)
        // Should have children: label, value, -, +
        var count = 0
        var child = GetWindow(hwnd!, UINT(GW_CHILD))
        while child != nil {
            count += 1
            child = GetWindow(child!, UINT(GW_HWNDNEXT))
        }
        XCTAssertGreaterThanOrEqual(count, 3, "Stepper should have label + value + buttons")
    }

    func testProgressViewCreatesBar() {
        let ctx = testContext()
        let hwnd = winRenderView(ProgressView(value: 0.5), in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testLabelCreatesStatic() {
        let ctx = testContext()
        let hwnd = winRenderView(Label("Settings", systemImage: "gear"), in: ctx)
        XCTAssertNotNil(hwnd)
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
        defer { buf.deallocate() }
        GetWindowTextW(hwnd!, buf, 64)
        let text = String(decodingCString: buf, as: UTF16.self)
        XCTAssertEqual(text, "[gear] Settings")
    }

    func testLinkCreatesButton() {
        let ctx = testContext()
        let hwnd = winRenderView(Link("Visit", destination: "https://example.com"), in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertEqual(className(of: hwnd!), "Button")
    }

    // MARK: - Phase 4B modifiers

    func testOnAppearFiresAction() {
        let ctx = testContext()
        // onAppear defers via runOnMainThread — in tests without a message
        // loop, just verify it renders without crash
        let hwnd = winRenderView(Text("appear").onAppear { }, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testOnDisappearRendersContent() {
        let ctx = testContext()
        let hwnd = winRenderView(Text("disappear").onDisappear { }, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testOverlayRendersContentAndOverlay() {
        let ctx = testContext()
        let hwnd = winRenderView(
            Text("base").overlay(alignment: .center) { Text("top") },
            in: ctx
        )
        XCTAssertNotNil(hwnd)
        var count = 0
        var child = GetWindow(hwnd!, UINT(GW_CHILD))
        while child != nil {
            count += 1
            child = GetWindow(child!, UINT(GW_HWNDNEXT))
        }
        XCTAssertEqual(count, 2, "Overlay should have base content + overlay child")
    }

    func testSectionRendersWithHeader() {
        let ctx = testContext()
        let hwnd = winRenderView(Section("Settings") { Text("Content") }, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testFormRendersContent() {
        let ctx = testContext()
        let hwnd = winRenderView(Form { Text("Field") }, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testTabViewCreatesButtonBar() {
        let ctx = testContext()
        let hwnd = winRenderView(TabView {
            Tab("Tab 1") { Text("Page 1") }
            Tab("Tab 2") { Text("Page 2") }
        }, in: ctx)
        XCTAssertNotNil(hwnd)
        var count = 0
        var child = GetWindow(hwnd!, UINT(GW_CHILD))
        while child != nil {
            count += 1
            child = GetWindow(child!, UINT(GW_HWNDNEXT))
        }
        XCTAssertGreaterThanOrEqual(count, 4, "TabView with 2 tabs should have buttons + pages")
    }

    func testTabViewSwitchesPages() {
        let ctx = testContext()
        let hwnd = winRenderView(TabView {
            Tab("Tab 1") { Text("Page 1") }
            Tab("Tab 2") { Text("Page 2") }
        }, in: ctx)!

        // Find tab buttons (Button class) and get second tab's control ID
        var buttons: [HWND] = []
        var child = GetWindow(hwnd, UINT(GW_CHILD))
        while let c = child {
            if className(of: c) == "Button" {
                buttons.append(c)
            }
            child = GetWindow(c, UINT(GW_HWNDNEXT))
        }
        XCTAssertEqual(buttons.count, 2, "Should have 2 tab buttons")
        guard buttons.count == 2 else { return }

        // Click tab 2 — should not crash and should dispatch
        let tab2ID = WPARAM(GetDlgCtrlID(buttons[1]))
        let handled = dispatchCommand(wParam: tab2ID)
        XCTAssertTrue(handled, "Tab 2 button should have a registered command handler")
    }
}

// MARK: - Test helpers

private func collectEditControls(in parent: HWND, into result: inout [HWND]) {
    var child = GetWindow(parent, UINT(GW_CHILD))
    while let c = child {
        if className(of: c) == "Edit" {
            result.append(c)
        }
        collectEditControls(in: c, into: &result)
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
}
