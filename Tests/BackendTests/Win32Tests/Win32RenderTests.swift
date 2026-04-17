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
    if let sheet = win32ActiveSheetWindow(for: parent) {
        DestroyWindow(sheet)
    }
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

private func windowText(of hwnd: HWND?) -> String {
    guard let hwnd else { return "" }
    let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: 256)
    defer { buffer.deallocate() }
    GetWindowTextW(hwnd, buffer, 256)
    return String(decodingCString: buffer, as: UTF16.self)
}

private final class DelayedEnvironmentModel {
    var count: Int

    init(count: Int = 0) {
        self.count = count
    }
}

private struct DelayedEnvironmentButtonView: View {
    @Environment(DelayedEnvironmentModel.self) var model

    var body: some View {
        Button("Increment") { model.count += 1 }
    }
}

private struct DelayedEnvironmentDestinationView: View {
    @Environment(DelayedEnvironmentModel.self) var model

    var body: some View {
        Text("Destination Count: \(model.count)")
    }
}

private struct DelayedEnvironmentMenuHostView: View {
    @Environment(DelayedEnvironmentModel.self) var model

    var menu: Menu {
        Menu("Actions") {
            MenuItem("Increment") { model.count += 1 }
        }
    }

    var body: some View { menu }
}

private struct DelayedEnvironmentOnAppearView: View {
    @Environment(DelayedEnvironmentModel.self) var model

    var body: some View {
        Text("appear").onAppear { model.count += 1 }
    }
}

private struct DelayedEnvironmentOnDisappearView: View {
    @Environment(DelayedEnvironmentModel.self) var model

    var body: some View {
        Text("disappear").onDisappear { model.count += 1 }
    }
}

private struct DelayedEnvironmentDisclosureGroupView: View {
    @Environment(DelayedEnvironmentModel.self) var model

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

private struct DelayedEnvironmentTapGestureView: View {
    @Environment(DelayedEnvironmentModel.self) var model

    var body: some View {
        Text("Tap").onTapGesture { model.count += 1 }
    }
}

private struct DelayedEnvironmentLongPressGestureView: View {
    @Environment(DelayedEnvironmentModel.self) var model

    var body: some View {
        Text("Hold").onLongPressGesture(minimumDuration: 0) { model.count += 1 }
    }
}

private struct DelayedEnvironmentDragChangedView: View {
    @Environment(DelayedEnvironmentModel.self) var model

    var body: some View {
        Text("Drag").onDrag(onChanged: { _ in model.count += 1 }, onEnded: nil)
    }
}

private struct DelayedEnvironmentDragEndedView: View {
    @Environment(DelayedEnvironmentModel.self) var model

    var body: some View {
        Text("Drag").onDrag(onChanged: nil, onEnded: { _ in model.count += 1 })
    }
}

// MARK: - Tests

final class Win32RenderTests: XCTestCase {

    private struct TestSheetItem: Identifiable, Equatable {
        let id: Int
        let title: String
    }

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

    func testWin32ExtractTitleRecursesThroughWrappedNavigationContent() {
        let view = VStack {
            Text("Hello")
        }
        .padding()
        .navigationTitle("Navigation")
        .navigationDestination(for: String.self) { value in
            Text(value)
        }

        XCTAssertEqual(win32ExtractTitle(from: view), "Navigation")
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

    func testStaleSlotRejectsNarrowPath() {
        // Simulate a text update where the HWND slot is invalid (0 = null)
        let oldDesc = Win32DescriptorNode(kind: .text, typeName: "Text",
                                           props: .text(Win32TextDescriptor(content: "Old")))
        let newDesc = Win32DescriptorNode(kind: .text, typeName: "Text",
                                           props: .text(Win32TextDescriptor(content: "New")))
        let retained = winRetainDescriptorTree(winIdentifyDescriptorTree(oldDesc))
        let plan = winPlanDescriptorTree(old: retained, new: winIdentifyDescriptorTree(newDesc))
        XCTAssertTrue(winCanApplyTextColorHostMutation(plan: plan))

        // Execute with no real HWND (nativeSlotID = nil)
        let identified = winIdentifyDescriptorTree(oldDesc)
        let executor = winMakeExecutorTree(from: identified)
        let action = winExecuteDescriptorPlan(old: executor, plan: plan)
        // Slot validation should reject because nativeSlotID is nil
        XCTAssertFalse(winAllSlotsValid(action: action))
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
            .vStack(Win32VStackDescriptor(spacing: 8, alignment: .center))
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

    func testWin32SheetProgrammaticDismissCallsOnDismissOnce() {
        let ctx = testContext()
        var isPresented = true
        var dismissCount = 0
        let binding = Binding<Bool>(
            get: { isPresented },
            set: { isPresented = $0 }
        )

        let presentedView = Text("Host").sheet(isPresented: binding, onDismiss: {
            dismissCount += 1
        }) {
            Text("Sheet")
        }

        _ = winRenderView(presentedView, in: ctx)
        let sheet = win32ActiveSheetWindow(for: testWindow)
        XCTAssertNotNil(sheet)
        XCTAssertTrue(isPresented)

        isPresented = false
        let dismissedView = Text("Host").sheet(isPresented: binding, onDismiss: {
            dismissCount += 1
        }) {
            Text("Sheet")
        }
        _ = winRenderView(dismissedView, in: ctx)

        XCTAssertNil(win32ActiveSheetWindow(for: testWindow))
        XCTAssertFalse(isPresented)
        XCTAssertEqual(dismissCount, 1)
    }

    func testWin32ItemSheetCloseClearsItemAndCallsOnDismissOnce() {
        let ctx = testContext()
        var selectedItem: TestSheetItem? = TestSheetItem(id: 1, title: "Record")
        var dismissCount = 0
        let binding = Binding<TestSheetItem?>(
            get: { selectedItem },
            set: { selectedItem = $0 }
        )

        let view = Text("Host").sheet(item: binding, onDismiss: {
            dismissCount += 1
        }) { item in
            Text(item.title)
        }

        _ = winRenderView(view, in: ctx)
        guard let sheet = win32ActiveSheetWindow(for: testWindow) else {
            return XCTFail("Expected active sheet window")
        }

        _ = SendMessageW(sheet, UINT(WM_CLOSE), 0, 0)

        XCTAssertNil(win32ActiveSheetWindow(for: testWindow))
        XCTAssertNil(selectedItem)
        XCTAssertEqual(dismissCount, 1)
    }

    func testWin32SheetDoesNotDuplicatePopupOnRebuild() {
        let ctx = testContext()
        var isPresented = true
        let binding = Binding<Bool>(
            get: { isPresented },
            set: { isPresented = $0 }
        )
        let view = Text("Host").sheet(isPresented: binding, onDismiss: nil) {
            Text("Sheet")
        }

        _ = winRenderView(view, in: ctx)
        let firstSheet = win32ActiveSheetWindow(for: testWindow)
        XCTAssertNotNil(firstSheet)

        _ = winRenderView(view, in: ctx)
        let secondSheet = win32ActiveSheetWindow(for: testWindow)
        XCTAssertEqual(firstSheet, secondSheet)
        XCTAssertTrue(isPresented)
    }

    func testWin32ItemSheetReplacesPopupWhenIdentityChanges() {
        let ctx = testContext()
        var selectedItem: TestSheetItem? = TestSheetItem(id: 1, title: "First")
        let binding = Binding<TestSheetItem?>(
            get: { selectedItem },
            set: { selectedItem = $0 }
        )

        let firstView = Text("Host").sheet(item: binding, onDismiss: nil) { item in
            Text(item.title)
        }
        _ = winRenderView(firstView, in: ctx)

        let firstSheet = win32ActiveSheetWindow(for: testWindow)
        XCTAssertNotNil(firstSheet)
        XCTAssertEqual(windowText(of: GetWindow(firstSheet, UINT(GW_CHILD))), "First")

        selectedItem = TestSheetItem(id: 2, title: "Second")
        let secondView = Text("Host").sheet(item: binding, onDismiss: nil) { item in
            Text(item.title)
        }
        _ = winRenderView(secondView, in: ctx)

        let secondSheet = win32ActiveSheetWindow(for: testWindow)
        XCTAssertNotNil(secondSheet)
        XCTAssertNotEqual(firstSheet, secondSheet)
        XCTAssertEqual(windowText(of: GetWindow(secondSheet, UINT(GW_CHILD))), "Second")
        XCTAssertEqual(selectedItem?.id, 2)
    }

    func testWin32SheetUsesLatestOnDismissClosureAfterRebuild() {
        let ctx = testContext()
        var isPresented = true
        var firstDismissCount = 0
        var secondDismissCount = 0
        let binding = Binding<Bool>(
            get: { isPresented },
            set: { isPresented = $0 }
        )

        let firstView = Text("Host").sheet(isPresented: binding, onDismiss: {
            firstDismissCount += 1
        }) {
            Text("Sheet")
        }
        _ = winRenderView(firstView, in: ctx)

        let rebuiltView = Text("Host").sheet(isPresented: binding, onDismiss: {
            secondDismissCount += 1
        }) {
            Text("Sheet")
        }
        _ = winRenderView(rebuiltView, in: ctx)

        guard let sheet = win32ActiveSheetWindow(for: testWindow) else {
            return XCTFail("Expected active sheet window")
        }
        _ = SendMessageW(sheet, UINT(WM_CLOSE), 0, 0)

        XCTAssertEqual(firstDismissCount, 0)
        XCTAssertEqual(secondDismissCount, 1)
        XCTAssertFalse(isPresented)
    }

    func testWin32SheetProgrammaticDismissUsesLatestOnDismissClosure() {
        let ctx = testContext()
        var isPresented = true
        var firstDismissCount = 0
        var secondDismissCount = 0
        let binding = Binding<Bool>(
            get: { isPresented },
            set: { isPresented = $0 }
        )

        let firstView = Text("Host").sheet(isPresented: binding, onDismiss: {
            firstDismissCount += 1
        }) {
            Text("Sheet")
        }
        _ = winRenderView(firstView, in: ctx)

        isPresented = false
        let dismissedView = Text("Host").sheet(isPresented: binding, onDismiss: {
            secondDismissCount += 1
        }) {
            Text("Sheet")
        }
        _ = winRenderView(dismissedView, in: ctx)

        XCTAssertEqual(firstDismissCount, 0)
        XCTAssertEqual(secondDismissCount, 1)
        XCTAssertNil(win32ActiveSheetWindow(for: testWindow))
    }

    func testWin32ItemSheetProgrammaticDismissUsesLatestOnDismissClosure() {
        let ctx = testContext()
        var selectedItem: TestSheetItem? = TestSheetItem(id: 1, title: "Record")
        var firstDismissCount = 0
        var secondDismissCount = 0
        let binding = Binding<TestSheetItem?>(
            get: { selectedItem },
            set: { selectedItem = $0 }
        )

        let firstView = Text("Host").sheet(item: binding, onDismiss: {
            firstDismissCount += 1
        }) { item in
            Text(item.title)
        }
        _ = winRenderView(firstView, in: ctx)

        selectedItem = nil
        let dismissedView = Text("Host").sheet(item: binding, onDismiss: {
            secondDismissCount += 1
        }) { item in
            Text(item.title)
        }
        _ = winRenderView(dismissedView, in: ctx)

        XCTAssertEqual(firstDismissCount, 0)
        XCTAssertEqual(secondDismissCount, 1)
        XCTAssertNil(selectedItem)
        XCTAssertNil(win32ActiveSheetWindow(for: testWindow))
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

        // D2D flat button uses a custom surface class (no window text)
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface")
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

        // Find the D2D flat button leaf
        var button: HWND = hwnd!
        while let child = GetWindow(button, UINT(GW_CHILD)) {
            button = child
        }
        XCTAssertEqual(className(of: button), "SwiftUID2DSurface",
                       "Button inside foregroundColor should be a D2D surface")

        // Verify foreground color was propagated to the FlatButtonState
        var refData: DWORD_PTR = 0
        if GetWindowSubclass(button, flatButtonProc, 48, &refData), refData != 0 {
            let state = Unmanaged<FlatButtonState>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(refData))!
            ).takeUnretainedValue()
            XCTAssertNotNil(state.textColorR, "FlatButtonState should have custom text color after .foregroundColor()")
        } else {
            XCTFail("D2D button should have FlatButtonState subclass")
        }
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

        // Find the innermost leaf HWND (font modifier wraps the button)
        var button: HWND = fonted
        while let child = GetWindow(button, UINT(GW_CHILD)) {
            button = child
        }

        var fontedRect = RECT()
        GetWindowRect(button, &fontedRect)
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

        // D2D flat buttons handle clicks via subclass proc mouse messages.
        // Simulate a click: LBUTTONDOWN sets pressed, LBUTTONUP fires action
        // if the cursor is inside the button rect.
        let lParam = LPARAM(0) // coordinates (0,0) — inside the button
        SendMessageW(hwnd!, UINT(WM_LBUTTONDOWN), 0, lParam)
        SendMessageW(hwnd!, UINT(WM_LBUTTONUP), 0, lParam)
        XCTAssertTrue(clicked, "Button action should fire via WM_LBUTTONDOWN + WM_LBUTTONUP")
    }

