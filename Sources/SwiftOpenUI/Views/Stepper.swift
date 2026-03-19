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

    /// Convenience init for Int bindings. Wraps the Int binding in a
    /// Double binding internally so users can write `@State var count: Int`.
    public init(_ label: String = "", value: Binding<Int>, in range: ClosedRange<Int> = 0...100, step: Int = 1) {
        self.label = label
        self.value = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0) }
        )
        self.range = Double(range.lowerBound)...Double(range.upperBound)
        self.step = Double(step)
    }

    public var body: Never { fatalError("Stepper is a primitive view") }
}
