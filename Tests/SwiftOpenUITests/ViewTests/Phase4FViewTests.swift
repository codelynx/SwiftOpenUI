import XCTest
@testable import SwiftOpenUI

final class Phase4FViewTests: XCTestCase {

    // MARK: - Picker

    func testPickerCallback() {
        var selected = -1
        let picker = Picker("Color", selection: 1, options: ["Red", "Green", "Blue"]) { selected = $0 }
        XCTAssertEqual(picker.label, "Color")
        XCTAssertEqual(picker.options.count, 3)
        XCTAssertEqual(picker.selected, 1)
        picker.onChanged?(2)
        XCTAssertEqual(selected, 2)
    }

    func testPickerBinding() {
        let picker = Picker("Size", selection: .constant(0), options: ["S", "M", "L"])
        XCTAssertEqual(picker.selected, 0)
        XCTAssertNotNil(picker.onChanged)
    }

    func testPickerStyle() {
        let picker = Picker("Mode", options: ["A", "B"]).pickerStyle(.segmented)
        if case .segmented = picker.style {} else {
            XCTFail("Expected .segmented style")
        }
    }

    // MARK: - DatePicker

    func testDateComponents() {
        let dc = SwiftOpenUI.DateComponents(year: 2025, month: 3, day: 15)
        XCTAssertEqual(dc.year, 2025)
        XCTAssertEqual(dc.month, 3)
        XCTAssertEqual(dc.day, 15)
    }

    func testDateComponentsToday() {
        let dc = SwiftOpenUI.DateComponents()
        XCTAssertGreaterThan(dc.year, 2020)
        XCTAssertTrue((1...12).contains(dc.month))
        XCTAssertTrue((1...31).contains(dc.day))
    }

    func testDatePickerCallback() {
        let picker = DatePicker("Birthday")
        XCTAssertEqual(picker.title, "Birthday")
        XCTAssertNil(picker.selection)
    }

    func testDatePickerBinding() {
        let dc = SwiftOpenUI.DateComponents(year: 2000, month: 1, day: 1)
        let picker = DatePicker("DOB", selection: .constant(dc))
        XCTAssertNotNil(picker.selection)
        XCTAssertEqual(picker.selection?.wrappedValue.year, 2000)
    }

    // MARK: - GeometryReader

    func testGeometrySize() {
        let size = GeometrySize(width: 100, height: 200)
        XCTAssertEqual(size.width, 100)
        XCTAssertEqual(size.height, 200)
    }

    func testGeometryProxy() {
        let proxy = GeometryProxy(size: GeometrySize(width: 300, height: 400))
        XCTAssertEqual(proxy.size.width, 300)
        XCTAssertEqual(proxy.size.height, 400)
    }

    func testGeometryReaderConstruction() {
        let reader = GeometryReader { geo in
            Text("Width: \(geo.size.width)")
        }
        // Verify content builder works
        let proxy = GeometryProxy(size: GeometrySize(width: 100, height: 50))
        let view = reader.content(proxy)
        XCTAssertTrue(view is Text)
    }

    // MARK: - Searchable

    func testSearchableModifier() {
        let text = Text("Content")
        let searchable = text.searchable(text: .constant("query"), prompt: "Find...")
        XCTAssertEqual(searchable.text.wrappedValue, "query")
        XCTAssertEqual(searchable.prompt, "Find...")
        XCTAssertEqual(searchable.placement, .automatic)
        XCTAssertNil(searchable.isPresented)
    }

    func testSearchableDefaultPrompt() {
        let searchable = Text("Content").searchable(text: .constant(""))
        XCTAssertEqual(searchable.prompt, "Search")
        XCTAssertEqual(searchable.placement, .automatic)
    }

    func testSearchableExplicitPlacement() {
        let searchable = Text("Content").searchable(
            text: .constant("query"),
            placement: .sidebar,
            prompt: "Find..."
        )
        XCTAssertEqual(searchable.placement, .sidebar)
        XCTAssertNil(searchable.isPresented)
    }

    func testSearchableStoresPresentationBinding() {
        let presented = Binding.constant(true)
        let searchable = Text("Content").searchable(
            text: .constant("query"),
            isPresented: presented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Find..."
        )
        XCTAssertTrue(searchable.isPresented?.wrappedValue == true)
        XCTAssertEqual(
            searchable.placement,
            .navigationBarDrawer(displayMode: .always)
        )
    }

    // MARK: - Menu

    func testMenuConstruction() {
        let menu = Menu("Actions") {
            MenuItem("Copy") { }
            MenuItem("Paste") { }
        }
        XCTAssertEqual(menu.title, "Actions")
        XCTAssertEqual(menu.elements.count, 2)
    }

    func testMenuWithSubmenu() {
        let menu = Menu("Edit") {
            MenuItem("Cut") { }
            SubMenu("Format") {
                MenuItem("Bold") { }
                MenuItem("Italic") { }
            }
        }
        XCTAssertEqual(menu.elements.count, 2)
        if case .submenu(let label, let children) = menu.elements[1] {
            XCTAssertEqual(label, "Format")
            XCTAssertEqual(children.count, 2)
        } else {
            XCTFail("Expected submenu")
        }
    }

    // MARK: - Toolbar

    func testToolbarItemConstruction() {
        let item = ToolbarItem(placement: .leading) {
            Button("Add") { }
        }
        if case .leading = item.placement {} else {
            XCTFail("Expected .leading placement")
        }
    }

