/// A view that shows progress toward completion.
///
/// Use with a value for determinate progress, or without for indeterminate.
public struct ProgressView: View {
    public typealias Body = Never

    public let label: String
    public let value: Double?
    public let total: Double

    /// Indeterminate progress (spinning indicator).
    public init(_ label: String = "") {
        self.label = label
        self.value = nil
        self.total = 1.0
    }

    /// Determinate progress (0.0 to total).
    public init(_ label: String = "", value: Double, total: Double = 1.0) {
        self.label = label
        self.value = value
        self.total = total
    }

    public var body: Never { fatalError("ProgressView is a primitive view") }
}
