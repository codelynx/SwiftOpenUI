import XCTest
@testable import SwiftOpenUI

final class FullScreenCoverTests: XCTestCase {

    func testFullScreenCoverWrapsContent() {
        var presented = false
        let view = Text("Main").fullScreenCover(isPresented: .init(
            get: { presented }, set: { presented = $0 }
        )) {
            Text("Cover")
        }
        XCTAssertEqual(view.content.content, "Main")
        XCTAssertFalse(view.isPresented.wrappedValue)
    }

    func testFullScreenCoverStoresBinding() {
        var presented = true
        let view = Text("Main").fullScreenCover(isPresented: .init(
            get: { presented }, set: { presented = $0 }
        )) {
            Text("Cover")
        }
        XCTAssertTrue(view.isPresented.wrappedValue)
    }

    func testFullScreenCoverOnDismiss() {
        var dismissed = false
        var presented = false
        let view = Text("Main").fullScreenCover(
            isPresented: .init(get: { presented }, set: { presented = $0 }),
            onDismiss: { dismissed = true }
        ) {
            Text("Cover")
        }
        XCTAssertNotNil(view.onDismiss)
        view.onDismiss?()
        XCTAssertTrue(dismissed)
    }

    func testFullScreenCoverChainedWithFrame() {
        var presented = false
        let view = Text("Main")
            .frame(width: 300, height: 200)
            .fullScreenCover(isPresented: .init(
                get: { presented }, set: { presented = $0 }
            )) {
                Text("Cover")
            }
        XCTAssertEqual(view.content.width, 300)
    }
}
