/// Role for an alert button.
public enum AlertButtonRole {
    case `default`
    case cancel
    case destructive
}

/// A button configuration for an alert dialog.
public struct AlertButton {
    public let label: String
    public let role: AlertButtonRole
    public let action: () -> Void

    public init(_ label: String, role: AlertButtonRole = .default, action: @escaping () -> Void = {}) {
        self.label = label
        self.role = role
        self.action = action
    }
}

/// A modifier that presents an alert dialog when a binding becomes true.
public struct AlertModifierView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let isPresented: Binding<Bool>
    public let title: String
    public let message: String
    public let buttons: [AlertButton]

    public var body: Never { fatalError("AlertModifierView is a primitive view") }
}

extension View {
    /// Present an alert dialog when `isPresented` becomes true.
    public func alert(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String = "",
        actions: [AlertButton] = [AlertButton("OK")]
    ) -> AlertModifierView<Self> {
        AlertModifierView(content: self, isPresented: isPresented, title: title, message: message, buttons: actions)
    }
}
