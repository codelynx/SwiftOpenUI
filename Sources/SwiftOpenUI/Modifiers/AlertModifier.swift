import Foundation

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

private func makeErrorAlertTitleAndMessage(from error: any Error) -> (title: String, message: String) {
    if let localized = error as? LocalizedError {
        let fallbackTitle = String(describing: type(of: error))
        let localizedDescription = error.localizedDescription
        let title = localized.errorDescription ?? (localizedDescription.isEmpty ? fallbackTitle : localizedDescription)

        var messageParts: [String] = []
        if let failureReason = localized.failureReason, !failureReason.isEmpty {
            messageParts.append(failureReason)
        }
        if let recoverySuggestion = localized.recoverySuggestion, !recoverySuggestion.isEmpty {
            messageParts.append(recoverySuggestion)
        }

        let message = messageParts.joined(separator: "\n")
        if !message.isEmpty {
            return (title, message)
        }

        if !localizedDescription.isEmpty && localizedDescription != title {
            return (title, localizedDescription)
        }

        return (title, "")
    }

    let title = error.localizedDescription.isEmpty
        ? String(describing: type(of: error))
        : error.localizedDescription
    return (title, "")
}

extension View {
    /// Present an alert dialog when `isPresented` becomes true.
    public func alert(
        _ title: String,
        isPresented: Binding<Bool>,
        actions: [AlertButton]
    ) -> AlertModifierView<Self> {
        AlertModifierView(
            content: self,
            isPresented: isPresented,
            title: title,
            message: "",
            buttons: actions
        )
    }

    /// Present an alert dialog when `isPresented` becomes true.
    public func alert(
        _ title: String,
        isPresented: Binding<Bool>,
        actions: [AlertButton],
        message: String
    ) -> AlertModifierView<Self> {
        AlertModifierView(
            content: self,
            isPresented: isPresented,
            title: title,
            message: message,
            buttons: actions
        )
    }

    /// Present an alert dialog when `isPresented` becomes true.
    public func alert(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String = "",
        actions: [AlertButton] = [AlertButton("OK")]
    ) -> AlertModifierView<Self> {
        AlertModifierView(
            content: self,
            isPresented: isPresented,
            title: title,
            message: message,
            buttons: actions
        )
    }

    /// Present an alert dialog for an error when `isPresented` becomes true.
    public func alert<E>(
        isPresented: Binding<Bool>,
        error: E?,
        actions: (E) -> [AlertButton] = { _ in [AlertButton("OK")] }
    ) -> AlertModifierView<Self> where E: Error {
        let resolved = error.map { makeErrorAlertTitleAndMessage(from: $0) }
        let effectivePresented = Binding(
            get: { isPresented.wrappedValue && error != nil },
            set: { newValue in isPresented.wrappedValue = newValue }
        )

        return AlertModifierView(
            content: self,
            isPresented: effectivePresented,
            title: resolved?.title ?? "",
            message: resolved?.message ?? "",
            buttons: error.map(actions) ?? [AlertButton("OK")]
        )
    }
}
