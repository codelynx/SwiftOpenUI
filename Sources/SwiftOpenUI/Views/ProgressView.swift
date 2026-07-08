/// A view that shows progress toward completion.
public struct ProgressView: View {
    public typealias Body = Never

    public let value: Double?
    public let total: Double
    /// Optional title shown with the indicator (SwiftUI's ProgressView("...")).
    public let title: String?

    /// Create a determinate progress view (0.0 to total).
    public init(value: Double, total: Double = 1.0) {
        self.value = value
        self.total = total
        self.title = nil
    }

    /// Create an indeterminate progress view.
    /// Note: GTK4 backend currently renders as an empty progress bar.
    /// Pulse animation is not yet implemented.
    public init() {
        self.value = nil
        self.total = 1.0
        self.title = nil
    }

    /// Indeterminate progress with a title label (SwiftUI's ProgressView("Loading…")).
    public init(_ title: String) {
        self.value = nil
        self.total = 1.0
        self.title = title
    }

    public var body: Never { fatalError("ProgressView is a primitive view") }
}
