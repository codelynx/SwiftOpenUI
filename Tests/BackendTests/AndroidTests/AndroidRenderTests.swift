import XCTest
@testable import SwiftOpenUI
@testable import BackendAndroid

final class AndroidRenderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        androidBeginRenderPass()
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

    // MARK: - Focused modifier pass-through

    func testFocusedViewPassesThrough() {
        let state = State<String>(wrappedValue: "hi")
        let focusState = FocusState<Bool>()
        let view = TextField("F", text: state.projectedValue)
            .focused(focusState)
        let node = androidRenderView(view)

        // FocusedView is a pass-through — should render the TextField directly
        XCTAssertEqual(node.type, "textfield")
        XCTAssertEqual(node.props["text"], "hi")
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
}
