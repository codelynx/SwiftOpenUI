import JavaScriptKit
import SwiftOpenUI

// MARK: - JSClosure lifetime management

/// Fallback for closures created outside any WebViewHost (e.g. at the root of the app).
private var _webFallbackRetainedClosures: [JSClosure] = []

/// Create a JSClosure and capture the current host context.
/// When the closure executes, it restores the host context so any
/// late-bound closures (e.g. from timers) are correctly retained by the host.
public func webMakeClosure(_ handler: @escaping ([JSValue]) -> JSValue) -> JSClosure {
    let host = WebViewHost.currentRebuilding
    let closure = JSClosure { args in
        if let host = host {
            return WebViewHost.withHost(host) { handler(args) }
        } else {
            return handler(args)
        }
    }
    webRetainClosure(closure)
    return closure
}

/// Retain a JSClosure so it lives as long as its DOM element.
/// Uses the current WebViewHost if one is active, otherwise falls back to a global bucket.
func webRetainClosure(_ closure: JSClosure) {
    if let host = WebViewHost.currentRebuilding {
        host.retainedClosures.append(closure)
    } else {
        _webFallbackRetainedClosures.append(closure)
    }
}

/// Clear the fallback closure bucket. Used after initial app render.
func webClearFallbackClosures() {
    _webFallbackRetainedClosures.removeAll()
}

/// Ensure global CSS for List row borders is present in the document.
private var _webListStylesInstalled = false
func webEnsureListRowStyles() {
    guard !_webListStylesInstalled else { return }
    _webListStylesInstalled = true

    let style = document.createElement("style")
    style.textContent = """
        .swiftopenui-list-row:not(:last-child) {
            border-bottom: 1px solid #333;
        }
    """
    _ = document.head.appendChild(style)
}

/// Retains WebViewHost instances so they survive for the lifetime of the app.
/// Without this, WebViewHost is deallocated after webRenderStatefulView returns,
/// and scheduleRebuild's requestAnimationFrame callback finds a nil weak self.
var _webRetainedHosts: [WebViewHost] = []

// MARK: - Hosted-node tagging

/// Tag a DOM element with its hosted kind for slot capture.
func webMarkHostedNodeKind(_ element: JSValue, kind: WebHostedNodeKind) {
    _ = element.setAttribute("data-hosted-kind", kind.rawValue)
}

/// Read the hosted kind from a tagged DOM element.
func webHostedNodeKind(of element: JSValue) -> WebHostedNodeKind {
    guard let attr = element.getAttribute("data-hosted-kind").string else { return .unknown }
    return WebHostedNodeKind(rawValue: attr) ?? .unknown
}

// MARK: - Web rendering protocol

/// Protocol that views implement (via extensions) to provide DOM element creation.
public protocol WebRenderable {
    func webCreateElement() -> JSValue
}

/// Protocol for views that provide multiple DOM child elements.
public protocol WebMultiChildRenderable {
    func webForEachChild(_ body: (JSValue) -> Void)
}

// MARK: - Rendering dispatch

let document = JSObject.global.document

/// Render any SwiftOpenUI View into a DOM element.
public func webRenderView<V: View>(_ view: V) -> JSValue {
    // Primitive views with known DOM rendering
    if let renderable = view as? WebRenderable {
        return renderable.webCreateElement()
    }

    // Composite view with reactive state — wrap in WebViewHost
    if hasReactiveProperties(view) {
        return webRenderStatefulView(view)
    }

    // Stateless composite view — recurse through body
    return webRenderView(view.body)
}

/// Call a closure for each child of a view, avoiding intermediate array allocations.
public func webRenderChildren<V: View>(_ view: V, _ body: (JSValue) -> Void) {
    if let multi = view as? WebMultiChildRenderable {
        multi.webForEachChild(body)
        return
    }
    if let multi = view as? MultiChildView {
        for child in multi.children {
            func render<C: View>(_ c: C) -> JSValue { webRenderView(c) }
            body(render(child))
        }
        return
    }
    body(webRenderView(view))
}

/// Render an existential (any View).
public func webRenderAnyView(_ view: any View) -> JSValue {
    func render<V: View>(_ v: V) -> JSValue { webRenderView(v) }
    return render(view)
}

/// Flatten a view's children into an array of existential views.
public func flattenChildren<V: View>(_ view: V) -> [any View] {
    if let multi = view as? any TransparentMultiChildView {
        return multi.children
    }
    return [view]
}

// MARK: - Primitive view extensions

extension Text: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        let span = document.createElement("span")
        span.textContent = .string(content)
        webMarkHostedNodeKind(span, kind: .text)
        return span
    }

    public func webDescribeNode() -> WebDescriptorNode {
        WebDescriptorNode(kind: .text, typeName: "Text",
                          props: .text(WebTextDescriptor(content: content)))
    }
}

extension EmptyView: WebRenderable {
    public func webCreateElement() -> JSValue {
        return document.createElement("span")
    }
}

extension Spacer: WebRenderable, WebDescribable {
    public func webDescribeNode() -> WebDescriptorNode {
        WebDescriptorNode(kind: .spacer, typeName: "Spacer")
    }

    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = "flex: 1;"
        return div
    }
}

extension SwiftOpenUI.Divider: WebRenderable, WebDescribable {
    public func webDescribeNode() -> WebDescriptorNode {
        WebDescriptorNode(kind: .divider, typeName: "Divider")
    }

    public func webCreateElement() -> JSValue {
        let hr = document.createElement("hr")
        hr.style = "border: none; border-top: 1px solid #ccc; margin: 4px 0; width: 100%;"
        return hr
    }
}

/// Flag to suppress input handler during programmatic value updates.
private var _webSuppressInputHandler = false

extension SwiftOpenUI.TextField: WebRenderable {
    public func webCreateElement() -> JSValue {
        let input = document.createElement("input")
        input.type = "text"
        input.value = .string(text.wrappedValue)
        input.placeholder = .string(title)
        input.style = "padding: 6px 8px; font-size: 16px; width: 100%; box-sizing: border-box;"

        // Wire text changes back through Binding<String>
        let binding = text
        let handler = webMakeClosure { _ in
            guard !_webSuppressInputHandler else { return .undefined }
            let newValue = input.value.string ?? ""
            if newValue != binding.wrappedValue {
                binding.wrappedValue = newValue
            }
            return .undefined
        }
        _ = input.addEventListener("input", handler)

        return input
    }
}

extension FocusedView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)

        // Wire DOM focus/blur to update @FocusState<Bool>
        let storage = focusState.storage
        let focusHandler = webMakeClosure { _ in
            storage.setValue(true)
            return .undefined
        }
        let blurHandler = webMakeClosure { _ in
            storage.setValue(false)
            return .undefined
        }
        _ = child.addEventListener("focus", focusHandler)
        _ = child.addEventListener("blur", blurHandler)

        // Handle programmatic focus changes
        let childRef = child
        storage.addPlatformFocusCallback(key: AnyHashable(ObjectIdentifier(storage))) { newValue in
            if let focused = newValue {
                if focused {
                    _ = childRef.focus()
                } else {
                    _ = childRef.blur()
                }
            }
        }

        // Apply initial focus if already set
        if focusState.wrappedValue {
            // Defer focus to after DOM insertion
            let applyFocus = webMakeClosure { _ in
                _ = childRef.focus()
                return .undefined
            }
            _ = JSObject.global.requestAnimationFrame!(applyFocus)
        }

        return child
    }
}

extension FocusedEqualsView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)

        // Wire DOM focus/blur to update @FocusState<Value?>
        let storage = focusState.storage
        let matchValue = value
        let focusHandler = webMakeClosure { _ in
            storage.setValue(matchValue)
            return .undefined
        }
        let blurHandler = webMakeClosure { _ in
            // Only clear if we're still the focused field
            if storage.value == matchValue {
                storage.setValue(nil)
            }
            return .undefined
        }
        _ = child.addEventListener("focus", focusHandler)
        _ = child.addEventListener("blur", blurHandler)

        // Handle programmatic focus changes
        let childRef = child
        storage.addPlatformFocusCallback(key: AnyHashable(matchValue)) { newValue in
            if newValue == matchValue {
                _ = childRef.focus()
            } else {
                _ = childRef.blur()
            }
        }

        // Apply initial focus if already set to our value
        if focusState.wrappedValue == value {
            let applyFocus = webMakeClosure { _ in
                _ = childRef.focus()
                return .undefined
            }
            _ = JSObject.global.requestAnimationFrame!(applyFocus)
        }

        return child
    }
}

// MARK: - Animation modifier views

extension OpacityView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let wrapper = document.createElement("div")
        wrapper.style = .string("display: inline-block; opacity: \(opacity);")
        _ = wrapper.appendChild(child)
        return wrapper
    }
}

extension OffsetView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let wrapper = document.createElement("div")
        wrapper.style = .string("display: inline-block; transform: translate(\(x)px, \(y)px);")
        _ = wrapper.appendChild(child)
        return wrapper
    }
}

extension ScaleEffectView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let wrapper = document.createElement("div")
        let scale = scaleX == scaleY ? "scale(\(scaleX))" : "scale(\(scaleX), \(scaleY))"
        wrapper.style = .string("display: inline-block; transform: \(scale); transform-origin: center;")
        _ = wrapper.appendChild(child)
        return wrapper
    }
}

extension AnimatedView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let element = webRenderView(content)
        if let anim = animation ?? getCurrentAnimation() {
            let timing: String
            switch anim.curve {
            case .linear: timing = "linear"
            case .easeIn: timing = "ease-in"
            case .easeOut: timing = "ease-out"
            case .easeInOut: timing = "ease-in-out"
            case .spring: timing = "cubic-bezier(0.5, 1.8, 0.3, 0.8)"
            }
            _ = element.style.setProperty("transition", "all \(anim.duration)s \(timing)")
        }
        return element
    }
}

// MARK: - Navigation views

/// Destination registry for type-based path navigation.
private class WebDestinationRegistry {
    private var factories: [(type: Any.Type, factory: (AnyHashable) -> JSValue?)] = []

    func register<V: Hashable>(for type: V.Type, factory: @escaping (V) -> JSValue) {
        factories.append((type: V.self, factory: { value in
            guard let typed = value.base as? V else { return nil }
            return factory(typed)
        }))
    }

    func resolve(_ value: AnyHashable) -> JSValue? {
        for entry in factories {
            if let result = entry.factory(value) {
                return result
            }
        }
        return nil
    }
}

