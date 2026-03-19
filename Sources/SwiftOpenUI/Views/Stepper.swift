/// An increment/decrement control.
public struct Stepper: View {
    public typealias Body = Never

    public let label: String
    public let value: Binding<Double>
    public let range: ClosedRange<Double>
    public let step: Double

    public init(_ label: String = "", value: Binding<Double>, in range: ClosedRange<Double> = 0...100, step: Double = 1) {
        self.label = label
        self.value = value
        self.range = range
        self.step = step
    }

    public var body: Never { fatalError("Stepper is a primitive view") }
}
