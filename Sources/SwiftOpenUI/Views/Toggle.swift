/// A control that toggles between on and off states.
public struct Toggle: View {
    public typealias Body = Never

    public let label: String
    public let isOn: Binding<Bool>

    public init(_ label: String = "", isOn: Binding<Bool>) {
        self.label = label
        self.isOn = isOn
    }

    public var body: Never { fatalError("Toggle is a primitive view") }
}
