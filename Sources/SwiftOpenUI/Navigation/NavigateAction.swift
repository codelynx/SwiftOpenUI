/// A callable action for programmatic navigation, available via `@Environment(\.navigate)`.
///
/// ```swift
/// @Environment(\.navigate) var navigate
///
/// Button("Go to Detail") {
///     navigate.push("detail-1")
/// }
/// ```
public struct NavigateAction {
    let pushHandler: (AnyHashable) -> Void
    let popHandler: () -> Void
    let popToRootHandler: () -> Void

    public init(
        push: @escaping (AnyHashable) -> Void = { _ in },
        pop: @escaping () -> Void = {},
        popToRoot: @escaping () -> Void = {}
    ) {
        self.pushHandler = push
        self.popHandler = pop
        self.popToRootHandler = popToRoot
    }

    /// Push a hashable value onto the navigation stack.
    /// Resolves the destination via `.navigationDestination(for:)`.
    public func push<V: Hashable>(_ value: V) {
        pushHandler(AnyHashable(value))
    }

    /// Pop the top view from the navigation stack.
    public func pop() {
        popHandler()
    }

    /// Pop to the root view.
    public func popToRoot() {
        popToRootHandler()
    }
}

/// Environment key for the navigate action.
public struct NavigateKey: EnvironmentKey {
    public static let defaultValue: NavigateAction = NavigateAction()
}

extension EnvironmentValues {
    /// Action for programmatic push/pop navigation inside a NavigationStack.
    public var navigate: NavigateAction {
        get { self[NavigateKey.self] }
        set { self[NavigateKey.self] = newValue }
    }
}