    func testToolbarModifier() {
        let view = Text("Content").toolbar {
            ToolbarItem(placement: .trailing) {
                Button("Save") { }
            }
        }
        XCTAssertEqual(view.toolbarItems.count, 1)
        if case .trailing = view.toolbarItems[0].placement {} else {
            XCTFail("Expected .trailing placement")
        }
    }

    // MARK: - ConfirmationDialog

    func testConfirmationDialogConstruction() {
        let dialog = Text("Content").confirmationDialog(
            "Delete Item?",
            isPresented: .constant(false),
            actions: [
                AlertButton("Delete", role: .destructive) { },
                AlertButton("Cancel", role: .cancel) { }
            ]
        )
        XCTAssertEqual(dialog.title, "Delete Item?")
        XCTAssertFalse(dialog.isPresented.wrappedValue)
        XCTAssertEqual(dialog.buttons.count, 2)
        XCTAssertEqual(dialog.buttons[0].label, "Delete")
        XCTAssertEqual(dialog.buttons[0].role, .destructive)
        XCTAssertEqual(dialog.buttons[1].role, .cancel)
    }

    // MARK: - Canvas

    func testCanvasConstruction() {
        let canvas = Canvas(width: 400, height: 300) { context, w, h in
            // draw handler
        }
        XCTAssertEqual(canvas.width, 400)
        XCTAssertEqual(canvas.height, 300)
    }

    func testCanvasDefaultSize() {
        let canvas = Canvas { _, _, _ in }
        XCTAssertEqual(canvas.width, 0)
        XCTAssertEqual(canvas.height, 0)
    }

    func testCanvasSizeModifier() {
        let canvas = Canvas { _, _, _ in }
            .canvasSize(width: 200, height: 100)
        XCTAssertEqual(canvas.width, 200)
        XCTAssertEqual(canvas.height, 100)
    }

    func testCanvasLayoutSizedInit() {
        let canvas = Canvas { context, size in
            // SwiftUI-style draw handler with CGSize
        }
        XCTAssertEqual(canvas.width, 0, "Layout-sized Canvas should have no explicit width")
        XCTAssertEqual(canvas.height, 0, "Layout-sized Canvas should have no explicit height")
        XCTAssertTrue(canvas.usesLayoutSize, "Canvas(renderer:) should use layout size")
        XCTAssertNotNil(canvas.sizedDrawHandler, "sizedDrawHandler should be set")
    }

    func testCanvasLegacyInitDoesNotUseLayoutSize() {
        let canvas = Canvas(width: 400, height: 300) { _, _, _ in }
        XCTAssertFalse(canvas.usesLayoutSize, "Legacy Canvas should not use layout size")
        XCTAssertNil(canvas.sizedDrawHandler, "Legacy Canvas should not have sizedDrawHandler")
    }

    func testCanvasLayoutSizedHandlerReceivesCGSize() {
        var receivedSize: CGSize?
        let canvas = Canvas { context, size in
            receivedSize = size
        }
        // Simulate what the backend does: call the legacy drawHandler
        // which wraps the sized handler
        let dummyCr = OpaquePointer(bitPattern: 1)!
        canvas.drawHandler(DrawingContext(cr: dummyCr), 640, 480)
        XCTAssertEqual(receivedSize?.width, 640)
        XCTAssertEqual(receivedSize?.height, 480)
    }

    // MARK: - Path tests

    func testPathConstruction() {
        var path = Path()
        XCTAssertTrue(path.isEmpty)
        path.move(to: CGPoint(x: 10, y: 20))
        path.addLine(to: CGPoint(x: 100, y: 200))
        XCTAssertFalse(path.isEmpty)
        XCTAssertEqual(path.elements.count, 2)
    }

    func testPathFromRect() {
        let path = Path(CGRect(x: 0, y: 0, width: 100, height: 50))
        // moveTo + 3 lineTo + closeSubpath = 5 elements
        XCTAssertEqual(path.elements.count, 5)
    }

    func testPathFromEllipse() {
        let path = Path(ellipseIn: CGRect(x: 0, y: 0, width: 100, height: 80))
        XCTAssertEqual(path.elements.count, 1) // single .ellipse element
    }

    func testPathAddCurve() {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(to: CGPoint(x: 100, y: 100),
                       control1: CGPoint(x: 30, y: 0),
                       control2: CGPoint(x: 70, y: 100))
        XCTAssertEqual(path.elements.count, 2)
    }

    func testPathCloseSubpath() {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 100, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 100))
        path.closeSubpath()
        XCTAssertEqual(path.elements.count, 4)
    }

    func testStrokeStyleDefaults() {
        let style = StrokeStyle()
        XCTAssertEqual(style.lineWidth, 1)
    }

    func testStrokeStyleCustom() {
        let style = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        XCTAssertEqual(style.lineWidth, 3)
    }

    func testShadingColorComponents() {
        let shading = Shading.color(Color(red: 1, green: 0.5, blue: 0, opacity: 0.8))
        let (r, g, b, a) = shading.colorComponents
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.5, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
        XCTAssertEqual(a, 0.8, accuracy: 0.01)
    }

    func testShadingOpaqueColor() {
        let shading = Shading.color(.red)
        let (_, _, _, a) = shading.colorComponents
        XCTAssertEqual(a, 1.0)
    }

    func testDrawingContextTypes() {
        // LineCap and LineJoin enums should be constructible
        let _ = LineCap.round
        let _ = LineCap.butt
        let _ = LineCap.square
        let _ = LineJoin.miter
        let _ = LineJoin.round
        let _ = LineJoin.bevel
    }
}
