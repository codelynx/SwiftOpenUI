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
        let textState = State<String>(wrappedValue: "")
        let boolState = State<Bool>(wrappedValue: false)
        let doubleState = State<Double>(wrappedValue: 0.0)
        
        _ = androidRenderView(Button("B") { })
        _ = androidRenderView(TextField("", text: textState.projectedValue))
        _ = androidRenderView(SecureField("", text: textState.projectedValue))
        _ = androidRenderView(TextEditor(text: textState.projectedValue))
        _ = androidRenderView(Toggle("T", isOn: boolState.projectedValue))
        _ = androidRenderView(Slider(value: doubleState.projectedValue))
        
        XCTAssertFalse(androidButtonActions.isEmpty)
        XCTAssertFalse(androidTextBindings.isEmpty)
        XCTAssertEqual(androidTextBindings.count, 3) // TextField, SecureField, TextEditor
        XCTAssertFalse(androidToggleBindings.isEmpty)
        XCTAssertFalse(androidSliderBindings.isEmpty)

        androidBeginRenderPass()
        XCTAssertTrue(androidButtonActions.isEmpty)
        XCTAssertTrue(androidTextBindings.isEmpty)
        XCTAssertTrue(androidToggleBindings.isEmpty)
        XCTAssertTrue(androidSliderBindings.isEmpty)
    }

    // MARK: - SecureField, TextEditor, ProgressView Tests

    func testSecureFieldRenders() {
        let state = State<String>(wrappedValue: "secret")
        let field = SecureField("Password", text: state.projectedValue)
        let node = androidRenderView(field)

        XCTAssertEqual(node.type, "securefield")
        XCTAssertEqual(node.props["placeholder"], "Password")
        XCTAssertEqual(node.props["text"], "secret")
    }

    func testTextEditorRenders() {
        let state = State<String>(wrappedValue: "body")
        let editor = TextEditor(text: state.projectedValue)
        let node = androidRenderView(editor)

        XCTAssertEqual(node.type, "texteditor")
        XCTAssertEqual(node.props["text"], "body")
    }

    func testProgressViewDeterminateRenders() {
        let view = ProgressView(value: 0.5, total: 2.0)
        let node = androidRenderView(view)

        XCTAssertEqual(node.type, "progressview")
        XCTAssertEqual(node.props["progress"], "0.25")
    }

    func testProgressViewIndeterminateRenders() {
        let view = ProgressView()
        let node = androidRenderView(view)

        XCTAssertEqual(node.type, "progressview")
        XCTAssertNil(node.props["progress"])
    }

    // MARK: - Toggle and Slider Tests

    func testToggleRenders() {
        let state = State<Bool>(wrappedValue: true)
        let toggle = Toggle("Wi-Fi", isOn: state.projectedValue)
        let node = androidRenderView(toggle)

        XCTAssertEqual(node.type, "toggle")
        XCTAssertEqual(node.props["label"], "Wi-Fi")
        XCTAssertEqual(node.props["isOn"], "true")
    }

    func testToggleRegistersBinding() {
        let state = State<Bool>(wrappedValue: false)
        let toggle = Toggle("", isOn: state.projectedValue)

        XCTAssertTrue(androidToggleBindings.isEmpty)
        _ = androidRenderView(toggle)
        XCTAssertEqual(androidToggleBindings.count, 1)
    }

    func testToggleBindingUpdatesState() {
        let state = State<Bool>(wrappedValue: false)
        let toggle = Toggle("", isOn: state.projectedValue)
        _ = androidRenderView(toggle)

        guard let (_, binding) = androidToggleBindings.first else {
            XCTFail("No toggle binding registered")
            return
        }
        binding.wrappedValue = true
        XCTAssertEqual(state.wrappedValue, true)
    }

    func testSliderRendersWithStep() {
        let state = State<Double>(wrappedValue: 0.5)
        let slider = Slider(value: state.projectedValue, in: 0...1, step: 0.1)
        let node = androidRenderView(slider)

        XCTAssertEqual(node.type, "slider")
        XCTAssertEqual(node.props["value"], "0.5")
        XCTAssertEqual(node.props["min"], "0.0")
        XCTAssertEqual(node.props["max"], "1.0")
        XCTAssertEqual(node.props["step"], "0.1")
    }

    func testSliderRegistersBinding() {
        let state = State<Double>(wrappedValue: 0.0)
        let slider = Slider(value: state.projectedValue)

        XCTAssertTrue(androidSliderBindings.isEmpty)
        _ = androidRenderView(slider)
        XCTAssertEqual(androidSliderBindings.count, 1)
    }

    func testSliderBindingUpdatesState() {
        let state = State<Double>(wrappedValue: 0.0)
        let slider = Slider(value: state.projectedValue)
        _ = androidRenderView(slider)

        guard let (_, binding) = androidSliderBindings.first else {
            XCTFail("No slider binding registered")
            return
        }
        binding.wrappedValue = 0.75
        XCTAssertEqual(state.wrappedValue, 0.75)
    }

    // MARK: - ScrollView Tests

    func testScrollViewRendersVertical() {
        let view = ScrollView(.vertical) { Text("Scroll") }
        let node = androidRenderView(view)

        XCTAssertEqual(node.type, "scrollview")
        XCTAssertEqual(node.props["axis"], "vertical")
        XCTAssertEqual(node.children.count, 1)
    }

    func testScrollViewRendersHorizontal() {
        let view = ScrollView(.horizontal) { Text("Scroll") }
        let node = androidRenderView(view)

        XCTAssertEqual(node.type, "scrollview")
        XCTAssertEqual(node.props["axis"], "horizontal")
        XCTAssertEqual(node.children.count, 1)
    }

    func testScrollViewRendersBothAxes() {
        let view = ScrollView([.horizontal, .vertical]) { Text("Scroll") }
        let node = androidRenderView(view)

        XCTAssertEqual(node.type, "scrollview")
        XCTAssertEqual(node.props["axis"], "both")
        XCTAssertEqual(node.children.count, 1)
    }

    // MARK: - List Tests

    func testListRenders() {
        let view = List { Text("Row 1"); Text("Row 2") }
        let node = androidRenderView(view)

        XCTAssertEqual(node.type, "list")
        XCTAssertEqual(node.children.count, 2)
        XCTAssertEqual(node.children[0].type, "text")
        XCTAssertEqual(node.children[1].type, "text")
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

    func testVStackPrecisionLayout() {
        let view = VStack(spacing: 10) {
            Text("Line 1")
            Text("Line 2")
        }
        let node = androidRenderView(view)
        
        // Root vstack should have container size
        XCTAssertNotNil(node.layout)
        XCTAssertGreaterThan(node.layout?["width"] ?? 0, 0)
        XCTAssertGreaterThan(node.layout?["height"] ?? 0, 0)

        // Children should have absolute offsets
        XCTAssertEqual(node.children.count, 2)
        
        let child1 = node.children[0]
        let child2 = node.children[1]
        
        XCTAssertEqual(child1.layout?["x"], 0)
        XCTAssertEqual(child1.layout?["y"], 0)
        
        XCTAssertEqual(child2.layout?["x"], 0)
        // Y offset should be child1 height + spacing
        let child1H = child1.layout?["height"] ?? 0
        XCTAssertEqual(child2.layout?["y"], child1H + 10.0)
    }

    func testVStackLayoutFallback() {
        // Stacks containing Spacers or non-allowlisted views should NOT have layout info
        let viewWithSpacer = VStack {
            Text("A")
            Spacer()
        }
        let node1 = androidRenderView(viewWithSpacer)
        XCTAssertNil(node1.layout, "VStack with Spacer should use Compose fallback")

        let viewWithSlider = VStack {
            Text("A")
            Slider(value: .constant(0.5))
        }
        let node2 = androidRenderView(viewWithSlider)
        XCTAssertNil(node2.layout, "VStack with Slider should use Compose fallback")

        let viewWithPadding = VStack {
            Text("A").padding()
        }
        let node3 = androidRenderView(viewWithPadding)
        XCTAssertNil(node3.layout, "VStack with padded child should use Compose fallback")
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

    // MARK: - Shape Tests

    func testCircleRenders() {
        let node = androidRenderView(Circle().foregroundColor(.red))
        XCTAssertEqual(node.type, "foregroundColor")
        let shapeNode = node.children[0]
        XCTAssertEqual(shapeNode.type, "filledShape")
        XCTAssertEqual(shapeNode.props["shapeType"], "circle")
        XCTAssertEqual(shapeNode.props["r"], "1.0")
    }

    func testRoundedRectangleRenders() {
        let node = androidRenderView(RoundedRectangle(cornerRadius: 12).fill(.blue))
        XCTAssertEqual(node.type, "filledShape")
        XCTAssertEqual(node.props["shapeType"], "roundedRectangle")
        XCTAssertEqual(node.props["cornerRadius"], "12.0")
        XCTAssertEqual(node.props["b"], "1.0")
    }

    func testStrokedShapeRenders() {
        let node = androidRenderView(Rectangle().stroke(.green, lineWidth: 4))
        XCTAssertEqual(node.type, "strokedShape")
        XCTAssertEqual(node.props["shapeType"], "rectangle")
        XCTAssertEqual(node.props["lineWidth"], "4.0")
        XCTAssertEqual(node.props["g"], "0.667")
    }

    func testEllipseRenders() {
        let node = androidRenderView(Ellipse().fill(.blue))
        XCTAssertEqual(node.type, "filledShape")
        XCTAssertEqual(node.props["shapeType"], "ellipse")
        XCTAssertEqual(node.props["b"], "1.0")
    }

    func testCapsuleRenders() {
        let node = androidRenderView(Capsule().fill(.orange))
        XCTAssertEqual(node.type, "filledShape")
        XCTAssertEqual(node.props["shapeType"], "capsule")
        XCTAssertEqual(node.props["r"], "1.0")
        XCTAssertEqual(node.props["g"], "0.533")
    }

    func testClipShapeModifier() {
        let node = androidRenderView(Text("A").clipShape(Circle()))
        XCTAssertEqual(node.type, "clipShape")
        XCTAssertEqual(node.props["shapeType"], "circle")
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].type, "text")
    }

    // MARK: - Presentation Tests

    func testSheetModifierRenders() {
        let isPresented = State(wrappedValue: true)
        let view = Text("Main").sheet(isPresented: isPresented.projectedValue) {
            Text("Sheet Content")
        }
        
        let node = androidRenderView(view)
        XCTAssertEqual(node.type, "text")
        XCTAssertEqual(node.children.count, 1)
        
        let sheetNode = node.children[0]
        XCTAssertEqual(sheetNode.type, "sheet")
        XCTAssertEqual(sheetNode.children.count, 1)
        XCTAssertEqual(sheetNode.children[0].type, "text")
        XCTAssertEqual(sheetNode.children[0].props["content"], "Sheet Content")
        
        // Verify dismissal action is registered
        XCTAssertNotNil(androidButtonActions[sheetNode.id])
        androidButtonActions[sheetNode.id]?()
        XCTAssertFalse(isPresented.wrappedValue)
    }

    func testAlertModifierRenders() {
        let isPresented = State(wrappedValue: true)
        let view = Text("Main").alert("Title", isPresented: isPresented.projectedValue, actions: [AlertButton("OK") { }], message: "Message")
        
        let node = androidRenderView(view)
        XCTAssertEqual(node.type, "text")
        XCTAssertEqual(node.children.count, 1)
        
        let alertNode = node.children[0]
        XCTAssertEqual(alertNode.type, "alert")
        XCTAssertEqual(alertNode.props["title"], "Title")
        XCTAssertEqual(alertNode.props["message"], "Message")
        XCTAssertEqual(alertNode.children.count, 1)
        
        let btnNode = alertNode.children[0]
        XCTAssertEqual(btnNode.type, "alertButton")
        XCTAssertEqual(btnNode.props["label"], "OK")
        
        // Verify button action is registered and dismisses
        XCTAssertNotNil(androidButtonActions[btnNode.id])
        androidButtonActions[btnNode.id]?()
        XCTAssertFalse(isPresented.wrappedValue)
    }

    func testAlertButtonDestructiveRole() {
        let isPresented = State(wrappedValue: true)
        let view = Text("Main").alert("Delete?", isPresented: isPresented.projectedValue, actions: [
            AlertButton("Delete", role: .destructive) { }
        ])
        
        let node = androidRenderView(view)
        let alertNode = node.children[0]
        let btnNode = alertNode.children[0]
        XCTAssertEqual(btnNode.props["role"], "destructive")
    }

    func testListWithSheetModifier() {
        let isPresented = State(wrappedValue: true)
        let view = List {
            Text("Row 1")
        }.sheet(isPresented: isPresented.projectedValue) {
            Text("Sheet")
        }
        
        let node = androidRenderView(view)
        // Root should be List
        XCTAssertEqual(node.type, "list")
        // Child 0 is the Row, Child 1 is the Sheet (appended)
        XCTAssertEqual(node.children.count, 2)
        XCTAssertEqual(node.children[0].type, "text")
        XCTAssertEqual(node.children[1].type, "sheet")
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
