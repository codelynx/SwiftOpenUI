/// SwiftUI's `.task` — start an async task when the view appears.
///
/// Parity notes (GTK4 pilot scope):
/// - Fires ONCE per view identity (guarded by @State) — a naive onAppear
///   restart would re-run the task on every state-driven rebuild.
/// - The guard only holds where nested @State survives a PARENT host's
///   rebuild. GTK4 guarantees this via positional child-state
///   reconciliation (see GTK4ChildStateReconciliationTests); Win32/Web do
///   NOT reconcile child state yet, so `.task` can re-fire on parent
///   rebuilds there. Tracked as a cross-backend parity gap.
/// - Does NOT yet cancel on disappear (SwiftUI cancels when the view's
///   identity ends). Long-lived tasks should check Task.isCancelled and/or
///   tolerate outliving the view. Tracked as a parity gap.
public struct TaskModifierView<Content: View>: View {
    let content: Content
    let priority: TaskPriority
    let action: @Sendable () async -> Void

    @State private var hasStarted = false

    public var body: some View {
        content.onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            Task(priority: priority) { await action() }
        }
    }
}

extension View {
    public func task(
        priority: TaskPriority = .userInitiated,
        _ action: @escaping @Sendable () async -> Void
    ) -> TaskModifierView<Self> {
        TaskModifierView(content: self, priority: priority, action: action)
    }
}
