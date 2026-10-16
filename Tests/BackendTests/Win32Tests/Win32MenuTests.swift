import XCTest
@testable import SwiftOpenUI
@testable import BackendWin32
import WinSDK
import CWin32

/// Flattened shape of an entry list, for comparing without closures.
private func shape(_ entries: [WinMenuEntry]) -> [String] {
    entries.map { entry in
        switch entry {
        case .item(let title, let isDisabled, _):
            return isDisabled ? "(\(title))" : title
        case .divider:
            return "---"
        case .submenu(let title, let isDisabled, let children):
            let name = isDisabled ? "(\(title))" : title
            return "\(name) > [\(shape(children).joined(separator: ", "))]"
        }
    }
}

private func menuString(_ hmenu: HMENU, at index: UINT) -> String {
    var buffer = [WCHAR](repeating: 0, count: 128)
    let length = GetMenuStringW(hmenu, index, &buffer, Int32(buffer.count), UINT(MF_BYPOSITION))
    return String(decoding: buffer.prefix(Int(length)), as: UTF16.self)
}

private var testWindow: HWND!
private let testClassName: [WCHAR] = Array("SwiftUIMenuTest".utf16) + [0]

private func testContext() -> RenderContext {
    let hInstance = GetModuleHandleW(nil)!
    if testWindow == nil {
        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.lpfnWndProc = DefWindowProcW
        wc.hInstance = hInstance
        testClassName.withUnsafeBufferPointer { ptr in
            wc.lpszClassName = ptr.baseAddress!
            RegisterClassExW(&wc)
            testWindow = CreateWindowExW(0, ptr.baseAddress!, nil, DWORD(WS_OVERLAPPEDWINDOW),
                                         0, 0, 400, 300, nil, nil, hInstance, nil)
        }
    }
    return RenderContext(parent: testWindow, hInstance: hInstance)
}

private func className(_ hwnd: HWND) -> String {
    var buffer = [WCHAR](repeating: 0, count: 64)
    let length = GetClassNameW(hwnd, &buffer, Int32(buffer.count))
    return String(decoding: buffer.prefix(Int(length)), as: UTF16.self)
}

final class Win32MenuTests: XCTestCase {
    override func tearDown() {
        if let parent = testWindow {
            while let child = GetWindow(parent, UINT(GW_CHILD)) { DestroyWindow(child) }
        }
        super.tearDown()
    }

    /// The default style renders a real button (focusable, with chrome).
    func testAutomaticStyleRendersButtonTrigger() throws {
        let hwnd = try XCTUnwrap(winRenderView(Menu("Actions") { Button("A") {} }, in: testContext()))
        XCTAssertEqual(className(hwnd), "SwiftUID2DSurface")
        XCTAssertNotEqual(win32_GetWindowLongPtrW(hwnd, GWL_STYLE) & LONG_PTR(WS_TABSTOP), 0)
    }

    /// .borderlessButton renders the label itself as the trigger.
    func testBorderlessStyleRendersPlainLabel() throws {
        let menu = Menu("Actions") { Button("A") {} }.menuStyle(.borderlessButton)
        let hwnd = try XCTUnwrap(winRenderView(menu, in: testContext()))
        XCTAssertEqual(className(hwnd), "Static")
        var buffer = [WCHAR](repeating: 0, count: 64)
        let length = GetWindowTextW(hwnd, &buffer, Int32(buffer.count))
        XCTAssertEqual(String(decoding: buffer.prefix(Int(length)), as: UTF16.self), "Actions")
    }

    func testButtonsDividersAndSubmenusFlattenInOrder() {
        let menu = Menu {
            Button("Use Source") {}
            Button("Use Destination") {}
            Divider()
            Menu("More") {
                Button("Keep Both") {}
            }
        } label: {
            Text("Resolve")
        }

        XCTAssertEqual(shape(winMenuEntries(from: menu.content)),
                       ["Use Source", "Use Destination", "---", "More > [Keep Both]"])
    }

    func testItemTitlesComeFromLabelViews() {
        let entries = winMenuEntries(from: Group {
            Button(action: {}) { Label("Copy", systemImage: "doc.on.doc") }
            Button(action: {}) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete")
                }
            }
        })
        XCTAssertEqual(shape(entries), ["Copy", "Delete"])
    }

    func testForEachAndConditionalsAreFlattened() {
        let names = ["A", "B"]
        let showExtra = true
        let entries = winMenuEntries(from: Group {
            ForEach(names, id: \.self) { name in Button(name) {} }
            if showExtra { Button("Extra") {} }
        })
        XCTAssertEqual(shape(entries), ["A", "B", "Extra"])
    }

    func testDisabledPropagatesToItemsAndSubmenus() {
        let entries = winMenuEntries(from: Group {
            Button("On") {}
            Button("Off") {}.disabled(true)
            Menu("Sub") { Button("Inner") {} }.disabled(true)
        })
        XCTAssertEqual(shape(entries), ["On", "(Off)", "(Sub) > [(Inner)]"])
    }

    func testSectionsAreSeparatedAndDividersCollapse() {
        let entries = winMenuEntries(from: Group {
            Section { Button("One") {} }
            Divider()
            Section(header: "Two") { Button("Two-a") {} }
            Divider()
        })
        XCTAssertEqual(shape(entries), ["One", "---", "(Two)", "Two-a"])
    }

    func testActionsRunFromEntries() {
        var fired: [String] = []
        let entries = winMenuEntries(from: Group {
            Button("First") { fired.append("first") }
            Button("Second") { fired.append("second") }
        })
        for case .item(_, _, let action) in entries { action() }
        XCTAssertEqual(fired, ["first", "second"])
    }

    func testPopupMenuMirrorsEntries() throws {
        var chosen = ""
        let entries = winMenuEntries(from: Group {
            Button("Alpha") { chosen = "alpha" }
            Divider()
            Button("Beta") {}.disabled(true)
            Menu("Sub") { Button("Gamma") { chosen = "gamma" } }
        })
        let hmenu = try XCTUnwrap(CreatePopupMenu())
        defer { DestroyMenu(hmenu) }
        var nextID: UINT = 1
        var actions: [UINT: () -> Void] = [:]
        winBuildPopupMenu(hmenu, entries: entries, nextID: &nextID, actions: &actions)

        XCTAssertEqual(GetMenuItemCount(hmenu), 4)
        XCTAssertEqual(menuString(hmenu, at: 0), "Alpha")
        XCTAssertNotEqual(GetMenuState(hmenu, 1, UINT(MF_BYPOSITION)) & UINT(MF_SEPARATOR), 0)
        XCTAssertNotEqual(GetMenuState(hmenu, 2, UINT(MF_BYPOSITION)) & UINT(MF_GRAYED), 0)
        let sub = try XCTUnwrap(GetSubMenu(hmenu, 3))
        XCTAssertEqual(menuString(sub, at: 0), "Gamma")

        // Command ids map back to the right actions, submenus included.
        actions[GetMenuItemID(sub, 0)]?()
        XCTAssertEqual(chosen, "gamma")
        actions[GetMenuItemID(hmenu, 0)]?()
        XCTAssertEqual(chosen, "alpha")
    }
}
