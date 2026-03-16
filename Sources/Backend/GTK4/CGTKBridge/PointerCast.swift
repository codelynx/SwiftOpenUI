import CGTK

/// Reinterpret-cast between GTK typed pointers.
@inlinable
public func widgetPointer<T>(_ ptr: UnsafeMutablePointer<T>) -> UnsafeMutablePointer<GtkWidget> {
    UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: GtkWidget.self)
}

@inlinable
public func boxPointer(_ ptr: UnsafeMutablePointer<GtkWidget>) -> UnsafeMutablePointer<GtkBox> {
    UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: GtkBox.self)
}

@inlinable
public func windowPointer(_ ptr: UnsafeMutablePointer<GtkWidget>) -> UnsafeMutablePointer<GtkWindow> {
    UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: GtkWindow.self)
}

@inlinable
public func applicationPointer(_ ptr: OpaquePointer) -> UnsafeMutablePointer<GApplication> {
    UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: GApplication.self)
}

@inlinable
public func gtkApplicationPointer(_ ptr: OpaquePointer) -> UnsafeMutablePointer<GtkApplication> {
    UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: GtkApplication.self)
}

@inlinable
public func widgetFromOpaque(_ ptr: OpaquePointer) -> UnsafeMutablePointer<GtkWidget> {
    UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: GtkWidget.self)
}

@inlinable
public func opaqueFromWidget(_ ptr: UnsafeMutablePointer<GtkWidget>) -> OpaquePointer {
    OpaquePointer(ptr)
}
