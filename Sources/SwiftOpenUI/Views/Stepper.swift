/// A control for incrementing or decrementing a value.
///
/// Stepper displays +/- buttons alongside a label.
public struct Stepper: View {
    public typealias Body = Never

    public let label: String
    public let value: Binding<Int>
    public let range: ClosedRange<Int>
    public let step: Int

    public init(_ label: String, value: Binding<Int>,
                in range: ClosedRange<Int> = 0...100, step: Int = 1) {
        self.label = label
        self.value = value
        self.range = range
        self.step = step
    }

    public var body: Never { fatalError("Stepper is a primitive view") }
}
