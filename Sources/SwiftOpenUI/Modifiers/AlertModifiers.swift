/// A view that presents a confirmation dialog with multiple actions.
public struct ConfirmationDialogView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let title: String
    public let message: String
    public let isPresented: Binding<Bool>
    public let onConfirm: () -> Void
    public let onCancel: (() -> Void)?

    public var body: Never { fatalError("ConfirmationDialogView is a primitive view") }
}

extension View {
    /// Present a confirmation dialog with confirm/cancel actions.
    public func confirmationDialog(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String = "",
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> ConfirmationDialogView<Self> {
        ConfirmationDialogView(
            content: self, title: title, message: message,
            isPresented: isPresented, onConfirm: onConfirm, onCancel: onCancel
        )
    }
}
