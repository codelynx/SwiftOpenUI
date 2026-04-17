import WinSDK
import CWin32
import CWin32Bridge
import SwiftOpenUI
import Foundation
#if canImport(Observation)
import Observation
#endif

/// Hosts a stateful view's Win32 HWND subtree. The container HWND
/// is stable across re-renders; only its children are replaced.
///
/// Uses PostMessage(WM_SWIFTUI_REBUILD) for coalesced scheduling
/// instead of GTK's g_idle_add.
public class Win32ViewHost: AnyViewHost, DependencyTrackingHost {
    /// Phase 6: storages read during last body evaluation.
    public var lastReadSet: Set<ObjectIdentifier>?
    /// Phase 7: generation snapshots for input-equality short-circuiting.
    public var lastInputSnapshot: [StorageSnapshot]?

    /// The stable container HWND that persists across rebuilds.
    public let container: HWND

    /// Closure that builds the view body and returns the root child HWND.
    public let buildBody: (RenderContext) -> HWND?

    /// Closure that describes the current view body without creating HWNDs.
    public let describeBody: () -> Win32DescriptorNode

    /// The render context for creating child windows.
    private let context: RenderContext

    /// Captured environment at initial render time, restored during rebuilds.
    private var capturedEnvironment: EnvironmentValues?

    /// Objects read by body via `@Environment(Type.self)` during the
    /// last successful render. Re-pushed into the environment before
    /// each rebuild so body's lookups find the same objects even when
    /// the originating `.environment(object)` modifier lives below
    /// this ViewHost in the render tree (and therefore isn't
    /// guaranteed to re-run the push before body's next read). Filled
    /// by `endEnvironmentReadTracking()` after each buildBody.
    private var capturedInjectedObjects: [ObjectIdentifier: AnyObject] = [:]

    /// Animation captured at initial render time from a wrapping .animation()
    /// modifier. Restored during every rebuild so D2D surfaces see the
    /// animation context even though AnimatedView.winCreateWidget doesn't
    /// re-run (it's outside the host).
    private var capturedAnimation: Animation?

    /// Animation captured at scheduleRebuild time from withAnimation().
    /// Single-use: consumed during the next rebuild, then cleared.
    private var pendingAnimation: Animation?

    private let lock = NSLock()
    private var scheduled = false
    private var isContainerAlive = true
    private var suppressFocusRestoreOnce = false
    private var interactiveUpdateDepth = 0
    private var rebuildDeferredDuringInteraction = false

    /// Current child HWND inside the container.
    private var currentChild: HWND?

    /// Descriptor/executor bookkeeping for narrow text/color host integration.
    private(set) var retainedDescriptorRoot: Win32RetainedDescriptorNode?
    private(set) var retainedExecutorRoot: Win32RetainedExecutorNode?

    /// The root window to post rebuild messages to.
    private var rootWindow: HWND?

    public init(context: RenderContext,
                buildBody: @escaping (RenderContext) -> HWND?,
                describeBody: @escaping () -> Win32DescriptorNode) {
        self.context = context
        self.buildBody = buildBody
        self.describeBody = describeBody

        Win32ViewHost.registerContainerClass(hInstance: context.hInstance)

        let containerHwnd = CreateWindowExW(
            0,
            Win32ViewHost.containerClassName,
            nil,
            DWORD(WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN),
            0, 0, 0, 0,
            context.parent,
            nil,
            context.hInstance,
            nil
        )!

        self.container = containerHwnd
        markHostedNodeKind(containerHwnd, .hostContainer)

        let retained = Unmanaged.passRetained(self).toOpaque()
        win32_SetWindowLongPtrW(containerHwnd, GWLP_USERDATA, LONG_PTR(Int(bitPattern: retained)))

        self.rootWindow = findRootWindow(from: context.parent)
    }

    /// Add the initial child HWND to the container.
    /// Sizes the container to match the child's natural size.
    public func addChild(_ child: HWND) {
        currentChild = child
        SetParent(child, container)

        var childRect = RECT()
        GetWindowRect(child, &childRect)
        let w = childRect.right - childRect.left
        let h = childRect.bottom - childRect.top
        if w > 0 || h > 0 {
            SetWindowPos(container, nil, 0, 0, w, h, UINT(SWP_NOZORDER | SWP_NOMOVE))
        }
        layoutChild()
        captureRetainedDescriptorState()
    }

