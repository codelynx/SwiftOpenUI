import JavaScriptKit
import SwiftOpenUI
#if canImport(Observation)
import Observation
#endif

/// Web-specific ViewHost that manages a stable DOM container element.
/// On state change, rebuilds the body and swaps children.
/// Supports narrow mutation path for text/color in-place updates.
public class WebViewHost: AnyViewHost, DependencyTrackingHost {
    public var lastReadSet: Set<ObjectIdentifier>?
    let container: JSValue
    let buildBody: () -> JSValue
    /// Describes the body as a descriptor tree without creating DOM elements.
    var describeBody: (() -> WebDescriptorNode)?
    /// Retained descriptor state for narrow mutation path.
    var lastRetainedDescriptor: WebRetainedDescriptorNode?
    var retainedExecutor: WebRetainedExecutorNode?
    /// Per-host slot table — isolates slot ownership so rebuilding
    /// one host does not invalidate slots for unrelated hosts.
    let slotTable = WebSlotTable()
    private var scheduled = false
    private var interactiveUpdateDepth = 0
    private var rebuildDeferredDuringInteraction = false
    var capturedEnvironment: EnvironmentValues

    public init(buildBody: @escaping () -> JSValue) {
        self.buildBody = buildBody
        self.capturedEnvironment = getCurrentEnvironment()
        self.container = document.createElement("div")
    }

    public func scheduleRebuild() {
        // Defer rebuild while interactive (e.g. slider drag)
        if interactiveUpdateDepth > 0 {
            rebuildDeferredDuringInteraction = true
            return
        }

        guard !scheduled else { return }
        scheduled = true

        // Use requestAnimationFrame for coalesced rebuilds
        let callback = JSClosure { [weak self] _ in
            self?.rebuild()
            return .undefined
        }
        _ = JSObject.global.requestAnimationFrame!(callback)
    }

    public func beginInteractiveUpdate() {
        interactiveUpdateDepth += 1
    }

    public func endInteractiveUpdate() {
        guard interactiveUpdateDepth > 0 else { return }
        interactiveUpdateDepth -= 1
        guard interactiveUpdateDepth == 0,
              rebuildDeferredDuringInteraction,
              !scheduled else { return }

        rebuildDeferredDuringInteraction = false
        scheduled = true

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
        if #available(macOS 14.0, iOS 17.0, *) {
            var result: JSValue = .undefined
            withObservationTracking {
                result = buildBody()
            } onChange: { [weak self] in
                self?.scheduleRebuild()
            }
            return result
        }
        #endif
        return buildBody()
    }

    func rebuild() {
        scheduled = false

        // --- Narrow mutation path: try text/color in-place update ---
        if let describeBody = describeBody,
           let oldRetained = lastRetainedDescriptor,
           let oldExecutor = retainedExecutor {

            let previousEnv = getCurrentEnvironment()
            setCurrentEnvironment(capturedEnvironment)
            let newDescriptor = describeBody()
            setCurrentEnvironment(previousEnv)

            let newIdentified = webIdentifyDescriptorTree(newDescriptor)
            let plan = webPlanDescriptorTree(old: oldRetained, new: newIdentified)

            if webCanApplyTextColorHostMutation(plan: plan) {
                let action = webExecuteDescriptorPlan(old: oldExecutor, plan: plan)

                // Set this host's slot table as current for validation + mutation
                _webCurrentSlotTable = slotTable
                defer { _webCurrentSlotTable = nil }

                // Verify all slots are still valid before mutating
                if webAllSlotsValid(action: action) {
                    let result = webApplyHookMutation(action: action)
                    if webHookMutationSucceeded(result) {
                        // Success — update retained state, skip full rebuild
                        lastRetainedDescriptor = webRetainDescriptorTree(newIdentified)
                        retainedExecutor = action.resultingNode
                        return
                    }
                }
            }
            // Fall through to full rebuild
        }

        // Release closures from the previous render pass
        _webRetainedClosures.removeAll()

        // Clear this host's slot table — old DOM elements are about to be destroyed
        slotTable.clear()

        // Remove old children
        container.innerHTML = ""

        // Set up rebuild context
        let previousHost = WebViewHost.currentRebuilding
        WebViewHost.currentRebuilding = self

        let previousEnv = getCurrentEnvironment()
        setCurrentEnvironment(capturedEnvironment)
        beginDependencyTracking()
        let element = buildBodyWithTracking()
        lastReadSet = endDependencyTracking()
        setCurrentEnvironment(previousEnv)

        WebViewHost.currentRebuilding = previousHost

        _ = container.appendChild(element)

        // Capture descriptor state for next rebuild's narrow mutation path
        if let describeBody = describeBody {
            let previousEnvForDesc = getCurrentEnvironment()
            setCurrentEnvironment(capturedEnvironment)
            let descriptor = describeBody()
            setCurrentEnvironment(previousEnvForDesc)

            let identified = webIdentifyDescriptorTree(descriptor)
            lastRetainedDescriptor = webRetainDescriptorTree(identified)
            var executor = webMakeExecutorTree(from: identified)
            _webCurrentSlotTable = slotTable
            executor = webCaptureSupportedNativeSlots(
                from: container,
                descriptorRoot: identified,
                executorRoot: executor
            )
            _webCurrentSlotTable = nil
            retainedExecutor = executor
        }
    }

    // MARK: - Rebuild context

    static var currentRebuilding: WebViewHost?
}

/// Render a stateful composite view wrapped in a WebViewHost.
public func webRenderStatefulView<V: View>(_ view: V) -> JSValue {
    let mutableView = view

    // Install mutation hooks on first use
    webInstallMutationHooks()

    let host = WebViewHost {
        webRenderView(mutableView.body)
    }
    host.describeBody = {
        webDescribeView(mutableView.body)
    }
    installState(mutableView, host: host)

    // Retain the host so it survives beyond this function.
    // Without this, the host is deallocated and scheduleRebuild
    // (via requestAnimationFrame) finds a nil weak self.
    _webRetainedHosts.append(host)

    // Initial render — set currentRebuilding so child views (e.g. Slider)
    // can find their containing host for interactive update hooks.
    let previousHost = WebViewHost.currentRebuilding
    WebViewHost.currentRebuilding = host

    let previousEnv = getCurrentEnvironment()
    host.capturedEnvironment = previousEnv
    beginDependencyTracking()
    let element = host.buildBodyWithTracking()
    host.lastReadSet = endDependencyTracking()
    _ = host.container.appendChild(element)

    WebViewHost.currentRebuilding = previousHost

    // Capture initial descriptor state for narrow mutation path
    let descriptor = webDescribeView(mutableView.body)
    let identified = webIdentifyDescriptorTree(descriptor)
    host.lastRetainedDescriptor = webRetainDescriptorTree(identified)
    var executor = webMakeExecutorTree(from: identified)
    _webCurrentSlotTable = host.slotTable
    executor = webCaptureSupportedNativeSlots(
        from: host.container,
        descriptorRoot: identified,
        executorRoot: executor
    )
    _webCurrentSlotTable = nil
    host.retainedExecutor = executor

    return host.container
}