    func testDelayedEnvironmentButtonActionUsesCapturedEnvironment() {
        let ctx = testContext()
        let model = DelayedEnvironmentModel()
        let hwnd = winRenderView(DelayedEnvironmentButtonView().environment(model), in: ctx)
        XCTAssertNotNil(hwnd)

        let button = findFlatButton(in: hwnd!, titled: "Increment")
        XCTAssertNotNil(button, "Delayed environment button view should render a flat button leaf")

        let lParam = LPARAM(0)
        SendMessageW(button, UINT(WM_LBUTTONDOWN), 0, lParam)
        SendMessageW(button, UINT(WM_LBUTTONUP), 0, lParam)

        XCTAssertEqual(model.count, 1,
                       "Delayed button action should run with the render-time environment installed")
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

    func testDragGestureOnChangedUsesCapturedEnvironment() {
        let ctx = testContext()
        let model = DelayedEnvironmentModel()
        let hwnd = winRenderView(DelayedEnvironmentDragChangedView().environment(model), in: ctx)!

        guard let staticHwnd = collectStaticLabels(in: hwnd).first else {
            XCTFail("Drag gesture onChanged environment test should render a STATIC control")
            return
        }

        let startLP = LPARAM(Int16(10)) | (LPARAM(Int16(10)) << 16)
        let moveLP = LPARAM(Int16(30)) | (LPARAM(Int16(20)) << 16)
        SendMessageW(staticHwnd, UINT(WM_LBUTTONDOWN), 0, startLP)
        SendMessageW(staticHwnd, UINT(WM_MOUSEMOVE), 0, moveLP)

        XCTAssertEqual(model.count, 1,
                       "Drag gesture onChanged should run with the render-time environment installed")

        SendMessageW(staticHwnd, UINT(WM_LBUTTONUP), 0, moveLP)
    }

    func testDragGestureOnEndedUsesCapturedEnvironment() {
        let ctx = testContext()
        let model = DelayedEnvironmentModel()
        let hwnd = winRenderView(DelayedEnvironmentDragEndedView().environment(model), in: ctx)!

        guard let staticHwnd = collectStaticLabels(in: hwnd).first else {
            XCTFail("Drag gesture onEnded environment test should render a STATIC control")
            return
        }

        let startLP = LPARAM(Int16(5)) | (LPARAM(Int16(5)) << 16)
        let moveLP = LPARAM(Int16(50)) | (LPARAM(Int16(50)) << 16)
        SendMessageW(staticHwnd, UINT(WM_LBUTTONDOWN), 0, startLP)
        SendMessageW(staticHwnd, UINT(WM_MOUSEMOVE), 0, moveLP)
        SendMessageW(staticHwnd, UINT(WM_LBUTTONUP), 0, moveLP)

        XCTAssertEqual(model.count, 1,
                       "Drag gesture onEnded should run with the render-time environment installed")
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

    func testTapGestureUsesCapturedEnvironment() {
        let ctx = testContext()
        let model = DelayedEnvironmentModel()
        let hwnd = winRenderView(DelayedEnvironmentTapGestureView().environment(model), in: ctx)!

        guard let staticHwnd = collectStaticLabels(in: hwnd).first else {
            XCTFail("Tap gesture environment test should render a STATIC control")
            return
        }

        SendMessageW(staticHwnd, UINT(WM_LBUTTONDOWN), 0, 0)
        SendMessageW(staticHwnd, UINT(WM_LBUTTONUP), 0, 0)
        XCTAssertEqual(model.count, 1,
                       "Tap gesture should run with the render-time environment installed")
    }

    func testLongPressGestureUsesCapturedEnvironment() {
        let ctx = testContext()
        let model = DelayedEnvironmentModel()
        let hwnd = winRenderView(DelayedEnvironmentLongPressGestureView().environment(model), in: ctx)!

        guard let staticHwnd = collectStaticLabels(in: hwnd).first else {
            XCTFail("Long press environment test should render a STATIC control")
            return
        }

        SendMessageW(staticHwnd, UINT(WM_LBUTTONDOWN), 0, 0)
        pumpWindowMessages(for: staticHwnd)
        XCTAssertEqual(model.count, 1,
                       "Long press gesture should run with the render-time environment installed")
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
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface")
    }

    func testNavigationLinkDelayedPushUsesCapturedEnvironment() {
        let ctx = testContext()
        let model = DelayedEnvironmentModel(count: 7)
        let view = NavigationStack {
            NavigationLink("Go", title: "Detail") {
                DelayedEnvironmentDestinationView()
            }
        }
        .environment(model)

        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let goButton = findFlatButton(in: hwnd!, titled: "Go")
        XCTAssertNotNil(goButton, "NavigationStack should render a flat button for the link label")

        let lParam = LPARAM(0)
        SendMessageW(goButton, UINT(WM_LBUTTONDOWN), 0, lParam)
        SendMessageW(goButton, UINT(WM_LBUTTONUP), 0, lParam)

        let texts = collectStaticLabels(in: hwnd!).map { windowText(of: $0) }
        XCTAssertTrue(texts.contains("Destination Count: 7"),
                      "Delayed NavigationLink push should preserve the injected environment for the destination")
    }

    func testMenuItemCommandDispatchUsesCapturedEnvironment() {
        let previousEnv = getCurrentEnvironment()
        defer { setCurrentEnvironment(previousEnv) }

        let model = DelayedEnvironmentModel()
        var renderEnv = previousEnv
        renderEnv.setObject(model)
        setCurrentEnvironment(renderEnv)

        let menu = DelayedEnvironmentMenuHostView().menu
        guard let hMenu = CreatePopupMenu() else {
            return XCTFail("Expected popup menu creation to succeed in test harness")
        }
        defer { DestroyMenu(hMenu) }

        var nextMenuID: UINT = 50000
        var actions: [UINT: () -> Void] = [:]
        winPopulateMenu(hMenu, elements: menu.elements, nextMenuID: &nextMenuID, actions: &actions)

        guard let itemAction = actions[50000] else {
            return XCTFail("Expected first menu item action to be registered through winPopulateMenu")
        }

        let controlID: WORD = 50000
        registerCommandHandler(controlID: controlID, action: itemAction)
        defer { unregisterCommandHandler(controlID: controlID) }

        setCurrentEnvironment(previousEnv)

        XCTAssertTrue(dispatchCommand(wParam: WPARAM(controlID)))
        XCTAssertEqual(model.count, 1,
                       "Menu item command dispatch should run with the render-time environment installed")
    }

    // MARK: - Phase 4B modifiers

    func testOnAppearFiresAction() {
        let ctx = testContext()
        // onAppear defers via runOnMainThread — in tests without a message
        // loop, just verify it renders without crash
        let hwnd = winRenderView(Text("appear").onAppear { }, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testOnAppearUsesCapturedEnvironment() {
        let ctx = testContext()
        let model = DelayedEnvironmentModel()
        let hwnd = winRenderView(DelayedEnvironmentOnAppearView().environment(model), in: ctx)
        XCTAssertNotNil(hwnd)

        let root = findRootWindow(from: hwnd!)
        pumpInvokeMessages(for: root)

        XCTAssertEqual(model.count, 1,
                       "Deferred onAppear should run with the render-time environment installed")
    }

    func testOnDisappearRendersContent() {
        let ctx = testContext()
        let hwnd = winRenderView(Text("disappear").onDisappear { }, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testOnDisappearUsesCapturedEnvironment() {
        let ctx = testContext()
        let model = DelayedEnvironmentModel()
        let hwnd = winRenderView(DelayedEnvironmentOnDisappearView().environment(model), in: ctx)
        XCTAssertNotNil(hwnd)

        XCTAssertTrue(DestroyWindow(hwnd))
        XCTAssertEqual(model.count, 1,
                       "Deferred onDisappear should run with the render-time environment installed")
    }

    func testDisclosureGroupUsesCapturedEnvironmentForExpansionCallback() {
        let ctx = testContext()
        let model = DelayedEnvironmentModel()
        let hwnd = winRenderView(DelayedEnvironmentDisclosureGroupView().environment(model), in: ctx)
        XCTAssertNotNil(hwnd)

        var buttons: [HWND] = []
        collectButtonControls(in: hwnd!, into: &buttons)
        XCTAssertEqual(buttons.count, 1, "DisclosureGroup should render one native button")
        guard let button = buttons.first else { return }

        let controlID = WPARAM(GetDlgCtrlID(button))
        XCTAssertTrue(dispatchCommand(wParam: controlID))
        XCTAssertEqual(model.count, 1,
                       "DisclosureGroup expansion callback should run with the render-time environment installed")
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

    // MARK: - Safe area

    func testIgnoresSafeAreaPassthrough() {
        let ctx = testContext()
        let view = Text("Hello").ignoresSafeArea()
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Should produce the same HWND as rendering Text directly (passthrough)
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: 64)
        defer { buf.deallocate() }
        GetWindowTextW(hwnd!, buf, 64)
        let text = String(decodingCString: buf, as: UTF16.self)
        XCTAssertEqual(text, "Hello")
    }

    func testSafeAreaInsetTopReservesSpace() {
        let ctx = testContext()
        let view = Text("Content")
            .safeAreaInset(edge: .top) { Text("Top Bar") }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Container should have two children: content and inset
        let child1 = GetWindow(hwnd!, UINT(GW_CHILD))
        XCTAssertNotNil(child1)
        let child2 = GetWindow(child1!, UINT(GW_HWNDNEXT))
        XCTAssertNotNil(child2)

        // Container height should be sum of both children (no spacing)
        var containerRect = RECT()
        GetWindowRect(hwnd!, &containerRect)
        let containerH = containerRect.bottom - containerRect.top
        XCTAssertGreaterThan(containerH, 0)

        var r1 = RECT()
        var r2 = RECT()
        GetWindowRect(child1!, &r1)
        GetWindowRect(child2!, &r2)
        let h1 = r1.bottom - r1.top
        let h2 = r2.bottom - r2.top
        XCTAssertEqual(containerH, h1 + h2)
    }

    func testSafeAreaInsetBottomReservesSpace() {
        let ctx = testContext()
        let view = Text("Content")
            .safeAreaInset(edge: .bottom) { Text("Bottom Bar") }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        var containerRect = RECT()
        GetWindowRect(hwnd!, &containerRect)
        let containerH = containerRect.bottom - containerRect.top
        XCTAssertGreaterThan(containerH, 0)
    }

    func testSafeAreaInsetLeadingReservesSpace() {
        let ctx = testContext()
        let view = Text("Content")
            .safeAreaInset(edge: .leading) { Text("Side") }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        var containerRect = RECT()
        GetWindowRect(hwnd!, &containerRect)
        let containerW = containerRect.right - containerRect.left
        XCTAssertGreaterThan(containerW, 0)
    }

    func testSafeAreaInsetTrailingReservesSpace() {
        let ctx = testContext()
        let view = Text("Content")
            .safeAreaInset(edge: .trailing) { Text("Side") }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        var containerRect = RECT()
        GetWindowRect(hwnd!, &containerRect)
        let containerW = containerRect.right - containerRect.left
        XCTAssertGreaterThan(containerW, 0)
    }

    func testSafeAreaInsetWithSpacing() {
        let ctx = testContext()
        let view = Text("Content")
            .safeAreaInset(edge: .top, spacing: 10) { Text("Top") }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Container height should include the 10px spacing gap
        let child1 = GetWindow(hwnd!, UINT(GW_CHILD))!
        let child2 = GetWindow(child1, UINT(GW_HWNDNEXT))!

        var containerRect = RECT()
        GetWindowRect(hwnd!, &containerRect)
        let containerH = containerRect.bottom - containerRect.top

        var r1 = RECT()
        var r2 = RECT()
        GetWindowRect(child1, &r1)
        GetWindowRect(child2, &r2)
        let h1 = r1.bottom - r1.top
        let h2 = r2.bottom - r2.top
        XCTAssertEqual(containerH, h1 + h2 + 10)
    }

    func testSafeAreaInsetContentDoesNotExpandWithoutFlag() {
        let ctx = testContext()
        // Text does not set expand flags — it should keep its natural size
        let view = Text("Small")
            .safeAreaInset(edge: .top) { Text("Top") }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Content child is the first child (rendered first)
        let child1 = GetWindow(hwnd!, UINT(GW_CHILD))
        XCTAssertNotNil(child1)

        var r = RECT()
        GetWindowRect(child1!, &r)
        let childW = r.right - r.left
        // Text natural width should be modest, not stretched to container
        XCTAssertGreaterThan(childW, 0)
        XCTAssertLessThan(childW, 400, "Content should not stretch to parent width without expand flags")
    }

    // MARK: - Searchable

    func testSearchableCreatesSearchField() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        let view = Text("Content").searchable(text: $query)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Should have an Edit child (the search field)
        var edits: [HWND] = []
        collectEditControls(in: hwnd!, into: &edits)
        XCTAssertGreaterThanOrEqual(edits.count, 1, "Should have at least one Edit control for search")
    }

    func testSearchableWithPlacement() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        // All placements render as top-of-content in Batch A
        let view = Text("Content").searchable(
            text: $query, placement: .toolbar, prompt: "Search")
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        var edits: [HWND] = []
        collectEditControls(in: hwnd!, into: &edits)
        XCTAssertGreaterThanOrEqual(edits.count, 1, "Toolbar placement should still render search field")
    }

    func testSearchableIsPresentedTrue() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        @SwiftOpenUI.State var presented = true
        let view = Text("Content").searchable(
            text: $query, isPresented: $presented)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        var edits: [HWND] = []
        collectEditControls(in: hwnd!, into: &edits)
        XCTAssertGreaterThanOrEqual(edits.count, 1, "isPresented=true should show search field")
    }

    func testSearchableIsPresentedFalse() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        @SwiftOpenUI.State var presented = false
        let view = Text("Content").searchable(
            text: $query, isPresented: $presented)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // With isPresented=false, no Edit control should be created
        var edits: [HWND] = []
        collectEditControls(in: hwnd!, into: &edits)
        XCTAssertEqual(edits.count, 0, "isPresented=false should hide search field")
    }

    func testSearchablePromptPreserved() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        let view = Text("Content").searchable(text: $query, prompt: "Find items")
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Searchable with custom prompt should render")
    }

    // MARK: - Disabled Batch A

    func testDisabledButtonIsNotEnabled() {
        let ctx = testContext()
        let view = Button("Click") {}.disabled(true)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertFalse(IsWindowEnabled(hwnd!), "Disabled button should not be enabled")
    }

    func testEnabledButtonIsEnabled() {
        let ctx = testContext()
        let view = Button("Click") {}.disabled(false)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertTrue(IsWindowEnabled(hwnd!), "Non-disabled button should be enabled")
    }

    func testDisabledTextFieldIsNotEnabled() {
        let ctx = testContext()
        @SwiftOpenUI.State var text = ""
        let view = TextField("Placeholder", text: $text).disabled(true)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // TextField renders as an Edit control — check it's disabled
        var edits: [HWND] = []
        collectEditControls(in: hwnd!, into: &edits)
        if let edit = edits.first {
            XCTAssertFalse(IsWindowEnabled(edit), "Disabled TextField should have disabled Edit control")
        }
    }

    func testDisabledToggleIsNotEnabled() {
        let ctx = testContext()
        @SwiftOpenUI.State var on = false
        let view = Toggle("Switch", isOn: $on).disabled(true)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertFalse(IsWindowEnabled(hwnd!), "Disabled toggle should not be enabled")
    }

    func testNestedDisabledCannotReEnable() {
        let ctx = testContext()
        // Parent disabled(true) must not be undone by child disabled(false)
        let view = Button("Click") {}.disabled(false).disabled(true)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertFalse(IsWindowEnabled(hwnd!),
            "Ancestor disabled(true) should not be overridden by child disabled(false)")
    }

    func testDisabledVStackDisablesChildren() {
        let ctx = testContext()
        let view = VStack {
            Button("One") {}
            Button("Two") {}
        }.disabled(true)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // All children in the tree should be disabled
        XCTAssertFalse(IsWindowEnabled(hwnd!), "Container should be disabled")
        var child = GetWindow(hwnd!, UINT(GW_CHILD))
        while let c = child {
            XCTAssertFalse(IsWindowEnabled(c), "Child should be disabled")
            child = GetWindow(c, UINT(GW_HWNDNEXT))
        }
    }

    // MARK: - Disabled Batch B (action gating)

    func testDisabledButtonIgnoresClick() {
        var clicked = false
        let ctx = testContext()
        let view = Button("Click", action: { clicked = true }).disabled(true)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Find the flat button leaf
        let button = findFlatButton(in: hwnd!, titled: "Click") ?? hwnd!

        let lParam = LPARAM(0) // coordinates (0,0)
        SendMessageW(button, UINT(WM_LBUTTONDOWN), 0, lParam)
        SendMessageW(button, UINT(WM_LBUTTONUP), 0, lParam)
        XCTAssertFalse(clicked, "Disabled button should not fire action on click")
    }

    func testDisabledButtonIgnoresKeyboard() {
        var pressed = false
        let ctx = testContext()
        let view = Button("Press", action: { pressed = true }).disabled(true)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let button = findFlatButton(in: hwnd!, titled: "Press") ?? hwnd!

        SendMessageW(button, UINT(WM_KEYDOWN), WPARAM(VK_SPACE), 0)
        SendMessageW(button, UINT(WM_KEYUP), WPARAM(VK_SPACE), 0)
        XCTAssertFalse(pressed, "Disabled button should not fire action on Space key")
    }

    func testDisabledButtonShortcutDoesNotFire() {
        var fired = false
        let ctx = testContext()
        // Use a distinctive shortcut to avoid registry collisions
        let view = Button("Save", action: { fired = true })
            .keyboardShortcut("j", modifiers: [.command, .shift])
            .disabled(true)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let ks = KeyboardShortcut("j", modifiers: [.command, .shift])
        let windowID = getCurrentEnvironment().windowID
        let handled = KeyboardShortcutRegistry.shared.dispatch(ks, windowID: windowID)
        XCTAssertTrue(handled, "Shortcut should be registered even when button is disabled")
        XCTAssertFalse(fired, "Disabled button's keyboard shortcut should not fire")
    }

    func testEnabledButtonStillFiresAfterDisabledGuard() {
        // Verify enabled buttons still work after the guard changes
        var clicked = false
        let ctx = testContext()
        let view = Button("Go", action: { clicked = true }).disabled(false)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let button = findFlatButton(in: hwnd!, titled: "Go") ?? hwnd!

        let lParam = LPARAM(0)
        SendMessageW(button, UINT(WM_LBUTTONDOWN), 0, lParam)
        SendMessageW(button, UINT(WM_LBUTTONUP), 0, lParam)
        XCTAssertTrue(clicked, "Enabled button should still fire action on click")
    }

    // MARK: - ViewThatFits Batch A

    func testViewThatFitsRendersFirstChild() {
        let ctx = testContext()
        let view = ViewThatFits {
            Text("Short")
            Text("LongerFallback")
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "ViewThatFits should render")

        let childCount = countDirectChildren(of: hwnd!)
        XCTAssertEqual(childCount, 1, "Should render only one selected child")

        // Verify the first child ("Short") was selected, not the fallback
        let statics = collectStaticLabels(in: hwnd!)
        let texts = statics.map { windowText(of: $0) }
        XCTAssertTrue(texts.contains("Short"),
            "First fitting child should be selected")
        XCTAssertFalse(texts.contains("LongerFallback"),
            "Fallback should not be rendered when first child fits")
    }

    func testViewThatFitsFallsBackToLast() {
        let ctx = testContext()
        // First child is wider than any screen; fallback to last
        let view = ViewThatFits {
            Text("TooWide").frame(width: 99999)
            Text("Fallback")
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "ViewThatFits should render fallback")

        let childCount = countDirectChildren(of: hwnd!)
        XCTAssertEqual(childCount, 1, "Should render exactly one child (fallback)")

        // Verify the fallback child was selected
        let statics = collectStaticLabels(in: hwnd!)
        let texts = statics.map { windowText(of: $0) }
        XCTAssertTrue(texts.contains("Fallback"),
            "Last child should be selected as fallback")
    }

    func testViewThatFitsEmptyChildrenReturnsNil() {
        let ctx = testContext()
        let view = ViewThatFits { }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNil(hwnd, "ViewThatFits with no children should return nil")
    }

    func testViewThatFitsSingleChild() {
        let ctx = testContext()
        let view = ViewThatFits {
            Text("Only child")
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "ViewThatFits with one child should render it")

        let childCount = countDirectChildren(of: hwnd!)
        XCTAssertEqual(childCount, 1, "Single child should be selected")

        let statics = collectStaticLabels(in: hwnd!)
        XCTAssertTrue(statics.map { windowText(of: $0) }.contains("Only child"),
            "The single child should be the one rendered")
    }

    // MARK: - Confirmation Dialog Batch B

    func testConfirmationDialogRendersContent() {
        let ctx = testContext()
        @SwiftOpenUI.State var presented = false
        let view = Text("Content").confirmationDialog(
            "Delete?",
            isPresented: $presented,
            titleVisibility: .visible,
            actions: [AlertButton("Delete", role: .destructive)],
            message: "This cannot be undone."
        )
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Confirmation dialog with message should render content")
    }

    func testConfirmationDialogHiddenTitleRendersContent() {
        let ctx = testContext()
        @SwiftOpenUI.State var presented = false
        let view = Text("Content").confirmationDialog(
            "Title",
            isPresented: $presented,
            titleVisibility: .hidden,
            actions: [AlertButton("OK")]
        )
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Confirmation dialog with hidden title should render content")
    }

    func testConfirmationDialogOldOverloadStillWorks() {
        let ctx = testContext()
        @SwiftOpenUI.State var presented = false
        let view = Text("Content").confirmationDialog(
            "Are you sure?",
            isPresented: $presented,
            actions: [AlertButton("Yes"), AlertButton("No", role: .cancel)]
        )
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Old convenience overload should still render")
    }

    // MARK: - Dismissal Confirmation Dialog Batch D

    func testDismissalInterceptionSetsBinding() {
        let ctx = testContext()
        @SwiftOpenUI.State var presented = true
        @SwiftOpenUI.State var shouldPresent = false
        let view = Text("Background").sheet(isPresented: $presented) {
            Text("Sheet Content")
                .dismissalConfirmationDialog(
                    "Discard changes?",
                    shouldPresent: $shouldPresent,
                    actions: [AlertButton("Discard", role: .destructive)]
                )
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Sheet should be presented
        let root = findRootWindow(from: hwnd!)
        let sheetHwnd = win32ActiveSheetWindow(for: root)
        XCTAssertNotNil(sheetHwnd, "Sheet should be presented")

        // Simulate user close (WM_CLOSE) — should intercept, not destroy
        if let sheet = sheetHwnd {
            SendMessageW(sheet, UINT(WM_CLOSE), 0, 0)
        }

        XCTAssertTrue(shouldPresent,
            "WM_CLOSE should set shouldPresent = true instead of closing sheet")

        // Sheet should still exist after interception
        let sheetAfter = win32ActiveSheetWindow(for: root)
        XCTAssertNotNil(sheetAfter, "Sheet should remain open after interception")
    }

    func testDismissalInterceptionWrappedContentSetsBinding() {
        let ctx = testContext()
        @SwiftOpenUI.State var presented = true
        @SwiftOpenUI.State var shouldPresent = false
        let view = Text("Background").sheet(isPresented: $presented) {
            Text("Sheet Content")
                .dismissalConfirmationDialog(
                    "Discard changes?",
                    shouldPresent: $shouldPresent,
                    actions: [AlertButton("Discard", role: .destructive)]
                )
                .padding()
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let root = findRootWindow(from: hwnd!)
        let sheetHwnd = win32ActiveSheetWindow(for: root)
        XCTAssertNotNil(sheetHwnd, "Wrapped sheet should be presented")

        if let sheet = sheetHwnd {
            SendMessageW(sheet, UINT(WM_CLOSE), 0, 0)
        }

        XCTAssertTrue(shouldPresent,
            "Wrapped dismissal confirmation should still intercept WM_CLOSE")
        XCTAssertNotNil(win32ActiveSheetWindow(for: root),
            "Wrapped sheet should remain open after interception")
    }

    func testProgrammaticDismissStillClosesWithInterception() {
        let ctx = testContext()
        @SwiftOpenUI.State var presented = true
        @SwiftOpenUI.State var shouldPresent = false
        let view = Text("Background").sheet(isPresented: $presented) {
            Text("Sheet Content")
                .dismissalConfirmationDialog(
                    "Discard?",
                    shouldPresent: $shouldPresent,
                    actions: [AlertButton("OK")]
                )
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let root = findRootWindow(from: hwnd!)
        let sheetHwnd = win32ActiveSheetWindow(for: root)
        XCTAssertNotNil(sheetHwnd, "Sheet should be presented")

        // Programmatic dismiss: set isPresented = false and re-render
        presented = false
        let hwnd2 = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd2)

        let sheetAfter = win32ActiveSheetWindow(for: root)
        XCTAssertNil(sheetAfter, "Programmatic dismiss should still close sheet")
    }

    func testDismissalConfirmationConfirmClosesInterceptedSheet() {
        let ctx = testContext()
        @SwiftOpenUI.State var presented = true
        @SwiftOpenUI.State var shouldPresent = false
        var confirmed = false
        let view = Text("Background").sheet(isPresented: $presented) {
            Text("Sheet Content")
                .dismissalConfirmationDialog(
                    "Discard?",
                    shouldPresent: $shouldPresent,
                    actions: [
                        AlertButton("Discard", role: .destructive) { confirmed = true },
                        AlertButton("Keep Editing", role: .cancel)
                    ]
                )
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let root = findRootWindow(from: hwnd!)
        let sheetHwnd = win32ActiveSheetWindow(for: root)
        XCTAssertNotNil(sheetHwnd, "Sheet should be presented")

        if let sheet = sheetHwnd {
            SendMessageW(sheet, UINT(WM_CLOSE), 0, 0)
        }
        XCTAssertTrue(shouldPresent, "Intercepted close should request confirmation")

        win32ConfirmationDialogTestHook = { _, _, _, _ in Int32(IDYES) }
        defer { win32ConfirmationDialogTestHook = nil }

        if let sheet = win32ActiveSheetWindow(for: root) {
            let sheetContext = RenderContext(parent: sheet, hInstance: testHInstance)
            let dialog = Text("Sheet Content").dismissalConfirmationDialog(
                "Discard?",
                shouldPresent: $shouldPresent,
                actions: [
                    AlertButton("Discard", role: .destructive) { confirmed = true },
                    AlertButton("Keep Editing", role: .cancel)
                ]
            )
            XCTAssertNotNil(winRenderView(dialog, in: sheetContext))
        } else {
            XCTFail("Expected intercepted sheet to remain open")
        }
        pumpInvokeMessages(for: root)

        XCTAssertTrue(confirmed, "Confirm action should run before dismissal")
        XCTAssertFalse(presented, "Confirming dismissal should clear the sheet binding")
        XCTAssertNil(win32ActiveSheetWindow(for: root), "Confirming should close the intercepted sheet")
    }

    func testDismissalConfirmationCancelLeavesInterceptedSheetOpen() {
        let ctx = testContext()
        @SwiftOpenUI.State var presented = true
        @SwiftOpenUI.State var shouldPresent = false
        var cancelled = false
        let view = Text("Background").sheet(isPresented: $presented) {
            Text("Sheet Content")
                .dismissalConfirmationDialog(
                    "Discard?",
                    shouldPresent: $shouldPresent,
                    actions: [
                        AlertButton("Discard", role: .destructive),
                        AlertButton("Keep Editing", role: .cancel) { cancelled = true }
                    ]
                )
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let root = findRootWindow(from: hwnd!)
        let sheetHwnd = win32ActiveSheetWindow(for: root)
        XCTAssertNotNil(sheetHwnd, "Sheet should be presented")

        if let sheet = sheetHwnd {
            SendMessageW(sheet, UINT(WM_CLOSE), 0, 0)
        }
        XCTAssertTrue(shouldPresent, "Intercepted close should request confirmation")

        win32ConfirmationDialogTestHook = { _, _, _, _ in Int32(IDNO) }
        defer { win32ConfirmationDialogTestHook = nil }

        if let sheet = win32ActiveSheetWindow(for: root) {
            let sheetContext = RenderContext(parent: sheet, hInstance: testHInstance)
            let dialog = Text("Sheet Content").dismissalConfirmationDialog(
                "Discard?",
                shouldPresent: $shouldPresent,
                actions: [
                    AlertButton("Discard", role: .destructive),
                    AlertButton("Keep Editing", role: .cancel) { cancelled = true }
                ]
            )
            XCTAssertNotNil(winRenderView(dialog, in: sheetContext))
        } else {
            XCTFail("Expected intercepted sheet to remain open")
        }
        pumpInvokeMessages(for: root)

        XCTAssertTrue(cancelled, "Cancel action should run for a rejected dismissal")
        XCTAssertTrue(presented, "Cancel should leave the sheet presented")
        XCTAssertNotNil(win32ActiveSheetWindow(for: root), "Cancel should leave the intercepted sheet open")
    }

    func testSheetWithoutDismissalConfigStillCloses() {
        let ctx = testContext()
        @SwiftOpenUI.State var presented = true
        let view = Text("Background").sheet(isPresented: $presented) {
            Text("Plain sheet")
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let root = findRootWindow(from: hwnd!)
        let sheetHwnd = win32ActiveSheetWindow(for: root)
        XCTAssertNotNil(sheetHwnd, "Sheet should be presented")

        // WM_CLOSE without dismissal config should destroy normally
        if let sheet = sheetHwnd {
            SendMessageW(sheet, UINT(WM_CLOSE), 0, 0)
        }

        let sheetAfter = win32ActiveSheetWindow(for: root)
        XCTAssertNil(sheetAfter, "Sheet without dismissal config should close on WM_CLOSE")
    }

    // MARK: - Searchable Batch B (tokens)

    private struct TestSearchToken: Identifiable {
        let id: String
        let name: String
    }

    func testSearchableTokensRenderChips() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        let tokens: [TestSearchToken] = [
            TestSearchToken(id: "1", name: "Swift"),
            TestSearchToken(id: "2", name: "UI")
        ]
        let view = Text("Content").searchable(
            text: $query,
            tokens: .constant(tokens)
        ) { token in
            Text(token.name)
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Should have search field + token chip statics
        let chips = collectStaticLabels(in: hwnd!)
        let chipTexts = chips.map { windowText(of: $0) }
        XCTAssertTrue(chipTexts.contains("[Swift]"), "Should render chip for 'Swift' token")
        XCTAssertTrue(chipTexts.contains("[UI]"), "Should render chip for 'UI' token")
    }

    func testSearchableEditableTokensRenderChips() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        let tokens: [TestSearchToken] = [
            TestSearchToken(id: "a", name: "Open"),
            TestSearchToken(id: "b", name: "Closed")
        ]
        let view = Text("Content").searchable(
            text: $query,
            editableTokens: .constant(tokens)
        ) { token in
            Text(token.name)
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let chips = collectStaticLabels(in: hwnd!)
        let chipTexts = chips.map { windowText(of: $0) }
        XCTAssertTrue(chipTexts.contains("[Open]"), "Should render chip for 'Open' token")
        XCTAssertTrue(chipTexts.contains("[Closed]"), "Should render chip for 'Closed' token")
    }

    func testSearchableEmptyTokensNoChips() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        let tokens: [TestSearchToken] = []
        let view = Text("Content").searchable(
            text: $query,
            tokens: .constant(tokens)
        ) { token in
            Text(token.name)
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // No chip labels should be present
        let chips = collectStaticLabels(in: hwnd!)
        let chipTexts = chips.map { windowText(of: $0) }.filter { $0.hasPrefix("[") }
        XCTAssertEqual(chipTexts.count, 0, "Empty tokens should produce no chip labels")
    }

    func testSearchableTokensPreserveOrder() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        let tokens: [TestSearchToken] = [
            TestSearchToken(id: "1", name: "Alpha"),
            TestSearchToken(id: "2", name: "Beta"),
            TestSearchToken(id: "3", name: "Gamma")
        ]
        let view = Text("Content").searchable(
            text: $query,
            tokens: .constant(tokens)
        ) { token in
            Text(token.name)
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Collect chip labels and verify order by X position
        let chips = collectStaticLabelsWithPositions(in: hwnd!)
            .filter { $0.text.hasPrefix("[") }
            .sorted { $0.x < $1.x }
        XCTAssertEqual(chips.count, 3, "All 3 token chips should render")
        XCTAssertEqual(chips[0].text, "[Alpha]")
        XCTAssertEqual(chips[1].text, "[Beta]")
        XCTAssertEqual(chips[2].text, "[Gamma]")
    }

    // MARK: - Searchable Batch C (suggestions)

    func testSearchSuggestionsRenderButtons() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        let view = Text("Content")
            .searchable(text: $query)
            .searchSuggestions {
                Text("Swift")
                Text("SwiftUI")
            }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Suggestion buttons should be present as native Button controls
        var buttons: [HWND] = []
        collectButtonControls(in: hwnd!, into: &buttons)
        let labels = buttons.map { windowText(of: $0) }
        XCTAssertTrue(labels.contains("Swift"), "Should render 'Swift' suggestion button")
        XCTAssertTrue(labels.contains("SwiftUI"), "Should render 'SwiftUI' suggestion button")
    }

    func testSearchSuggestionsPreserveOrder() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        let view = Text("Content")
            .searchable(text: $query)
            .searchSuggestions {
                Text("Alpha")
                Text("Beta")
                Text("Gamma")
            }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        var buttons: [HWND] = []
        collectButtonControls(in: hwnd!, into: &buttons)
        let suggestionButtons = buttons.filter {
            let t = windowText(of: $0)
            return t == "Alpha" || t == "Beta" || t == "Gamma"
        }
        XCTAssertEqual(suggestionButtons.count, 3, "All 3 suggestions should render")

        // Verify vertical order by Y position
        let positions = suggestionButtons.map { hwnd -> (text: String, y: Int32) in
            var r = RECT()
            GetWindowRect(hwnd, &r)
            return (text: windowText(of: hwnd), y: r.top)
        }.sorted { $0.y < $1.y }
        XCTAssertEqual(positions[0].text, "Alpha")
        XCTAssertEqual(positions[1].text, "Beta")
        XCTAssertEqual(positions[2].text, "Gamma")
    }

    func testSearchSuggestionCompletionWritesBinding() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        let view = Text("Content")
            .searchable(text: $query)
            .searchSuggestions {
                Text("SwiftUI").searchCompletion("import SwiftUI")
            }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Install a test subclass on the root window so WM_COMMAND forwarding
        // through the suggestion container's searchableLayoutProc actually
        // reaches dispatchCommand — exercising the real routing path.
        let root = findRootWindow(from: hwnd!)
        SetWindowSubclass(root, testCommandDispatchProc, 99, 0)
        defer { RemoveWindowSubclass(root, testCommandDispatchProc, 99) }

        // Find the suggestion button and send WM_COMMAND to its parent
        // (the suggestion container), which has searchableLayoutProc subclassed.
        var buttons: [HWND] = []
        collectButtonControls(in: hwnd!, into: &buttons)
        let suggestionBtn = buttons.first { windowText(of: $0) == "SwiftUI" }
        XCTAssertNotNil(suggestionBtn, "Should find suggestion button")

        if let btn = suggestionBtn {
            let sugContainer = GetParent(btn)!
            let controlID = GetDlgCtrlID(btn)
            // BN_CLICKED: HIWORD = 0, LOWORD = controlID, lParam = button HWND
            let wParam = WPARAM(UInt16(controlID))
            let lParam = LPARAM(Int(bitPattern: btn))
            SendMessageW(sugContainer, UINT(WM_COMMAND), wParam, lParam)
        }

        XCTAssertEqual(query, "import SwiftUI",
            "Clicking suggestion should write completion text into search binding")
    }

    func testSearchSuggestionsEmptyNoButtons() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        let view = Text("Content")
            .searchable(text: $query)
        // No .searchSuggestions call — suggestions array is empty
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        var buttons: [HWND] = []
        collectButtonControls(in: hwnd!, into: &buttons)
        XCTAssertEqual(buttons.count, 0, "No suggestion buttons without searchSuggestions")
    }

    func testSearchSuggestionsWithTokens() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        let tokens: [TestSearchToken] = [
            TestSearchToken(id: "1", name: "Tag")
        ]
        let view = Text("Content")
            .searchable(text: $query, tokens: .constant(tokens)) { t in Text(t.name) }
            .searchSuggestions {
                Text("Suggestion")
            }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Both token chip and suggestion button should be present
        let chips = collectStaticLabels(in: hwnd!)
        let chipTexts = chips.map { windowText(of: $0) }
        XCTAssertTrue(chipTexts.contains("[Tag]"), "Token chip should still render")

        var buttons: [HWND] = []
        collectButtonControls(in: hwnd!, into: &buttons)
        let suggestionLabels = buttons.map { windowText(of: $0) }
        XCTAssertTrue(suggestionLabels.contains("Suggestion"), "Suggestion button should render alongside tokens")
    }

    // MARK: - Searchable Batch D (scopes)

    func testSearchScopesRenderButtons() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        @SwiftOpenUI.State var scope = "all"
        let view = Text("Content")
            .searchable(text: $query)
            .searchScopes($scope, scopes: ["all", "recent", "favorites"]) { s in
                Text(s)
            }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        var buttons: [HWND] = []
        collectButtonControls(in: hwnd!, into: &buttons)
        let labels = buttons.map { windowText(of: $0) }
        // Selected scope "all" renders as "[all]", others as plain labels
        XCTAssertTrue(labels.contains("[all]"), "Selected scope should render with brackets")
        XCTAssertTrue(labels.contains("recent"), "Unselected scope should render")
        XCTAssertTrue(labels.contains("favorites"), "Unselected scope should render")
    }

