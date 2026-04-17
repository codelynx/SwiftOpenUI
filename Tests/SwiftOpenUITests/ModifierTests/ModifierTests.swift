import XCTest
@testable import SwiftOpenUI

final class ModifierTests: XCTestCase {

    struct TestIdentifiableItem: Identifiable {
        let id: Int
        let title: String
    }

    // MARK: - ViewModifier preserves content

    struct RedBackground: ViewModifier {
        func body(content: Content) -> some View {
            // In a real modifier, content.wrapped holds the original view
            content
        }
    }

    func testViewModifierPreservesWrappedContent() {
        let text = Text("hello")
        _ = text.modifier(RedBackground())
        // ModifiedContent should pass AnyView(text) through to the modifier
        let modifierContent = RedBackground().body(
            content: _ViewModifierContent<RedBackground>(AnyView(text))
        )
        XCTAssertTrue(modifierContent is _ViewModifierContent<RedBackground>)
        // The wrapped view inside _ViewModifierContent should be our Text
        let content = _ViewModifierContent<RedBackground>(AnyView(text))
        XCTAssertTrue(content.wrapped.wrapped is Text)
    }

    // MARK: - Padding

    func testPaddingUniform() {
        let padded = Text("hello").padding(16)
        XCTAssertEqual(padded.top, 16)
        XCTAssertEqual(padded.bottom, 16)
        XCTAssertEqual(padded.leading, 16)
        XCTAssertEqual(padded.trailing, 16)
    }

    func testPaddingEdges() {
        let padded = Text("hello").padding(.horizontal, 10)
        XCTAssertEqual(padded.leading, 10)
        XCTAssertEqual(padded.trailing, 10)
        XCTAssertEqual(padded.top, 0)
        XCTAssertEqual(padded.bottom, 0)
    }

    func testPaddingPerEdge() {
        let padded = Text("hello").padding(top: 1, bottom: 2, leading: 3, trailing: 4)
        XCTAssertEqual(padded.top, 1)
        XCTAssertEqual(padded.bottom, 2)
        XCTAssertEqual(padded.leading, 3)
        XCTAssertEqual(padded.trailing, 4)
    }

    // MARK: - Frame

    func testFrameFixed() {
        let framed = Text("hello").frame(width: 100, height: 50)
        XCTAssertEqual(framed.width, 100)
        XCTAssertEqual(framed.height, 50)
    }

    func testFrameFlexible() {
        let framed = Text("hello").frame(minWidth: 10, maxWidth: 200)
        XCTAssertEqual(framed.minWidth, 10)
        XCTAssertEqual(framed.maxWidth, 200)
    }

    // MARK: - Style modifiers

    func testForegroundColor() {
        let styled = Text("hello").foregroundColor(.red)
        XCTAssertEqual(styled.color, .red)
    }

    func testForegroundStyleAlias() {
        let styled = Text("hello").foregroundStyle(.blue)
        XCTAssertEqual(styled.color, .blue)
    }

    func testBackgroundColor() {
        let styled = Text("hello").background(.green)
        XCTAssertEqual(styled.color, .green)
        XCTAssertEqual(styled.alignment, .center)
    }

    func testBackgroundViewOverload() {
        let styled = Text("hello").background(Text("bg"), alignment: .bottomTrailing)
        XCTAssertEqual(styled.background.content, "bg")
        XCTAssertEqual(styled.alignment, .bottomTrailing)
    }

    func testBackgroundBuilderOverload() {
        let styled = Text("hello").background(alignment: .topLeading) {
            Text("bg")
        }
        XCTAssertEqual(styled.background.content, "bg")
        XCTAssertEqual(styled.alignment, .topLeading)
    }

    func testFontModifier() {
        let styled = Text("hello").font(.title)
        XCTAssertNotNil(styled as FontModifiedView<Text>)
    }

    func testBorderModifier() {
        let styled = Text("hello").border(.red, width: 2)
        XCTAssertEqual(styled.color, .red)
        XCTAssertEqual(styled.width, 2)
    }

    func testOverlayDirectViewOverload() {
        let styled = Text("hello").overlay(Text("badge"), alignment: .topTrailing)
        XCTAssertEqual(styled.overlay.content, "badge")
        XCTAssertEqual(styled.alignment, .topTrailing)
    }

