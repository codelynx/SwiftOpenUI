/// A modifier that presents a confirmation dialog with vertical buttons
/// when a binding becomes true.
public struct ConfirmationDialogView<Content: View>: View {
    public typealias Body = Never

    public let content: Content
    public let title: String
    public let isPresented: Binding<Bool>
    public let buttons: [AlertButton]

    public var body: Never { fatalError("ConfirmationDialogView is a primitive view") }
}

extension View {
    /// Show a confirmation dialog when `isPresented` becomes true.
    /// Buttons are displayed vertically (action sheet style).
    public func confirmationDialog(
        _ title: String,
        isPresented: Binding<Bool>,
        actions: [AlertButton]
    ) -> ConfirmationDialogView<Self> {
        ConfirmationDialogView(
            content: self,
            title: title,
            isPresented: isPresented,
            buttons: actions
        )
    }
}
