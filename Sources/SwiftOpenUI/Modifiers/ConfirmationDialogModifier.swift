/// Visibility preference for titles and labels.
public enum Visibility: Equatable {
    case automatic
    case visible
    case hidden
}

/// Stored dismissal-confirmation configuration carried by a view tree.
public struct DismissalConfirmationConfiguration {
    public let title: String
    public let isPresented: Binding<Bool>
    public let titleVisibility: Visibility
    public let message: String
    public let buttons: [AlertButton]

    public init(
        title: String,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility,
        message: String,
        buttons: [AlertButton]
    ) {
        self.title = title
        self.isPresented = isPresented
        self.titleVisibility = titleVisibility
        self.message = message
        self.buttons = buttons
    }
}

/// Protocol for views that carry dismissal-confirmation interception metadata.
public protocol DismissalConfirmationProvider {
    var dismissalConfirmationConfiguration: DismissalConfirmationConfiguration? { get }
}

/// A modifier that presents a confirmation dialog with vertical buttons
/// when a binding becomes true.
public struct ConfirmationDialogView<Content: View>: View, DismissalConfirmationProvider {
    public typealias Body = Never

    public let content: Content
    public let title: String
    public let isPresented: Binding<Bool>
    public let titleVisibility: Visibility
    public let message: String
    public let buttons: [AlertButton]
    public let participatesInDismissalInterception: Bool

    public var dismissalConfirmationConfiguration: DismissalConfirmationConfiguration? {
        guard participatesInDismissalInterception else { return nil }
        return DismissalConfirmationConfiguration(
            title: title,
            isPresented: isPresented,
            titleVisibility: titleVisibility,
            message: message,
            buttons: buttons
        )
    }

    public var body: Never { fatalError("ConfirmationDialogView is a primitive view") }
}

extension View {
    /// Show a dismissal confirmation dialog when `shouldPresent` becomes true.
    public func dismissalConfirmationDialog(
        _ title: String,
        shouldPresent: Binding<Bool>,
        actions: [AlertButton]
    ) -> ConfirmationDialogView<Self> {
        ConfirmationDialogView(
            content: self,
            title: title,
            isPresented: shouldPresent,
            titleVisibility: .automatic,
            message: "",
            buttons: actions,
            participatesInDismissalInterception: true
        )
    }

    /// Show a confirmation dialog when `isPresented` becomes true.
    /// Buttons are displayed vertically (action sheet style).
    public func confirmationDialog(
        _ title: String,
        isPresented: Binding<Bool>,
        actions: [AlertButton]
    ) -> ConfirmationDialogView<Self> {
        confirmationDialog(
            title,
            isPresented: isPresented,
            titleVisibility: .automatic,
            actions: actions,
            message: ""
        )
    }

    /// Show a confirmation dialog with explicit title visibility.
    public func confirmationDialog(
        _ title: String,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility,
        actions: [AlertButton]
    ) -> ConfirmationDialogView<Self> {
        confirmationDialog(
            title,
            isPresented: isPresented,
            titleVisibility: titleVisibility,
            actions: actions,
            message: ""
        )
    }

    /// Show a confirmation dialog with explicit title visibility and message.
    public func confirmationDialog(
        _ title: String,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility,
        actions: [AlertButton],
        message: String
    ) -> ConfirmationDialogView<Self> {
        ConfirmationDialogView(
            content: self,
            title: title,
            isPresented: isPresented,
            titleVisibility: titleVisibility,
            message: message,
            buttons: actions,
            participatesInDismissalInterception: false
        )
    }
}