/// Thread-local navigation context for the Web backend.
/// Manages a stack of DOM elements with push/pop transitions and path binding sync.
private class WebNavigationContext {
    let container: JSValue         // outer div
    let headerTitle: JSValue       // <span> for title text
    let backButton: JSValue        // <button> Back
    let contentArea: JSValue       // div holding current page
    var stack: [(element: JSValue, title: String)] = []
    var pathBinding: Binding<NavigationPath>?
    let destinationRegistry = WebDestinationRegistry()
    private var isSyncing = false
    let toolbarArea: JSValue  // Right side of header for toolbar items

    init() {
        let doc = JSObject.global.document
        container = doc.createElement("div")
        container.style = "display: flex; flex-direction: column; width: 100%;"

        // Header bar
        let header = doc.createElement("div")
        header.style = "display: flex; align-items: center; padding: 8px 12px; background: #f0f0f0; border-bottom: 1px solid #ccc; gap: 8px;"

        backButton = doc.createElement("button")
        backButton.textContent = "← Back"
        backButton.style = "display: none; padding: 4px 8px; cursor: pointer;"
        _ = header.appendChild(backButton)

        headerTitle = doc.createElement("span")
        headerTitle.style = "font-weight: bold; font-size: 17px;"
        _ = header.appendChild(headerTitle)

        // Spacer pushes toolbar to the right
        let spacer = doc.createElement("div")
        spacer.style = "flex: 1;"
        _ = header.appendChild(spacer)

        // Toolbar area (right side of header)
        toolbarArea = doc.createElement("div")
        toolbarArea.style = "display: flex; align-items: center; gap: 4px;"
        _ = header.appendChild(toolbarArea)

        _ = container.appendChild(header)

        // Content area
        contentArea = doc.createElement("div")
        contentArea.style = "flex: 1;"
        _ = container.appendChild(contentArea)

        // Wire back button
        let backHandler = webMakeClosure { [weak self] _ in
            self?.pop()
            return .undefined
        }
        backButton.onclick = .object(backHandler)
    }

    func push(element: JSValue, title: String) {
        stack.append((element: element, title: title))
        contentArea.innerHTML = ""
        _ = contentArea.appendChild(element)
        headerTitle.textContent = .string(title)
        backButton.style = "display: inline-block; padding: 4px 8px; cursor: pointer;"
    }

    /// Push a value from NavigationPath — resolves via destination registry.
    func pushValue(_ value: AnyHashable) {
        guard let element = destinationRegistry.resolve(value) else { return }
        let title = "\(value)"
        push(element: element, title: title)
        syncPathAfterPush(value)
    }

    func pop() {
        guard stack.count > 1 else { return }
        stack.removeLast()
        let current = stack.last!
        contentArea.innerHTML = ""
        _ = contentArea.appendChild(current.element)
        headerTitle.textContent = .string(current.title)
        if stack.count <= 1 {
            backButton.style = "display: none; padding: 4px 8px; cursor: pointer;"
        }
        syncPathAfterPop()
    }

    func popToRoot() {
        guard stack.count > 1 else { return }
        let root = stack[0]
        stack = [root]
        contentArea.innerHTML = ""
        _ = contentArea.appendChild(root.element)
        headerTitle.textContent = .string(root.title)
        backButton.style = "display: none; padding: 4px 8px; cursor: pointer;"
        // Clear the entire path, not just one element
        guard !isSyncing, var path = pathBinding?.wrappedValue, !path.isEmpty else { return }
        isSyncing = true
        path.removeLast(path.count)
        pathBinding?.wrappedValue = path
        isSyncing = false
    }

    func setRoot(element: JSValue, title: String) {
        stack = [(element: element, title: title)]
        contentArea.innerHTML = ""
        _ = contentArea.appendChild(element)
        headerTitle.textContent = .string(title)
        backButton.style = "display: none; padding: 4px 8px; cursor: pointer;"
    }

    // MARK: - Path binding sync (bidirectional with re-entrancy guard)

    func beginSync() { isSyncing = true }
    func endSync() { isSyncing = false }

    private func syncPathAfterPush(_ value: AnyHashable) {
        guard !isSyncing, var path = pathBinding?.wrappedValue else { return }
        isSyncing = true
        path.append(value)
        pathBinding?.wrappedValue = path
        isSyncing = false
    }

    private func syncPathAfterPop() {
        guard !isSyncing, var path = pathBinding?.wrappedValue, !path.isEmpty else { return }
        isSyncing = true
        path.removeLast()
        pathBinding?.wrappedValue = path
        isSyncing = false
    }
}

/// Current navigation context — set during NavigationStack rendering.
private var _webCurrentNavContext: WebNavigationContext?

extension NavigationStack: WebRenderable {
    public func webCreateElement() -> JSValue {
        let ctx = WebNavigationContext()
        ctx.pathBinding = pathBinding
        let previousCtx = _webCurrentNavContext
        _webCurrentNavContext = ctx

        // Extract title from content if it has .navigationTitle
        var title = "Home"
        if let titled = content as? NavigationTitled {
            title = titled.navigationTitle
        }

        // Wire NavigateAction into the environment
        let prevEnv = getCurrentEnvironment()
        var env = prevEnv
        env.navigate = NavigateAction(
            push: { [weak ctx] value in ctx?.pushValue(value) },
            pop: { [weak ctx] in ctx?.pop() },
            popToRoot: { [weak ctx] in ctx?.popToRoot() }
        )
        setCurrentEnvironment(env)

        // Render root content
        let rootElement = webRenderView(content)
        ctx.setRoot(element: rootElement, title: title)

        // Consume initial path if present
        if let path = pathBinding?.wrappedValue, !path.isEmpty {
            ctx.beginSync()
            for element in path.elements {
                ctx.pushValue(element)
            }
            ctx.endSync()
        }

        setCurrentEnvironment(prevEnv)
        _webCurrentNavContext = previousCtx
        return ctx.container
    }
}

extension NavigationLink: WebRenderable {
    public func webCreateElement() -> JSValue {
        let button = document.createElement("button")
        button.style = "padding: 6px 12px; cursor: pointer; border: none; background: none; color: inherit; font: inherit; display: flex; align-items: center; justify-content: center;"
        _ = button.appendChild(webRenderView(labelView))

        // Capture the nav context NOW (during render), not at click time
        let capturedCtx = _webCurrentNavContext

        let handler = webMakeClosure { _ in
            guard let ctx = capturedCtx else { return .undefined }
            let prevCtx = _webCurrentNavContext
            _webCurrentNavContext = ctx
            // Install NavigateAction so pushed destinations can use @Environment(\.navigate)
            let prevEnv = getCurrentEnvironment()
            var env = prevEnv
            env.navigate = NavigateAction(
                push: { [weak ctx] value in ctx?.pushValue(value) },
                pop: { [weak ctx] in ctx?.pop() },
                popToRoot: { [weak ctx] in ctx?.popToRoot() }
            )
            setCurrentEnvironment(env)
            let destElement = webRenderView(self.destination())
            setCurrentEnvironment(prevEnv)
            _webCurrentNavContext = prevCtx
            ctx.push(element: destElement, title: self.title)
            return .undefined
        }
        button.onclick = .object(handler)

        return button
    }
}

extension TitledView: WebRenderable {
    public func webCreateElement() -> JSValue {
        webRenderView(content)
    }
}

extension NavigationDestinationModifier: WebRenderable {
    public func webCreateElement() -> JSValue {
        // Register destination factory in current navigation context
        if let ctx = _webCurrentNavContext {
            ctx.destinationRegistry.register(for: dataType) { value in
                let prevCtx = _webCurrentNavContext
                _webCurrentNavContext = ctx
                // Install NavigateAction so destinations can use @Environment(\.navigate)
                let prevEnv = getCurrentEnvironment()
                var env = prevEnv
                env.navigate = NavigateAction(
                    push: { [weak ctx] v in ctx?.pushValue(v) },
                    pop: { [weak ctx] in ctx?.pop() },
                    popToRoot: { [weak ctx] in ctx?.popToRoot() }
                )
                setCurrentEnvironment(env)
                let element = webRenderView(self.destination(value))
                setCurrentEnvironment(prevEnv)
                _webCurrentNavContext = prevCtx
                return element
            }
        }
        return webRenderView(content)
    }
}

// MARK: - Gesture views

extension TapGestureView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let element = webRenderView(content)

        if count <= 1 {
            // Single tap — use click event
            let handler = webMakeClosure { _ in
                self.action()
                return .undefined
            }
            _ = element.addEventListener("click", handler)
        } else {
            // Multi-tap (e.g. double-click) — track click count with timeout
            var clickCount = 0
            var timer: JSValue = .undefined
            let requiredCount = count

            let handler = webMakeClosure { _ in
                clickCount += 1
                // Clear previous timeout
                if timer != .undefined {
                    _ = JSObject.global.clearTimeout!(timer)
                }
                if clickCount >= requiredCount {
                    clickCount = 0
                    self.action()
                } else {
                    // Reset after 400ms (double-click window)
                    let resetClosure = webMakeClosure { _ in
                        clickCount = 0
                        return .undefined
                    }
                    timer = JSObject.global.setTimeout!(resetClosure, 400)
                }
                return .undefined
            }
            _ = element.addEventListener("click", handler)
        }

        return element
    }
}

extension LongPressGestureView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let element = webRenderView(content)
        let durationMs = Int(minimumDuration * 1000)

        var timer: JSValue = .undefined
        var fired = false

        // Start timer on pointerdown
        let downHandler = webMakeClosure { _ in
            fired = false
            let fireClosure = webMakeClosure { _ in
                fired = true
                self.action()
                return .undefined
            }
            timer = JSObject.global.setTimeout!(fireClosure, durationMs)
            return .undefined
        }
        _ = element.addEventListener("pointerdown", downHandler)

        // Cancel on pointerup / pointerleave
        let cancelHandler = webMakeClosure { _ in
            if timer != .undefined {
                _ = JSObject.global.clearTimeout!(timer)
                timer = .undefined
            }
            return .undefined
        }
        _ = element.addEventListener("pointerup", cancelHandler)
        _ = element.addEventListener("pointerleave", cancelHandler)

        // Prevent context menu if long press fired
        let contextHandler = webMakeClosure { event in
            if fired {
                _ = event[0].preventDefault()
            }
            return .undefined
        }
        _ = element.addEventListener("contextmenu", contextHandler)

        // Make element interactive
        _ = element.style.setProperty("touch-action", "none")
        _ = element.style.setProperty("user-select", "none")
        _ = element.style.setProperty("-webkit-user-select", "none")

        return element
    }
}

