import SwiftOpenUI

/// Android ViewHost — holds the root view builder and re-renders to JSON on state change.
/// Session-scoped: survives Activity recreation. Owned by the global session, not by any Activity.
public class AndroidViewHost: AnyViewHost {
    let buildBody: () -> String
    var capturedEnvironment: EnvironmentValues

    /// After a state change triggers scheduleRebuild(), the new JSON is stored here.
    /// The JNI caller reads it after nativeOnButtonClick returns.
    public var pendingJSON: String?

    /// When true, the next rebuild should not restore focus from InputSnapshot.
    /// Set by setProgrammatic(nil) on @FocusState to actively clear focus.
    public var suppressFocusRestore: Bool = false

    public init(buildBody: @escaping () -> String) {
        self.buildBody = buildBody
        self.capturedEnvironment = getCurrentEnvironment()
    }

    public func scheduleRebuild() {
        // Synchronous rebuild — we're on the Kotlin callback thread.
        // No coalescing needed for Phase 2 (full-tree re-render).
        rebuild()
    }

    public func suppressNextFocusRestore() {
        suppressFocusRestore = true
    }

    func rebuild() {
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(capturedEnvironment)
        androidBeginRenderPass()
        pendingJSON = buildBody()
        setCurrentEnvironment(prev)
        // Reset flag after each rebuild
        suppressFocusRestore = false
    }
}
