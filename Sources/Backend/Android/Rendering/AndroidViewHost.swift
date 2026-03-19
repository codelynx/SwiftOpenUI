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

    /// Set to true when a state change occurs but rebuild hasn't happened yet.
    public var needsRebuild = false

    public func scheduleRebuild() {
        // Mark that state changed. The actual rebuild is deferred to the
        // JNI caller (nativeOnButtonClick/nativeOnTextInput) to avoid
        // stack overflow from deep JNI→Swift→rebuild→render call chains.
        needsRebuild = true
    }

    public func suppressNextFocusRestore() {
        suppressFocusRestore = true
    }

    func rebuild() {
        let prev = getCurrentEnvironment()
        setCurrentEnvironment(capturedEnvironment)
        let prevHost = androidCurrentHost
        androidCurrentHost = self
        androidShouldClearFocus = suppressFocusRestore
        androidBeginRenderPass()
        pendingJSON = buildBody()
        androidCurrentHost = prevHost
        setCurrentEnvironment(prev)
        suppressFocusRestore = false
    }
}