extension DragGestureView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let element = webRenderView(content)
        let minDist = minimumDistance

        var startX: Double = 0
        var startY: Double = 0
        var dragging = false

        let moveHandler = webMakeClosure { event in
            let e = event[0]
            let clientX = e.clientX.number!
            let clientY = e.clientY.number!
            let dx = clientX - startX
            let dy = clientY - startY

            if !dragging {
                let dist = (dx * dx + dy * dy).squareRoot()
                if dist < minDist { return .undefined }
                dragging = true
            }

            let value = DragGestureValue(
                startLocation: (x: startX, y: startY),
                location: (x: clientX, y: clientY),
                translation: (width: dx, height: dy)
            )
            self.onChanged?(value)
            return .undefined
        }

        let upHandler = webMakeClosure { event in
            guard dragging else {
                _ = JSObject.global.document.removeEventListener("pointermove", moveHandler)
                _ = JSObject.global.document.removeEventListener("pointerup", event[0])
                return .undefined
            }
            dragging = false
            let e = event[0]
            let clientX = e.clientX.number!
            let clientY = e.clientY.number!
            let value = DragGestureValue(
                startLocation: (x: startX, y: startY),
                location: (x: clientX, y: clientY),
                translation: (width: clientX - startX, height: clientY - startY)
            )
            self.onEnded?(value)
            _ = JSObject.global.document.removeEventListener("pointermove", moveHandler)
            return .undefined
        }

        let downHandler = webMakeClosure { event in
            let e = event[0]
            startX = e.clientX.number!
            startY = e.clientY.number!
            dragging = false
            _ = JSObject.global.document.addEventListener("pointermove", moveHandler)
            _ = JSObject.global.document.addEventListener("pointerup", upHandler)
            return .undefined
        }
        _ = element.addEventListener("pointerdown", downHandler)

        // Prevent default drag behavior
        _ = element.style.setProperty("touch-action", "none")
        _ = element.style.setProperty("user-select", "none")
        _ = element.style.setProperty("-webkit-user-select", "none")

        return element
    }
}

extension SwiftOpenUI.Button: WebRenderable {
    public func webCreateElement() -> JSValue {
        let button = document.createElement("button")
        button.style = "padding: 6px 12px; cursor: pointer; border: none; background: none; color: inherit; font: inherit; display: flex; align-items: center; justify-content: center;"

        // Render label content
        let labelElement = webRenderView(label)
        _ = button.appendChild(labelElement)

        // Wire up action
        let handler = webMakeClosure { _ in
            self.action()
            return .undefined
        }
        button.onclick = .object(handler)

        return button
    }
}

extension SwiftOpenUI.Color: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = .string("background-color: \(cssColor); width: 100%; height: 100%; min-height: 20px;")
        webMarkHostedNodeKind(div, kind: .color)
        return div
    }

    var cssColor: String {
        "rgba(\(Int(red * 255)), \(Int(green * 255)), \(Int(blue * 255)), \(alpha))"
    }

    public func webDescribeNode() -> WebDescriptorNode {
        WebDescriptorNode(kind: .color, typeName: "Color",
                          props: .color(webColorDescriptor(self)))
    }
}

// MARK: - Container views

extension VStack: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = .string("display: flex; flex-direction: column; gap: \(spacing)px; align-items: \(cssAlignment);")

        webRenderChildren(content) { child in
            _ = div.appendChild(child)
        }
        return div
    }

    private var cssAlignment: String {
        switch alignment {
        case .leading: return "flex-start"
        case .trailing: return "flex-end"
        default: return "center"
        }
    }

    public func webDescribeNode() -> WebDescriptorNode {
        let childDescs: [WebDescriptorNode]
        if let multi = content as? MultiChildView {
            childDescs = multi.children.map(webDescribeAnyView)
        } else {
            childDescs = [webDescribeView(content)]
        }
        return WebDescriptorNode(
            kind: .vStack, typeName: "VStack",
            props: .vStack(WebVStackDescriptor(
                spacing: spacing,
                alignment: webHorizontalAlignmentDescriptor(alignment))),
            children: childDescs)
    }
}

extension HStack: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = .string("display: flex; flex-direction: row; gap: \(spacing)px; align-items: \(cssAlignment);")

        webRenderChildren(content) { child in
            _ = div.appendChild(child)
        }
        return div
    }

    private var cssAlignment: String {
        switch alignment {
        case .top: return "flex-start"
        case .bottom: return "flex-end"
        default: return "center"
        }
    }

    public func webDescribeNode() -> WebDescriptorNode {
        let childDescs: [WebDescriptorNode]
        if let multi = content as? MultiChildView {
            childDescs = multi.children.map(webDescribeAnyView)
        } else {
            childDescs = [webDescribeView(content)]
        }
        return WebDescriptorNode(
            kind: .hStack, typeName: "HStack",
            props: .hStack(WebHStackDescriptor(
                spacing: spacing,
                alignment: webVerticalAlignmentDescriptor(alignment))),
            children: childDescs)
    }
}

extension ZStack: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = "display: grid; place-items: center;"

        webRenderChildren(content) { child in
            // All children stack in the same grid cell
            child.style.object?.gridArea = "1 / 1"
            _ = div.appendChild(child)
        }
        return div
    }

    public func webDescribeNode() -> WebDescriptorNode {
        let childDescs: [WebDescriptorNode]
        if let multi = content as? MultiChildView {
            childDescs = multi.children.map(webDescribeAnyView)
        } else {
            childDescs = [webDescribeView(content)]
        }
        return WebDescriptorNode(
            kind: .zStack, typeName: "ZStack",
            props: .zStack(WebZStackDescriptor(
                alignment: webAlignmentDescriptor(alignment))),
            children: childDescs)
    }
}

extension Group: WebRenderable, WebMultiChildRenderable {
    public func webCreateElement() -> JSValue {
        // display: contents makes Group invisible to layout —
        // children participate directly in the parent flex container.
        let div = document.createElement("div")
        div.style = "display: contents;"
        webRenderChildren(content) { child in
            _ = div.appendChild(child)
        }

        return div
    }

    public func webForEachChild(_ body: (JSValue) -> Void) {
        BackendWeb.webRenderChildren(content, body)
    }
}

extension ForEach: WebRenderable, WebMultiChildRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        webForEachChild { child in
            _ = div.appendChild(child)
        }
        return div
    }

    public func webForEachChild(_ body: (JSValue) -> Void) {
        for item in data {
            let view = content(item)
            body(webRenderView(view))
        }
    }
}

extension ForEach: WebDescribable {
    public func webDescribeNode() -> WebDescriptorNode {
        let childDescs = data.map { item in
            webDescribeView(content(item))
        }
        return WebDescriptorNode(kind: .composite, typeName: "ForEach", children: childDescs)
    }
}

extension Group: WebDescribable {
    public func webDescribeNode() -> WebDescriptorNode {
        WebDescriptorNode(
            kind: .composite, typeName: "Group",
            children: BackendWeb.flattenChildren(content).map(webDescribeAnyView))
    }
}

extension _ConditionalView: WebDescribable {
    public func webDescribeNode() -> WebDescriptorNode {
        switch self {
        case .trueContent(let v): return webDescribeView(v)
        case .falseContent(let v): return webDescribeView(v)
        }
    }
}

extension Optional: WebDescribable where Wrapped: View {
    public func webDescribeNode() -> WebDescriptorNode {
        switch self {
        case .none: return WebDescriptorNode(kind: .composite, typeName: "Optional.none")
        case .some(let v): return webDescribeView(v)
        }
    }
}

// MARK: - Modifier views

extension PaddedView: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let padding = "padding: \(top)px \(trailing)px \(bottom)px \(leading)px;"
        let wrapper = document.createElement("div")
        wrapper.style = .string(padding)
        webMarkHostedNodeKind(wrapper, kind: .padding)
        _ = wrapper.appendChild(child)
        return wrapper
    }

    public func webDescribeNode() -> WebDescriptorNode {
        WebDescriptorNode(
            kind: .padding, typeName: "PaddedView",
            props: .padding(WebPaddingDescriptor(
                top: top, bottom: bottom, leading: leading, trailing: trailing)),
            children: [webDescribeView(content)])
    }
}

extension FrameView: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        var styles = [String]()
        if let w = width { styles.append("width: \(w)px") }
        if let h = height { styles.append("height: \(h)px") }
        if let minW = minWidth { styles.append("min-width: \(minW)px") }
        if let maxW = maxWidth { styles.append("max-width: \(maxW == .infinity ? 99999 : maxW)px") }
        if let minH = minHeight { styles.append("min-height: \(minH)px") }
        if let maxH = maxHeight { styles.append("max-height: \(maxH == .infinity ? 99999 : maxH)px") }
        // Propagate flex layout so children (Spacer, etc.) work inside frames.
        // Center content by default — matches SwiftUI .frame() behavior.
        styles.append("display: flex")
        styles.append("flex-direction: column")
        styles.append("align-items: center")
        styles.append("justify-content: center")

        let wrapper = document.createElement("div")
        wrapper.style = .string(styles.joined(separator: "; ") + ";")
        _ = wrapper.appendChild(child)
        return wrapper
    }

    public func webDescribeNode() -> WebDescriptorNode {
        WebDescriptorNode(
            kind: .frame, typeName: "FrameView",
            props: .frame(WebFrameDescriptor(
                width: width, height: height,
                minWidth: minWidth, minHeight: minHeight,
                maxWidth: maxWidth, maxHeight: maxHeight,
                alignment: webAlignmentDescriptor(alignment))),
            children: [webDescribeView(content)])
    }
}

extension ForegroundColorView: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let css = "color: \(color.cssColor);"
        let wrapper = document.createElement("div")
        wrapper.style = .string(css)
        webMarkHostedNodeKind(wrapper, kind: .foregroundColor)
        _ = wrapper.appendChild(child)
        return wrapper
    }

    public func webDescribeNode() -> WebDescriptorNode {
        WebDescriptorNode(
            kind: .foregroundColor, typeName: "ForegroundColorView",
            props: .foregroundColor(webColorDescriptor(color)),
            children: [webDescribeView(content)])
    }
}

