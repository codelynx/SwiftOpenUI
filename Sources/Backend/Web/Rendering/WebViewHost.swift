import JavaScriptKit
import SwiftOpenUI
#if canImport(Observation)
import Observation
#endif

/// Web-specific ViewHost that manages a stable DOM container element.
/// On state change, rebuilds the body and swaps children.
public class WebViewHost: AnyViewHost {
    let container: JSValue
    let buildBody: () -> JSValue
    private var scheduled = false
    var capturedEnvironment: EnvironmentValues

    public init(buildBody: @escaping () -> JSValue) {
        self.buildBody = buildBody
        self.capturedEnvironment = getCurrentEnvironment()
        self.container = document.createElement("div")
    }

    public func scheduleRebuild() {
        guard !scheduled else { return }
        scheduled = true

        // Use requestAnimationFrame for coalesced rebuilds
        let callback = JSClosure { [weak self] _ in
            self?.rebuild()
            return .undefined
        }
        _ = JSObject.global.requestAnimationFrame!(callback)
    }

    public func suppressNextFocusRestore() {
        // No-op for web — browser handles focus
    }

    /// Build the body with observation tracking for @Observable support.
    func buildBodyWithTracking() -> JSValue {
        #if canImport(Observation)
        var result: JSValue = .undefined
        withObservationTracking {
            result = buildBody()
        } onChange: { [weak self] in
            self?.scheduleRebuild()
        }
        return result
        #else
        return buildBody()
        #endif
    }

    func rebuild() {
        scheduled = false

        // Release closures from the previous render pass
        _webRetainedClosures.removeAll()

        // Remove old children
        container.innerHTML = ""

        // Set up rebuild context
        let previousHost = WebViewHost.currentRebuilding
        WebViewHost.currentRebuilding = self

        let previousEnv = getCurrentEnvironment()
        setCurrentEnvironment(capturedEnvironment)
        let element = buildBodyWithTracking()
        setCurrentEnvironment(previousEnv)

        WebViewHost.currentRebuilding = previousHost

        _ = container.appendChild(element)
    }

    // MARK: - Rebuild context

    static var currentRebuilding: WebViewHost?
}

/// Render a stateful composite view wrapped in a WebViewHost.
public func webRenderStatefulView<V: View>(_ view: V) -> JSValue {
    let mutableView = view
    let host = WebViewHost {
        webRenderView(mutableView.body)
    }
    installState(mutableView, host: host)

    // Retain the host so it survives beyond this function.
    // Without this, the host is deallocated and scheduleRebuild
    // (via requestAnimationFrame) finds a nil weak self.
    _webRetainedHosts.append(host)

    // Initial render
    let previousEnv = getCurrentEnvironment()
    host.capturedEnvironment = previousEnv
    let element = host.buildBodyWithTracking()
    _ = host.container.appendChild(element)

    return host.container
}
