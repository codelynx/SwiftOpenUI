import CGTK

/// A box that wraps a Swift closure so it can be passed through C void pointers.
public class ClosureBox {
    public let closure: () -> Void
    public init(_ closure: @escaping () -> Void) { self.closure = closure }
}
