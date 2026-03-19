/// A view that fires an action when it appears on screen.
public struct OnAppearView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let action: () -> Void

    public var body: Never { fatalError("OnAppearView is a primitive view") }
}

/// A view that fires an action when it disappears from screen.
public struct OnDisappearView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let action: () -> Void

    public var body: Never { fatalError("OnDisappearView is a primitive view") }
}

/// A view that presents content as a modal overlay.
public struct SheetView<Content: View, SheetContent: View>: View {
    public typealias Body = Never

    public let content: Content
    public let isPresented: Binding<Bool>
    public let sheetContent: () -> SheetContent

    public var body: Never { fatalError("SheetView is a primitive view") }
}

/// A view that presents an alert dialog.
public struct AlertView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let title: String
    public let message: String
    public let isPresented: Binding<Bool>

    public var body: Never { fatalError("AlertView is a primitive view") }
}

/// A view wrapped in an overlay container.
public struct OverlayView<Content: View, Overlay: View>: View {
    public typealias Body = Never

    public let content: Content
    public let overlay: Overlay
    public let alignment: Alignment

    public var body: Never { fatalError("OverlayView is a primitive view") }
}

/// A visual grouping with optional header.
public struct Section<Content: View>: View {
    public typealias Body = Never

    public let header: String
    public let content: Content

    public init(_ header: String = "", @ViewBuilder content: () -> Content) {
        self.header = header
        self.content = content()
    }

    public var body: Never { fatalError("Section is a primitive view") }
}

extension View {
    /// Perform an action when this view appears.
    public func onAppear(perform action: @escaping () -> Void) -> OnAppearView<Self> {
        OnAppearView(content: self, action: action)
    }

    /// Perform an action when this view disappears.
    public func onDisappear(perform action: @escaping () -> Void) -> OnDisappearView<Self> {
        OnDisappearView(content: self, action: action)
    }

    /// Present a sheet when the binding is true.
    public func sheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> SheetView<Self, SheetContent> {
        SheetView(content: self, isPresented: isPresented, sheetContent: content)
    }

    /// Present an alert when the binding is true.
    public func alert(_ title: String, isPresented: Binding<Bool>,
                      message: String = "") -> AlertView<Self> {
        AlertView(content: self, title: title, message: message, isPresented: isPresented)
    }

    /// Layer an overlay view on top of this view.
    public func overlay<V: View>(_ overlay: V, alignment: Alignment = .center) -> OverlayView<Self, V> {
        OverlayView(content: self, overlay: overlay, alignment: alignment)
    }
}