    /// Schedule a coalesced rebuild via PostMessage.
    public func scheduleRebuild() {
        lock.lock()
        let currentAnim = getCurrentAnimation()
        guard isContainerAlive else {
            lock.unlock()
            return
        }
        if interactiveUpdateDepth > 0 {
            rebuildDeferredDuringInteraction = true
            lock.unlock()
            return
        }
        if let currentAnim {
            pendingAnimation = currentAnim
        }
        guard !scheduled else {
            lock.unlock()
            return
        }
        scheduled = true
        lock.unlock()

        if let root = rootWindow {
            let ptr = Unmanaged.passRetained(self).toOpaque()
            PostMessageW(root, WM_SWIFTUI_REBUILD, 0, LPARAM(Int(bitPattern: ptr)))
        }
    }

    /// Defer coalesced rebuilds while an interactive control owns pointer capture.
    /// Controls still repaint locally; one rebuild is posted when interaction ends.
    public func beginInteractiveUpdate() {
        lock.lock()
        defer { lock.unlock() }
        guard isContainerAlive else { return }
        interactiveUpdateDepth += 1
    }

    public func endInteractiveUpdate() {
        lock.lock()
        guard interactiveUpdateDepth > 0 else {
            lock.unlock()
            return
        }

        interactiveUpdateDepth -= 1
        guard interactiveUpdateDepth == 0,
              rebuildDeferredDuringInteraction,
              isContainerAlive,
              !scheduled else {
            lock.unlock()
            return
        }

        rebuildDeferredDuringInteraction = false
        scheduled = true
        let root = rootWindow
        lock.unlock()

        if let root = root {
            let ptr = Unmanaged.passRetained(self).toOpaque()
            PostMessageW(root, WM_SWIFTUI_REBUILD, 0, LPARAM(Int(bitPattern: ptr)))
        }
    }

    public func suppressNextFocusRestore() {
        lock.lock()
        suppressFocusRestoreOnce = true
        lock.unlock()
    }

    /// Build the body with observation tracking for @Observable support.
    public func buildBodyWithTracking(_ context: RenderContext) -> HWND? {
        // Track `@Environment(Type.self)` reads so we can re-push the
        // same objects into env on rebuild even if the pushing
        // modifier lives below us in the render tree. Pairs with
        // `endEnvironmentReadTracking()` after body evaluates.
        beginEnvironmentReadTracking()

        #if canImport(Observation)
        if #available(macOS 14.0, iOS 17.0, *) {
            var result: HWND?
            withObservationTracking {
                result = buildBody(context)
            } onChange: { [weak self] in
                self?.scheduleRebuild()
            }
            if let reads = endEnvironmentReadTracking() {
                capturedInjectedObjects = reads
            }
            return result
        }
        #endif