    // MARK: - Safe area modifiers

    func testIgnoresSafeAreaStoresRegionsAndEdges() {
        let view = Text("hello").ignoresSafeArea([.container], edges: .horizontal)
        XCTAssertTrue(view.regions.contains(.container))
        XCTAssertFalse(view.regions.contains(.keyboard))
        XCTAssertTrue(view.edges.contains(.leading))
        XCTAssertTrue(view.edges.contains(.trailing))
        XCTAssertFalse(view.edges.contains(.top))
    }

    func testSafeAreaInsetVerticalStoresValues() {
        let view = Text("hello").safeAreaInset(edge: .top, alignment: .leading, spacing: 12) {
            Text("inset")
        }

        XCTAssertEqual(view.edge, .top)
        XCTAssertEqual(view.spacing, 12)
        XCTAssertEqual(view.inset.content, "inset")
        if case let .horizontal(alignment) = view.alignment {
            XCTAssertEqual(alignment, .leading)
        } else {
            XCTFail("Expected horizontal alignment")
        }
    }

    func testSafeAreaInsetHorizontalStoresValues() {
        let view = Text("hello").safeAreaInset(edge: .trailing, alignment: .bottom) {
            Text("inset")
        }

        XCTAssertEqual(view.edge, .trailing)
        XCTAssertEqual(view.spacing, 0)
        XCTAssertEqual(view.inset.content, "inset")
        if case let .vertical(alignment) = view.alignment {
            XCTAssertEqual(alignment, .bottom)
        } else {
            XCTFail("Expected vertical alignment")
        }
    }

    func testSafeAreaPaddingDefaultStoresAllEdgesAndNilLength() {
        let view = Text("hello").safeAreaPadding()
        XCTAssertTrue(view.edges.contains(.top))
        XCTAssertTrue(view.edges.contains(.bottom))
        XCTAssertTrue(view.edges.contains(.leading))
        XCTAssertTrue(view.edges.contains(.trailing))
        XCTAssertNil(view.length)
    }

    func testSafeAreaPaddingExplicitLengthStoresAllEdges() {
        let view = Text("hello").safeAreaPadding(20)
        XCTAssertTrue(view.edges.contains(.top))
        XCTAssertTrue(view.edges.contains(.bottom))
        XCTAssertTrue(view.edges.contains(.leading))
        XCTAssertTrue(view.edges.contains(.trailing))
        XCTAssertEqual(view.length, 20)
    }

    func testSafeAreaPaddingSelectedEdgesStoresValues() {
        let view = Text("hello").safeAreaPadding(.horizontal, 12)
        XCTAssertFalse(view.edges.contains(.top))
        XCTAssertFalse(view.edges.contains(.bottom))
        XCTAssertTrue(view.edges.contains(.leading))
        XCTAssertTrue(view.edges.contains(.trailing))
        XCTAssertEqual(view.length, 12)
    }

    func testSafeAreaPaddingSelectedEdgesAllowsSyntheticLength() {
        let view = Text("hello").safeAreaPadding(.vertical)
        XCTAssertTrue(view.edges.contains(.top))
        XCTAssertTrue(view.edges.contains(.bottom))
        XCTAssertFalse(view.edges.contains(.leading))
        XCTAssertFalse(view.edges.contains(.trailing))
        XCTAssertNil(view.length)
    }

    // MARK: - Presentation modifiers

    func testSheetOnDismissStoresClosure() {
        let binding = Binding.constant(true)
        let view = Text("hello").sheet(isPresented: binding, onDismiss: {}) {
            Text("sheet")
        }

        XCTAssertTrue(view.isPresented.wrappedValue)
        XCTAssertNotNil(view.onDismiss)
        XCTAssertEqual(view.sheetContent.content, "sheet")
    }

    func testItemSheetStoresItemBindingAndBuilder() {
        let binding = Binding.constant(TestIdentifiableItem(id: 7, title: "Record") as TestIdentifiableItem?)
        let view = Text("hello").sheet(item: binding, onDismiss: {}) { item in
            Text(item.title)
        }

        XCTAssertEqual(view.item.wrappedValue?.id, 7)
        XCTAssertNotNil(view.onDismiss)
        XCTAssertEqual(view.sheetContent(TestIdentifiableItem(id: 9, title: "Preview")).content, "Preview")
    }

