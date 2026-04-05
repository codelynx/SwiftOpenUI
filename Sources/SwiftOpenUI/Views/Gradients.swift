import Foundation

// MARK: - Gradient

/// A color gradient represented as an array of color stops.
public struct Gradient: Equatable {
    public struct Stop: Equatable {
        public let color: Color
        public let location: Double

        public init(color: Color, location: Double) {
            self.color = color
            self.location = location
        }
    }

    public let stops: [Stop]

    public init(stops: [Stop]) {
        self.stops = stops
    }

    public init(colors: [Color]) {
        let count = colors.count
        if count == 0 {
            self.stops = []
        } else if count == 1 {
            self.stops = [Stop(color: colors[0], location: 0)]
        } else {
            self.stops = colors.enumerated().map { i, color in
                Stop(color: color, location: Double(i) / Double(count - 1))
            }
        }
    }
}

// MARK: - Unit Point (already defined in ScrollViewReader.swift)
// UnitPoint is reused for gradient start/end points.

// MARK: - Linear Gradient

/// A gradient that varies color along a line between two points.
public struct LinearGradient: View, PrimitiveView {
    public typealias Body = Never
    public let gradient: Gradient
    public let startPoint: UnitPoint
    public let endPoint: UnitPoint

    public init(gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) {
        self.gradient = gradient
        self.startPoint = startPoint
        self.endPoint = endPoint
    }

    public init(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) {
        self.gradient = Gradient(colors: colors)
        self.startPoint = startPoint
        self.endPoint = endPoint
    }

    public init(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) {
        self.gradient = Gradient(stops: stops)
        self.startPoint = startPoint
        self.endPoint = endPoint
    }

    public var body: Never { fatalError() }
}

// MARK: - Radial Gradient

/// A gradient that varies color radiating from a center point.
public struct RadialGradient: View, PrimitiveView {
    public typealias Body = Never
    public let gradient: Gradient
    public let center: UnitPoint
    public let startRadius: Double
    public let endRadius: Double

    public init(gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {
        self.gradient = gradient
        self.center = center
        self.startRadius = startRadius
        self.endRadius = endRadius
    }

    public init(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {
        self.gradient = Gradient(colors: colors)
        self.center = center
        self.startRadius = startRadius
        self.endRadius = endRadius
    }

    public var body: Never { fatalError() }
}
