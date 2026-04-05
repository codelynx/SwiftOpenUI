import XCTest
@testable import SwiftOpenUI
@testable import BackendWin32
import WinSDK
import CWin32

// MARK: - Test harness

private var testWindow: HWND!
private var testHInstance: HINSTANCE!

private let testClassName: [WCHAR] = Array("SwiftUIStyleTest".utf16) + [0]
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

private func cleanupChildren() {
    guard let parent = testWindow else { return }
    while let child = GetWindow(parent, UINT(GW_CHILD)) {
        DestroyWindow(child)
    }
}

private func className(of hwnd: HWND) -> String {
    var buffer: [WCHAR] = Array(repeating: 0, count: 64)
    _ = GetClassNameW(hwnd, &buffer, Int32(buffer.count))
    return String(decodingCString: buffer, as: UTF16.self)
}

/// Find the first Edit control in an HWND tree (DFS).
private func findEdit(in hwnd: HWND) -> HWND? {
    if className(of: hwnd) == "Edit" { return hwnd }
    var child = GetWindow(hwnd, UINT(GW_CHILD))
    while let c = child {
        if let found = findEdit(in: c) { return found }
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
    return nil
}

// MARK: - Tests

final class Win32StyleTests: XCTestCase {
    override func tearDown() {
        cleanupChildren()
        super.tearDown()
    }

    // MARK: - ButtonStyleModifier

    func testButtonStyleModifierSetsEnvironment() {
        let ctx = testContext()
        // .buttonStyle(.plain) should propagate through environment
        let view = Button("Click") {}
            .buttonStyle(.plain)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Button with .buttonStyle(.plain) should render")
    }

    func testButtonStyleBorderedRendersHWND() {
        let ctx = testContext()
        let view = Button("Click") {}
            .buttonStyle(.bordered)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface",
            "Bordered button should be D2D surface")
    }

    func testButtonStyleBorderedProminentRendersHWND() {
        let ctx = testContext()
        let view = Button("Click") {}
            .buttonStyle(.borderedProminent)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface")
    }

    func testButtonStylePlainRendersHWND() {
        let ctx = testContext()
        let view = Button("Click") {}
            .buttonStyle(.plain)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    // MARK: - ToggleStyleModifier

    func testToggleStyleModifierSetsEnvironment() {
        let ctx = testContext()
        let view = Toggle("Test", isOn: .constant(true))
            .toggleStyle(.checkbox)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Toggle with .toggleStyle(.checkbox) should render")
    }

    func testToggleStyleSwitchFallsBackToCheckbox() {
        let ctx = testContext()
        // .switch falls back to checkbox on Win32 (no native switch control)
        let view = Toggle("Test", isOn: .constant(false))
            .toggleStyle(.switch)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Toggle with .toggleStyle(.switch) should render")
    }

    // MARK: - TextFieldStyleModifier

    func testTextFieldStylePlainNoBorder() {
        let ctx = testContext()
        let view = TextField("Placeholder", text: .constant("Hello"))
            .textFieldStyle(.plain)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // The modifier wraps the TextField, so find the Edit control
        guard let edit = findEdit(in: hwnd!) else {
            XCTFail("Should find an Edit control"); return
        }
        let style = win32_GetWindowLongPtrW(edit, GWL_STYLE)
        XCTAssertEqual(style & LONG_PTR(WS_BORDER), 0,
            ".textFieldStyle(.plain) should remove WS_BORDER")
    }

    func testTextFieldStyleRoundedBorderRendersHWND() {
        let ctx = testContext()
        let view = TextField("Placeholder", text: .constant("Hello"))
            .textFieldStyle(.roundedBorder)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, ".textFieldStyle(.roundedBorder) should render")

        let edit = findEdit(in: hwnd!)
        XCTAssertNotNil(edit, "Should find an Edit control inside")
    }

    func testTextFieldStyleAutomaticRendersHWND() {
        let ctx = testContext()
        let view = TextField("Placeholder", text: .constant("Hello"))
            .textFieldStyle(.automatic)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, ".textFieldStyle(.automatic) should render")

        let edit = findEdit(in: hwnd!)
        XCTAssertNotNil(edit, "Should find an Edit control inside")
    }

    // MARK: - Style propagation through containers

    func testStylePropagatesThroughVStack() {
        let ctx = testContext()
        let view = VStack {
            TextField("Field", text: .constant(""))
        }
        .textFieldStyle(.plain)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Style should propagate through containers")
    }

    // MARK: - SecureField style

    func testSecureFieldStylePlainNoBorder() {
        let ctx = testContext()
        let view = SecureField("Password", text: .constant("secret"))
            .textFieldStyle(.plain)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        guard let edit = findEdit(in: hwnd!) else {
            XCTFail("Should find an Edit control"); return
        }
        let style = win32_GetWindowLongPtrW(edit, GWL_STYLE)
        XCTAssertEqual(style & LONG_PTR(WS_BORDER), 0,
            "SecureField with .textFieldStyle(.plain) should remove WS_BORDER")
    }

    // MARK: - TextEditor style

    func testTextEditorStylePlainNoBorder() {
        let ctx = testContext()
        let view = TextEditor(text: .constant("Hello"))
            .textFieldStyle(.plain)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        guard let edit = findEdit(in: hwnd!) else {
            XCTFail("Should find an Edit control"); return
        }
        let style = win32_GetWindowLongPtrW(edit, GWL_STYLE)
        XCTAssertEqual(style & LONG_PTR(WS_BORDER), 0,
            "TextEditor with .textFieldStyle(.plain) should remove WS_BORDER")
    }
}