extension BackgroundView: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        if let color = background as? Color {
            let child = webRenderView(content)
            let css = "background-color: \(color.cssColor); display: flex; flex-direction: column; flex: 1;"
            let wrapper = document.createElement("div")
            wrapper.style = .string(css)
            webMarkHostedNodeKind(wrapper, kind: .background)
            _ = wrapper.appendChild(child)
            return wrapper
        }

        return webRenderView(ZStack(alignment: alignment) {
            self.background
            content
        })
    }

    public func webDescribeNode() -> WebDescriptorNode {
        if let color = background as? Color {
            return WebDescriptorNode(
                kind: .background, typeName: "BackgroundView",
                props: .background(webColorDescriptor(color)),
                children: [webDescribeView(content)])
        }

        return webDescribeView(ZStack(alignment: alignment) {
            self.background
            content
        })
    }
}

extension FontModifiedView: WebRenderable, WebDescribable {
    public func webDescribeNode() -> WebDescriptorNode {
        WebDescriptorNode(
            kind: .font, typeName: "FontModifiedView",
            props: .font(WebFontDescriptor(font: font)),
            children: [webDescribeView(content)])
    }

    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let css: String
        switch font {
        case .largeTitle: css = "font-size: 34px; font-weight: bold;"
        case .title:      css = "font-size: 28px; font-weight: bold;"
        case .title2:     css = "font-size: 22px; font-weight: bold;"
        case .title3:     css = "font-size: 20px; font-weight: 600;"
        case .headline:   css = "font-size: 17px; font-weight: 600;"
        case .subheadline: css = "font-size: 15px;"
        case .body:       css = "font-size: 17px;"
        case .callout:    css = "font-size: 16px;"
        case .footnote:   css = "font-size: 13px;"
        case .caption:    css = "font-size: 12px;"
        case .caption2:   css = "font-size: 11px;"
        case .custom(let size, let weight, _):
            let w: String
            switch weight {
            case .ultraLight: w = "100"
            case .thin:       w = "200"
            case .light:      w = "300"
            case .regular:    w = "400"
            case .medium:     w = "500"
            case .semibold:   w = "600"
            case .bold:       w = "700"
            case .heavy:      w = "800"
            case .black:      w = "900"
            }
            css = "font-size: \(size)px; font-weight: \(w);"
        }
        let wrapper = document.createElement("div")
        wrapper.style = .string(css)
        _ = wrapper.appendChild(child)
        return wrapper
    }
}

extension BorderView: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let css = "border: \(width)px solid \(color.cssColor);"
        let wrapper = document.createElement("div")
        wrapper.style = .string(css)
        _ = wrapper.appendChild(child)
        return wrapper
    }

    public func webDescribeNode() -> WebDescriptorNode {
        WebDescriptorNode(
            kind: .border, typeName: "BorderView",
            props: .border(WebBorderDescriptor(
                color: webColorDescriptor(color), width: width)),
            children: [webDescribeView(content)])
    }
}

// MARK: - Type-erased / conditional views

extension AnyView: WebRenderable {
    public func webCreateElement() -> JSValue {
        webRenderAnyView(wrapped)
    }
}

extension _ConditionalView: WebRenderable {
    public func webCreateElement() -> JSValue {
        switch self {
        case .trueContent(let view): return webRenderView(view)
        case .falseContent(let view): return webRenderView(view)
        }
    }
}

extension ViewList: WebRenderable {
    public func webCreateElement() -> JSValue {
        let container = document.createElement("div")
        for child in children {
            _ = container.appendChild(webRenderAnyView(child))
        }
        return container
    }
}

// MARK: - TupleView rendering

extension TupleView: WebMultiChildRenderable {
    public func webForEachChild(_ body: (JSValue) -> Void) {
        repeat body(webRenderView(each value))
    }
}

// MARK: - Optional view

extension Optional: WebRenderable where Wrapped: View {
    public func webCreateElement() -> JSValue {
        switch self {
        case .some(let view): return webRenderView(view)
        case .none: return document.createElement("span")
        }
    }
}

// MARK: - Environment modifier views

extension EnvironmentObjectModifierView: WebRenderable {
    public func webCreateElement() -> JSValue {
        var env = getCurrentEnvironment()
        env.setObject(object)
        setCurrentEnvironment(env)
        let result = webRenderView(content)
        return result
    }
}

extension EnvironmentModifierView: WebRenderable {
    public func webCreateElement() -> JSValue {
        var env = getCurrentEnvironment()
        env[keyPath: keyPath] = value
        setCurrentEnvironment(env)
        let result = webRenderView(content)
        return result
    }
}

// MARK: - Phase A views

extension Toggle: WebRenderable {
    public func webCreateElement() -> JSValue {
        let container = document.createElement("label")
        container.style = "display: flex; align-items: center; gap: 8px; cursor: pointer;"

        let input = document.createElement("input")
        input.type = "checkbox"
        input.checked = .boolean(isOn.wrappedValue)

        let binding = isOn
        let handler = webMakeClosure { _ in
            binding.wrappedValue = input.checked.boolean ?? false
            return .undefined
        }
        _ = input.addEventListener("change", handler)

        let text = document.createTextNode(label)
        _ = container.appendChild(input)
        _ = container.appendChild(text)
        return container
    }
}

extension Slider: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        let input = document.createElement("input")
        input.type = "range"
        input.min = .string("\(range.lowerBound)")
        input.max = .string("\(range.upperBound)")
        input.step = .string("\(step)")
        input.value = .string("\(value.wrappedValue)")
        input.style = "width: 100%;"

        let binding = value
        let handler = webMakeClosure { _ in
            if let str = input.value.string, let val = Double(str) {
                binding.wrappedValue = val
            }
            return .undefined
        }
        _ = input.addEventListener("input", handler)
        webMarkHostedNodeKind(input, kind: .slider)

        // Interactive deferral: suppress host rebuilds during pointer drag
        let host = WebViewHost.currentRebuilding
        let downHandler = webMakeClosure { _ in
            host?.beginInteractiveUpdate()
            // Add document-level pointerup/pointercancel to catch release anywhere
            let doc = JSObject.global.document
            var upHandler: JSClosure!
            upHandler = webMakeClosure { _ in
                host?.endInteractiveUpdate()
                _ = doc.removeEventListener("pointerup", upHandler)
                _ = doc.removeEventListener("pointercancel", upHandler)
                return .undefined
            }
            _ = doc.addEventListener("pointerup", upHandler)
            _ = doc.addEventListener("pointercancel", upHandler)
            return .undefined
        }
        _ = input.addEventListener("pointerdown", downHandler)

        return input
    }

    public func webDescribeNode() -> WebDescriptorNode {
        WebDescriptorNode(
            kind: .slider, typeName: "Slider",
            props: .slider(WebSliderDescriptor(
                value: value.wrappedValue, range: range, step: step)))
    }
}

extension ScrollView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        let overflowX = axes.contains(.horizontal) ? "auto" : "hidden"
        let overflowY = axes.contains(.vertical) ? "auto" : "hidden"
        div.style = .string("overflow-x: \(overflowX); overflow-y: \(overflowY); max-height: 100%;")

        webRenderChildren(content) { child in
            _ = div.appendChild(child)
        }
        return div
    }
}

extension SecureField: WebRenderable {
    public func webCreateElement() -> JSValue {
        let input = document.createElement("input")
        input.type = "password"
        input.value = .string(text.wrappedValue)
        input.placeholder = .string(placeholder)
        input.style = "padding: 6px 8px; font-size: 16px; width: 100%; box-sizing: border-box;"

        let binding = text
        let handler = webMakeClosure { _ in
            let newValue = input.value.string ?? ""
            if newValue != binding.wrappedValue {
                binding.wrappedValue = newValue
            }
            return .undefined
        }
        _ = input.addEventListener("input", handler)

        return input
    }
}

extension TextEditor: WebRenderable {
    public func webCreateElement() -> JSValue {
        let textarea = document.createElement("textarea")
        textarea.value = .string(text.wrappedValue)
        textarea.style = "padding: 6px 8px; font-size: 16px; width: 100%; min-height: 80px; box-sizing: border-box; resize: vertical;"

        let binding = text
        let handler = webMakeClosure { _ in
            let newValue = textarea.value.string ?? ""
            if newValue != binding.wrappedValue {
                binding.wrappedValue = newValue
            }
            return .undefined
        }
        _ = textarea.addEventListener("input", handler)

        return textarea
    }
}

extension Link: WebRenderable {
    public func webCreateElement() -> JSValue {
        let a = document.createElement("a")
        a.href = .string(destination)
        a.target = "_blank"
        a.textContent = .string(title)
        a.style = "color: #0a84ff; text-decoration: underline; cursor: pointer;"
        return a
    }
}

extension Form: WebRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = "display: flex; flex-direction: column; gap: 8px; padding: 12px;"

        webRenderChildren(content) { child in
            _ = div.appendChild(child)
        }
        return div
    }
}

extension Section: WebRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = "display: flex; flex-direction: column; gap: 4px;"

        if let headerText = header {
            let h = document.createElement("h3")
            h.textContent = .string(headerText)
            h.style = "margin: 0; font-size: 14px; font-weight: 600; color: #888;"
            _ = div.appendChild(h)
        }

        webRenderChildren(content) { child in
            _ = div.appendChild(child)
        }

        if let footerText = footer {
            let f = document.createElement("p")
            f.textContent = .string(footerText)
            f.style = "margin: 0; font-size: 12px; color: #666;"
            _ = div.appendChild(f)
        }

        return div
    }
}

// MARK: - Phase A modifiers

extension CornerRadiusView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let wrapper = document.createElement("div")
        wrapper.style = .string("display: inline-block; border-radius: \(radius)px; overflow: hidden;")
        _ = wrapper.appendChild(child)
        return wrapper
    }
}

extension ShadowView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let wrapper = document.createElement("div")
        wrapper.style = .string("display: inline-block; box-shadow: \(x)px \(y)px \(radius)px \(color.cssColor);")
        _ = wrapper.appendChild(child)
        return wrapper
    }
}

extension RotationView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let wrapper = document.createElement("div")
        wrapper.style = .string("display: inline-block; transform: rotate(\(angle)deg); transform-origin: center;")
        _ = wrapper.appendChild(child)
        return wrapper
    }
}

// MARK: - Phase B views

extension NavigationSplitViewColumnWidthView: WebRenderable {
    public func webCreateElement() -> JSValue {
        // Renders content; width constraints are consumed by NavigationSplitView (Phase C).
        webRenderView(content)
    }
}

