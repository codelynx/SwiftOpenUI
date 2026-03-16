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

    // MARK: - WinRenderable conformance

    func testTextConformsToWinRenderable() {
        XCTAssertTrue(Text("x") is WinRenderable)
    }

    func testButtonConformsToWinRenderable() {
        XCTAssertTrue(Button("x", action: {}) is WinRenderable)
    }

    func testSpacerConformsToWinRenderable() {
        XCTAssertTrue(Spacer() is WinRenderable)
    }

    func testDividerConformsToWinRenderable() {
        XCTAssertTrue(Divider() is WinRenderable)
    }

    func testEmptyViewConformsToWinRenderable() {
        XCTAssertTrue(EmptyView() is WinRenderable)
    }

    func testContainerViewsConformToWinRenderable() {
        XCTAssertTrue(VStack { Text("a") } is WinRenderable)
        XCTAssertTrue(HStack { Text("a") } is WinRenderable)
        XCTAssertTrue(ZStack { Text("a") } is WinRenderable)
    }

    func testModifierViewsConformToWinRenderable() {
        XCTAssertTrue(Text("a").padding() is WinRenderable)
        XCTAssertTrue(Text("a").frame(width: 100) is WinRenderable)
        XCTAssertTrue(Text("a").foregroundColor(.blue) is WinRenderable)
        XCTAssertTrue(Text("a").background(.red) is WinRenderable)
        XCTAssertTrue(Text("a").font(.title) is WinRenderable)
        XCTAssertTrue(Text("a").border(.black) is WinRenderable)
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
        let host = Win32ViewHost(context: ctx, buildBody: { ctx in
            winRenderView(Text("test"), in: ctx)
        })

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

    // MARK: - Win32Backend

    func testWin32BackendConformsToRenderBackend() {
        XCTAssertTrue(Win32Backend() is RenderBackend)
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
}