    func testAlertActionsOverloadStoresButtonsAndEmptyMessage() {
        let view = Text("hello").alert(
            "Delete",
            isPresented: .constant(true),
            actions: [AlertButton("Delete", role: .destructive)]
        )

        XCTAssertEqual(view.title, "Delete")
        XCTAssertEqual(view.message, "")
        XCTAssertEqual(view.buttons.count, 1)
        XCTAssertEqual(view.buttons[0].role, .destructive)
    }

    func testAlertActionsMessageOverloadStoresMessage() {
        let view = Text("hello").alert(
            "Delete",
            isPresented: .constant(true),
            actions: [AlertButton("Cancel", role: .cancel)],
            message: "This cannot be undone."
        )

        XCTAssertEqual(view.title, "Delete")
        XCTAssertEqual(view.message, "This cannot be undone.")
        XCTAssertEqual(view.buttons.count, 1)
        XCTAssertEqual(view.buttons[0].role, .cancel)
    }

    func testErrorAlertOverloadDerivesTitleMessageAndButtons() {
        struct SampleError: LocalizedError {
            var errorDescription: String? { "Sync Failed" }
            var failureReason: String? { "The server rejected the request." }
            var recoverySuggestion: String? { "Try again later." }
        }

        let view = Text("hello").alert(
            isPresented: .constant(true),
            error: SampleError()
        ) { _ in
            [AlertButton("Retry"), AlertButton("Cancel", role: .cancel)]
        }

        XCTAssertTrue(view.isPresented.wrappedValue)
        XCTAssertEqual(view.title, "Sync Failed")
        XCTAssertEqual(view.message, "The server rejected the request.\nTry again later.")
        XCTAssertEqual(view.buttons.count, 2)
        XCTAssertEqual(view.buttons[1].role, .cancel)
    }

    func testErrorAlertOverloadSuppressesPresentationWhenErrorIsNil() {
        enum NilError: Error { case missing }

        let view = Text("hello").alert(
            isPresented: .constant(true),
            error: Optional<NilError>.none
        )

        XCTAssertFalse(view.isPresented.wrappedValue)
        XCTAssertEqual(view.title, "")
        XCTAssertEqual(view.message, "")
        XCTAssertEqual(view.buttons.count, 1)
        XCTAssertEqual(view.buttons[0].label, "OK")
    }

    // MARK: - Environment modifiers

    class TestModel: SwiftOpenUI.ObservableObject {
        @SwiftOpenUI.Published var value = "test"
    }

    func testEnvironmentObjectModifier() {
        let model = TestModel()
        let view = Text("hello").environmentObject(model)
        XCTAssertNotNil(view as EnvironmentObjectModifierView<Text, TestModel>)
        XCTAssertTrue(view.object === model)
    }

    func testEnvironmentModifier() {
        let view = Text("hello").environment(\.colorScheme, .dark)
        XCTAssertNotNil(view as EnvironmentModifierView<Text, ColorScheme>)
    }

    // Exercises the Observation-era `.environment(object)` path.
    // Uses a plain class (not ObservableObject) to confirm the new
    // overload binds against `AnyObject`, not the legacy constraint.
    class TestObservableLike {
        var value: Int = 0
    }

    func testEnvironmentObjectOverloadWrapsInObservableModifier() {
        let obj = TestObservableLike()
        let view = Text("hello").environment(obj)
        XCTAssertNotNil(view as EnvironmentObservableModifierView<Text, TestObservableLike>)
        XCTAssertTrue(view.object === obj)
    }

    func testEnvironmentTypeInitReadsInjectedObject() {
        let obj = TestObservableLike()
        obj.value = 42

        var env = EnvironmentValues()
        env.setObject(obj)
        setCurrentEnvironment(env)
        defer { setCurrentEnvironment(nil) }

        let env_read = Environment(TestObservableLike.self)
        XCTAssertTrue(env_read.wrappedValue === obj)
        XCTAssertEqual(env_read.wrappedValue.value, 42)
    }

