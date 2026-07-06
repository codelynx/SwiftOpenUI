import XCTest
import SwiftOpenUI
@testable import BackendGTK4

/// Guards the GTK4 LinearGradient CSS-angle mapping. The prior bug emitted an
/// invalid `linear-gradient(from X% Y% to X% Y%, …)` that GTK silently dropped
/// (nothing rendered); the fix emits a real CSS angle.
final class GTK4LinearGradientAngleTests: XCTestCase {
    func testAngles() {
        XCTAssertEqual(gtkLinearGradientAngle(from: .leading, to: .trailing), 90)   // to right
        XCTAssertEqual(gtkLinearGradientAngle(from: .trailing, to: .leading), 270)  // to left
        XCTAssertEqual(gtkLinearGradientAngle(from: .top, to: .bottom), 180)        // to bottom
        XCTAssertEqual(gtkLinearGradientAngle(from: .bottom, to: .top), 0)          // to top
        XCTAssertEqual(gtkLinearGradientAngle(from: .topLeading, to: .bottomTrailing), 135) // diagonal
    }
}
