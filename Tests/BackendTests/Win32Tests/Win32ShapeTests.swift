import XCTest
@testable import SwiftOpenUI
@testable import BackendWin32
import WinSDK
import CWin32

// MARK: - Test harness

private var testWindow: HWND!
private var testHInstance: HINSTANCE!

private let testClassName: [WCHAR] = Array("SwiftUIShapeTest".utf16) + [0]
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

// MARK: - Tests

final class Win32ShapeTests: XCTestCase {
    override func tearDown() {
        cleanupChildren()
        super.tearDown()
    }

    // MARK: - Bare shapes render

    func testCircleRendersHWND() {
        let ctx = testContext()
        let hwnd = winRenderView(Circle(), in: ctx)
        XCTAssertNotNil(hwnd, "Circle should render an HWND")
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface",
            "Circle should render as D2D surface")
    }

    func testRectangleRendersHWND() {
        let ctx = testContext()
        let hwnd = winRenderView(SwiftOpenUI.Rectangle(), in: ctx)
        XCTAssertNotNil(hwnd, "Rectangle should render an HWND")
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface")
    }

    func testRoundedRectangleRendersHWND() {
        let ctx = testContext()
        let hwnd = winRenderView(RoundedRectangle(cornerRadius: 10), in: ctx)
        XCTAssertNotNil(hwnd, "RoundedRectangle should render an HWND")
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface")
    }

    func testCapsuleRendersHWND() {
        let ctx = testContext()
        let hwnd = winRenderView(Capsule(), in: ctx)
        XCTAssertNotNil(hwnd, "Capsule should render an HWND")
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface")
    }

    func testEllipseRendersHWND() {
        let ctx = testContext()
        let hwnd = winRenderView(Ellipse(), in: ctx)
        XCTAssertNotNil(hwnd, "Ellipse should render an HWND")
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface")
    }

    // MARK: - FilledShape

    func testFilledShapeRendersHWND() {
        let ctx = testContext()
        let hwnd = winRenderView(Circle().fill(.red), in: ctx)
        XCTAssertNotNil(hwnd, "FilledShape should render an HWND")
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface")
    }

    func testFilledRectangleRendersHWND() {
        let ctx = testContext()
        let hwnd = winRenderView(SwiftOpenUI.Rectangle().fill(.blue), in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface")
    }

    // MARK: - StrokedShape

    func testStrokedShapeRendersHWND() {
        let ctx = testContext()
        let hwnd = winRenderView(Circle().stroke(.red, lineWidth: 2), in: ctx)
        XCTAssertNotNil(hwnd, "StrokedShape should render an HWND")
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface")
    }

    func testStrokedRectangleRendersHWND() {
        let ctx = testContext()
        let hwnd = winRenderView(SwiftOpenUI.Rectangle().stroke(.green, lineWidth: 3), in: ctx)
        XCTAssertNotNil(hwnd)
        XCTAssertEqual(className(of: hwnd!), "SwiftUID2DSurface")
    }

    // MARK: - Bare shape default color
    //
    // Bare shapes default to filled black. `.foregroundColor()` propagation
    // to shape surfaces is not yet implemented (requires core environment
    // key for foreground color — coordinator-owned). This test documents
    // the current behavior.

    func testBareShapeRendersWithoutCrash() {
        let ctx = testContext()
        // Bare shape with foregroundColor — should not crash,
        // though the color is not yet propagated to the D2D surface.
        let view = Circle()
            .foregroundColor(.red)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Bare shape with foregroundColor should render")
    }

    // MARK: - Shape with .frame()

    func testShapeWithFrameProducesCorrectDimensions() {
        let ctx = testContext()
        let view = Circle()
            .frame(width: 50, height: 50)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        var rect = RECT()
        GetWindowRect(hwnd!, &rect)
        let w = rect.right - rect.left
        let h = rect.bottom - rect.top
        XCTAssertEqual(w, 50, "Frame should constrain width to 50")
        XCTAssertEqual(h, 50, "Frame should constrain height to 50")
    }

    func testFilledShapeWithFrame() {
        let ctx = testContext()
        let view = RoundedRectangle(cornerRadius: 8)
            .fill(.red)
            .frame(width: 80, height: 40)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        var rect = RECT()
        GetWindowRect(hwnd!, &rect)
        let w = rect.right - rect.left
        let h = rect.bottom - rect.top
        XCTAssertEqual(w, 80)
        XCTAssertEqual(h, 40)
    }
}