        let result = buildBody(context)
        if let reads = endEnvironmentReadTracking() {
            capturedInjectedObjects = reads
        }
        return result
    }

    /// Install the captured ancestor environment plus every injected
    /// object body read during its last render. Called at each
    /// rebuild entry point instead of `setCurrentEnvironment(captured)`
    /// alone, so descendant `@Environment(Type.self)` lookups survive
    /// even when the pushing modifier lives inside a parent's body.
    func installEffectiveEnvironment() {
        guard let captured = capturedEnvironment else { return }
        var env = captured
        for (typeID, object) in capturedInjectedObjects {
            env.setObjectByID(typeID, object)
        }
        setCurrentEnvironment(env)
    }

    /// Describe the body with observation tracking for @Observable support.
    public func buildDescriptorWithTracking() -> Win32DescriptorNode {
        #if canImport(Observation)
        if #available(macOS 14.0, iOS 17.0, *) {
            var result: Win32DescriptorNode?
            withObservationTracking {
                result = describeBody()
            } onChange: { [weak self] in
                self?.scheduleRebuild()
            }
            return result ?? Win32DescriptorNode(kind: .composite, typeName: "EmptyDescriptor")
        }
        #endif
        return describeBody()
    }

    /// Capture the current environment.
    public func captureEnvironment() {
        capturedEnvironment = getCurrentEnvironment()
    }

    /// Capture the current animation context (from a wrapping .animation()).
    public func captureAnimation() {
        capturedAnimation = getCurrentAnimation()
    }

    /// Perform the rebuild.
    public func rebuild() {
        lock.lock()
        scheduled = false
        guard isContainerAlive else {
            lock.unlock()
            return
        }
        let shouldSuppressFocus = suppressFocusRestoreOnce
        suppressFocusRestoreOnce = false
        lock.unlock()

        // Phase 7: skip rebuild entirely if no tracked inputs changed.
        // This avoids body evaluation, HWND destruction, and repainting
        // when the state change that triggered this rebuild didn't affect
        // any storage read during the last body evaluation.
        if let snapshot = lastInputSnapshot,
           inputsUnchanged(snapshot: snapshot) {
            return
        }

        SendMessageW(container, UINT(WM_SETREDRAW), 0, 0)

        let inputState = saveInputState(in: container)

        let previousEnv = getCurrentEnvironment()
        defer { setCurrentEnvironment(previousEnv) }
        installEffectiveEnvironment()

        // Restore animation context for this rebuild.
        // Priority: withAnimation() pending token (one-shot from scheduleRebuild)
        // then .animation() wrapper (persistent from initial render).
        let previousAnim = getCurrentAnimation()
        let rebuildAnim = pendingAnimation ?? capturedAnimation
        pendingAnimation = nil
        if let rebuildAnim {
            setCurrentAnimation(rebuildAnim)
        }
        defer { setCurrentAnimation(previousAnim) }

        defer {
            restoreEditStates(inputState.editStates, in: container)

            if !shouldSuppressFocus {
                restoreFocus(inputState.focus, in: container)
            }

            SendMessageW(container, UINT(WM_SETREDRAW), 1, 0)
            RedrawWindow(container, nil, nil,
                         UINT(RDW_ERASE | RDW_FRAME | RDW_INVALIDATE | RDW_ALLCHILDREN))
        }

        if tryTextColorMutationRebuild() {
            return
        }

        if let oldChild = currentChild {
            DestroyWindow(oldChild)
            currentChild = nil
        }

        let childContext = RenderContext(parent: container, hInstance: context.hInstance)

        // Phase 6+7: track which storages are read during body evaluation
        resetOnChangeTracking()
        // ID registry not cleared — global, overwrite + liveness handles stale entries
        beginDependencyTracking()
        let newChild = buildBodyWithTracking(childContext)
        if let tracking = endDependencyTracking() {
            lastReadSet = tracking.readSet
            lastInputSnapshot = tracking.snapshots
        }

        if let newChild = newChild {
            currentChild = newChild
            layoutChild()
            captureRetainedDescriptorState()
        } else {
            retainedDescriptorRoot = nil
            retainedExecutorRoot = nil
        }
    }

    /// Layout the current child to fill the container.
    func layoutChild() {
        guard let child = currentChild else { return }
        var rect = RECT()
        GetClientRect(container, &rect)
        SetWindowPos(child, nil, 0, 0, rect.right - rect.left, rect.bottom - rect.top, UINT(SWP_NOZORDER))
    }

    private func captureRetainedDescriptorState() {
        guard let child = currentChild else {
            retainedDescriptorRoot = nil
            retainedExecutorRoot = nil
            return
        }

        // Descriptor capture can re-enter body after the initial child HWND
        // tree has already been created. Re-install the host's effective
        // environment so `@Environment(Type.self)` lookups see the same
        // injected objects that body read during `buildBodyWithTracking()`.
        let previousEnvForDesc = getCurrentEnvironment()
        installEffectiveEnvironment()
        let identified = winIdentifyDescriptorTree(describeBody())
        setCurrentEnvironment(previousEnvForDesc)
        retainedDescriptorRoot = winRetainDescriptorTree(identified)
        let executorRoot = winMakeExecutorTree(from: identified)
        retainedExecutorRoot = winCaptureSupportedNativeSlots(
            from: child,
            descriptorRoot: identified,
            executorRoot: executorRoot
        )
    }

    private func tryTextColorMutationRebuild() -> Bool {
        guard currentChild != nil,
              let retainedDescriptorRoot,
              let retainedExecutorRoot else {
            return false
        }

        let identified = winIdentifyDescriptorTree(buildDescriptorWithTracking())
        let plan = winPlanDescriptorTree(old: retainedDescriptorRoot, new: identified)
        guard winCanApplyTextColorHostMutation(plan: plan) else {
            return false
        }

        let action = winExecuteDescriptorPlan(old: retainedExecutorRoot, plan: plan)
        // Validate all target HWNDs are still alive before mutating
        guard winAllSlotsValid(action: action) else {
            return false
        }
        let hookResult = winApplyHookMutation(action: action)
        guard winHookMutationSucceeded(hookResult) else {
            return false
        }
        self.retainedDescriptorRoot = winRetainDescriptorTree(identified)
        self.retainedExecutorRoot = action.resultingNode
        return true
    }

    /// Called when the container is about to be destroyed.
    public func markDestroyed() {
        lock.lock()
        isContainerAlive = false
        scheduled = false
        interactiveUpdateDepth = 0
        rebuildDeferredDuringInteraction = false
        lastReadSet = nil
        lastInputSnapshot = nil
        lock.unlock()
    }

    private static let containerClassName: UnsafePointer<WCHAR> = {
        "SwiftUIContainer".withCString(encodedAs: UTF16.self) { ptr in
            let len = wcslen(ptr) + 1
            let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
            buf.initialize(from: ptr, count: len)
            return UnsafePointer(buf)
        }
    }()

    private static var classRegistered = false
    private static let classLock = NSLock()

    private static func registerContainerClass(hInstance: HINSTANCE) {
        classLock.lock()
        defer { classLock.unlock() }
        guard !classRegistered else { return }
        classRegistered = true

        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.style = UINT(CS_HREDRAW | CS_VREDRAW)
        wc.lpfnWndProc = containerWndProc
        wc.hInstance = hInstance
        wc.hbrBackground = GetSysColorBrush(COLOR_WINDOW)
        wc.lpszClassName = containerClassName

        RegisterClassExW(&wc)
    }
}

