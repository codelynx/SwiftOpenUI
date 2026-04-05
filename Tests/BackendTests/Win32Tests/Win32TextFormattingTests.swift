import XCTest
@testable import SwiftOpenUI
@testable import BackendWin32
import WinSDK
import CWin32

// MARK: - Test harness

private var testWindow: HWND!
private var testHInstance: HINSTANCE!

private let testClassName: [WCHAR] = Array("SwiftUITextFmtTest".utf16) + [0]
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

/// Find the first Static control in an HWND tree (DFS).
private func findStatic(in hwnd: HWND) -> HWND? {
    if className(of: hwnd) == "Static" {
        let style = win32_GetWindowLongPtrW(hwnd, GWL_STYLE)
        if style & LONG_PTR(SS_NOTIFY) != 0 {
            return hwnd
        }
    }
    var child = GetWindow(hwnd, UINT(GW_CHILD))
    while let c = child {
        if let found = findStatic(in: c) { return found }
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
    return nil
}

// MARK: - Tests

final class Win32TextFormattingTests: XCTestCase {
    override func tearDown() {
        cleanupChildren()
        super.tearDown()
    }

    // MARK: - LineLimitView

    func testLineLimitOneSingleLine() {
        let ctx = testContext()
        let view = Text("Hello world")
            .lineLimit(1)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        guard let label = findStatic(in: hwnd!) else {
            XCTFail("Should find a Static label"); return
        }

        let style = win32_GetWindowLongPtrW(label, GWL_STYLE)
        // lineLimit(1) should keep SS_LEFTNOWORDWRAP (no wrapping)
        XCTAssertTrue(style & LONG_PTR(SS_LEFTNOWORDWRAP) != 0,
            "lineLimit(1) should preserve SS_LEFTNOWORDWRAP")
    }

    func testLineLimitNilEnablesWrapping() {
        let ctx = testContext()
        let view = Text("Hello world this is a long text")
            .lineLimit(nil)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        guard let label = findStatic(in: hwnd!) else {
            XCTFail("Should find a Static label"); return
        }

        let style = win32_GetWindowLongPtrW(label, GWL_STYLE)
        // lineLimit(nil) should remove SS_LEFTNOWORDWRAP and use SS_LEFT
        XCTAssertTrue(style & LONG_PTR(SS_LEFTNOWORDWRAP) == 0,
            "lineLimit(nil) should remove SS_LEFTNOWORDWRAP")
    }

    func testLineLimitSpecificNumber() {
        let ctx = testContext()
        let view = Text("Line one and more text that should wrap")
            .lineLimit(2)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        guard let label = findStatic(in: hwnd!) else {
            XCTFail("Should find a Static label"); return
        }

        let style = win32_GetWindowLongPtrW(label, GWL_STYLE)
        // lineLimit(2) should enable wrapping
        XCTAssertTrue(style & LONG_PTR(SS_LEFTNOWORDWRAP) == 0,
            "lineLimit(2) should remove SS_LEFTNOWORDWRAP for wrapping")
    }

    // MARK: - TruncationModeView

    func testTruncationModeTail() {
        let ctx = testContext()
        let view = Text("Hello")
            .truncationMode(.tail)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        guard let label = findStatic(in: hwnd!) else {
            XCTFail("Should find a Static label"); return
        }

        let style = win32_GetWindowLongPtrW(label, GWL_STYLE)
        // SS_ENDELLIPSIS = 0x4000
        XCTAssertTrue(style & LONG_PTR(0x4000) != 0,
            "truncationMode(.tail) should set SS_ENDELLIPSIS")
    }

    func testTruncationModeMiddle() {
        let ctx = testContext()
        let view = Text("Hello")
            .truncationMode(.middle)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        guard let label = findStatic(in: hwnd!) else {
            XCTFail("Should find a Static label"); return
        }

        let style = win32_GetWindowLongPtrW(label, GWL_STYLE)
        // SS_PATHELLIPSIS = 0x8000
        XCTAssertTrue(style & LONG_PTR(0x8000) != 0,
            "truncationMode(.middle) should set SS_PATHELLIPSIS")
    }

    func testTruncationModeHeadFallsBackToTail() {
        let ctx = testContext()
        let view = Text("Hello")
            .truncationMode(.head)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        guard let label = findStatic(in: hwnd!) else {
            XCTFail("Should find a Static label"); return
        }

        let style = win32_GetWindowLongPtrW(label, GWL_STYLE)
        // SS_ENDELLIPSIS = 0x4000 (fallback for head)
        XCTAssertTrue(style & LONG_PTR(0x4000) != 0,
            "truncationMode(.head) should fall back to SS_ENDELLIPSIS")
    }

    // MARK: - MultilineTextAlignmentView

    func testMultilineAlignmentCenter() {
        let ctx = testContext()
        let view = Text("Hello")
            .multilineTextAlignment(.center)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        guard let label = findStatic(in: hwnd!) else {
            XCTFail("Should find a Static label"); return
        }

        let style = win32_GetWindowLongPtrW(label, GWL_STYLE)
        // SS_CENTER = 1, check low nibble
        XCTAssertEqual(style & LONG_PTR(0x3), LONG_PTR(SS_CENTER),
            "multilineTextAlignment(.center) should set SS_CENTER")
    }

    func testMultilineAlignmentTrailing() {
        let ctx = testContext()
        let view = Text("Hello")
            .multilineTextAlignment(.trailing)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        guard let label = findStatic(in: hwnd!) else {
            XCTFail("Should find a Static label"); return
        }

        let style = win32_GetWindowLongPtrW(label, GWL_STYLE)
        // SS_RIGHT = 2
        XCTAssertEqual(style & LONG_PTR(0x3), LONG_PTR(SS_RIGHT),
            "multilineTextAlignment(.trailing) should set SS_RIGHT")
    }

    func testMultilineAlignmentLeading() {
        let ctx = testContext()
        let view = Text("Hello")
            .multilineTextAlignment(.leading)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        guard let label = findStatic(in: hwnd!) else {
            XCTFail("Should find a Static label"); return
        }

        let style = win32_GetWindowLongPtrW(label, GWL_STYLE)
        // SS_LEFT = 0
        XCTAssertEqual(style & LONG_PTR(0x3), LONG_PTR(SS_LEFT),
            "multilineTextAlignment(.leading) should set SS_LEFT")
    }

    // MARK: - Modifier composition

    func testLineLimitOneOverridesInnerWrapping() {
        let ctx = testContext()

        // Render lineLimit(1) alone to get reference height
        let refView = Text("Hello world this is long text")
            .lineLimit(1)
        let refHwnd = winRenderView(refView, in: ctx)!
        let refLabel = findStatic(in: refHwnd)!
        var refRect = RECT()
        GetWindowRect(refLabel, &refRect)
        let singleLineH = refRect.bottom - refRect.top
        DestroyWindow(refHwnd)

        // Inner lineLimit(nil) enables wrapping, outer lineLimit(1) should override
        let view = Text("Hello world this is long text")
            .lineLimit(nil)
            .lineLimit(1)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        guard let label = findStatic(in: hwnd!) else {
            XCTFail("Should find a Static label"); return
        }

        let style = win32_GetWindowLongPtrW(label, GWL_STYLE)
        XCTAssertTrue(style & LONG_PTR(SS_LEFTNOWORDWRAP) != 0,
            "Outer lineLimit(1) should override inner lineLimit(nil)")

        // Height should match lineLimit(1) alone
        var labelRect = RECT()
        GetWindowRect(label, &labelRect)
        let labelH = labelRect.bottom - labelRect.top
        XCTAssertEqual(labelH, singleLineH,
            "Composed lineLimit(nil).lineLimit(1) height should match lineLimit(1) alone")
    }

    func testTruncationModeComposition() {
        let ctx = testContext()
        // Inner .middle sets 0x8000, outer .tail should clear it and set 0x4000
        let view = Text("Hello")
            .truncationMode(.middle)
            .truncationMode(.tail)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd)

        guard let label = findStatic(in: hwnd!) else {
            XCTFail("Should find a Static label"); return
        }

        let style = win32_GetWindowLongPtrW(label, GWL_STYLE)
        XCTAssertTrue(style & LONG_PTR(0x4000) != 0,
            "Outer .tail should set SS_ENDELLIPSIS")
        XCTAssertTrue(style & LONG_PTR(0x8000) == 0,
            "Outer .tail should clear inner SS_PATHELLIPSIS")
    }

    // MARK: - LineSpacingView (pass-through)

    func testLineSpacingPassesThrough() {
        let ctx = testContext()
        let view = Text("Hello")
            .lineSpacing(8.0)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "lineSpacing should pass through and render content")

        let label = findStatic(in: hwnd!)
        XCTAssertNotNil(label, "lineSpacing should preserve the Static label")
    }

    // MARK: - Non-text content

    func testModifierOnNonTextPassesThrough() {
        let ctx = testContext()
        // Button is not a Static text control — modifier should pass through
        let view = Button("Click") {}
            .truncationMode(.tail)
        let hwnd = winRenderView(view, in: ctx)
        XCTAssertNotNil(hwnd, "Modifier on non-text content should still render")
    }
}
