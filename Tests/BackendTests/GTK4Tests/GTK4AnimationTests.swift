import XCTest
import SwiftOpenUI
@testable import BackendGTK4
import CGTK
import CGTKBridge

final class GTK4AnimationTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if gtk_is_initialized() == 0 {
            _ = gtk_init_check()
        }
    }

    // MARK: - Opacity

    func testOpacityViewSetsGtkOpacity() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(Text("Hi").opacity(0.5)))
        XCTAssertEqual(gtk_widget_get_opacity(widget), 0.5, accuracy: 0.01)
    }

    func testFullOpacityIsDefault() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(Text("Hi")))
        XCTAssertEqual(gtk_widget_get_opacity(widget), 1.0, accuracy: 0.01)
    }

    // MARK: - Offset widget data

    func testOffsetViewStoresWidgetData() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(Text("Hi").offset(x: 10, y: 20)))
        XCTAssertEqual(getWidgetDouble(widget, key: "gtk-swift-offset-x"), 10)
        XCTAssertEqual(getWidgetDouble(widget, key: "gtk-swift-offset-y"), 20)
    }

    func testOffsetViewStoresZeroValues() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(Text("Hi").offset(x: 0, y: 0)))
        XCTAssertEqual(getWidgetDouble(widget, key: "gtk-swift-offset-x"), 0)
        XCTAssertEqual(getWidgetDouble(widget, key: "gtk-swift-offset-y"), 0)
    }

    // MARK: - Scale widget data

    func testScaleEffectViewStoresWidgetData() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(Text("Hi").scaleEffect(1.5)))
        XCTAssertEqual(getWidgetDouble(widget, key: "gtk-swift-scale-x"), 1.5)
        XCTAssertEqual(getWidgetDouble(widget, key: "gtk-swift-scale-y"), 1.5)
    }

    // MARK: - Rotation widget data

    func testRotationViewStoresWidgetData() throws {
        try requireGTK()

        let widget = widgetFromOpaque(gtkRenderView(Text("Hi").rotationEffect(45.0)))
        XCTAssertEqual(getWidgetDouble(widget, key: "gtk-swift-rotation"), 45.0)
    }

    // MARK: - buildTransformCSS

    func testBuildTransformCSSOffsetOnly() {
        let css = buildTransformCSS(offsetX: 10, offsetY: 20, scaleX: 1, scaleY: 1)
        XCTAssertEqual(css, "transform: translate(10px, 20px);")
    }

    func testBuildTransformCSSScaleOnly() {
        let css = buildTransformCSS(offsetX: 0, offsetY: 0, scaleX: 2.0, scaleY: 0.5)
        XCTAssertEqual(css, "transform: scale(2.0, 0.5);")
    }

    func testBuildTransformCSSRotationOnly() {
        let css = buildTransformCSS(offsetX: 0, offsetY: 0, scaleX: 1, scaleY: 1, rotation: 90)
        XCTAssertEqual(css, "transform: rotate(90.0deg);")
    }

    func testBuildTransformCSSEmptyForDefaults() {
        let css = buildTransformCSS(offsetX: 0, offsetY: 0, scaleX: 1, scaleY: 1)
        XCTAssertEqual(css, "")
    }

    func testBuildTransformCSSCombinedOffsetScaleRotation() {
        let css = buildTransformCSS(offsetX: 5, offsetY: 10, scaleX: 2.0, scaleY: 2.0, rotation: 45)
        // Order must be: translate → rotate → scale
        XCTAssertEqual(css, "transform: translate(5px, 10px) rotate(45.0deg) scale(2.0, 2.0);")
    }

    func testBuildTransformCSSOffsetAndRotation() {
        let css = buildTransformCSS(offsetX: 8, offsetY: 0, scaleX: 1, scaleY: 1, rotation: 30)
        XCTAssertEqual(css, "transform: translate(8px, 0px) rotate(30.0deg);")
    }

    func testBuildTransformCSSRotationAndScale() {
        let css = buildTransformCSS(offsetX: 0, offsetY: 0, scaleX: 1.5, scaleY: 1.5, rotation: 60)
        XCTAssertEqual(css, "transform: rotate(60.0deg) scale(1.5, 1.5);")
    }

    // MARK: - Descriptor conformance

    func testOpacityViewDescriptor() throws {
        try requireGTK()

        let view = Text("Hi").opacity(0.7)
        guard let describable = view as? GTKDescribable else {
            return XCTFail("OpacityView should conform to GTKDescribable")
        }
        let node = describable.gtkDescribeNode()
        XCTAssertEqual(node.kind, .opacity)
        XCTAssertEqual(node.typeName, "OpacityView")
        if case .opacity(let desc) = node.props {
            XCTAssertEqual(desc.opacity, 0.7)
        } else {
            XCTFail("Expected .opacity props")
        }
    }

    func testOffsetViewDescriptor() throws {
        try requireGTK()

        let view = Text("Hi").offset(x: 3, y: 4)
        guard let describable = view as? GTKDescribable else {
            return XCTFail("OffsetView should conform to GTKDescribable")
        }
        let node = describable.gtkDescribeNode()
        XCTAssertEqual(node.kind, .offset)
        if case .offset(let desc) = node.props {
            XCTAssertEqual(desc.x, 3)
            XCTAssertEqual(desc.y, 4)
        } else {
            XCTFail("Expected .offset props")
        }
    }

    func testScaleEffectViewDescriptor() throws {
        try requireGTK()

        let view = Text("Hi").scaleEffect(2.0)
        guard let describable = view as? GTKDescribable else {
            return XCTFail("ScaleEffectView should conform to GTKDescribable")
        }
        let node = describable.gtkDescribeNode()
        XCTAssertEqual(node.kind, .scale)
        if case .scale(let desc) = node.props {
            XCTAssertEqual(desc.scaleX, 2.0)
            XCTAssertEqual(desc.scaleY, 2.0)
        } else {
            XCTFail("Expected .scale props")
        }
    }

    func testRotationViewDescriptor() throws {
        try requireGTK()

        let view = Text("Hi").rotationEffect(45.0)
        guard let describable = view as? GTKDescribable else {
            return XCTFail("RotationView should conform to GTKDescribable")
        }
        let node = describable.gtkDescribeNode()
        XCTAssertEqual(node.kind, .rotation)
        if case .rotation(let desc) = node.props {
            XCTAssertEqual(desc.angle, 45.0)
        } else {
            XCTFail("Expected .rotation props")
        }
    }

    func testAnimatedViewDescriptor() throws {
        try requireGTK()

        let view = Text("Hi").animation(.linear)
        guard let describable = view as? GTKDescribable else {
            return XCTFail("AnimatedView should conform to GTKDescribable")
        }
        let node = describable.gtkDescribeNode()
        XCTAssertEqual(node.kind, .animated)
        XCTAssertEqual(node.typeName, "AnimatedView")
        if case .animated(let desc) = node.props {
            XCTAssertEqual(desc.curve, "linear")
            XCTAssertEqual(desc.duration, 0.35)
        } else {
            XCTFail("Expected .animated props for non-nil animation")
        }
    }

    func testAnimatedViewDescriptorNilAnimation() throws {
        try requireGTK()

        let view = Text("Hi").animation(nil)
        guard let describable = view as? GTKDescribable else {
            return XCTFail("AnimatedView should conform to GTKDescribable")
        }
        let node = describable.gtkDescribeNode()
        XCTAssertEqual(node.props, .none)
    }

    func testAnimatedViewDescriptorDistinguishesCurves() throws {
        try requireGTK()

        let linearView = Text("Hi").animation(.linear)
        let easeInView = Text("Hi").animation(.easeIn)
        let linearNode = (linearView as! GTKDescribable).gtkDescribeNode()
        let easeInNode = (easeInView as! GTKDescribable).gtkDescribeNode()
        XCTAssertNotEqual(linearNode.props, easeInNode.props)
    }
}

private func requireGTK(
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    guard gtk_is_initialized() != 0 else {
        throw XCTSkip("GTK could not initialize in this environment.", file: file, line: line)
    }
}