    // MARK: - Environment-read tracker (rebuild-survival)
    //
    // The tracker captures `@Environment(Type.self)` reads so a
    // ViewHost can re-push the same objects into env on rebuild,
    // even when the originating `.environment(object)` modifier
    // lives below the ViewHost in the render tree (and isn't
    // guaranteed to re-run before body's next read on rebuild).

    func testEnvironmentReadTrackerCapturesObjectAccessedDuringBody() {
        let obj = TestObservableLike()
        obj.value = 99

        var env = EnvironmentValues()
        env.setObject(obj)
        setCurrentEnvironment(env)
        defer { setCurrentEnvironment(nil) }

        beginEnvironmentReadTracking()
        // Simulate body evaluation: a descendant view reads via @Environment.
        let env_read = Environment(TestObservableLike.self)
        _ = env_read.wrappedValue
        let captured = endEnvironmentReadTracking()

        XCTAssertNotNil(captured)
        XCTAssertEqual(captured?.count, 1)
        XCTAssertTrue(captured?[ObjectIdentifier(TestObservableLike.self)] === obj)
    }

    func testEnvironmentReadTrackerNotActiveOutsideBody() {
        // A read outside `beginEnvironmentReadTracking()` should NOT
        // record anywhere — `endEnvironmentReadTracking()` returns nil.
        XCTAssertNil(endEnvironmentReadTracking())
    }

    func testEnvironmentReadTrackerSurvivesRebuildCycle() {
        // This is the crash-reproduction the Win32 reviewer hit:
        // a parent's body installs `.environment(model)` for a child,
        // the child reads via @Environment(Type.self), then the parent
        // restores its captured env (which lacks the model) and asks
        // the child to re-render. With the tracker, the captured
        // injected-object reads are remembered and can be re-installed
        // before the child's body re-evaluates.
        let model = TestObservableLike()
        model.value = 7

        // === First render: env is set, body reads, tracker captures. ===
        var setupEnv = EnvironmentValues()
        setupEnv.setObject(model)
        setCurrentEnvironment(setupEnv)

        beginEnvironmentReadTracking()
        let firstRead = Environment(TestObservableLike.self).wrappedValue
        XCTAssertTrue(firstRead === model)
        let captured = endEnvironmentReadTracking()
        XCTAssertEqual(captured?.count, 1)

        // === Simulate parent restoring its (object-less) captured env
        // for the rebuild pass — without the tracker fix, body's next
        // read would fatalError. With the fix, ViewHost re-installs
        // captured.injected-objects via setObjectByID(_:) before body
        // re-evaluates.
        var rebuildEnv = EnvironmentValues()  // ancestor env with no model
        for (typeID, obj) in captured ?? [:] {
            rebuildEnv.setObjectByID(typeID, obj)
        }
        setCurrentEnvironment(rebuildEnv)

        // === Second render: body's @Environment(Type.self) read
        // succeeds because the tracker preserved the object. ===
        let secondRead = Environment(TestObservableLike.self).wrappedValue
        XCTAssertTrue(secondRead === model, "Tracker-restored env must yield the same object instance")

        setCurrentEnvironment(nil)
    }

    func testEnvironmentValuesIsEnabledDefaultsTrue() {
        let env = EnvironmentValues()
        XCTAssertTrue(env.isEnabled)
    }

    // MARK: - Help / tooltip modifier

    func testHelpModifierWrapsContent() {
        let view = Text("hello").help("Show details")
        XCTAssertNotNil(view as HelpView<Text>)
        XCTAssertEqual(view.text, "Show details")
        XCTAssertEqual(view.content.content, "hello")
    }

    func testHelpModifierAcceptsEmptyString() {
        // Empty string is forwarded verbatim so callers can intentionally
        // clear a prior tooltip value rather than toggle it off.
        let view = Text("hello").help("")
        XCTAssertEqual(view.text, "")
    }

    func testDisabledModifierStoresWrapperState() {
        let view = Text("hello").disabled(true)
        XCTAssertTrue(view.isDisabled)
        XCTAssertEqual(view.content.content, "hello")
    }

    func testDisabledModifierCanNestWithoutErasingInnerWrapper() {
        let view = Text("hello").disabled(true).disabled(false)
        XCTAssertFalse(view.isDisabled)
        XCTAssertTrue(view.content.isDisabled)
        XCTAssertEqual(view.content.content.content, "hello")
    }
}
