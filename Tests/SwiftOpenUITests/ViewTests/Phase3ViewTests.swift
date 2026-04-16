import XCTest
@testable import SwiftOpenUI

final class Phase3ViewTests: XCTestCase {

    // MARK: - Toggle

    func testToggleConstruction() {
        let toggle = Toggle("Dark Mode", isOn: .constant(true))
        XCTAssertEqual(toggle.label, "Dark Mode")
        XCTAssertTrue(toggle.isOn.wrappedValue)
    }

    func testToggleEmptyLabel() {
        let toggle = Toggle(isOn: .constant(false))
        XCTAssertEqual(toggle.label, "")
        XCTAssertFalse(toggle.isOn.wrappedValue)
    }

    // MARK: - Slider

    func testSliderDefaults() {
        let slider = Slider(value: .constant(0.5))
        XCTAssertEqual(slider.value.wrappedValue, 0.5)
        XCTAssertEqual(slider.range, 0...1)
        XCTAssertEqual(slider.step, 0.01)
    }

    func testSliderCustomRange() {
        let slider = Slider(value: .constant(50), in: 0...100, step: 1)
        XCTAssertEqual(slider.value.wrappedValue, 50)
        XCTAssertEqual(slider.range, 0...100)
        XCTAssertEqual(slider.step, 1)
    }

    // MARK: - ScrollView

    func testScrollViewDefaultAxis() {
        let scroll = ScrollView { Text("content") }
        XCTAssertTrue(scroll.axes.contains(.vertical))
        XCTAssertFalse(scroll.axes.contains(.horizontal))
    }

    func testScrollViewHorizontal() {
        let scroll = ScrollView(.horizontal) { Text("content") }
        XCTAssertTrue(scroll.axes.contains(.horizontal))
        XCTAssertFalse(scroll.axes.contains(.vertical))
    }

    func testScrollViewBothAxes() {
        let scroll = ScrollView([.horizontal, .vertical]) { Text("content") }
        XCTAssertTrue(scroll.axes.contains(.horizontal))
        XCTAssertTrue(scroll.axes.contains(.vertical))
    }

    // MARK: - Image

    func testImageSystemName() {
        let image = Image(systemName: "document-open")
        if case .systemName(let name) = image.source {
            XCTAssertEqual(name, "document-open")
        } else {
            XCTFail("Expected systemName source")
        }
        XCTAssertEqual(image.scale.pointSize, 20) // medium default
    }

    func testImageFilePath() {
        let image = Image(filePath: "/tmp/test.png")
        if case .filePath(let path) = image.source {
            XCTAssertEqual(path, "/tmp/test.png")
        } else {
            XCTFail("Expected filePath source")
        }
    }

    func testImageScale() {
        let image = Image(systemName: "edit-copy").imageScale(.large)
        XCTAssertEqual(image.scale.pointSize, 24)
    }

    func testImageDefaultsToNonResizable() {
        XCTAssertFalse(Image(systemName: "star").isResizable)
        XCTAssertFalse(Image(filePath: "/tmp/test.png").isResizable)
        XCTAssertFalse(Image(material: "home").isResizable)
    }

    func testImageResizableSetsFlag() {
        XCTAssertTrue(Image(systemName: "star").resizable().isResizable)
        XCTAssertTrue(Image(filePath: "/tmp/test.png").resizable().isResizable)
        XCTAssertTrue(Image(material: "home").resizable().isResizable)
    }

    func testImageResizablePreservesSource() {
        let image = Image(filePath: "/tmp/photo.jpg").resizable()
        if case .filePath(let path) = image.source {
            XCTAssertEqual(path, "/tmp/photo.jpg")
        } else {
            XCTFail("Expected filePath source")
        }
    }

    func testImageResizableComposesWithImageScale() {
        let image = Image(systemName: "star").resizable().imageScale(.large)
        XCTAssertTrue(image.isResizable)
        XCTAssertEqual(image.scale.pointSize, 24)
    }

    // MARK: - List

    func testListConstruction() {
        let list = List {
            Text("Row 1")
            Text("Row 2")
        }
        // List wraps a TupleView, which conforms to MultiChildView
        XCTAssertTrue(list.content is any MultiChildView)
        let children = (list.content as! any MultiChildView).children
        XCTAssertEqual(children.count, 2)
    }
}
