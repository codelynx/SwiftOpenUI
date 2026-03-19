import XCTest
@testable import SwiftOpenUI
#if canImport(Observation)
import Observation
#endif

#if canImport(Observation)
@Observable
final class TestModel {
    var name = "hello"
    var count = 0
}

final class ObservableTests: XCTestCase {

    func testObservableDetectedByMirror() {
        // A view struct with an @Observable property should be detected
        // as having reactive properties
        struct TestView: View {
            var model: TestModel
            var body: some View { Text(model.name) }
        }

        let model = TestModel()
        let view = TestView(model: model)
        XCTAssertTrue(hasReactiveProperties(view),
            "@Observable stored property should be detected as reactive")
    }

    func testNonObservableNotDetected() {
        // A plain struct property should not be detected
        struct PlainView: View {
            var label: String
            var body: some View { Text(label) }
        }

        let view = PlainView(label: "test")
        XCTAssertFalse(hasReactiveProperties(view),
            "Plain stored property should not be detected as reactive")
    }

    func testObservationTrackingWorks() {
        // Verify that withObservationTracking fires onChange
        let model = TestModel()
        let expectation = XCTestExpectation(description: "onChange fired")

        withObservationTracking {
            _ = model.name
        } onChange: {
            expectation.fulfill()
        }

        model.name = "world"
        wait(for: [expectation], timeout: 1.0)
    }

    func testObservableModelConstruction() {
        let model = TestModel()
        XCTAssertEqual(model.name, "hello")
        XCTAssertEqual(model.count, 0)
        model.name = "world"
        model.count = 42
        XCTAssertEqual(model.name, "world")
        XCTAssertEqual(model.count, 42)
    }
}
#endif