extension List: WebRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = "display: flex; flex-direction: column; border: 1px solid #333; border-radius: 4px; overflow: hidden;"

        webRenderChildren(content) { child in
            let row = document.createElement("div")
            // Use CSS to add border to all but the last item
            row.style = "padding: 8px 12px;"
            row.className = "swiftopenui-list-row"
            _ = row.appendChild(child)
            _ = div.appendChild(row)
        }

        // Add a global style tag for the list row borders if not already present
        webEnsureListRowStyles()

        return div
    }
}

extension SwiftOpenUI.Image: WebRenderable {
    public func webCreateElement() -> JSValue {
        let size = scale.pointSize
        switch source {
        case .filePath(let path):
            let img = document.createElement("img")
            img.src = .string(path)
            img.style = .string("width: \(size)px; height: \(size)px; object-fit: contain;")
            return img
        case .systemName(let name):
            // No browser icon theme — render as text placeholder
            let span = document.createElement("span")
            span.textContent = .string("[\(name)]")
            span.style = .string("font-size: \(size)px; color: #888;")
            return span
        }
    }
}

extension ProgressView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let progress = document.createElement("progress")
        progress.style = "width: 100%;"
        if let val = value {
            progress.value = .number(val)
            progress.max = .number(total)
        }
        // No value attribute = indeterminate (browser handles natively)
        return progress
    }
}

extension Stepper: WebRenderable {
    public func webCreateElement() -> JSValue {
        let container = document.createElement("div")
        container.style = "display: flex; align-items: center; gap: 8px;"

        if !label.isEmpty {
            let labelSpan = document.createElement("span")
            labelSpan.textContent = .string(label)
            _ = container.appendChild(labelSpan)
        }

        let binding = value
        let rng = range
        let stp = step

        let minus = document.createElement("button")
        minus.textContent = "-"
        minus.style = "width: 28px; height: 28px; cursor: pointer;"
        let minusHandler = webMakeClosure { _ in
            let newVal = max(rng.lowerBound, binding.wrappedValue - stp)
            binding.wrappedValue = newVal
            return .undefined
        }
        minus.onclick = .object(minusHandler)

        let display = document.createElement("span")
        display.textContent = .string("\(Int(value.wrappedValue))")
        display.style = "min-width: 24px; text-align: center;"

        let plus = document.createElement("button")
        plus.textContent = "+"
        plus.style = "width: 28px; height: 28px; cursor: pointer;"
        let plusHandler = webMakeClosure { _ in
            let newVal = min(rng.upperBound, binding.wrappedValue + stp)
            binding.wrappedValue = newVal
            return .undefined
        }
        plus.onclick = .object(plusHandler)

        _ = container.appendChild(minus)
        _ = container.appendChild(display)
        _ = container.appendChild(plus)
        return container
    }
}

extension SwiftOpenUI.Label: WebRenderable {
    public func webCreateElement() -> JSValue {
        let container = document.createElement("span")
        container.style = "display: inline-flex; align-items: center; gap: 4px;"

        if let path = imagePath {
            let img = document.createElement("img")
            img.src = .string(path)
            img.style = "width: 16px; height: 16px; object-fit: contain;"
            _ = container.appendChild(img)
        } else if let sysName = systemImage {
            let icon = document.createElement("span")
            icon.textContent = .string("[\(sysName)]")
            icon.style = "font-size: 14px; color: #888;"
            _ = container.appendChild(icon)
        }

        let text = document.createTextNode(title)
        _ = container.appendChild(text)
        return container
    }
}

extension DisclosureGroup: WebRenderable {
    public func webCreateElement() -> JSValue {
        let details = document.createElement("details")
        if isExpanded {
            details.open = .boolean(true)
        }

        let summary = document.createElement("summary")
        summary.textContent = .string(title)
        summary.style = "cursor: pointer; font-weight: 600; padding: 4px 0;"
        _ = details.appendChild(summary)

        let contentDiv = document.createElement("div")
        contentDiv.style = "padding: 4px 0 4px 16px;"
        let child = webRenderView(content)
        _ = contentDiv.appendChild(child)
        _ = details.appendChild(contentDiv)

        if let callback = onExpandedChange {
            let handler = webMakeClosure { _ in
                let isOpen = details.open.boolean ?? false
                callback(isOpen)
                return .undefined
            }
            _ = details.addEventListener("toggle", handler)
        }

        return details
    }
}

extension Picker: WebRenderable {
    public func webCreateElement() -> JSValue {
        let container = document.createElement("div")
        container.style = "display: flex; align-items: center; gap: 8px;"

        if !label.isEmpty {
            let labelEl = document.createElement("label")
            labelEl.textContent = .string(label)
            _ = container.appendChild(labelEl)
        }

        switch style {
        case .segmented, .palette:
            // Segmented control: row of buttons with active state
            let row = document.createElement("div")
            row.style = "display: flex; gap: 0;"
            for (i, option) in options.enumerated() {
                let btn = document.createElement("button")
                btn.textContent = .string(option)
                let isActive = i == selected
                let bg = isActive ? "#0a84ff" : "#444"
                let color = isActive ? "white" : "#ccc"
                var btnStyle = "padding: 4px 12px; font-size: 13px; cursor: pointer; border: 1px solid #555; background: \(bg); color: \(color);"
                if i == 0 { btnStyle += " border-radius: 4px 0 0 4px;" }
                else if i == options.count - 1 { btnStyle += " border-radius: 0 4px 4px 0; border-left: none;" }
                else { btnStyle += " border-radius: 0; border-left: none;" }
                btn.style = .string(btnStyle)

                if let callback = onChanged {
                    let idx = i
                    let handler = webMakeClosure { _ in
                        callback(idx)
                        return .undefined
                    }
                    btn.onclick = .object(handler)
                }
                _ = row.appendChild(btn)
            }
            _ = container.appendChild(row)
            return container

        case .automatic:
            break // fall through to <select> below
        }

        let select = document.createElement("select")
        select.style = "padding: 4px 8px; font-size: 14px;"
        for (i, option) in options.enumerated() {
            let opt = document.createElement("option")
            opt.value = .string("\(i)")
            opt.textContent = .string(option)
            if i == selected {
                opt.selected = .boolean(true)
            }
            _ = select.appendChild(opt)
        }

        if let callback = onChanged {
            let handler = webMakeClosure { _ in
                if let idxStr = select.value.string, let idx = Int(idxStr) {
                    callback(idx)
                }
                return .undefined
            }
            _ = select.addEventListener("change", handler)
        }

        _ = container.appendChild(select)
        return container
    }
}

extension DatePicker: WebRenderable {
    public func webCreateElement() -> JSValue {
        let container = document.createElement("div")
        container.style = "display: flex; align-items: center; gap: 8px;"

        if !title.isEmpty {
            let labelEl = document.createElement("label")
            labelEl.textContent = .string(title)
            _ = container.appendChild(labelEl)
        }

        let input = document.createElement("input")
        input.type = "date"

        // Set initial value from binding or default to today
        if let sel = selection {
            let dc = sel.wrappedValue
            input.value = .string(String(format: "%04d-%02d-%02d", dc.year, dc.month, dc.day))
        }

        let sel = selection
        let cb = onChange
        let handler = webMakeClosure { _ in
            guard let str = input.value.string else { return .undefined }
            let parts = str.split(separator: "-")
            guard parts.count == 3,
                  let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else {
                return .undefined
            }
            let dc = DateComponents(year: y, month: m, day: d)
            sel?.wrappedValue = dc
            cb?(dc)
            return .undefined
        }
        _ = input.addEventListener("change", handler)

        _ = container.appendChild(input)
        return container
    }
}

// MARK: - Phase B modifiers

extension OverlayView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let wrapper = document.createElement("div")
        wrapper.style = "position: relative; display: inline-block;"

        let base = webRenderView(content)
        _ = wrapper.appendChild(base)

        let overlayEl = webRenderView(overlay)
        let css: String
        switch alignment {
        case .topLeading:    css = "position: absolute; top: 0; left: 0;"
        case .top:           css = "position: absolute; top: 0; left: 50%; transform: translateX(-50%);"
        case .topTrailing:   css = "position: absolute; top: 0; right: 0;"
        case .leading:       css = "position: absolute; top: 50%; left: 0; transform: translateY(-50%);"
        case .center:        css = "position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);"
        case .trailing:      css = "position: absolute; top: 50%; right: 0; transform: translateY(-50%);"
        case .bottomLeading: css = "position: absolute; bottom: 0; left: 0;"
        case .bottom:        css = "position: absolute; bottom: 0; left: 50%; transform: translateX(-50%);"
        case .bottomTrailing:css = "position: absolute; bottom: 0; right: 0;"
        }
        let overlayWrapper = document.createElement("div")
        overlayWrapper.style = .string(css)
        _ = overlayWrapper.appendChild(overlayEl)
        _ = wrapper.appendChild(overlayWrapper)

        return wrapper
    }
}

extension IgnoresSafeAreaView: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        // Batch 1: passthrough until the Web backend grows a real safe-area model.
        webRenderView(content)
    }

    public func webDescribeNode() -> WebDescriptorNode {
        WebDescriptorNode(
            kind: .composite,
            typeName: "IgnoresSafeAreaView",
            props: .ignoresSafeArea(
                WebIgnoresSafeAreaDescriptor(
                    regionsRawValue: regions.rawValue,
                    edgesRawValue: edges.rawValue
                )
            ),
            children: [webDescribeView(content)]
        )
    }
}

extension SafeAreaInsetView: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        let container = document.createElement("div")
        container.style = .string(webSafeAreaContainerStyle(edge: edge, spacing: spacing))

        let contentElement = webRenderView(content)
        let insetElement = webRenderView(inset)
        let contentWrapper = webSafeAreaWrappedContent(contentElement, edge: edge, spacing: spacing)
        let insetWrapper = webSafeAreaWrappedInset(insetElement, edge: edge, alignment: alignment, spacing: spacing)

        switch edge {
        case .top, .leading:
            _ = container.appendChild(insetWrapper)
            _ = container.appendChild(contentWrapper)
        case .bottom, .trailing:
            _ = container.appendChild(contentWrapper)
            _ = container.appendChild(insetWrapper)
        }

        return container
    }

    public func webDescribeNode() -> WebDescriptorNode {
        let contentDescriptor = webDescribeView(content)
        let insetDescriptor = webDescribeView(inset)
        let children: [WebDescriptorNode]
        switch edge {
        case .top, .leading:
            children = [insetDescriptor, contentDescriptor]
        case .bottom, .trailing:
            children = [contentDescriptor, insetDescriptor]
        }

        return WebDescriptorNode(
            kind: .composite,
            typeName: "SafeAreaInsetView",
            props: .safeAreaInset(webSafeAreaInsetDescriptor(edge: edge, alignment: alignment, spacing: spacing)),
            children: children
        )
    }
}

