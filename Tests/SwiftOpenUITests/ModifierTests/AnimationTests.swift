import XCTest
@testable import SwiftOpenUI

final class AnimationTests: XCTestCase {

    // MARK: - Animation struct

    func testAnimationDefaultValues() {
        let anim = Animation.default
        XCTAssertEqual(anim.curve, .easeInOut)
        XCTAssertEqual(anim.duration, 0.35)
    }

    func testAnimationLinearPreset() {
        let anim = Animation.linear
        XCTAssertEqual(anim.curve, .linear)
        XCTAssertEqual(anim.duration, 0.35)
    }

    func testAnimationSpringPreset() {
        let anim = Animation.spring
        XCTAssertEqual(anim.curve, .spring)
        XCTAssertEqual(anim.duration, 0.5)
    }

    func testAnimationCustomDuration() {
        let anim = Animation.easeIn(duration: 1.0)
        XCTAssertEqual(anim.curve, .easeIn)
        XCTAssertEqual(anim.duration, 1.0)
    }

    func testAnimationEquatable() {
        XCTAssertEqual(Animation.linear, Animation(curve: .linear, duration: 0.35))
        XCTAssertNotEqual(Animation.linear, Animation.easeIn)
    }

    // MARK: - withAnimation / pending animation

    func testWithAnimationSetsPendingAnimation() {
        // Ensure clean state
        _ = consumePendingAnimation()

        withAnimation(.easeOut) {}
        let pending = getPendingAnimation()
        XCTAssertNotNil(pending)
        XCTAssertEqual(pending?.curve, .easeOut)

        // Clean up
        _ = consumePendingAnimation()
    }

    func testConsumePendingAnimationClearsIt() {
        _ = consumePendingAnimation()

        withAnimation(.linear) {}
        let consumed = consumePendingAnimation()
        XCTAssertNotNil(consumed)
        XCTAssertEqual(consumed?.curve, .linear)

        let second = consumePendingAnimation()
        XCTAssertNil(second)
    }

    func testWithAnimationRestoresCurrentAnimation() {
        setCurrentAnimation(nil)
        withAnimation(.spring) {}
        // After withAnimation, current animation should be restored to nil
        XCTAssertNil(getCurrentAnimation())

        // Clean up
        _ = consumePendingAnimation()
    }

    // MARK: - View modifier wrappers

    func testOpacityViewWrapsContent() {
        let view = Text("hello").opacity(0.5)
        XCTAssertEqual(view.opacity, 0.5)
        XCTAssertEqual(view.content.content, "hello")
    }

    func testOffsetViewWrapsContent() {
        let view = Text("hello").offset(x: 10, y: 20)
        XCTAssertEqual(view.x, 10)
        XCTAssertEqual(view.y, 20)
        XCTAssertEqual(view.content.content, "hello")
    }

    func testScaleEffectViewUniformScale() {
        let view = Text("hello").scaleEffect(2.0)
        XCTAssertEqual(view.scaleX, 2.0)
        XCTAssertEqual(view.scaleY, 2.0)
    }

    func testScaleEffectViewIndependentAxes() {
        let view = Text("hello").scaleEffect(x: 1.5, y: 0.5)
        XCTAssertEqual(view.scaleX, 1.5)
        XCTAssertEqual(view.scaleY, 0.5)
    }

    func testAnimatedViewWrapsContent() {
        let view = Text("hello").animation(.easeInOut)
        XCTAssertEqual(view.animation?.curve, .easeInOut)
        XCTAssertEqual(view.content.content, "hello")
    }

    func testAnimatedViewNilAnimation() {
        let view = Text("hello").animation(nil)
        XCTAssertNil(view.animation)
    }

    func testRotationViewWrapsContent() {
        let view = Text("hello").rotationEffect(45.0)
        XCTAssertEqual(view.angle, 45.0)
        XCTAssertEqual(view.content.content, "hello")
    }

    func testRotationViewWithAngle() {
        let view = Text("hello").rotationEffect(Angle.degrees(90))
        XCTAssertEqual(view.angle, 90.0)
    }
}
