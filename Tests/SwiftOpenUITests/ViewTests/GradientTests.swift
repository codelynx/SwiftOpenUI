import XCTest
@testable import SwiftOpenUI

final class GradientTests: XCTestCase {

    // MARK: - Gradient

    func testGradientFromColors() {
        let g = Gradient(colors: [.red, .blue])
        XCTAssertEqual(g.stops.count, 2)
        XCTAssertEqual(g.stops[0].location, 0)
        XCTAssertEqual(g.stops[1].location, 1)
    }

    func testGradientFromStops() {
        let g = Gradient(stops: [
            .init(color: .red, location: 0.2),
            .init(color: .blue, location: 0.8)
        ])
        XCTAssertEqual(g.stops.count, 2)
        XCTAssertEqual(g.stops[0].location, 0.2)
    }

    func testGradientSingleColor() {
        let g = Gradient(colors: [.red])
        XCTAssertEqual(g.stops.count, 1)
        XCTAssertEqual(g.stops[0].location, 0)
    }

    func testGradientEmpty() {
        let g = Gradient(colors: [])
        XCTAssertEqual(g.stops.count, 0)
    }

    func testGradientThreeColors() {
        let g = Gradient(colors: [.red, .green, .blue])
        XCTAssertEqual(g.stops.count, 3)
        XCTAssertEqual(g.stops[0].location, 0, accuracy: 0.01)
        XCTAssertEqual(g.stops[1].location, 0.5, accuracy: 0.01)
        XCTAssertEqual(g.stops[2].location, 1, accuracy: 0.01)
    }

    // MARK: - LinearGradient

    func testLinearGradientFromColors() {
        let lg = LinearGradient(colors: [.red, .blue], startPoint: .leading, endPoint: .trailing)
        XCTAssertEqual(lg.gradient.stops.count, 2)
        XCTAssertEqual(lg.startPoint, .leading)
        XCTAssertEqual(lg.endPoint, .trailing)
    }

    func testLinearGradientFromGradient() {
        let g = Gradient(colors: [.red, .green, .blue])
        let lg = LinearGradient(gradient: g, startPoint: .top, endPoint: .bottom)
        XCTAssertEqual(lg.gradient.stops.count, 3)
        XCTAssertEqual(lg.startPoint, .top)
        XCTAssertEqual(lg.endPoint, .bottom)
    }

    func testLinearGradientFromStops() {
        let lg = LinearGradient(stops: [
            .init(color: .red, location: 0),
            .init(color: .blue, location: 1)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        XCTAssertEqual(lg.gradient.stops.count, 2)
    }

    // MARK: - RadialGradient

    func testRadialGradientFromColors() {
        let rg = RadialGradient(colors: [.red, .blue], center: .center, startRadius: 0, endRadius: 100)
        XCTAssertEqual(rg.gradient.stops.count, 2)
        XCTAssertEqual(rg.center, .center)
        XCTAssertEqual(rg.startRadius, 0)
        XCTAssertEqual(rg.endRadius, 100)
    }

    func testRadialGradientFromGradient() {
        let g = Gradient(colors: [.white, .black])
        let rg = RadialGradient(gradient: g, center: .top, startRadius: 10, endRadius: 200)
        XCTAssertEqual(rg.center, .top)
        XCTAssertEqual(rg.startRadius, 10)
        XCTAssertEqual(rg.endRadius, 200)
    }
}
