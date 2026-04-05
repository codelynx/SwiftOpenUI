/// Trigger for submit actions.
public enum SubmitTriggers: Equatable {
    case text
    case search
}

/// Action to fire when the user submits (e.g., presses Return).
public struct SubmitAction {
    public let handler: () -> Void

    public init(handler: @escaping () -> Void = {}) {
        self.handler = handler
    }

    public func callAsFunction() {
        handler()
    }
}

/// Environment key for the submit action.
struct SubmitActionKey: EnvironmentKey {
    static let defaultValue: SubmitAction? = nil
}

extension EnvironmentValues {
    public var submitAction: SubmitAction? {
        get { self[SubmitActionKey.self] }
        set { self[SubmitActionKey.self] = newValue }
    }
}

/// Sets a submit action on the content. Text fields within the
/// content will fire this action when the user presses Return.
public struct OnSubmitView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public let content: Content
    public let triggers: SubmitTriggers
    public let action: () -> Void

    public var body: Never { fatalError() }
}

extension View {
    /// Adds an action to perform when the user submits a value.
    public func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping () -> Void) -> OnSubmitView<Self> {
        OnSubmitView(content: self, triggers: triggers, action: action)
    }
}
