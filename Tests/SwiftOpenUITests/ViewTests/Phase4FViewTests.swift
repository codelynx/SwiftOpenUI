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

    // MARK: - ViewThatFits

    func testViewThatFitsStoresChildrenInSourceOrder() {
        let view = ViewThatFits {
            Text("Wide")
            Text("Compact")
            Button("Fallback") { }
        }

        XCTAssertEqual(view.children.count, 3)
        XCTAssertEqual((view.children[0].wrapped as? Text)?.content, "Wide")
        XCTAssertEqual((view.children[1].wrapped as? Text)?.content, "Compact")
        XCTAssertNotNil(view.children[2].wrapped as? Button<Text>)
    }

    func testViewThatFitsBuilderSupportsConditionals() {
        let includeCompact = true
        let view = ViewThatFits {
            Text("Primary")
            if includeCompact {
                Text("Compact")
            }
        }

        XCTAssertEqual(view.children.count, 2)
        XCTAssertEqual((view.children[0].wrapped as? Text)?.content, "Primary")
        XCTAssertEqual((view.children[1].wrapped as? Text)?.content, "Compact")
    }

    func testViewThatFitsBuilderSupportsLoops() {
        let labels = ["One", "Two", "Three"]
        let view = ViewThatFits {
            for label in labels {
                Text(label)
            }
        }

        XCTAssertEqual(view.children.count, 3)
        XCTAssertEqual((view.children[0].wrapped as? Text)?.content, "One")
        XCTAssertEqual((view.children[1].wrapped as? Text)?.content, "Two")
        XCTAssertEqual((view.children[2].wrapped as? Text)?.content, "Three")
    }

    func testViewThatFitsAllowsEmptyContent() {
        let view = ViewThatFits {}
        XCTAssertTrue(view.children.isEmpty)
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

    func testSearchableStoresTokenValues() {
        struct SearchToken: Identifiable {
            let id: Int
            let name: String
        }

        let searchable = Text("Content").searchable(
            text: .constant("query"),
            tokens: .constant([
                SearchToken(id: 1, name: "Swift"),
                SearchToken(id: 2, name: "UI")
            ]),
            placement: .sidebar,
            prompt: "Find"
        ) { token in
            Text(token.name)
        }

        XCTAssertEqual(searchable.placement, .sidebar)
        XCTAssertEqual(searchable.tokenMode, .tokens)
        XCTAssertEqual(
            searchable.tokens,
            [
                SearchTokenValue(id: "1", label: "Swift"),
                SearchTokenValue(id: "2", label: "UI")
            ]
        )
    }

    func testSearchableStoresEditableTokenValues() {
        struct SearchToken: Identifiable {
            let id: String
            let label: String
        }

        let searchable = Text("Content").searchable(
            text: .constant(""),
            editableTokens: .constant([
                SearchToken(id: "a", label: "Open"),
                SearchToken(id: "b", label: "Closed")
            ]),
            prompt: "Filter"
        ) { token in
            Text(token.label)
        }

        XCTAssertEqual(searchable.tokenMode, .editableTokens)
        XCTAssertEqual(searchable.tokens.count, 2)
        XCTAssertEqual(searchable.tokens[0].id, "a")
        XCTAssertEqual(searchable.tokens[1].label, "Closed")
    }

    func testSearchableStoresSuggestions() {
        let searchable = Text("Content")
            .searchable(text: .constant("query"))
            .searchSuggestions {
                Text("SwiftUI")
                Text("UIKit").searchCompletion("UIKit")
            }

        XCTAssertEqual(searchable.suggestionMode, .suggestions)
        XCTAssertEqual(
            searchable.suggestions,
            [
                SearchSuggestionValue(id: "SwiftUI", label: "SwiftUI"),
                SearchSuggestionValue(id: "UIKit|UIKit", label: "UIKit", completion: "UIKit")
            ]
        )
    }

    func testSearchableSuggestionBuilderSupportsConditionals() {
        let includeSuggestion = true
        let searchable = Text("Content")
            .searchable(text: .constant(""))
            .searchSuggestions {
                if includeSuggestion {
                    Text("Alpha")
                }
                Text("Beta").searchCompletion("B")
            }

        XCTAssertEqual(searchable.suggestions.count, 2)
        XCTAssertEqual(searchable.suggestions[0].label, "Alpha")
        XCTAssertEqual(searchable.suggestions[1].completion, "B")
    }

    func testSearchableStoresFilteredSuggestionsForQuery() {
        let searchable = Text("Content")
            .searchable(text: .constant("swift"))
            .searchSuggestions(
                [
                    SearchSuggestionValue(id: "swiftui", label: "SwiftUI"),
                    SearchSuggestionValue(id: "uikit", label: "UIKit"),
                    SearchSuggestionValue(id: "swift-data", label: "Swift Data")
                ],
                for: "swift"
            )

        XCTAssertEqual(searchable.suggestionMode, .suggestionsFor)
        XCTAssertEqual(
            searchable.suggestions,
            [
                SearchSuggestionValue(id: "swiftui", label: "SwiftUI"),
                SearchSuggestionValue(id: "swift-data", label: "Swift Data")
            ]
        )
    }

    func testSearchableFilteredSuggestionsAreCaseInsensitive() {
        let searchable = Text("Content")
            .searchable(text: .constant("KIT"))
            .searchSuggestions(
                [
                    SearchSuggestionValue(id: "swiftui", label: "SwiftUI"),
                    SearchSuggestionValue(id: "uikit", label: "UIKit")
                ],
                for: "KIT"
            )

        XCTAssertEqual(searchable.suggestions.count, 1)
        XCTAssertEqual(searchable.suggestions[0].label, "UIKit")
    }

    func testSearchableFilteredSuggestionsMatchCompletionText() {
        let searchable = Text("Content")
            .searchable(text: .constant("ios"))
            .searchSuggestions(
                [
                    SearchSuggestionValue(id: "swift", label: "SwiftUI", completion: "ios ui"),
                    SearchSuggestionValue(id: "server", label: "Vapor", completion: "server")
                ],
                for: "ios"
            )

        XCTAssertEqual(searchable.suggestions.count, 1)
        XCTAssertEqual(searchable.suggestions[0].label, "SwiftUI")
        XCTAssertEqual(searchable.suggestions[0].completion, "ios ui")
    }

    func testSearchableFilteredSuggestionsKeepAllRowsForEmptyQuery() {
        let searchable = Text("Content")
            .searchable(text: .constant(""))
            .searchSuggestions(
                [
                    SearchSuggestionValue(id: "one", label: "Alpha"),
                    SearchSuggestionValue(id: "two", label: "Beta")
                ],
                for: ""
            )

        XCTAssertEqual(searchable.suggestions.count, 2)
        XCTAssertEqual(searchable.suggestions[0].label, "Alpha")
        XCTAssertEqual(searchable.suggestions[1].label, "Beta")
    }

    func testSearchableStoresScopes() {
        enum Scope: String, Hashable {
            case all
            case open
            case closed
        }

        let selected = Binding.constant(Scope.open)
        let searchable = Text("Content")
            .searchable(text: .constant("query"))
            .searchScopes(selected, scopes: [Scope.all, Scope.open, Scope.closed]) { scope in
                Text(scope.rawValue.capitalized)
            }

        XCTAssertEqual(searchable.scopeMode, .scopes)
        XCTAssertEqual(searchable.selectedScopeID, "open")
        XCTAssertEqual(
            searchable.scopes,
            [
                SearchScopeValue(id: "all", label: "All"),
                SearchScopeValue(id: "open", label: "Open"),
                SearchScopeValue(id: "closed", label: "Closed")
            ]
        )
    }

    func testSearchableScopeSelectionWritesBack() {
        enum Scope: String, Hashable {
            case all
            case favorites
        }

        var selected = Scope.all
        let searchable = Text("Content")
            .searchable(text: .constant(""))
            .searchScopes(
                Binding(get: { selected }, set: { selected = $0 }),
                scopes: [.all, .favorites]
            ) { scope in
                Text(scope.rawValue.capitalized)
            }

        searchable.selectScope(id: "favorites")
        XCTAssertEqual(selected, .favorites)
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
        XCTAssertNil(view.toolbarID)
        XCTAssertEqual(view.toolbarItems.count, 1)
        XCTAssertEqual(view.toolbarConfiguration, ToolbarConfiguration())
        if case .trailing = view.toolbarItems[0].placement {} else {
            XCTFail("Expected .trailing placement")
        }
    }

    func testToolbarModifierFlattensMultipleItemsInOrder() {
        let view = Text("Content").toolbar {
            ToolbarItem(placement: .leading) {
                Button("Back") { }
            }
            ToolbarItem(placement: .trailing) {
                Button("Edit") { }
            }
            ToolbarItem {
                Button("Done") { }
            }
        }

        XCTAssertEqual(view.toolbarItems.count, 3)
        if case .leading = view.toolbarItems[0].placement {} else {
            XCTFail("Expected first item to be .leading")
        }
        if case .trailing = view.toolbarItems[1].placement {} else {
            XCTFail("Expected second item to be .trailing")
        }
        if case .primaryAction = view.toolbarItems[2].placement {} else {
            XCTFail("Expected third item to be .primaryAction")
        }
    }

    func testToolbarModifierStoresID() {
        let view = Text("Content").toolbar(id: "detail-toolbar") {
            ToolbarItem(placement: .trailing) {
                Button("Save") { }
            }
        }

        XCTAssertEqual(view.toolbarID, "detail-toolbar")
        XCTAssertEqual(view.toolbarItems.count, 1)
        XCTAssertEqual(view.toolbarConfiguration, ToolbarConfiguration())
    }

    func testToolbarModifierChainsMergeItemsInOrder() {
        let view = Text("Content")
            .toolbar {
                ToolbarItem(placement: .leading) {
                    Button("Lead") { }
                }
            }
            .toolbar {
                ToolbarItem(placement: .trailing) {
                    Button("Trail") { }
                }
            }

        XCTAssertNil(view.toolbarID)
        XCTAssertEqual(view.toolbarItems.count, 2)
        if case .leading = view.toolbarItems[0].placement {} else {
            XCTFail("Expected first item to be .leading")
        }
        if case .trailing = view.toolbarItems[1].placement {} else {
            XCTFail("Expected second item to be .trailing")
        }
    }

    func testToolbarModifierChainsPreserveExistingID() {
        let view = Text("Content")
            .toolbar(id: "detail-toolbar") {
                ToolbarItem(placement: .leading) {
                    Button("Lead") { }
                }
            }
            .toolbar {
                ToolbarItem(placement: .trailing) {
                    Button("Trail") { }
                }
            }

        XCTAssertEqual(view.toolbarID, "detail-toolbar")
        XCTAssertEqual(view.toolbarItems.count, 2)
    }

    func testToolbarModifierChainsCanReplaceID() {
        let view = Text("Content")
            .toolbar {
                ToolbarItem(placement: .leading) {
                    Button("Lead") { }
                }
            }
            .toolbar(id: "secondary-toolbar") {
                ToolbarItem(placement: .trailing) {
                    Button("Trail") { }
                }
            }

        XCTAssertEqual(view.toolbarID, "secondary-toolbar")
        XCTAssertEqual(view.toolbarItems.count, 2)
    }

    func testToolbarVisibilityConfigurationStored() {
        let view = Text("Content").toolbar(.hidden, for: .navigationBar)

        XCTAssertEqual(
            view.toolbarConfiguration,
            ToolbarConfiguration(
                visibility: .hidden,
                visibilityTarget: .navigationBar
            )
        )
    }

    func testToolbarRemovingPlacementsStored() {
        let view = Text("Content").toolbar(removing: .leading, .primaryAction)

        XCTAssertEqual(
            view.toolbarConfiguration.removedPlacements,
            [.leading, .primaryAction]
        )
    }

    func testToolbarConfigurationWrapsToolbarItems() {
        let configured = Text("Content")
            .toolbar {
                ToolbarItem(placement: .trailing) {
                    Button("Save") { }
                }
            }
            .toolbar(.hidden, for: .navigationBar)

        XCTAssertEqual(configured.toolbarConfiguration.visibility, .hidden)
        XCTAssertEqual(configured.toolbarConfiguration.visibilityTarget, .navigationBar)
        XCTAssertEqual(configured.toolbarItems.count, 1)
    }

    func testToolbarConfigurationCanMergeVisibilityAndRemovals() {
        let configured = Text("Content")
            .toolbar(.visible, for: .navigationBar)
            .toolbar(removing: .trailing)
            .toolbar(removing: .trailing, .primaryAction)

        XCTAssertEqual(configured.toolbarConfiguration.visibility, .visible)
        XCTAssertEqual(configured.toolbarConfiguration.visibilityTarget, .navigationBar)
        XCTAssertEqual(
            configured.toolbarConfiguration.removedPlacements,
            [.trailing, .primaryAction]
        )
    }

    func testToolbarConfigurationAndItemsComposeInEitherOrder() {
        let configured = Text("Content")
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .leading) {
                    Button("Lead") { }
                }
                ToolbarItem(placement: .trailing) {
                    Button("Trail") { }
                }
            }
            .toolbar(removing: .leading)

        XCTAssertEqual(configured.toolbarConfiguration.visibility, .hidden)
        XCTAssertEqual(configured.toolbarConfiguration.visibilityTarget, .navigationBar)
        XCTAssertEqual(configured.toolbarConfiguration.removedPlacements, [.leading])
        XCTAssertEqual(configured.toolbarItems.count, 2)
        if case .leading = configured.toolbarItems[0].placement {} else {
            XCTFail("Expected first item to be .leading")
        }
        if case .trailing = configured.toolbarItems[1].placement {} else {
            XCTFail("Expected second item to be .trailing")
        }
    }

    func testToolbarItemsAndConfigurationComposeAcrossRepeatedToolbarCalls() {
        let configured = Text("Content")
            .toolbar {
                ToolbarItem(placement: .leading) {
                    Button("Lead") { }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .trailing) {
                    Button("Trail") { }
                }
            }
            .toolbar(removing: .leading)

        XCTAssertEqual(configured.toolbarConfiguration.visibility, .hidden)
        XCTAssertEqual(configured.toolbarConfiguration.visibilityTarget, .navigationBar)
        XCTAssertEqual(configured.toolbarConfiguration.removedPlacements, [.leading])
        XCTAssertEqual(configured.toolbarItems.count, 2)
        if case .leading = configured.toolbarItems[0].placement {} else {
            XCTFail("Expected first item to be .leading")
        }
        if case .trailing = configured.toolbarItems[1].placement {} else {
            XCTFail("Expected second item to be .trailing")
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
        XCTAssertEqual(dialog.titleVisibility, .automatic)
        XCTAssertEqual(dialog.message, "")
        XCTAssertEqual(dialog.buttons.count, 2)
        XCTAssertEqual(dialog.buttons[0].label, "Delete")
        XCTAssertEqual(dialog.buttons[0].role, .destructive)
        XCTAssertEqual(dialog.buttons[1].role, .cancel)
    }

    func testConfirmationDialogStoresTitleVisibility() {
        let dialog = Text("Content").confirmationDialog(
            "Archive?",
            isPresented: .constant(true),
            titleVisibility: .hidden,
            actions: [AlertButton("Archive", role: .destructive)]
        )

        XCTAssertTrue(dialog.isPresented.wrappedValue)
        XCTAssertEqual(dialog.title, "Archive?")
        XCTAssertEqual(dialog.titleVisibility, .hidden)
        XCTAssertEqual(dialog.message, "")
        XCTAssertEqual(dialog.buttons.count, 1)
    }

    func testConfirmationDialogStoresMessage() {
        let dialog = Text("Content").confirmationDialog(
            "Archive?",
            isPresented: .constant(true),
            titleVisibility: .visible,
            actions: [AlertButton("Cancel", role: .cancel)],
            message: "This will move the item to archived status."
        )

        XCTAssertEqual(dialog.titleVisibility, .visible)
        XCTAssertEqual(dialog.message, "This will move the item to archived status.")
        XCTAssertEqual(dialog.buttons.count, 1)
        XCTAssertEqual(dialog.buttons[0].role, .cancel)
    }

    func testDismissalConfirmationDialogConstruction() {
        let dialog = Text("Content").dismissalConfirmationDialog(
            "Discard changes?",
            shouldPresent: .constant(true),
            actions: [
                AlertButton("Discard", role: .destructive) { },
                AlertButton("Keep Editing", role: .cancel) { }
            ]
        )

        XCTAssertEqual(dialog.title, "Discard changes?")
        XCTAssertTrue(dialog.isPresented.wrappedValue)
        XCTAssertEqual(dialog.titleVisibility, .automatic)
        XCTAssertEqual(dialog.message, "")
        XCTAssertEqual(dialog.buttons.count, 2)
        XCTAssertEqual(dialog.buttons[0].label, "Discard")
        XCTAssertEqual(dialog.buttons[0].role, .destructive)
        XCTAssertEqual(dialog.buttons[1].label, "Keep Editing")
        XCTAssertEqual(dialog.buttons[1].role, .cancel)
        XCTAssertTrue(dialog.participatesInDismissalInterception)

        let config = dialog.dismissalConfirmationConfiguration
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.title, "Discard changes?")
        XCTAssertTrue(config?.isPresented.wrappedValue ?? false)
        XCTAssertEqual(config?.titleVisibility, .automatic)
        XCTAssertEqual(config?.message, "")
        XCTAssertEqual(config?.buttons.count, 2)
    }

    func testStandardConfirmationDialogDoesNotExposeDismissalInterceptionConfiguration() {
        let dialog = Text("Content").confirmationDialog(
            "Archive?",
            isPresented: .constant(true),
            actions: [AlertButton("Cancel", role: .cancel)]
        )

        XCTAssertFalse(dialog.participatesInDismissalInterception)
        XCTAssertNil(dialog.dismissalConfirmationConfiguration)
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