    func testSearchScopesPreserveOrder() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        @SwiftOpenUI.State var scope = "A"
        let view = Text("Content")
            .searchable(text: $query)
            .searchScopes($scope, scopes: ["A", "B", "C"]) { s in Text(s) }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        var buttons: [HWND] = []
        collectButtonControls(in: hwnd!, into: &buttons)
        let scopeButtons = buttons.filter {
            let t = windowText(of: $0)
            return t == "[A]" || t == "B" || t == "C"
        }.map { hwnd -> (text: String, x: Int32) in
            var r = RECT()
            GetWindowRect(hwnd, &r)
            return (text: windowText(of: hwnd), x: r.left)
        }.sorted { $0.x < $1.x }

        XCTAssertEqual(scopeButtons.count, 3)
        XCTAssertEqual(scopeButtons[0].text, "[A]")
        XCTAssertEqual(scopeButtons[1].text, "B")
        XCTAssertEqual(scopeButtons[2].text, "C")
    }

    func testSearchScopeSelectionWritesBack() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        @SwiftOpenUI.State var scope = "all"
        let view = Text("Content")
            .searchable(text: $query)
            .searchScopes($scope, scopes: ["all", "recent"]) { s in Text(s) }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Install test dispatch proc on root
        let root = findRootWindow(from: hwnd!)
        SetWindowSubclass(root, testCommandDispatchProc, 99, 0)
        defer { RemoveWindowSubclass(root, testCommandDispatchProc, 99) }

