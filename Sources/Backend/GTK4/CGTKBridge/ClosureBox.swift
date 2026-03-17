import CGTK

/// A box that wraps a Swift closure so it can be passed through C void pointers.
public class ClosureBox {
    public let closure: () -> Void
    public init(_ closure: @escaping () -> Void) { self.closure = closure }
}

/// A box for closures that take a String parameter (e.g., text changed signals).
public class StringClosureBox {
    public let closure: (String) -> Void
    public init(_ closure: @escaping (String) -> Void) { self.closure = closure }
}
