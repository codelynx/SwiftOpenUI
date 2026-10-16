import XCTest
@testable import SwiftOpenUI
@testable import BackendWin32
import WinSDK
import CWin32
import CWin32Bridge

// MARK: - Test harness

private var testWindow: HWND!
private var testHInstance: HINSTANCE!

private let testClassName: [WCHAR] = Array("SwiftUIOutlineTest".utf16) + [0]
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

private struct Node: Identifiable {
    let id: String
    var children: [Node]?
}

/// The first outline tree container under `parent`, depth-first.
private func findOutlineTree(in parent: HWND) -> HWND? {
    var child = GetWindow(parent, UINT(GW_CHILD))
    while let c = child {
        var buffer = [WCHAR](repeating: 0, count: 64)
        if GetClassNameW(c, &buffer, Int32(buffer.count)) > 0,
           String(decodingCString: buffer, as: UTF16.self) == "SwiftUIOutlineTree" {
            return c
        }
        if let found = findOutlineTree(in: c) { return found }
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
    return nil
}

private func model(of tree: HWND) -> Win32OutlineModel? {
    let ud = win32_GetWindowLongPtrW(tree, GWLP_USERDATA)
    guard ud != 0 else { return nil }
    return Unmanaged<Win32OutlineModel>
        .fromOpaque(UnsafeMutableRawPointer(bitPattern: Int(ud))!)
        .takeUnretainedValue()
}

// MARK: - Tests

final class Win32OutlineTreeTests: XCTestCase {
    override func tearDown() {
        cleanupChildren()
        super.tearDown()
    }

    private func makeHost(_ nodes: @escaping () -> [Node]) -> Win32ViewHost {
        let ctx = testContext()
        let host = Win32ViewHost(
            context: ctx,
            buildBody: { ctx in
                winRenderView(
                    OutlineGroup(nodes(), id: \.id, children: \.children) { Text($0.id) },
                    in: ctx
                )
            },
            describeBody: {
                winDescribeView(OutlineGroup(nodes(), id: \.id, children: \.children) { Text($0.id) })
            }
        )
        let child = host.buildBody(RenderContext(parent: host.container, hInstance: ctx.hInstance))
        if let c = child { host.addChild(c) }
        return host
    }

    /// An ancestor rebuild re-creates the tree with a fresh model; the
    /// expanded folders must come back instead of collapsing to the roots.
    func testExpansionSurvivesHostRebuild() throws {
        let nodes = [
            Node(id: "a", children: [Node(id: "a1", children: [Node(id: "a1x")])]),
            Node(id: "b", children: [Node(id: "b1")]),
        ]
        let host = makeHost { nodes }

        let tree = try XCTUnwrap(findOutlineTree(in: host.container))
        let before = try XCTUnwrap(model(of: tree))
        before.toggle("0") // a
        before.toggle("1") // a/a1

        host.rebuild()

        let newTree = try XCTUnwrap(findOutlineTree(in: host.container))
        let after = try XCTUnwrap(model(of: newTree))
        XCTAssertFalse(after === before, "rebuild should have re-created the tree")
        XCTAssertEqual(after.expandedIdentityPaths, [["a"], ["a", "a1"]])
        XCTAssertEqual(after.visibleKeys().count, 4, "a, a1, a1x, b")
    }

    /// Expansion is keyed by id path, not position: when the data changes
    /// (a filter drops an earlier row), the same node stays expanded even
    /// though its positional key shifted.
    func testExpansionFollowsIdentityWhenDataChanges() throws {
        var nodes = [
            Node(id: "a", children: [Node(id: "a1")]),
            Node(id: "b", children: [Node(id: "b1")]),
        ]
        let host = makeHost { nodes }

        let tree = try XCTUnwrap(findOutlineTree(in: host.container))
        try XCTUnwrap(model(of: tree)).toggle("2") // b

        nodes.removeFirst()
        host.rebuild()

        let after = try XCTUnwrap(model(of: XCTUnwrap(findOutlineTree(in: host.container))))
        XCTAssertEqual(after.expandedIdentityPaths, [["b"]])
        XCTAssertEqual(after.expanded, ["0"], "b is now the first node")
    }

    /// The WM_DPICHANGED path saves state while the old tree still holds
    /// old-DPI pixels, and may pass the tree itself as the root. Scroll is
    /// carried in points, so it lands at the same logical offset.
    func testSnapshotCarriesScrollInPointsAcrossScale() throws {
        let nodes = (0..<40).map { Node(id: "n\($0)", children: [Node(id: "c\($0)")]) }
        let group = OutlineGroup(nodes, id: \.id, children: \.children) { Text($0.id) }
        let ctx = testContext()

        let oldTree = try XCTUnwrap(winRenderView(group, in: ctx))
        let old = try XCTUnwrap(model(of: oldTree))
        old.toggle("2") // n1
        old.layoutScale = 2 // pretend it was laid out at 200%
        old.scrollY = 200   // = 100pt
        let snapshots = saveOutlineTreeStates(in: oldTree)
        XCTAssertEqual(snapshots.count, 1, "the root itself is the tree")
        DestroyWindow(oldTree)

        let newTree = try XCTUnwrap(winRenderView(group, in: ctx))
        restoreOutlineTreeStates(snapshots, in: newTree)
        let new = try XCTUnwrap(model(of: newTree))
        XCTAssertEqual(new.expandedIdentityPaths, [["n1"]])
        XCTAssertEqual(new.scrollY, px(100, for: newTree))
    }

    /// A node that no longer exists after the rebuild is dropped, not
    /// mapped onto whatever now sits at its old position.
    func testRemovedNodeExpansionIsDropped() throws {
        var nodes = [
            Node(id: "a", children: [Node(id: "a1")]),
            Node(id: "b", children: [Node(id: "b1")]),
        ]
        let host = makeHost { nodes }

        let tree = try XCTUnwrap(findOutlineTree(in: host.container))
        try XCTUnwrap(model(of: tree)).toggle("0") // a

        nodes.removeFirst()
        host.rebuild()

        let after = try XCTUnwrap(model(of: XCTUnwrap(findOutlineTree(in: host.container))))
        XCTAssertTrue(after.expanded.isEmpty)
    }

    /// A row with a Spacer fills the list width (so a trailing element sits
    /// at the right edge) and follows resizes; a plain row keeps its natural
    /// width.
    func testFlexibleRowsStretchToListWidth() throws {
        let nodes = [Node(id: "flex"), Node(id: "plain")]
        let group = OutlineGroup(nodes, id: \.id, children: \.children) { node in
            if node.id == "flex" {
                AnyView(HStack { Text(node.id); Spacer(); Text("(3)") })
            } else {
                AnyView(Text(node.id))
            }
        }
        let tree = try XCTUnwrap(winRenderView(group, in: testContext()))
        let m = try XCTUnwrap(model(of: tree))
        XCTAssertEqual(m.flexibleRows.count, 1, "only the Spacer row is flexible")
        let row = m.flexibleRows[0]

        func width(_ hwnd: HWND) -> Int32 {
            var r = RECT(); GetWindowRect(hwnd, &r); return r.right - r.left
        }
        func rightEdge(_ hwnd: HWND) -> Int32 {
            var r = RECT(); GetWindowRect(hwnd, &r); return r.right
        }

        for listWidth: Int32 in [360, 500, 300] {
            SetWindowPos(tree, nil, 0, 0, listWidth, 200, UINT(SWP_NOZORDER | SWP_NOMOVE))
            let expected = max(row.naturalWidth, listWidth - row.x)
            XCTAssertEqual(width(row.body), expected, "at list width \(listWidth)")

            // The trailing "(3)" is pushed to the row's right edge.
            var last: HWND?
            var child = GetWindow(row.body, UINT(GW_CHILD))
            while let c = child { last = c; child = GetWindow(c, UINT(GW_HWNDNEXT)) }
            XCTAssertEqual(rightEdge(try XCTUnwrap(last)), rightEdge(row.body))
        }
    }
}