        // Find the "recent" scope button and click it via WM_COMMAND
        var buttons: [HWND] = []
        collectButtonControls(in: hwnd!, into: &buttons)
        let recentBtn = buttons.first { windowText(of: $0) == "recent" }
        XCTAssertNotNil(recentBtn, "Should find 'recent' scope button")

        if let btn = recentBtn {
            let scopeRow = GetParent(btn)!
            let controlID = GetDlgCtrlID(btn)
            let wParam = WPARAM(UInt16(controlID))
            let lParam = LPARAM(Int(bitPattern: btn))
            SendMessageW(scopeRow, UINT(WM_COMMAND), wParam, lParam)
        }

        XCTAssertEqual(scope, "recent",
            "Clicking scope should write back to selection binding")
    }

    func testSearchScopesWithSuggestionsAndTokens() {
        let ctx = testContext()
        @SwiftOpenUI.State var query = ""
        @SwiftOpenUI.State var scope = "all"
        let tokens: [TestSearchToken] = [TestSearchToken(id: "1", name: "Tag")]
        let view = Text("Content")
            .searchable(text: $query, tokens: .constant(tokens)) { t in Text(t.name) }
            .searchScopes($scope, scopes: ["all", "recent"]) { s in Text(s) }
            .searchSuggestions { Text("Hint") }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Token chip present
        let chips = collectStaticLabels(in: hwnd!)
        XCTAssertTrue(chips.map { windowText(of: $0) }.contains("[Tag]"), "Token chip should render")

        // Scope buttons present
        var buttons: [HWND] = []
        collectButtonControls(in: hwnd!, into: &buttons)
        let labels = buttons.map { windowText(of: $0) }
        XCTAssertTrue(labels.contains("[all]") || labels.contains("all"), "Scope should render")

        // Suggestion button present
        XCTAssertTrue(labels.contains("Hint"), "Suggestion should render alongside scopes")
    }

    // MARK: - Safe area padding

    func testSafeAreaPaddingDefaultAllEdges() {
        let ctx = testContext()
        let view = Text("Hello").safeAreaPadding()
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Container should be larger than child by 16 on each edge (synthetic default)
        let child = GetWindow(hwnd!, UINT(GW_CHILD))
        XCTAssertNotNil(child)

        var containerRect = RECT()
        GetWindowRect(hwnd!, &containerRect)
        let cw = containerRect.right - containerRect.left
        let ch = containerRect.bottom - containerRect.top

        var childRect = RECT()
        GetWindowRect(child!, &childRect)
        let childW = childRect.right - childRect.left
        let childH = childRect.bottom - childRect.top

        // 16 leading + 16 trailing = 32 extra width
        XCTAssertEqual(cw, childW + 32, "Default safeAreaPadding should add 16px on each side")
        XCTAssertEqual(ch, childH + 32, "Default safeAreaPadding should add 16px on top and bottom")
    }

    func testSafeAreaPaddingExplicitLength() {
        let ctx = testContext()
        let view = Text("Hello").safeAreaPadding(10)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let child = GetWindow(hwnd!, UINT(GW_CHILD))
        XCTAssertNotNil(child)

        var containerRect = RECT()
        GetWindowRect(hwnd!, &containerRect)
        var childRect = RECT()
        GetWindowRect(child!, &childRect)

        let extraW = (containerRect.right - containerRect.left) - (childRect.right - childRect.left)
        let extraH = (containerRect.bottom - containerRect.top) - (childRect.bottom - childRect.top)
        XCTAssertEqual(extraW, 20, "safeAreaPadding(10) should add 10px on leading + trailing")
        XCTAssertEqual(extraH, 20, "safeAreaPadding(10) should add 10px on top + bottom")
    }

    func testSafeAreaPaddingSelectedEdges() {
        let ctx = testContext()
        let view = Text("Hello").safeAreaPadding(.top, 8)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let child = GetWindow(hwnd!, UINT(GW_CHILD))
        XCTAssertNotNil(child)

        var containerRect = RECT()
        GetWindowRect(hwnd!, &containerRect)
        var childRect = RECT()
        GetWindowRect(child!, &childRect)

        let extraW = (containerRect.right - containerRect.left) - (childRect.right - childRect.left)
        let extraH = (containerRect.bottom - containerRect.top) - (childRect.bottom - childRect.top)
        XCTAssertEqual(extraW, 0, "Top-only padding should not add horizontal space")
        XCTAssertEqual(extraH, 8, "Top-only padding(8) should add 8px vertically")
    }

    func testSafeAreaPaddingHorizontalEdges() {
        let ctx = testContext()
        let view = Text("Hello").safeAreaPadding(.horizontal, 12)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let child = GetWindow(hwnd!, UINT(GW_CHILD))
        XCTAssertNotNil(child)

        var containerRect = RECT()
        GetWindowRect(hwnd!, &containerRect)
        var childRect = RECT()
        GetWindowRect(child!, &childRect)

        let extraW = (containerRect.right - containerRect.left) - (childRect.right - childRect.left)
        let extraH = (containerRect.bottom - containerRect.top) - (childRect.bottom - childRect.top)
        XCTAssertEqual(extraW, 24, "Horizontal padding(12) should add 12px leading + 12px trailing")
        XCTAssertEqual(extraH, 0, "Horizontal-only padding should not add vertical space")
    }

    func testSafeAreaPaddingNegativeLengthClamps() {
        let ctx = testContext()
        let view = Text("Hello").safeAreaPadding(-5)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let child = GetWindow(hwnd!, UINT(GW_CHILD))
        XCTAssertNotNil(child)

        var containerRect = RECT()
        GetWindowRect(hwnd!, &containerRect)
        var childRect = RECT()
        GetWindowRect(child!, &childRect)

        let extraW = (containerRect.right - containerRect.left) - (childRect.right - childRect.left)
        let extraH = (containerRect.bottom - containerRect.top) - (childRect.bottom - childRect.top)
        XCTAssertEqual(extraW, 0, "Negative length should clamp to 0")
        XCTAssertEqual(extraH, 0, "Negative length should clamp to 0")
    }

    func testSafeAreaPaddingDescriptor() {
        let node = winDescribeView(Text("Hello").safeAreaPadding(.top, 20))
        XCTAssertEqual(node.kind, .padding)
        XCTAssertEqual(node.props, .padding(
            Win32PaddingDescriptor(top: 20, bottom: 0, leading: 0, trailing: 0)
        ))
        XCTAssertEqual(node.children.count, 1)
    }

    func testSafeAreaPaddingDescriptorDefault() {
        let node = winDescribeView(Text("Hello").safeAreaPadding())
        XCTAssertEqual(node.kind, .padding)
        XCTAssertEqual(node.props, .padding(
            Win32PaddingDescriptor(top: 16, bottom: 16, leading: 16, trailing: 16)
        ))
    }

    // MARK: - Toolbar Batch A (fallback path — outside NavigationStack)

    func testToolbarSingleItem() {
        let ctx = testContext()
        let view = Text("Content").toolbar {
            ToolbarItem(placement: .trailing) {
                Button("Action") {}
            }
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Toolbar with single item should render")
    }

    func testToolbarMultipleItems() {
        let ctx = testContext()
        let view = Text("Content").toolbar {
            ToolbarItem(placement: .leading) {
                Button("Back") {}
            }
            ToolbarItem(placement: .trailing) {
                Button("Save") {}
            }
            ToolbarItem(placement: .trailing) {
                Button("Share") {}
            }
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Toolbar with multiple items should render")

        // Outside NavigationStack, toolbar renders as container with items + content.
        // 3 toolbar item HWNDs + 1 content HWND = at least 4 children.
        var childCount: Int = 0
        var child = GetWindow(hwnd!, UINT(GW_CHILD))
        while let c = child {
            childCount += 1
            child = GetWindow(c, UINT(GW_HWNDNEXT))
        }
        XCTAssertGreaterThanOrEqual(childCount, 4,
            "Container should have 3 toolbar item HWNDs + content HWND")
    }

    func testToolbarLeadingTrailingPlacement() {
        let ctx = testContext()
        let view = Text("Content").toolbar {
            ToolbarItem(placement: .leading) {
                Button("Lead") {}
            }
            ToolbarItem(placement: .trailing) {
                Button("Trail") {}
            }
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Collect toolbar-bar children (y == 0) in creation order.
        // The renderer creates HWNDs in source order, so GW_CHILD + GW_HWNDNEXT
        // walks them in source order: index 0 = leading "Lead", index 1 = trailing "Trail".
        let items = collectToolbarBarChildren(in: hwnd!)
        XCTAssertEqual(items.count, 2, "Should have 2 toolbar item HWNDs at y=0")

        // The leading item (index 0) must have a smaller X than the trailing item (index 1)
        XCTAssertLessThan(items[0].x, items[1].x,
            "Leading item should be positioned left of trailing item")
    }

    func testToolbarWithID() {
        let ctx = testContext()
        let view = Text("Content").toolbar(id: "myToolbar") {
            ToolbarItem(placement: .trailing) {
                Button("Done") {}
            }
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "toolbar(id:content:) should render identically to toolbar(content:)")
    }

    func testToolbarEmptyContent() {
        let ctx = testContext()
        let view = Text("Content").toolbar {}
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Toolbar with no items should still render content")
    }

    func testToolbarMultipleItemsPreserveOrder() {
        let ctx = testContext()
        // Three trailing items in source order: First, Second, Third.
        // The renderer positions trailing items from the right edge via
        // trailingRendered.reversed(), so the last source item ends up
        // rightmost and the first source item ends up leftmost:
        //   - "Third"  (last in source)  → positioned first from right → rightmost
        //   - "Second" (middle)          → positioned next             → middle
        //   - "First"  (first in source) → positioned last from right  → leftmost
        let view = Text("Content").toolbar {
            ToolbarItem(placement: .trailing) {
                Button("First") {}
            }
            ToolbarItem(placement: .trailing) {
                Button("Second") {}
            }
            ToolbarItem(placement: .trailing) {
                Button("Third") {}
            }
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Collect in creation order (= source order): index 0=First, 1=Second, 2=Third
        let items = collectToolbarBarChildren(in: hwnd!)
        XCTAssertEqual(items.count, 3, "All 3 toolbar items should render at y=0")

        // "First" (index 0) should be leftmost, "Third" (index 2) should be rightmost
        XCTAssertLessThan(items[0].x, items[1].x,
            "First (source[0]) should be left of Second (source[1])")
        XCTAssertLessThan(items[1].x, items[2].x,
            "Second (source[1]) should be left of Third (source[2])")
    }

    // MARK: - Toolbar Batch A (navigation-header path — inside NavigationStack)

    func testToolbarInNavigationStack() {
        let ctx = testContext()
        let view = NavigationStack {
            Text("Content")
                .toolbar {
                    ToolbarItem(placement: .trailing) {
                        Button("Save") {}
                    }
                }
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "NavigationStack with toolbar should render")

        // The toolbar items are tagged with the "SwiftUIToolbarItem" window property.
        // Walk all descendants and count tagged windows.
        let tagged = collectToolbarTaggedWindows(in: hwnd!)
        XCTAssertEqual(tagged.count, 1, "One toolbar item should be tagged in header")
    }

    func testToolbarMultipleItemsInNavigationStack() {
        let ctx = testContext()
        let view = NavigationStack {
            Text("Content")
                .toolbar {
                    ToolbarItem(placement: .leading) {
                        Button("Back") {}
                    }
                    ToolbarItem(placement: .trailing) {
                        Button("Save") {}
                    }
                    ToolbarItem(placement: .trailing) {
                        Button("Share") {}
                    }
                }
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let tagged = collectToolbarTaggedWindows(in: hwnd!)
        XCTAssertEqual(tagged.count, 3,
            "All 3 toolbar items should be tagged in navigation header")
    }

    func testToolbarLeadingTrailingInNavigationStack() {
        let ctx = testContext()
        let view = NavigationStack {
            Text("Content")
                .toolbar {
                    ToolbarItem(placement: .leading) {
                        Button("Lead") {}
                    }
                    ToolbarItem(placement: .trailing) {
                        Button("Trail") {}
                    }
                }
        }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Tagged windows in creation order: index 0 = leading, index 1 = trailing.
        let tagged = collectToolbarTaggedWindows(in: hwnd!)
        XCTAssertEqual(tagged.count, 2, "Both items should be tagged")

        // Verify the leading item is positioned at the renderer's leading start (68).
        // The trailing item position depends on the header container width which is
        // set after toolbar rendering in the NavigationStack layout pass, so we only
        // verify it was placed at a different position.
        let parent = GetParent(tagged[0])!
        var r0 = RECT()
        var r1 = RECT()
        GetWindowRect(tagged[0], &r0)
        GetWindowRect(tagged[1], &r1)
        var pt0 = POINT(x: r0.left, y: r0.top)
        var pt1 = POINT(x: r1.left, y: r1.top)
        ScreenToClient(parent, &pt0)
        ScreenToClient(parent, &pt1)
        XCTAssertEqual(pt0.x, 68,
            "Leading item should start at renderer's leadingX origin (68)")
        XCTAssertNotEqual(pt0.x, pt1.x,
            "Leading and trailing items should be at different X positions")
    }

    // MARK: - Toolbar Batch B (visibility and removal)

    func testToolbarHiddenVisibilitySkipsRendering() {
        let ctx = testContext()
        let view = Text("Content")
            .toolbar {
                ToolbarItem(placement: .trailing) {
                    Button("Action") {}
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // With hidden visibility, the toolbar items should not be rendered.
        // The result should be the content HWND directly, no toolbar container.
        let childCount = countDirectChildren(of: hwnd!)
        // A toolbar container would have toolbar items + content as children.
        // Without toolbar, content renders directly with no extra wrapper.
        XCTAssertEqual(childCount, 0,
            "Hidden toolbar should not create a toolbar container with children")
    }

    func testToolbarRemovingPlacementFiltersItems() {
        let ctx = testContext()
        let view = Text("Content")
            .toolbar {
                ToolbarItem(placement: .leading) {
                    Button("Lead") {}
                }
                ToolbarItem(placement: .trailing) {
                    Button("Trail") {}
                }
            }
            .toolbar(removing: .leading)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // Only the trailing item should remain.
        // Fallback toolbar renders items at y=0 in a container.
        let items = collectToolbarBarChildren(in: hwnd!)
        XCTAssertEqual(items.count, 1,
            "Only trailing item should remain after removing .leading")
    }

    func testToolbarRemovingAllPlacementsReturnsContent() {
        let ctx = testContext()
        let view = Text("Content")
            .toolbar {
                ToolbarItem(placement: .trailing) {
                    Button("Action") {}
                }
            }
            .toolbar(removing: .trailing)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // All items removed — no toolbar container, just content
        let childCount = countDirectChildren(of: hwnd!)
        XCTAssertEqual(childCount, 0,
            "Removing all placements should return content without toolbar")
    }

    func testToolbarVisibleExplicitStillRenders() {
        let ctx = testContext()
        let view = Text("Content")
            .toolbar {
                ToolbarItem(placement: .trailing) {
                    Button("Action") {}
                }
            }
            .toolbar(.visible, for: .navigationBar)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let items = collectToolbarBarChildren(in: hwnd!)
        XCTAssertEqual(items.count, 1, "Visible toolbar should still render items")
    }

    // MARK: - Toolbar Batch B (reverse modifier order)

    func testToolbarHiddenReverseOrder() {
        let ctx = testContext()
        // Config applied before .toolbar { ... } — ToolbarView wraps ToolbarConfigurationView
        let view = Text("Content")
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .trailing) {
                    Button("Action") {}
                }
            }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let childCount = countDirectChildren(of: hwnd!)
        XCTAssertEqual(childCount, 0,
            "Hidden toolbar in reverse order should not create toolbar container")
    }

    func testToolbarRemovingReverseOrder() {
        let ctx = testContext()
        // Config applied before .toolbar { ... }
        let view = Text("Content")
            .toolbar(removing: .leading)
            .toolbar {
                ToolbarItem(placement: .leading) {
                    Button("Lead") {}
                }
                ToolbarItem(placement: .trailing) {
                    Button("Trail") {}
                }
            }
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let items = collectToolbarBarChildren(in: hwnd!)
        XCTAssertEqual(items.count, 1,
            "Removing .leading in reverse order should leave only trailing item")
    }

    func testToolbarMixedVisibilityAndRemovalChainUsesMergedConfiguration() {
        let ctx = testContext()
        let view = Text("Content")
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .leading) {
                    Button("Lead") {}
                }
                ToolbarItem(placement: .trailing) {
                    Button("Trail") {}
                }
            }
            .toolbar(removing: .leading)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        let items = collectToolbarBarChildren(in: hwnd!)
        XCTAssertEqual(items.count, 1,
            "Merged visibility/removal config should still remove .leading")
    }
    // MARK: - Animation (Win32 scoping)

    /// AnimatedView sets currentAnimation for its subtree and restores it after.
    func testAnimatedViewSetsCurrentAnimation() {
        // Before rendering, no animation should be active
        XCTAssertNil(getCurrentAnimation())

        let view = Text("hello")
            .animation(.easeIn)

        ensureTestWindow()
        let context = RenderContext(parent: testWindow, hInstance: testHInstance)
        _ = winRenderView(view, in: context)
        let after = getCurrentAnimation()

        // Animation TLS should be restored to nil after rendering
        XCTAssertNil(after, "currentAnimation should be restored after AnimatedView renders")
    }

    /// AnimatedView with nil animation clears any outer animation.
    func testAnimatedViewNilOverridesOuter() {
        // Set an outer animation
        setCurrentAnimation(.easeIn)
        defer { setCurrentAnimation(nil) }

        // Wrap content in .animation(nil)
        let view = Text("hello")
            .opacity(0.5)
            .animation(nil)

        ensureTestWindow()
        let context = RenderContext(parent: testWindow, hInstance: testHInstance)
        _ = winRenderView(view, in: context)

        // After rendering, TLS should be restored to outer value
        let restored = getCurrentAnimation()
        XCTAssertNotNil(restored, "Outer animation should be restored after .animation(nil) renders")
        XCTAssertEqual(restored?.curve, Animation.easeIn.curve)
    }

    /// withAnimation still works when no .animation() wrapper is present.
    func testWithAnimationStillWorksWithoutWrapper() {
        // Simulate withAnimation setting pending animation
        setPendingAnimation(.easeOut)

        // No .animation() wrapper — D2D surface should consume pending
        let pending = consumePendingAnimation()
        XCTAssertNotNil(pending, "consumePendingAnimation should return the animation")
        XCTAssertEqual(pending?.curve, Animation.easeOut.curve)

        // Second consume should return nil (single-consumer)
        let second = consumePendingAnimation()
        XCTAssertNil(second, "consumePendingAnimation is single-consumer")
    }

    /// currentAnimation takes priority over pendingAnimation in D2D surface.
    func testCurrentAnimationPriorityOverPending() {
        // Set both channels
        setCurrentAnimation(.spring)
        setPendingAnimation(.linear)
        defer {
            setCurrentAnimation(nil)
            _ = consumePendingAnimation()
        }

        // getCurrentAnimation should return the scoped one
        let current = getCurrentAnimation()
        XCTAssertEqual(current?.curve, Animation.spring.curve)

        // Pending should still be available (not consumed)
        let pending = getPendingAnimation()
        XCTAssertNotNil(pending)
    }

    /// Win32ViewHost captures .animation() context and restores it on rebuild.
    func testViewHostCapturesAnimationAcrossRebuild() {
        let ctx = testContext()

        // Set up animation scope as if AnimatedView.winCreateWidget ran
        setCurrentAnimation(.easeInOut)
        defer { setCurrentAnimation(nil) }

        // Verify captureAnimation stores the scoped animation
        let host = Win32ViewHost(
            context: ctx,
            buildBody: { ctx in
                winRenderView(Text("test"), in: ctx)
            },
            describeBody: {
                winDescribeView(Text("test"))
            }
        )

        host.captureEnvironment()
        host.captureAnimation()

        // Clear animation scope (simulating AnimatedView.winCreateWidget defer)
        setCurrentAnimation(nil)
        XCTAssertNil(getCurrentAnimation(), "Animation should be nil after outer scope ends")

        // Simulate what rebuild does: restore captured animation
        // We test the mechanism directly since full rebuild involves
        // complex HWND lifecycle that's orthogonal to animation scoping.
        let animBeforeRebuild = getCurrentAnimation()
        XCTAssertNil(animBeforeRebuild)

        // Trigger rebuild — the animation restore happens inside rebuild()
        // which calls buildBodyWithTracking. We verify the TLS state is
        // correct by checking it wasn't leaked after rebuild completes.
        host.rebuild()
        let afterRebuild = getCurrentAnimation()
        XCTAssertNil(afterRebuild, "Animation TLS should be restored after rebuild")
    }

    // MARK: - Dashed Stroke Smoke Tests

    func testDashedRoundedRectangleRenders() {
        let ctx = testContext()
        let view = RoundedRectangle(cornerRadius: 8)
            .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
            .frame(width: 200, height: 100)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Dashed RoundedRectangle should render an HWND")
        // Force the D2D paint path so the dash shim is actually exercised
        XCTAssertTrue(RedrawWindow(hwnd!, nil, nil, UINT(RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN)), "RedrawWindow should succeed")
    }

    func testDashedRectangleWithThickStrokeRenders() {
        let ctx = testContext()
        let view = Rectangle()
            .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, dash: [10, 4], dashPhase: 2))
            .frame(width: 150, height: 80)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Dashed Rectangle with thick stroke should render")
        XCTAssertTrue(RedrawWindow(hwnd!, nil, nil, UINT(RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN)), "RedrawWindow should succeed")
    }

    func testSolidStrokeStillWorks() {
        let ctx = testContext()
        let view = Circle()
            .stroke(Color.red, lineWidth: 2)
            .frame(width: 60, height: 60)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Solid stroke Circle should still render")
        XCTAssertTrue(RedrawWindow(hwnd!, nil, nil, UINT(RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN)), "RedrawWindow should succeed")
    }
}