func webSafeAreaContainerStyle(edge: SafeAreaInsetEdge, spacing: Int) -> String {
    let normalizedSpacing = max(spacing, 0)
    switch edge {
    case .top, .bottom:
        return "display: flex; flex-direction: column; gap: \(normalizedSpacing)px; align-items: stretch;"
    case .leading, .trailing:
        return "display: flex; flex-direction: row; gap: \(normalizedSpacing)px; align-items: stretch;"
    }
}

private func webSafeAreaWrappedContent(_ child: JSValue, edge: SafeAreaInsetEdge, spacing: Int) -> JSValue {
    let wrapper = document.createElement("div")
    wrapper.style = .string(webSafeAreaContentWrapperStyle(edge: edge, spacing: spacing))
    _ = wrapper.appendChild(child)
    return wrapper
}

private func webSafeAreaWrappedInset(
    _ child: JSValue,
    edge: SafeAreaInsetEdge,
    alignment: SafeAreaInsetAlignment,
    spacing: Int
) -> JSValue {
    let wrapper = document.createElement("div")
    wrapper.style = .string(webSafeAreaInsetWrapperStyle(edge: edge, alignment: alignment, spacing: spacing))
    _ = wrapper.appendChild(child)
    return wrapper
}

func webSafeAreaContentWrapperStyle(edge: SafeAreaInsetEdge, spacing: Int) -> String {
    var styles: [String]
    switch edge {
    case .top, .bottom:
        styles = [
            "display: flex",
            "width: 100%",
            "justify-content: flex-start",
            "align-items: flex-start",
        ]
    case .leading, .trailing:
        styles = [
            "display: flex",
            "height: 100%",
            "justify-content: flex-start",
            "align-items: flex-start",
        ]
    }

    if spacing < 0 {
        switch edge {
        case .top:
            styles.append("margin-top: \(spacing)px")
        case .leading:
            styles.append("margin-left: \(spacing)px")
        case .bottom, .trailing:
            break
        }
    }

    return styles.joined(separator: "; ") + ";"
}

func webSafeAreaInsetWrapperStyle(
    edge: SafeAreaInsetEdge,
    alignment: SafeAreaInsetAlignment,
    spacing: Int
) -> String {
    var styles: [String]
    switch edge {
    case .top, .bottom:
        styles = [
            "display: flex",
            "width: 100%",
            "justify-content: \(webSafeAreaHorizontalAlignment(alignment))",
        ]
    case .leading, .trailing:
        styles = [
            "display: flex",
            "height: 100%",
            "align-items: \(webSafeAreaVerticalAlignment(alignment))",
        ]
    }

    if spacing < 0 {
        switch edge {
        case .bottom:
            styles.append("margin-top: \(spacing)px")
        case .trailing:
            styles.append("margin-left: \(spacing)px")
        case .top, .leading:
            break
        }
    }

    return styles.joined(separator: "; ") + ";"
}

private func webSafeAreaHorizontalAlignment(_ alignment: SafeAreaInsetAlignment) -> String {
    let horizontalAlignment: HorizontalAlignment
    switch alignment {
    case .horizontal(let value):
        horizontalAlignment = value
    case .vertical:
        horizontalAlignment = .center
    }

    switch horizontalAlignment {
    case .leading:
        return "flex-start"
    case .center:
        return "center"
    case .trailing:
        return "flex-end"
    }
}

private func webSafeAreaVerticalAlignment(_ alignment: SafeAreaInsetAlignment) -> String {
    let verticalAlignment: VerticalAlignment
    switch alignment {
    case .horizontal:
        verticalAlignment = .center
    case .vertical(let value):
        verticalAlignment = value
    }

    switch verticalAlignment {
    case .top:
        return "flex-start"
    case .center:
        return "center"
    case .bottom:
        return "flex-end"
    }
}

private func webSafeAreaInsetDescriptor(
    edge: SafeAreaInsetEdge,
    alignment: SafeAreaInsetAlignment,
    spacing: Int
) -> WebSafeAreaInsetDescriptor {
    switch edge {
    case .top:
        return WebSafeAreaInsetDescriptor(
            edge: .top,
            horizontalAlignment: webSafeAreaHorizontalAlignmentDescriptor(alignment),
            verticalAlignment: nil,
            spacing: spacing
        )
    case .bottom:
        return WebSafeAreaInsetDescriptor(
            edge: .bottom,
            horizontalAlignment: webSafeAreaHorizontalAlignmentDescriptor(alignment),
            verticalAlignment: nil,
            spacing: spacing
        )
    case .leading:
        return WebSafeAreaInsetDescriptor(
            edge: .leading,
            horizontalAlignment: nil,
            verticalAlignment: webSafeAreaVerticalAlignmentDescriptor(alignment),
            spacing: spacing
        )
    case .trailing:
        return WebSafeAreaInsetDescriptor(
            edge: .trailing,
            horizontalAlignment: nil,
            verticalAlignment: webSafeAreaVerticalAlignmentDescriptor(alignment),
            spacing: spacing
        )
    }
}

private func webSafeAreaHorizontalAlignmentDescriptor(
    _ alignment: SafeAreaInsetAlignment
) -> WebHorizontalAlignmentDescriptor {
    switch alignment {
    case .horizontal(let value):
        return webHorizontalAlignmentDescriptor(value)
    case .vertical:
        return .center
    }
}

private func webSafeAreaVerticalAlignmentDescriptor(
    _ alignment: SafeAreaInsetAlignment
) -> WebVerticalAlignmentDescriptor {
    switch alignment {
    case .horizontal:
        return .center
    case .vertical(let value):
        return webVerticalAlignmentDescriptor(value)
    }
}

// MARK: - Safe Area Padding

/// Synthetic safe-area padding default for Batch A (no native measurement).
private let webSafeAreaPaddingSyntheticDefault = 16

extension SafeAreaPaddingView: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let amount = max(length ?? webSafeAreaPaddingSyntheticDefault, 0)

        let top = edges.contains(.top) ? amount : 0
        let bottom = edges.contains(.bottom) ? amount : 0
        let leading = edges.contains(.leading) ? amount : 0
        let trailing = edges.contains(.trailing) ? amount : 0

        let wrapper = document.createElement("div")
        wrapper.style = .string("padding: \(top)px \(trailing)px \(bottom)px \(leading)px;")
        _ = wrapper.appendChild(child)
        return wrapper
    }

    public func webDescribeNode() -> WebDescriptorNode {
        let amount = max(length ?? webSafeAreaPaddingSyntheticDefault, 0)
        let top = edges.contains(.top) ? amount : 0
        let bottom = edges.contains(.bottom) ? amount : 0
        let leading = edges.contains(.leading) ? amount : 0
        let trailing = edges.contains(.trailing) ? amount : 0

        return WebDescriptorNode(
            kind: .composite,
            typeName: "SafeAreaPaddingView",
            props: .safeAreaPadding(
                WebSafeAreaPaddingDescriptor(
                    top: top, bottom: bottom, leading: leading, trailing: trailing
                )
            ),
            children: [webDescribeView(content)]
        )
    }
}

extension OnAppearView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        // Fire on render — host-level approximation only.
        // See web-parity-plan.md for limitations.
        action()
        return child
    }
}

extension SearchableView: WebRenderable, WebDescribable {
    public func webCreateElement() -> JSValue {
        let container = document.createElement("div")
        container.style = "display: flex; flex-direction: column; gap: 8px;"

        let input = document.createElement("input")
        input.type = "search"
        input.placeholder = .string(prompt)
        input.value = .string(text.wrappedValue)
        input.style = "padding: 6px 8px; font-size: 14px; width: 100%; box-sizing: border-box;"

        // Honor isPresented: hide the search field when explicitly dismissed
        if let presented = isPresented, !presented.wrappedValue {
            input.style = "display: none;"
        }

        let binding = text
        let presentedBinding = isPresented
        let handler = webMakeClosure { _ in
            let newValue = input.value.string ?? ""
            if newValue != binding.wrappedValue {
                binding.wrappedValue = newValue
            }
            // When text changes and isPresented binding exists, ensure it's true
            if let presented = presentedBinding, !presented.wrappedValue {
                presented.wrappedValue = true
            }
            return .undefined
        }
        _ = input.addEventListener("input", handler)

        _ = container.appendChild(input)

        let contentEl = webRenderView(content)
        _ = container.appendChild(contentEl)

        return container
    }

    public func webDescribeNode() -> WebDescriptorNode {
        WebDescriptorNode(
            kind: .composite,
            typeName: "SearchableView",
            props: .searchable(
                WebSearchableDescriptor(
                    prompt: prompt,
                    placement: webSearchFieldPlacementString(placement),
                    isPresented: isPresented?.wrappedValue
                )
            ),
            children: [webDescribeView(content)]
        )
    }
}

private func webSearchFieldPlacementString(_ placement: SearchFieldPlacement) -> String {
    switch placement {
    case .automatic: return "automatic"
    case .toolbar: return "toolbar"
    case .sidebar: return "sidebar"
    case .navigationBarDrawer(let displayMode):
        switch displayMode {
        case .automatic: return "navigationBarDrawer"
        case .always: return "navigationBarDrawerAlways"
        }
    }
}

extension ConfirmationDialogView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)

        if isPresented.wrappedValue {
            let overlay = webCreateModalOverlay(title: title, presented: isPresented, buttons: buttons)
            let wrapper = document.createElement("div")
            _ = wrapper.appendChild(child)
            _ = wrapper.appendChild(overlay)
            return wrapper
        }

        return child
    }
}

// MARK: - Modal overlay helper