func findContainingViewHost(from hwnd: HWND?) -> Win32ViewHost? {
    var current = hwnd
    while let window = current {
        if getWindowClassName(window) == "SwiftUIContainer" {
            let userData = win32_GetWindowLongPtrW(window, GWLP_USERDATA)
            if userData != 0 {
                return Unmanaged<Win32ViewHost>.fromOpaque(
                    UnsafeMutableRawPointer(bitPattern: Int(userData))!
                ).takeUnretainedValue()
            }
        }
        current = GetParent(window)
    }
    return nil
}

private let containerWndProc: WNDPROC = { (hwnd, uMsg, wParam, lParam) in
    switch uMsg {
    case UINT(WM_SIZE):
        if let host = findContainingViewHost(from: hwnd) {
            host.layoutChild()
        }
        return 0

    case UINT(WM_COMMAND):
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            SendMessageW(childHwnd, uMsg, wParam, lParam)
        }
        let root = findRootWindow(from: hwnd!)
        return SendMessageW(root, uMsg, wParam, lParam)

    case UINT(WM_HSCROLL), UINT(WM_VSCROLL):
        if lParam != 0, let childHwnd = HWND(bitPattern: Int(lParam)) {
            return SendMessageW(childHwnd, uMsg, wParam, lParam)
        }
        return 0

    case UINT(WM_ERASEBKGND):
        return eraseWithInheritedBackground(hwnd: hwnd!, wParam: wParam)

    case UINT(WM_CTLCOLORSTATIC), UINT(WM_CTLCOLORBTN):
        if let parent = GetParent(hwnd!) {
            return SendMessageW(parent, uMsg, wParam, lParam)
        }
        let hdc = HDC(bitPattern: Int(bitPattern: UInt(wParam)))
        SetBkMode(hdc, TRANSPARENT)
        return LRESULT(Int(bitPattern: GetSysColorBrush(COLOR_WINDOW)))

    case UINT(WM_NCDESTROY):
        let userData = win32_GetWindowLongPtrW(hwnd!, GWLP_USERDATA)
        if userData != 0 {
            let host = Unmanaged<Win32ViewHost>.fromOpaque(
                UnsafeMutableRawPointer(bitPattern: Int(userData))!
            ).takeRetainedValue()
            host.markDestroyed()
            win32_SetWindowLongPtrW(hwnd!, GWLP_USERDATA, 0)
        }
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)

    default:
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
}

