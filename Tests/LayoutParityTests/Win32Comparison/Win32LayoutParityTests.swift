/// Win32 layout parity tests.
///
/// Renders the same layout scenarios using SwiftOpenUI + Win32 backend,
/// captures HWND tree positions, and compares against macOS reference fixtures.
///
/// Run on Windows:
///   swift test --filter Win32LayoutParityTests

#if os(Windows)
import XCTest
import WinSDK
import CWin32
import CWin32Bridge
import SwiftOpenUI
@testable import BackendWin32
import LayoutParityShared

// MARK: - Test Window Setup

private var testWindow: HWND!
private var testHInstance: HINSTANCE!

private func ensureTestWindow() {
    guard testWindow == nil else { return }
    testHInstance = GetModuleHandleW(nil)

    let className = "Win32ParityTestWindow"
    className.withCString(encodedAs: UTF16.self) { ptr in
        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.lpfnWndProc = DefWindowProcW
        wc.hInstance = testHInstance
        wc.lpszClassName = ptr
        RegisterClassExW(&wc)

        testWindow = CreateWindowExW(
            0, ptr, nil,
            DWORD(WS_OVERLAPPEDWINDOW),
            0, 0, 400, 600,
            nil, nil, testHInstance, nil
        )
    }
}

private func cleanupChildren() {
    guard let parent = testWindow else { return }
    while let child = GetWindow(parent, UINT(GW_CHILD)) {
        DestroyWindow(child)
    }
}

private func testContext() -> RenderContext {
    ensureTestWindow()
    return RenderContext(parent: testWindow, hInstance: testHInstance)
}

// MARK: - Tests

final class Win32LayoutParityTests: XCTestCase {

    private var fixturesDir: URL {
        let thisFile = URL(fileURLWithPath: #filePath)
        let parityDir = thisFile
            .deletingLastPathComponent()  // Win32Comparison/
            .deletingLastPathComponent()  // LayoutParityTests/
        return parityDir.appendingPathComponent("Fixtures")
    }

    override func tearDown() {
        cleanupChildren()
        super.tearDown()
    }

    // MARK: - Compare All Scenarios

    func testCompareAllScenariosAgainstReference() throws {
        var passed: [(String, LeafComparisonResult)] = []
        var failed: [(String, LeafComparisonResult)] = []
        var skipped: [String] = []
        var errors: [(String, Error)] = []

        for (name, view) in allLayoutScenarios {
            let fixtureURL = fixturesDir.appendingPathComponent("\(name).json")
            guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
                skipped.append(name)
                continue
            }

            do {
                let reference = try readSnapshot(from: fixtureURL)
                let actual = captureWin32Layout(
                    scenario: name,
                    view: view,
                    width: parityRootWidth,
                    height: parityRootHeight
                )

                let result = compareLeaves(
                    reference: reference,
                    actual: actual,
                    tolerances: ParityTolerances()
                )

                if result.passed {
                    passed.append((name, result))
                } else {
                    failed.append((name, result))
                }

                // Print normalized leaves for comparison
                let refLeaves = sortLeaves(normalizeLeaves(
                    sortLeaves(extractLeaves(from: reference.root))
                ))
                let actLeaves = sortLeaves(normalizeLeaves(
                    sortLeaves(extractLeaves(from: actual.root))
                ))

                print("=== \(name) ===")
                print("macOS (normalized):")
                for leaf in refLeaves { print("  \(leaf)") }
                print("Win32 (normalized):")
                for leaf in actLeaves { print("  \(leaf)") }
                if !result.passed {
                    print(result)
                } else {
                    print("PASS")
                }
                print()

                cleanupChildren()
            } catch {
                errors.append((name, error))
                cleanupChildren()
            }
        }

        // Collect text-metric diffs from ALL scenarios (passed + failed)
        let allResults = passed + failed
        let totalStructuralFailures = failed.flatMap { $0.1.structuralDiffs }.count
        let totalTextMetricInfo = allResults.flatMap { $0.1.textMetricDiffs }.count

        print("\n=== PARITY SUMMARY ===")
        print("Passed:  \(passed.count) (no structural failures)")
        print("Failed:  \(failed.count) (structural layout bugs)")
        print("Skipped: \(skipped.count) (no reference fixture)")
        print("Errors:  \(errors.count)")
        print("")
        print("Structural failures: \(totalStructuralFailures) diffs across \(failed.count) scenarios")
        print("Text-metric info:    \(totalTextMetricInfo) diffs across \(allResults.count) scenarios (expected, not bugs)")

        for (name, result) in failed {
            print("\nFAILED: \(name)")
            print(result)
        }
        for (name, err) in errors {
            print("\nERROR: \(name): \(err)")
        }

        // Hard-fail the test on structural failures or errors
        for (name, result) in failed {
            XCTFail("\(name): \(result.structuralDiffs.count) structural layout failure(s)")
        }
        for (name, err) in errors {
            XCTFail("\(name): capture error: \(err)")
        }
    }

    // MARK: - Dump All (gated, not run by default)

