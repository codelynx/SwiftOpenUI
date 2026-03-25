import XCTest
@testable import SwiftOpenUI

final class NavigationLinkTests: XCTestCase {

    func testStringNavigationLinkKeepsTextFallback() {
        let link = NavigationLink("Go", title: "Detail") {
            Text("Destination")
        }

        XCTAssertEqual(link.label, "Go")
        XCTAssertEqual(link.title, "Detail")
        XCTAssertTrue(link.labelView.wrapped is Text)
    }

    func testDestinationNavigationLinkStoresCustomLabelView() {
        let link = NavigationLink(title: "Detail") {
            Text("Destination")
        } label: {
            HStack {
                Text("Go")
                Text("Now")
            }
        }

        XCTAssertEqual(link.label, "")
        XCTAssertEqual(link.title, "Detail")
        XCTAssertTrue(String(describing: type(of: link.labelView.wrapped)).contains("HStack"))
    }

    func testValueNavigationLinkUsesTextLabelAsDefaultTitle() {
        let link = NavigationLink(value: "detail") {
            Text("Go")
        }

        XCTAssertEqual(link.label, "Go")
        XCTAssertEqual(link.title, "Go")
        XCTAssertEqual(link.pushValue as? String, "detail")
    }
}