// MARK: - Input state save/restore across rebuilds

struct FocusSnapshot {
    let className: String
    let classIndex: Int
    let selStart: Int
    let selEnd: Int
    let hasFocus: Bool
}

struct EditControlSnapshot {
    let index: Int
    let selStart: Int
    let selEnd: Int
}

struct InputStateSnapshot {
    let focus: FocusSnapshot
    let editStates: [EditControlSnapshot]
}

func saveInputState(in container: HWND) -> InputStateSnapshot {
    let focus: FocusSnapshot
    if let focused = GetFocus(), IsChild(container, focused) {
        let className = getWindowClassName(focused)
        let classIndex = findClassIndex(hwnd: focused, in: container, className: className)

        var selStart: Int = 0
        var selEnd: Int = 0
        if className == "Edit" {
            let sel = SendMessageW(focused, UINT(EM_GETSEL), 0, 0)
            selStart = Int(win32_LOWORD(DWORD_PTR(sel)))
            selEnd = Int(win32_HIWORD(DWORD_PTR(sel)))
        }
        focus = FocusSnapshot(className: className, classIndex: classIndex,
                              selStart: selStart, selEnd: selEnd, hasFocus: true)
    } else {
        focus = FocusSnapshot(className: "", classIndex: 0, selStart: 0, selEnd: 0, hasFocus: false)
    }

    var editControls: [HWND] = []
    collectControlsByClass(parent: container, className: "Edit", into: &editControls)

    var editStates: [EditControlSnapshot] = []
    for (i, edit) in editControls.enumerated() {
        let sel = SendMessageW(edit, UINT(EM_GETSEL), 0, 0)
        let selStart = Int(win32_LOWORD(DWORD_PTR(sel)))
        let selEnd = Int(win32_HIWORD(DWORD_PTR(sel)))
        editStates.append(EditControlSnapshot(index: i, selStart: selStart, selEnd: selEnd))
    }

    return InputStateSnapshot(focus: focus, editStates: editStates)
}

func restoreEditStates(_ editStates: [EditControlSnapshot], in parent: HWND) {
    var editControls: [HWND] = []
    collectControlsByClass(parent: parent, className: "Edit", into: &editControls)

    for editState in editStates {
        guard editState.index < editControls.count else { continue }
        let edit = editControls[editState.index]
        SendMessageW(edit, UINT(EM_SETSEL),
                     WPARAM(editState.selStart), LPARAM(editState.selEnd))
    }
}

func restoreFocus(_ snapshot: FocusSnapshot, in parent: HWND) {
    guard snapshot.hasFocus else { return }
    if let target = findNthControlByClass(className: snapshot.className,
                                          index: snapshot.classIndex, in: parent) {
        SetFocus(target)
        if snapshot.className == "Edit" {
            SendMessageW(target, UINT(EM_SETSEL),
                         WPARAM(snapshot.selStart), LPARAM(snapshot.selEnd))
        }
    }
}

private func getWindowClassName(_ hwnd: HWND) -> String {
    let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: 256)
    defer { buffer.deallocate() }
    let length = GetClassNameW(hwnd, buffer, 256)
    guard length > 0 else { return "" }
    return String(decodingCString: buffer, as: UTF16.self)
}

private func findClassIndex(hwnd target: HWND, in parent: HWND, className: String) -> Int {
    var controls: [HWND] = []
    collectControlsByClass(parent: parent, className: className, into: &controls)
    return controls.firstIndex(of: target) ?? 0
}

private func findNthControlByClass(className: String, index: Int, in parent: HWND) -> HWND? {
    var controls: [HWND] = []
    collectControlsByClass(parent: parent, className: className, into: &controls)
    guard index < controls.count else { return nil }
    return controls[index]
}

private func collectControlsByClass(parent: HWND, className: String, into result: inout [HWND]) {
    var child = GetWindow(parent, UINT(GW_CHILD))
    while let c = child {
        if getWindowClassName(c) == className {
            result.append(c)
        }
        collectControlsByClass(parent: c, className: className, into: &result)
        child = GetWindow(c, UINT(GW_HWNDNEXT))
    }
}