/// Shared modal overlay used by ConfirmationDialog, .sheet(), and .alert().
private func webCreateModalOverlay(
    title: String,
    presented: Binding<Bool>,
    message: String? = nil,
    buttons: [AlertButton] = [],
    sheetContent: JSValue? = nil
) -> JSValue {
    let overlay = document.createElement("div")
    overlay.style = "position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.4); display: flex; align-items: center; justify-content: center; z-index: 9999;"

    let dialog = document.createElement("div")
    dialog.style = "background: #2a2a2a; border-radius: 8px; padding: 20px; min-width: 280px; max-width: 480px; color: white;"

    let titleEl = document.createElement("h3")
    titleEl.textContent = .string(title)
    titleEl.style = "margin: 0 0 12px 0; font-size: 16px;"
    _ = dialog.appendChild(titleEl)

    if let msg = message, !msg.isEmpty {
        let msgEl = document.createElement("p")
        msgEl.textContent = .string(msg)
        msgEl.style = "margin: 0 0 12px 0; font-size: 14px; color: #aaa;"
        _ = dialog.appendChild(msgEl)
    }

    if let content = sheetContent {
        _ = dialog.appendChild(content)
        let closeBtn = document.createElement("button")
        closeBtn.textContent = "Close"
        closeBtn.style = "display: block; width: 100%; padding: 8px; margin-top: 12px; cursor: pointer; border: none; border-radius: 4px; font-size: 14px; background: #555; color: white;"
        let handler = webMakeClosure { _ in
            presented.wrappedValue = false
            return .undefined
        }
        closeBtn.onclick = .object(handler)
        _ = dialog.appendChild(closeBtn)
    }

    for button in buttons {
        let btn = document.createElement("button")
        btn.textContent = .string(button.label)
        var btnStyle = "display: block; width: 100%; padding: 8px; margin-top: 4px; cursor: pointer; border: none; border-radius: 4px; font-size: 14px;"
        switch button.role {
        case .destructive: btnStyle += " background: #d33; color: white;"
        case .cancel: btnStyle += " background: #555; color: white;"
        default: btnStyle += " background: #0a84ff; color: white;"
        }
        btn.style = .string(btnStyle)

        let action = button.action
        let handler = webMakeClosure { _ in
            action()
            presented.wrappedValue = false
            return .undefined
        }
        btn.onclick = .object(handler)
        _ = dialog.appendChild(btn)
    }

    _ = overlay.appendChild(dialog)
    return overlay
}

// MARK: - Phase C views

extension TabView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let container = document.createElement("div")
        container.style = "display: flex; flex-direction: column; height: 100%;"

        // Tab bar
        let tabBar = document.createElement("div")
        tabBar.style = "display: flex; gap: 0; border-bottom: 1px solid #444;"

        // Content panels — pre-render all, show active only
        let contentArea = document.createElement("div")
        contentArea.style = "flex: 1; overflow: auto;"

        let activeIndex = initialTab ?? 0
        var panels: [JSValue] = []

        for (i, tab) in tabs.enumerated() {
            // Tab button
            let btn = document.createElement("button")
            btn.textContent = .string(tab.title)
            let isActive = i == activeIndex
            btn.style = .string("padding: 8px 16px; cursor: pointer; border: none; border-bottom: 2px solid \(isActive ? "#0a84ff" : "transparent"); background: \(isActive ? "#2a2a2a" : "#1a1a1a"); color: \(isActive ? "white" : "#888"); font-size: 14px;")
            btn.dataset.index = .string("\(i)")

            // Panel
            let panel = document.createElement("div")
            panel.style = .string("display: \(isActive ? "block" : "none");")
            let rendered = webRenderAnyView(tab.wrapped)
            _ = panel.appendChild(rendered)
            panels.append(panel)
            _ = contentArea.appendChild(panel)

            let tabBarRef = tabBar
            let handler = webMakeClosure { _ in
                // Hide all panels, show this one
                for (j, p) in panels.enumerated() {
                    p.style = .string("display: \(j == i ? "block" : "none");")
                    // Update tab button styles
                    if let tabBtn = tabBarRef.children[j].object {
                        tabBtn.style = .string("padding: 8px 16px; cursor: pointer; border: none; border-bottom: 2px solid \(j == i ? "#0a84ff" : "transparent"); background: \(j == i ? "#2a2a2a" : "#1a1a1a"); color: \(j == i ? "white" : "#888"); font-size: 14px;")
                    }
                }
                return .undefined
            }
            btn.onclick = .object(handler)

            _ = tabBar.appendChild(btn)
        }

        _ = container.appendChild(tabBar)
        _ = container.appendChild(contentArea)
        return container
    }
}

extension Grid: WebRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")

        if useExplicitRows {
            // Explicit rows: detect max column count from GridRow children
            var maxCols = 1

            // First pass: find the widest row
            let children = flattenChildren(content)
            for child in children {
                if let gridRow = child as? (any MultiChildView) {
                    let rowChildren = gridRow.children
                    var cols = 0
                    for rc in rowChildren {
                        if let span = rc as? GridCellSpanProvider {
                            cols += span.gridColumnSpan
                        } else {
                            cols += 1
                        }
                    }
                    maxCols = max(maxCols, cols)
                }
            }

            div.style = .string("display: grid; grid-template-columns: repeat(\(maxCols), 1fr); gap: \(vSpacing)px \(hSpacing)px;")

            // Second pass: render each row's children as grid cells
            for child in children {
                if let gridRow = child as? (any MultiChildView) {
                    for rc in gridRow.children {
                        let cell = webRenderAnyView(rc)
                        if let span = rc as? GridCellSpanProvider, span.gridColumnSpan > 1 {
                            let wrapper = document.createElement("div")
                            wrapper.style = .string("grid-column: span \(span.gridColumnSpan);")
                            _ = wrapper.appendChild(cell)
                            _ = div.appendChild(wrapper)
                        } else {
                            _ = div.appendChild(cell)
                        }
                    }
                } else {
                    let cell = webRenderAnyView(child)
                    _ = div.appendChild(cell)
                }
            }
        } else {
            // Auto-wrap mode
            div.style = .string("display: grid; grid-template-columns: repeat(\(columns), 1fr); gap: \(vSpacing)px \(hSpacing)px;")
            webRenderChildren(content) { child in
                _ = div.appendChild(child)
            }
        }

        return div
    }
}

extension GridRow: WebRenderable, WebMultiChildRenderable {
    public func webCreateElement() -> JSValue {
        // GridRow is typically consumed by Grid; standalone renders as a div
        let div = document.createElement("div")
        div.style = "display: contents;"
        webRenderChildren(content) { child in
            _ = div.appendChild(child)
        }

        return div
    }

    public func webForEachChild(_ body: (JSValue) -> Void) {
        BackendWeb.webRenderChildren(content, body)
    }
}

extension GridCellSpanView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let wrapper = document.createElement("div")
        wrapper.style = .string("grid-column: span \(gridColumnSpan);")
        _ = wrapper.appendChild(child)
        return wrapper
    }
}

extension LazyVStack: WebRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = "display: flex; flex-direction: column;"
        for item in items {
            let child = webRenderView(contentBuilder(item))
            _ = div.appendChild(child)
        }
        return div
    }
}

extension LazyHStack: WebRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = "display: flex; flex-direction: row;"
        for item in items {
            let child = webRenderView(contentBuilder(item))
            _ = div.appendChild(child)
        }
        return div
    }
}

extension LazyVGrid: WebRenderable {
    public func webCreateElement() -> JSValue {
        let colCount = max(1, gridItems.count)
        let div = document.createElement("div")
        div.style = .string("display: grid; grid-template-columns: repeat(\(colCount), 1fr); gap: 4px;")
        for item in items {
            let child = webRenderView(contentBuilder(item))
            _ = div.appendChild(child)
        }
        return div
    }
}

extension LazyHGrid: WebRenderable {
    public func webCreateElement() -> JSValue {
        let rowCount = max(1, gridItems.count)
        let div = document.createElement("div")
        div.style = .string("display: grid; grid-template-rows: repeat(\(rowCount), 1fr); grid-auto-flow: column; gap: 4px;")
        for item in items {
            let child = webRenderView(contentBuilder(item))
            _ = div.appendChild(child)
        }
        return div
    }
}

extension Menu: WebRenderable {
    public func webCreateElement() -> JSValue {
        let container = document.createElement("div")
        container.style = "position: relative; display: inline-block;"

        let btn = document.createElement("button")
        btn.textContent = .string(title)
        btn.style = "padding: 6px 12px; cursor: pointer; font-size: 14px;"

        let dropdown = document.createElement("div")
        dropdown.style = "display: none; position: absolute; top: 100%; left: 0; min-width: 160px; background: #2a2a2a; border: 1px solid #444; border-radius: 4px; z-index: 9999; padding: 4px 0;"

        webRenderMenuElements(elements, into: dropdown)

        let toggleHandler = webMakeClosure { _ in
            let current = dropdown.style.object?.display.string ?? "none"
            dropdown.style.object?.display = .string(current == "none" ? "block" : "none")
            return .undefined
        }
        btn.onclick = .object(toggleHandler)

        // Close on outside click
        let dropdownRef = dropdown
        let dismissHandler = webMakeClosure { args in
            guard let event = args.first?.object else { return .undefined }
            let target = event.target
            // Check if click is outside the container
            if container.contains(target).boolean != true {
                dropdownRef.style.object?.display = .string("none")
            }
            return .undefined
        }
        _ = JSObject.global.document.addEventListener("click", dismissHandler)

        _ = container.appendChild(btn)
        _ = container.appendChild(dropdown)
        return container
    }
}

private func webRenderMenuElements(_ elements: [MenuElement], into container: JSValue) {
    for element in elements {
        switch element {
        case .item(let label, let action):
            let item = document.createElement("button")
            item.textContent = .string(label)
            item.style = "display: block; width: 100%; padding: 6px 16px; border: none; background: none; color: white; text-align: left; cursor: pointer; font-size: 13px;"
            let handler = webMakeClosure { _ in
                action()
                return .undefined
            }
            item.onclick = .object(handler)
            _ = container.appendChild(item)

        case .divider:
            let hr = document.createElement("hr")
            hr.style = "margin: 4px 0; border: none; border-top: 1px solid #444;"
            _ = container.appendChild(hr)

        case .submenu(let label, let children):
            let sub = document.createElement("div")
            sub.style = "position: relative;"
            let subBtn = document.createElement("button")
            subBtn.textContent = .string("\(label) ▸")
            subBtn.style = "display: block; width: 100%; padding: 6px 16px; border: none; background: none; color: white; text-align: left; cursor: pointer; font-size: 13px;"

            let subMenu = document.createElement("div")
            subMenu.style = "display: none; position: absolute; left: 100%; top: 0; min-width: 140px; background: #2a2a2a; border: 1px solid #444; border-radius: 4px; padding: 4px 0;"
            webRenderMenuElements(children, into: subMenu)

            let subHandler = webMakeClosure { _ in
                let current = subMenu.style.object?.display.string ?? "none"
                subMenu.style.object?.display = .string(current == "none" ? "block" : "none")
                return .undefined
            }
            subBtn.onclick = .object(subHandler)

            _ = sub.appendChild(subBtn)
            _ = sub.appendChild(subMenu)
            _ = container.appendChild(sub)
        }
    }
}

