/// A box that wraps a Swift closure so it can be passed through C void pointers.
/// Same pattern as the GTK4 backend's ClosureBox.
public class ClosureBox {
    public let closure: () -> Void
    public init(_ closure: @escaping () -> Void) { self.closure = closure }
}