    /// Dumps all Win32 snapshots to the fixtures directory for manual inspection.
    /// Skipped unless DUMP_PARITY_SNAPSHOTS=1 is set — avoids dirtying the
    /// working tree during normal test runs.
    ///
    /// Usage: DUMP_PARITY_SNAPSHOTS=1 swift test --filter testDumpAllWin32Snapshots
    func testDumpAllWin32Snapshots() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["DUMP_PARITY_SNAPSHOTS"] == "1",
            "Set DUMP_PARITY_SNAPSHOTS=1 to run snapshot dumps"
        )

        for (name, view) in allLayoutScenarios {
            let snapshot = captureWin32Layout(
                scenario: name,
                view: view,
                width: parityRootWidth,
                height: parityRootHeight
            )
            print("=== Win32: \(name) ===")
            print(snapshot.root)
            print()

            let url = fixturesDir.appendingPathComponent("win32-\(name).json")
            try writeSnapshot(snapshot, to: url)

            cleanupChildren()
        }
    }
}

// MARK: - Win32 Layout Capture Engine

func captureWin32Layout(
    scenario: String,
    view: AnyView,
    width: Double,
    height: Double
) -> LayoutSnapshot {
    let ctx = testContext()

    // Render the SwiftOpenUI view to a Win32 HWND tree
    guard let rootHwnd = winRenderAnyView(view, in: ctx) else {
        return LayoutSnapshot(
            scenario: scenario,
            rootWidth: width,
            rootHeight: height,
            root: LayoutNode(tag: "empty", viewType: "empty", x: 0, y: 0, width: 0, height: 0),
            platform: "Windows-Win32",
            capturedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    // Size the content to fill the target area and trigger layout
    SetWindowPos(rootHwnd, nil, 0, 0, Int32(width), Int32(height), UINT(SWP_NOZORDER))

    // Pump messages to let WM_SIZE propagate through stack layout procs
    var msg = MSG()
    while PeekMessageW(&msg, nil, 0, 0, UINT(PM_REMOVE)) {
        TranslateMessage(&msg)
        DispatchMessageW(&msg)
    }

    // Capture the HWND tree
    let rootNode = captureWin32WidgetTree(hwnd: rootHwnd, rootHwnd: rootHwnd)

    return LayoutSnapshot(
        scenario: scenario,
        rootWidth: width,
        rootHeight: height,
        root: rootNode,
        platform: "Windows-Win32",
        capturedAt: ISO8601DateFormatter().string(from: Date())
    )
}

/// Recursively walk Win32 HWND tree, converting to LayoutNode.
func captureWin32WidgetTree(
    hwnd: HWND,
    rootHwnd: HWND
) -> LayoutNode {
    // Get position relative to root
    var hwndRect = RECT()
    GetWindowRect(hwnd, &hwndRect)
    var rootRect = RECT()
    GetWindowRect(rootHwnd, &rootRect)

    let x: Double
    let y: Double
    if hwnd == rootHwnd {
        x = 0
        y = 0
    } else {
        x = Double(hwndRect.left - rootRect.left)
        y = Double(hwndRect.top - rootRect.top)
    }

    let width = Double(hwndRect.right - hwndRect.left)
    let height = Double(hwndRect.bottom - hwndRect.top)

    // Walk children
    var children: [LayoutNode] = []
    var child = GetWindow(hwnd, UINT(GW_CHILD))
    while let c = child {
        children.append(captureWin32WidgetTree(hwnd: c, rootHwnd: rootHwnd))
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }

    // Identify the node
    let kind = hostedNodeKind(of: hwnd)
    let isSpacer = isSpacerHwnd(hwnd)
    let tag = win32IdentifyHwnd(hwnd, kind: kind, isSpacer: isSpacer)

    let effectiveViewType: String
    if isSpacer {
        effectiveViewType = "Spacer"
    } else {
        switch kind {
        case .text: effectiveViewType = "Text"
        case .color: effectiveViewType = "Color"
        case .vStack: effectiveViewType = "VStack"
        case .hStack: effectiveViewType = "HStack"
        case .zStack: effectiveViewType = "ZStack"
        case .frame: effectiveViewType = "Frame"
        case .padding: effectiveViewType = "Padding"
        case .slider: effectiveViewType = "Slider"
        default: effectiveViewType = getWindowClassName(hwnd)
        }
    }

    return LayoutNode(
        tag: tag,
        viewType: effectiveViewType,
        x: x,
        y: y,
        width: width,
        height: height,
        children: children
    )
}

/// Identify a Win32 HWND with a human-readable tag.
private func win32IdentifyHwnd(
    _ hwnd: HWND,
    kind: Win32HostedNodeKind,
    isSpacer: Bool
) -> String {
    if isSpacer { return "Spacer" }

    // For text windows, extract the text content
    if kind == .text {
        let len = GetWindowTextLengthW(hwnd)
        if len > 0 {
            var buffer = [WCHAR](repeating: 0, count: Int(len) + 1)
            GetWindowTextW(hwnd, &buffer, Int32(buffer.count))
            let text = String(decodingCString: buffer, as: UTF16.self)
            return "text:\(String(text.prefix(40)))"
        }
    }

    let className = getWindowClassName(hwnd)
    if kind != .unknown {
        return "\(kind.rawValue):\(className)"
    }
    return className
}

/// Get the Win32 window class name for an HWND.
private func getWindowClassName(_ hwnd: HWND) -> String {
    var buffer = [WCHAR](repeating: 0, count: 64)
    GetClassNameW(hwnd, &buffer, Int32(buffer.count))
    return String(decodingCString: buffer, as: UTF16.self)
}

#endif // os(Windows)