extension NavigationSplitView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let container = document.createElement("div")
        container.style = "display: flex; flex-direction: row; height: 100%;"

        // Sidebar
        let sidebarEl = document.createElement("div")
        sidebarEl.style = .string("width: \(sidebarWidth)px; min-width: \(sidebarWidth)px; border-right: 1px solid #444; overflow: auto;")

        // Extract column width from sidebar if present
        if let provider = sidebar as? NavigationSplitViewColumnWidthProvider,
           let ideal = provider.columnIdealWidth {
            let minW = provider.columnMinWidth ?? ideal
            let maxW = provider.columnMaxWidth ?? ideal
            sidebarEl.style = .string("width: \(Int(ideal))px; min-width: \(Int(minW))px; max-width: \(Int(maxW))px; border-right: 1px solid #444; overflow: auto;")
        }

        let sidebarContent = webRenderView(sidebar)
        _ = sidebarEl.appendChild(sidebarContent)
        _ = container.appendChild(sidebarEl)

        // Content column (three-column mode)
        if hasContentColumn {
            let contentEl = document.createElement("div")
            contentEl.style = "width: 250px; min-width: 200px; border-right: 1px solid #444; overflow: auto;"
            let contentRendered = webRenderView(content)
            _ = contentEl.appendChild(contentRendered)
            _ = container.appendChild(contentEl)
        }

        // Detail
        let detailEl = document.createElement("div")
        detailEl.style = "flex: 1; overflow: auto;"
        let detailContent = webRenderView(detail)
        _ = detailEl.appendChild(detailContent)
        _ = container.appendChild(detailEl)

        return container
    }
}

// MARK: - Phase C modifiers

extension SheetModifierView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let host = WebViewHost.currentRebuilding
        let sheetKey = host?.nextSheetKey() ?? -1

        if isPresented.wrappedValue {
            // Register this sheet as active for transition detection
            host?.currentSheetState[sheetKey] = onDismiss
            let sheetEl = webRenderView(sheetContent)
            let overlay = webCreateModalOverlay(
                title: "",
                presented: isPresented,
                sheetContent: sheetEl
            )
            let wrapper = document.createElement("div")
            _ = wrapper.appendChild(child)
            _ = wrapper.appendChild(overlay)
            return wrapper
        }

        // Not presenting — host post-render check handles onDismiss transition
        return child
    }
}

extension ItemSheetModifierView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let host = WebViewHost.currentRebuilding
        let sheetKey = host?.nextSheetKey() ?? -1

        if let currentItem = item.wrappedValue {
            // Register this item sheet as active for transition detection
            host?.currentSheetState[sheetKey] = onDismiss
            let sheetEl = webRenderView(sheetContent(currentItem))
            let itemBinding = item
            let overlay = webCreateModalOverlay(
                title: "",
                presented: Binding(
                    get: { itemBinding.wrappedValue != nil },
                    set: { newValue in
                        if !newValue { itemBinding.wrappedValue = nil }
                    }
                ),
                sheetContent: sheetEl
            )
            let wrapper = document.createElement("div")
            _ = wrapper.appendChild(child)
            _ = wrapper.appendChild(overlay)
            return wrapper
        }

        // Not presenting — host post-render check handles onDismiss transition
        return child
    }
}

extension AlertModifierView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)

        if isPresented.wrappedValue {
            let overlay = webCreateModalOverlay(
                title: title,
                presented: isPresented,
                message: message,
                buttons: buttons
            )
            let wrapper = document.createElement("div")
            _ = wrapper.appendChild(child)
            _ = wrapper.appendChild(overlay)
            return wrapper
        }

        return child
    }
}

// MARK: - Phase D (partial)

extension ToolbarView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)

        // Inject toolbar items into the current NavigationStack header
        if let ctx = _webCurrentNavContext {
            ctx.toolbarArea.innerHTML = ""
            for item in toolbarItems {
                let rendered = webRenderAnyView(item.wrapped)
                _ = ctx.toolbarArea.appendChild(rendered)
            }
        }

        return child
    }
}

// MARK: - Canvas

/// Wraps a JS CanvasRenderingContext2D for use as DrawingContext.cr
private class WebCanvasContext {
    let jsContext: JSValue
    init(_ ctx: JSValue) { self.jsContext = ctx }
}

/// Retained Web canvas contexts (prevent deallocation during draw).
private var _webCanvasContexts: [WebCanvasContext] = []

extension DrawingContext {
    /// Access the underlying JS Canvas 2D context.
    fileprivate var jsCtx: JSValue {
        Unmanaged<WebCanvasContext>.fromOpaque(UnsafeMutableRawPointer(cr)).takeUnretainedValue().jsContext
    }

    // MARK: - Color
    public func setColor(r: Double, g: Double, b: Double) {
        jsCtx.strokeStyle = .string("rgb(\(Int(r * 255)), \(Int(g * 255)), \(Int(b * 255)))")
        jsCtx.fillStyle = .string("rgb(\(Int(r * 255)), \(Int(g * 255)), \(Int(b * 255)))")
    }
    public func setColor(r: Double, g: Double, b: Double, a: Double) {
        jsCtx.strokeStyle = .string("rgba(\(Int(r * 255)), \(Int(g * 255)), \(Int(b * 255)), \(a))")
        jsCtx.fillStyle = .string("rgba(\(Int(r * 255)), \(Int(g * 255)), \(Int(b * 255)), \(a))")
    }

    // MARK: - Line style
    public func setLineWidth(_ width: Double) {
        jsCtx.lineWidth = .number(width)
    }
    public func setLineCap(_ cap: LineCap) {
        let v: String
        switch cap {
        case .butt: v = "butt"
        case .round: v = "round"
        case .square: v = "square"
        }
        jsCtx.lineCap = .string(v)
    }
    public func setLineJoin(_ join: LineJoin) {
        let v: String
        switch join {
        case .miter: v = "miter"
        case .round: v = "round"
        case .bevel: v = "bevel"
        }
        jsCtx.lineJoin = .string(v)
    }

    // MARK: - Path operations
    public func moveTo(x: Double, y: Double) {
        _ = jsCtx.object!.moveTo!(x, y)
    }
    public func lineTo(x: Double, y: Double) {
        _ = jsCtx.object!.lineTo!(x, y)
    }
    public func rectangle(x: Double, y: Double, width: Double, height: Double) {
        _ = jsCtx.object!.rect!(x, y, width, height)
    }
    public func arc(centerX: Double, centerY: Double, radius: Double,
                    startAngle: Double = 0, endAngle: Double = .pi * 2) {
        _ = jsCtx.object!.arc!(centerX, centerY, radius, startAngle, endAngle)
    }

    // MARK: - Drawing
    public func stroke() {
        _ = jsCtx.object!.stroke!()
    }
    public func fill() {
        _ = jsCtx.object!.fill!()
    }
    public func paint() {
        let c = jsCtx.object!
        let w = c.canvas.object!.width.number ?? 0
        let h = c.canvas.object!.height.number ?? 0
        _ = c.fillRect!(0, 0, w, h)
    }

    // MARK: - State
    public func save() { _ = jsCtx.object!.save!() }
    public func restore() { _ = jsCtx.object!.restore!() }
    public func scale(x: Double, y: Double) { _ = jsCtx.object!.scale!(x, y) }
}

extension Canvas: WebRenderable {
    public func webCreateElement() -> JSValue {
        let canvas = document.createElement("canvas")
        let w = width > 0 ? width : 300
        let h = height > 0 ? height : 150
        canvas.width = .number(Double(w))
        canvas.height = .number(Double(h))
        canvas.style = .string("width: \(w)px; height: \(h)px;")

        // Get 2D context and wrap for DrawingContext
        let jsCtx = canvas.object!.getContext!("2d")
        let webCtx = WebCanvasContext(jsCtx)
        _webCanvasContexts.append(webCtx)

        let ptr = Unmanaged.passRetained(webCtx).toOpaque()
        let drawCtx = DrawingContext(cr: OpaquePointer(ptr))

        // Call the draw handler
        _ = jsCtx.object!.beginPath!()
        drawHandler(drawCtx, w, h)

        return canvas
    }
}

// MARK: - GeometryReader

/// Retains GeometryReader contexts so ResizeObserver callbacks survive.
private var _webGeometryContexts: [WebGeometryContext] = []

private class WebGeometryContext {
    let container: JSValue
    let contentBuilder: (GeometryProxy) -> JSValue
    var lastWidth: Double = -1
    var lastHeight: Double = -1

    init(container: JSValue, contentBuilder: @escaping (GeometryProxy) -> JSValue) {
        self.container = container
        self.contentBuilder = contentBuilder
    }

    func renderWithSize(width: Double, height: Double) {
        // Only re-render if size actually changed
        guard width != lastWidth || height != lastHeight else { return }
        lastWidth = width
        lastHeight = height

        let proxy = GeometryProxy(size: GeometrySize(width: width, height: height))
        let child = contentBuilder(proxy)
        container.innerHTML = ""
        _ = container.appendChild(child)
    }
}

extension GeometryReader: WebRenderable {
    public func webCreateElement() -> JSValue {
        let wrapper = document.createElement("div")
        wrapper.style = "width: 100%; flex: 1; position: relative;"

        let contentDiv = document.createElement("div")
        _ = wrapper.appendChild(contentDiv)

        // Capture the content builder as a function that returns JSValue
        let builder = content
        let ctx = WebGeometryContext(container: contentDiv) { proxy in
            let view = builder(proxy)
            return webRenderView(view)
        }
        _webGeometryContexts.append(ctx)

        // Initial render with zero size — will be updated by ResizeObserver
        ctx.renderWithSize(width: 0, height: 0)

        // Set up ResizeObserver to detect actual dimensions
        let observerCallback = webMakeClosure { entries in
            guard let entry = entries.first?.object,
                  let contentRect = entry.contentRect.object else { return .undefined }
            let w = contentRect.width.number ?? 0
            let h = contentRect.height.number ?? 0
            ctx.renderWithSize(width: w, height: h)
            return .undefined
        }

        let observer = JSObject.global.ResizeObserver.function!.new(observerCallback)
        _ = observer.observe!(wrapper)

        return wrapper
    }
}
