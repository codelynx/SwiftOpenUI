import XCTest
@testable import SwiftOpenUI
@testable import BackendAndroid

final class AndroidRenderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        androidBeginRenderPass()
        androidStateCache.removeAll()
        androidCurrentHost = nil
    }

    // MARK: - TextField rendering

    func testTextFieldRendersWithPlaceholderAndText() {
        let state = State<String>(wrappedValue: "hello")
        let field = TextField("Enter name", text: state.projectedValue)
        let node = androidRenderView(field)

        XCTAssertEqual(node.type, "textfield")
        XCTAssertEqual(node.props["placeholder"], "Enter name")
        XCTAssertEqual(node.props["text"], "hello")
    }

    func testTextFieldEmptyText() {
        let state = State<String>(wrappedValue: "")
        let field = TextField("Placeholder", text: state.projectedValue)
        let node = androidRenderView(field)

        XCTAssertEqual(node.props["text"], "")
        XCTAssertEqual(node.props["placeholder"], "Placeholder")
    }

    func testTextFieldRegistersBinding() {
        let state = State<String>(wrappedValue: "test")
        let field = TextField("", text: state.projectedValue)

        XCTAssertTrue(androidTextBindings.isEmpty)
        _ = androidRenderView(field)
        XCTAssertEqual(androidTextBindings.count, 1)
    }

    func testTextFieldBindingUpdatesState() {
        let state = State<String>(wrappedValue: "original")
        let field = TextField("", text: state.projectedValue)
        _ = androidRenderView(field)

        // Simulate text input by invoking the registered binding
        guard let (_, binding) = androidTextBindings.first else {
            XCTFail("No text binding registered")
            return
        }
        binding.wrappedValue = "updated"
        XCTAssertEqual(state.wrappedValue, "updated")
    }

    func testMultipleTextFieldsRegisterSeparateBindings() {
        let state1 = State<String>(wrappedValue: "a")
        let state2 = State<String>(wrappedValue: "b")

        let view = VStack {
            TextField("First", text: state1.projectedValue)
            TextField("Second", text: state2.projectedValue)
        }
        _ = androidRenderView(view)

        XCTAssertEqual(androidTextBindings.count, 2)
    }

    // MARK: - TextField in JSON output

    func testTextFieldJSON() {
        let state = State<String>(wrappedValue: "world")
        let field = TextField("Name", text: state.projectedValue)
        let node = androidRenderView(field)
        let json = renderNodeToJSON(node)

        XCTAssertTrue(json.contains("\"textfield\""))
        XCTAssertTrue(json.contains("\"world\""))
        XCTAssertTrue(json.contains("\"Name\""))
    }

    // MARK: - Button action registry

    func testButtonRegistersAction() {
        var tapped = false
        let button = Button("Tap") { tapped = true }

        XCTAssertTrue(androidButtonActions.isEmpty)
        _ = androidRenderView(button)
        XCTAssertEqual(androidButtonActions.count, 1)

        // Invoke the registered action
        androidButtonActions.values.first?()
        XCTAssertTrue(tapped)
    }

    func testBeginRenderPassClearsRegistries() {
        let state = State<String>(wrappedValue: "")
        _ = androidRenderView(Button("B") { })
        _ = androidRenderView(TextField("", text: state.projectedValue))
        XCTAssertFalse(androidButtonActions.isEmpty)
        XCTAssertFalse(androidTextBindings.isEmpty)

        androidBeginRenderPass()
        XCTAssertTrue(androidButtonActions.isEmpty)
        XCTAssertTrue(androidTextBindings.isEmpty)
    }

    // MARK: - Stable node IDs

    func testNodeIdsAreStableAcrossRenders() {
        let state = State<String>(wrappedValue: "v1")
        let field = TextField("F", text: state.projectedValue)

        androidBeginRenderPass()
        let node1 = androidRenderView(field)
        let id1 = node1.id

        androidBeginRenderPass()
        let node2 = androidRenderView(field)
        let id2 = node2.id

        XCTAssertEqual(id1, id2, "Same structural position should produce the same node ID")
        XCTAssertNotEqual(id1, 0, "Node ID should not be zero")
    }

    func testDifferentFieldsGetDifferentIds() {
        let s1 = State<String>(wrappedValue: "")
        let s2 = State<String>(wrappedValue: "")

        let view = VStack {
            TextField("A", text: s1.projectedValue)
            TextField("B", text: s2.projectedValue)
        }
        _ = androidRenderView(view)

        let ids = Array(androidTextBindings.keys)
        XCTAssertEqual(ids.count, 2)
        XCTAssertNotEqual(ids[0], ids[1], "Different fields should have different node IDs")
    }

    // MARK: - Focus modifier

    func testFocusedViewRendersFocusProp() {
        let state = State<String>(wrappedValue: "hi")
        let focus = FocusState<Bool>()
        let view = TextField("F", text: state.projectedValue)
            .focused(focus)
        let node = androidRenderView(view)

        XCTAssertEqual(node.type, "textfield")
        XCTAssertEqual(node.props["text"], "hi")
        XCTAssertEqual(node.props["focused"], "false")
    }

    func testFocusedViewPropTrueWhenFocused() {
        let state = State<String>(wrappedValue: "")
        let focus = FocusState<Bool>()
        focus.wrappedValue = true
        let view = TextField("F", text: state.projectedValue)
            .focused(focus)
        let node = androidRenderView(view)

        XCTAssertEqual(node.props["focused"], "true")
    }

    func testFocusedViewRegistersFocusHandler() {
        let state = State<String>(wrappedValue: "")
        let focus = FocusState<Bool>()
        let view = TextField("F", text: state.projectedValue)
            .focused(focus)

        XCTAssertTrue(androidFocusHandlers.isEmpty)
        let node = androidRenderView(view)
        XCTAssertEqual(androidFocusHandlers.count, 1)

        // Handler must be registered under the child's node ID (what Kotlin sees),
        // not the FocusedView wrapper's ID
        XCTAssertNotNil(androidFocusHandlers[node.id],
            "Focus handler should be keyed to the child node's ID")
    }

    func testFocusHandlerUpdatesFocusState() {
        let state = State<String>(wrappedValue: "")
        let focus = FocusState<Bool>()
        let view = TextField("F", text: state.projectedValue)
            .focused(focus)
        let node = androidRenderView(view)

        // Look up by child node ID (what Kotlin sends)
        guard let handler = androidFocusHandlers[node.id] else {
            XCTFail("No focus handler registered for node ID \(node.id)")
            return
        }
        handler(true)
        XCTAssertEqual(focus.storage.value, true)

        handler(false)
        XCTAssertEqual(focus.storage.value, false)
    }

    func testFocusedEqualsViewRendersFocusProp() {
        enum Field: Hashable { case name, email }
        let state = State<String>(wrappedValue: "")
        let focus = FocusState<Field?>()
        let view = TextField("Name", text: state.projectedValue)
            .focused(focus, equals: .name)
        let node = androidRenderView(view)

        XCTAssertEqual(node.props["focused"], "false")
    }

    func testFocusedEqualsViewPropTrueWhenMatched() {
        enum Field: Hashable { case name, email }
        let state = State<String>(wrappedValue: "")
        let focus = FocusState<Field?>()
        focus.wrappedValue = .name
        let view = TextField("Name", text: state.projectedValue)
            .focused(focus, equals: .name)
        let node = androidRenderView(view)

        XCTAssertEqual(node.props["focused"], "true")
    }

    func testFocusedEqualsHandlerSetsValue() {
        enum Field: Hashable { case name, email }
        let state = State<String>(wrappedValue: "")
        let focus = FocusState<Field?>()
        let view = TextField("Name", text: state.projectedValue)
            .focused(focus, equals: .name)
        let node = androidRenderView(view)

        guard let handler = androidFocusHandlers[node.id] else {
            XCTFail("No focus handler registered for node ID \(node.id)")
            return
        }
        handler(true)
        XCTAssertEqual(focus.storage.value, Field.name)

        handler(false)
        XCTAssertNil(focus.storage.value as Any?)
    }

    func testBeginRenderPassClearsFocusHandlers() {
        let state = State<String>(wrappedValue: "")
        let focus = FocusState<Bool>()
        _ = androidRenderView(TextField("", text: state.projectedValue).focused(focus))
        XCTAssertFalse(androidFocusHandlers.isEmpty)

        androidBeginRenderPass()
        XCTAssertTrue(androidFocusHandlers.isEmpty)
    }

    // MARK: - Primitive views

    func testTextRenders() {
        let node = androidRenderView(Text("Hello"))
        XCTAssertEqual(node.type, "text")
        XCTAssertEqual(node.props["content"], "Hello")
    }

    func testSpacerRenders() {
        let node = androidRenderView(Spacer())
        XCTAssertEqual(node.type, "spacer")
    }

    func testDividerRenders() {
        let node = androidRenderView(Divider())
        XCTAssertEqual(node.type, "divider")
    }

    // MARK: - Container views

    func testVStackRendersChildren() {
        let view = VStack {
            Text("A")
            Text("B")
        }
        let node = androidRenderView(view)
        XCTAssertEqual(node.type, "vstack")
        XCTAssertEqual(node.children.count, 2)
        XCTAssertEqual(node.children[0].type, "text")
        XCTAssertEqual(node.children[1].type, "text")
    }

    func testHStackRendersChildren() {
        let view = HStack {
            Text("L")
            Spacer()
            Text("R")
        }
        let node = androidRenderView(view)
        XCTAssertEqual(node.type, "hstack")
        XCTAssertEqual(node.children.count, 3)
        XCTAssertEqual(node.children[1].type, "spacer")
    }

    func testTopLevelTupleViewRendersAsGroup() {
        let tuple = TupleView(Text("A"), Text("B"))
        let node = androidRenderView(tuple)

        XCTAssertEqual(node.type, "group")
        XCTAssertEqual(node.children.count, 2)
        XCTAssertEqual(node.children[0].type, "text")
        XCTAssertEqual(node.children[0].props["content"], "A")
        XCTAssertEqual(node.children[1].type, "text")
        XCTAssertEqual(node.children[1].props["content"], "B")
    }

    // MARK: - Modifier views

    func testPaddingModifier() {
        let view = Text("Padded").padding(8)
        let node = androidRenderView(view)
        XCTAssertEqual(node.type, "padding")
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].type, "text")
    }

    func testFontModifier() {
        let view = Text("Title").font(.title)
        let node = androidRenderView(view)
        XCTAssertEqual(node.type, "font")
        XCTAssertEqual(node.props["size"], "28")
        XCTAssertEqual(node.props["weight"], "bold")
    }

    func testForegroundColorModifier() {
        let view = Text("Red").foregroundColor(.red)
        let node = androidRenderView(view)
        XCTAssertEqual(node.type, "foregroundColor")
        XCTAssertEqual(node.children.count, 1)
    }

    func testFrameModifier() {
        let view = Text("Framed").frame(width: 100, height: 50)
        let node = androidRenderView(view)
        XCTAssertEqual(node.type, "frame")
        XCTAssertEqual(node.props["width"], "100.0")
        XCTAssertEqual(node.props["height"], "50.0")
    }

    // MARK: - Conditional rendering

    func testConditionalTrue() {
        let show = true
        let view = VStack {
            if show {
                Text("Visible")
            }
        }
        let node = androidRenderView(view)
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].type, "text")
    }

    func testConditionalFalse() {
        let show = false
        let view = VStack {
            if show {
                Text("Hidden")
            }
        }
        let node = androidRenderView(view)
        // Optional<Text> when false renders as empty
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].type, "empty")
    }

    // MARK: - Structural state cache

    func testNestedStateRestoredAcrossRenders() {
        // A child view with its own @State
        struct ChildCounter: View {
            @SwiftOpenUI.State var count: Int = 0
            var body: some View {
                Text("Count: \(count)")
            }
        }

        // Set up a mock host
        let host = MockViewHost()
        androidCurrentHost = host

        // First render — state cache is empty, count = 0
        androidBeginRenderPass()
        var child = ChildCounter()
        let node1 = androidRenderView(child)
        XCTAssertEqual(node1.props["content"], "Count: 0")

        // Simulate state mutation: find the cached storage and set it to 5
        let cachedEntries = androidStateCache.values.first { $0.count > 0 }
        XCTAssertNotNil(cachedEntries, "State should be cached after first render")
        if let storage = cachedEntries?.first as? StateStorage<Int> {
            storage.setValue(5)
        }

        // Second render — should restore cached value (5)
        androidBeginRenderPass()
        child = ChildCounter()  // fresh instance with count = 0
        let node2 = androidRenderView(child)
        XCTAssertEqual(node2.props["content"], "Count: 5")

        androidCurrentHost = nil
    }

    // MARK: - Drag gesture

    func testDragGestureRegistersHandler() {
        var changedValue: DragGestureValue?
        var endedValue: DragGestureValue?

        let view = Text("Drag me").onDrag(
            minimumDistance: 5,
            onChanged: { changedValue = $0 },
            onEnded: { endedValue = $0 }
        )
        let node = androidRenderView(view)

        XCTAssertEqual(node.props["onDrag"], "true")
        XCTAssertEqual(node.props["dragMinDist"], "5.0")

        // Verify handler is registered
        let handler = androidDragHandlers[node.id]
        XCTAssertNotNil(handler)
        XCTAssertEqual(handler?.minimumDistance, 5.0)

        // Simulate drag changed
        handler?.onChanged?(DragGestureValue(
            startLocation: (x: 10, y: 20),
            location: (x: 30, y: 40),
            translation: (width: 20, height: 20)
        ))
        XCTAssertNotNil(changedValue)
        XCTAssertEqual(changedValue?.translation.width, 20)

        // Simulate drag ended
        handler?.onEnded?(DragGestureValue(
            startLocation: (x: 10, y: 20),
            location: (x: 50, y: 60),
            translation: (width: 40, height: 40)
        ))
        XCTAssertNotNil(endedValue)
        XCTAssertEqual(endedValue?.translation.width, 40)
    }

    // MARK: - Navigation back button

    func testNavigationStackBackNodeIdWiredOnPush() {
        let host = MockViewHost()
        androidCurrentHost = host

        // View with NavigationStack + NavigationLink (registers destination in registry)
        struct NavDemo: View {
            @SwiftOpenUI.State var path = NavigationPath()
            var body: some View {
                NavigationStack(path: $path) {
                    NavigationLink("Go to Detail", title: "Detail") {
                        Text("Detail Page")
                    }
                }
            }
        }

        let view = NavDemo()
        installState(view, host: host)

        // First render — root view, no back button
        androidBeginRenderPass()
        let node1 = androidRenderView(view)
        let navNode1 = findNode(node1, type: "navigationStack")
        XCTAssertNotNil(navNode1, "Should render a navigationStack")
        XCTAssertNil(navNode1?.props["showBack"], "Root should not show back")

        // Push "Detail" via Mirror to access the StateStorage
        let mirror = Mirror(reflecting: view)
        let pathProvider = mirror.children.first { $0.value is AnyStateStorageProvider }!.value as! AnyStateStorageProvider
        let pathStorage = pathProvider.anyStorage as! StateStorage<NavigationPath>
        var updatedPath = pathStorage.value
        updatedPath.append("Detail")
        pathStorage.setValue(updatedPath)

        // Second render — destination resolved via NavigationLink registry
        androidBeginRenderPass()
        let node2 = androidRenderView(view)
        let navNode2 = findNode(node2, type: "navigationStack")
        XCTAssertEqual(navNode2?.props["showBack"], "true", "Pushed state should show back")
        XCTAssertNotNil(navNode2?.props["backNodeId"], "Should have backNodeId")

        // Verify the back action is in androidButtonActions
        if let backIdStr = navNode2?.props["backNodeId"],
           let backId = Int64(backIdStr) {
            XCTAssertNotNil(androidButtonActions[backId], "Back action should be registered in androidButtonActions")

            // Invoke it — should pop the path
            androidButtonActions[backId]!()
            XCTAssertTrue(pathStorage.value.isEmpty, "Path should be empty after back action")
        } else {
            XCTFail("backNodeId should be a valid Int64")
        }

        androidCurrentHost = nil
    }

    func testNavigationLinkWithCustomLabelRendersNestedLabelNode() {
        let node = androidRenderView(
            NavigationLink(title: "Detail") {
                Text("Destination")
            } label: {
                HStack {
                    Text("Go")
                    Text("Now")
                }
            }
        )

        XCTAssertEqual(node.type, "navigationLink")
        XCTAssertEqual(node.props["title"], "Detail")
        XCTAssertNil(node.props["label"])
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].type, "hstack")
    }

    func testBackgroundViewUsesZStackForCustomBackground() {
        let node = androidRenderView(
            Text("Hello").background(Text("BG"), alignment: .bottom)
        )

        XCTAssertEqual(node.type, "zstack")
        XCTAssertEqual(node.children.count, 2)
        XCTAssertEqual(node.children[0].type, "text")
        XCTAssertEqual(node.children[0].props["content"], "BG")
        XCTAssertEqual(node.children[1].type, "text")
        XCTAssertEqual(node.children[1].props["content"], "Hello")
    }

    /// Helper to find a node by type in the render tree.
    private func findNode(_ node: RenderNode, type: String) -> RenderNode? {
        if node.type == type { return node }
        for child in node.children {
            if let found = findNode(child, type: type) { return found }
        }
        return nil
    }
}

private class MockViewHost: AnyViewHost {
    var rebuildCount = 0
    func scheduleRebuild() { rebuildCount += 1 }
    func suppressNextFocusRestore() {}
}
