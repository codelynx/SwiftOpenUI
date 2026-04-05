import XCTest
@testable import SwiftOpenUI
@testable import BackendWin32
import WinSDK
import CWin32

// MARK: - Test harness

private var testWindow: HWND!
private var testHInstance: HINSTANCE!

private let testClassName: [WCHAR] = Array("SwiftUIClipTest".utf16) + [0]
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

// MARK: - Tests

final class Win32ClipShapeTests: XCTestCase {
    override func tearDown() {
        cleanupChildren()
        super.tearDown()
    }

    // MARK: - ClippedView (.clipped())

    func testClippedViewRendersHWND() {
        let ctx = testContext()
        let view = Text("Hello")
            .clipped()
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, ".clipped() should render an HWND")
    }

    func testClippedViewHasRegion() {
        let ctx = testContext()
        let view = Text("Hello")
            .frame(width: 60, height: 20)
            .clipped()
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        // GetWindowRgn returns SIMPLEREGION/COMPLEXREGION if a region is set
        var rgn = RECT()
        let result = GetWindowRgnBox(hwnd!, &rgn)
        XCTAssertTrue(result != 0, ".clipped() should set a window region")
    }

    // MARK: - ClipShapeView (.clipShape())

    func testClipShapeCircleRendersHWND() {
        let ctx = testContext()
        let view = Text("Hello")
            .frame(width: 50, height: 50)
            .clipShape(Circle())
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, ".clipShape(Circle()) should render an HWND")
    }

    func testClipShapeCircleHasRegion() {
        let ctx = testContext()
        let view = Text("Hello")
            .frame(width: 50, height: 50)
            .clipShape(Circle())
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        var rgn = RECT()
        let result = GetWindowRgnBox(hwnd!, &rgn)
        XCTAssertTrue(result != 0, ".clipShape(Circle()) should set a window region")
    }

    func testClipShapeRoundedRectangleRendersHWND() {
        let ctx = testContext()
        let view = Text("Hello")
            .frame(width: 80, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, ".clipShape(RoundedRectangle) should render an HWND")
    }

    func testClipShapeCapsuleRendersHWND() {
        let ctx = testContext()
        let view = Text("Hello")
            .frame(width: 80, height: 30)
            .clipShape(Capsule())
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testClipShapeEllipseRendersHWND() {
        let ctx = testContext()
        let view = Text("Hello")
            .frame(width: 60, height: 40)
            .clipShape(Ellipse())
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testClipShapeRectangleRendersHWND() {
        let ctx = testContext()
        let view = Text("Hello")
            .frame(width: 60, height: 20)
            .clipShape(SwiftOpenUI.Rectangle())
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)
    }

    func testClipShapeRectangleHasRegion() {
        let ctx = testContext()
        let view = Text("Hello")
            .frame(width: 60, height: 20)
            .clipShape(SwiftOpenUI.Rectangle())
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        var rgn = RECT()
        let result = GetWindowRgnBox(hwnd!, &rgn)
        XCTAssertTrue(result != 0, ".clipShape(Rectangle()) should set a window region")
    }
}