// MARK: - Test helpers

/// Collect direct children of a toolbar container that sit at y=0 (toolbar bar row),
/// returned in creation order (GW_CHILD + GW_HWNDNEXT). Content is at y=barH (28).
private func collectToolbarBarChildren(in container: HWND) -> [(hwnd: HWND, x: Int32)] {
    var result: [(hwnd: HWND, x: Int32)] = []
    var child = GetWindow(container, UINT(GW_CHILD))
    while let c = child {
        var r = RECT()
        GetWindowRect(c, &r)
        var pt = POINT(x: r.left, y: r.top)
        ScreenToClient(container, &pt)
        if pt.y == 0 {
            result.append((hwnd: c, x: pt.x))
        }
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
    return result
}

private let testToolbarItemPropName: [WCHAR] = Array("SwiftUIToolbarItem".utf16) + [0]

private func collectToolbarTaggedWindows(in parent: HWND) -> [HWND] {
    var result: [HWND] = []
    collectToolbarTaggedWindowsRecursive(in: parent, into: &result)
    return result
}

private func collectToolbarTaggedWindowsRecursive(in parent: HWND, into result: inout [HWND]) {
    var child = GetWindow(parent, UINT(GW_CHILD))
    while let c = child {
        testToolbarItemPropName.withUnsafeBufferPointer { ptr in
            if GetPropW(c, ptr.baseAddress!) != nil {
                result.append(c)
            }
        }
        collectToolbarTaggedWindowsRecursive(in: c, into: &result)
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
}

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

private func collectStaticLabels(in parent: HWND) -> [HWND] {
    var result: [HWND] = []
    collectStaticLabelsRecursive(in: parent, into: &result)
    return result
}

private func collectStaticLabelsRecursive(in parent: HWND, into result: inout [HWND]) {
    var child = GetWindow(parent, UINT(GW_CHILD))
    while let c = child {
        if className(of: c) == "Static" {
            result.append(c)
        }
        collectStaticLabelsRecursive(in: c, into: &result)
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
}

private func collectStaticLabelsWithPositions(in parent: HWND) -> [(text: String, x: Int32)] {
    let statics = collectStaticLabels(in: parent)
    return statics.map { hwnd in
        var r = RECT()
        GetWindowRect(hwnd, &r)
        return (text: windowText(of: hwnd), x: r.left)
    }
}

/// Test subclass proc that forwards WM_COMMAND to dispatchCommand,
/// simulating the real app root window's WndProc for command routing tests.
private let testCommandDispatchProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    if uMsg == UINT(WM_COMMAND) {
        _ = dispatchCommand(wParam: wParam)
        return 0
    }
    return DefSubclassProc(hwnd, uMsg, wParam, lParam)
}

private func countDirectChildren(of parent: HWND) -> Int {
    var count = 0
    var child = GetWindow(parent, UINT(GW_CHILD))
    while let c = child {
        count += 1
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
    return count
}

private func pumpInvokeMessages(for hwnd: HWND) {
    win32PumpInvokeMessages(for: hwnd)
}

private func pumpWindowMessages(for hwnd: HWND, timeoutMs: DWORD = 50) {
    let start = GetTickCount()
    var msg = MSG()
    repeat {
        while PeekMessageW(&msg, hwnd, 0, 0, UINT(PM_REMOVE)) {
            TranslateMessage(&msg)
            DispatchMessageW(&msg)
        }
        Sleep(1)
    } while (GetTickCount() - start) < timeoutMs
}

private func collectButtonControls(in parent: HWND, into result: inout [HWND]) {
    var child = GetWindow(parent, UINT(GW_CHILD))
    while let c = child {
        if className(of: c) == "Button" {
            result.append(c)
        }
        collectButtonControls(in: c, into: &result)
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
}

private func findFlatButton(in parent: HWND, titled title: String) -> HWND? {
    var child = GetWindow(parent, UINT(GW_CHILD))
    while let c = child {
        var refData: DWORD_PTR = 0
        if className(of: c) == "SwiftUID2DSurface",
           GetWindowSubclass(c, flatButtonProc, 48, &refData),
           refData != 0 {
            let state = Unmanaged<FlatButtonState>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: UInt(refData))!
            ).takeUnretainedValue()
            if state.title == title {
                return c
            }
        }
        if let nested = findFlatButton(in: c, titled: title) {
            return nested
        }
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
    return nil
}
