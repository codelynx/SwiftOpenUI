import JavaScriptKit
import SwiftOpenUI

// MARK: - JSClosure lifetime management

/// Retains JSClosure instances so they survive until the next rebuild.
/// Cleared at the start of each WebViewHost rebuild — old closures are
/// released when their DOM elements are destroyed via innerHTML = "".
var _webRetainedClosures: [JSClosure] = []

/// Retain a JSClosure so it lives as long as its DOM element.
func webRetainClosure(_ closure: JSClosure) {
    _webRetainedClosures.append(closure)
}

/// Retains WebViewHost instances so they survive for the lifetime of the app.
/// Without this, WebViewHost is deallocated after webRenderStatefulView returns,
/// and scheduleRebuild's requestAnimationFrame callback finds a nil weak self.
var _webRetainedHosts: [WebViewHost] = []

// MARK: - Web rendering protocol

/// Protocol that views implement (via extensions) to provide DOM element creation.
public protocol WebRenderable {
    func webCreateElement() -> JSValue
}

/// Protocol for views that provide multiple DOM child elements.
public protocol WebMultiChildRenderable {
    func webRenderChildren() -> [JSValue]
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

/// Render children from a view.
public func webRenderChildren<V: View>(_ view: V) -> [JSValue] {
    if let multi = view as? WebMultiChildRenderable {
        return multi.webRenderChildren()
    }
    if let multi = view as? MultiChildView {
        return multi.children.map { child in
            func render<C: View>(_ c: C) -> JSValue { webRenderView(c) }
            return render(child)
        }
    }
    return [webRenderView(view)]
}

/// Render an existential (any View).
public func webRenderAnyView(_ view: any View) -> JSValue {
    func render<V: View>(_ v: V) -> JSValue { webRenderView(v) }
    return render(view)
}

// MARK: - Primitive view extensions

extension Text: WebRenderable {
    public func webCreateElement() -> JSValue {
        let span = document.createElement("span")
        span.textContent = .string(content)
        return span
    }
}

extension EmptyView: WebRenderable {
    public func webCreateElement() -> JSValue {
        return document.createElement("span")
    }
}

extension Spacer: WebRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = "flex: 1;"
        return div
    }
}

extension SwiftOpenUI.Divider: WebRenderable {
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
        let handler = JSClosure { _ in
            guard !_webSuppressInputHandler else { return .undefined }
            let newValue = input.value.string ?? ""
            if newValue != binding.wrappedValue {
                binding.wrappedValue = newValue
            }
            return .undefined
        }
        webRetainClosure(handler)
        _ = input.addEventListener("input", handler)

        return input
    }
}

extension FocusedView: WebRenderable {
    public func webCreateElement() -> JSValue {
        webRenderView(content)
    }
}

extension FocusedEqualsView: WebRenderable {
    public func webCreateElement() -> JSValue {
        webRenderView(content)
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
            element.style.setProperty("transition", "all \(anim.duration)s \(timing)")
        }
        return element
    }
}

// MARK: - Navigation views

/// Thread-local navigation context for the Web backend.
/// Manages a stack of DOM elements with push/pop transitions.
private class WebNavigationContext {
    let container: JSValue         // outer div
    let headerTitle: JSValue       // <span> for title text
    let backButton: JSValue        // <button> Back
    let contentArea: JSValue       // div holding current page
    var stack: [(element: JSValue, title: String)] = []

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

        _ = container.appendChild(header)

        // Content area
        contentArea = doc.createElement("div")
        contentArea.style = "flex: 1;"
        _ = container.appendChild(contentArea)

        // Wire back button
        let backHandler = JSClosure { [weak self] _ in
            self?.pop()
            return .undefined
        }
        webRetainClosure(backHandler)
        backButton.onclick = .object(backHandler)
    }

    func push(element: JSValue, title: String) {
        stack.append((element: element, title: title))
        contentArea.innerHTML = ""
        _ = contentArea.appendChild(element)
        headerTitle.textContent = .string(title)
        backButton.style = "display: inline-block; padding: 4px 8px; cursor: pointer;"
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
    }

    func setRoot(element: JSValue, title: String) {
        stack = [(element: element, title: title)]
        contentArea.innerHTML = ""
        _ = contentArea.appendChild(element)
        headerTitle.textContent = .string(title)
        backButton.style = "display: none; padding: 4px 8px; cursor: pointer;"
    }
}

/// Current navigation context — set during NavigationStack rendering.
private var _webCurrentNavContext: WebNavigationContext?

extension NavigationStack: WebRenderable {
    public func webCreateElement() -> JSValue {
        let ctx = WebNavigationContext()
        let previousCtx = _webCurrentNavContext
        _webCurrentNavContext = ctx

        // Extract title from content if it has .navigationTitle
        var title = "Home"
        if let titled = content as? NavigationTitled {
            title = titled.navigationTitle
        }

        // Render root content
        let rootElement = webRenderView(content)
        ctx.setRoot(element: rootElement, title: title)

        _webCurrentNavContext = previousCtx
        return ctx.container
    }
}

extension NavigationLink: WebRenderable {
    public func webCreateElement() -> JSValue {
        let button = document.createElement("button")
        button.textContent = .string(label)
        button.style = "padding: 6px 12px; cursor: pointer;"

        // Capture the nav context NOW (during render), not at click time
        let capturedCtx = _webCurrentNavContext

        let handler = JSClosure { _ in
            guard let ctx = capturedCtx else { return .undefined }
            let prevCtx = _webCurrentNavContext
            _webCurrentNavContext = ctx
            let destElement = webRenderView(self.destination())
            _webCurrentNavContext = prevCtx
            ctx.push(element: destElement, title: self.title)
            return .undefined
        }
        webRetainClosure(handler)
        button.onclick = .object(handler)

        return button
    }
}

extension TitledView: WebRenderable {
    public func webCreateElement() -> JSValue {
        // Pass through — title is read by NavigationStack during rendering
        webRenderView(content)
    }
}

extension NavigationDestinationModifier: WebRenderable {
    public func webCreateElement() -> JSValue {
        // Pass through — path-based navigation not yet implemented on Web
        webRenderView(content)
    }
}

// MARK: - Gesture views

extension TapGestureView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let element = webRenderView(content)

        if count <= 1 {
            // Single tap — use click event
            let handler = JSClosure { _ in
                self.action()
                return .undefined
            }
            webRetainClosure(handler)
            _ = element.addEventListener("click", handler)
        } else {
            // Multi-tap (e.g. double-click) — track click count with timeout
            var clickCount = 0
            var timer: JSValue = .undefined
            let requiredCount = count

            let handler = JSClosure { _ in
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
                    let resetClosure = JSClosure { _ in
                        clickCount = 0
                        return .undefined
                    }
                    webRetainClosure(resetClosure)
                    timer = JSObject.global.setTimeout!(resetClosure, 400)
                }
                return .undefined
            }
            webRetainClosure(handler)
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
        let downHandler = JSClosure { _ in
            fired = false
            let fireClosure = JSClosure { _ in
                fired = true
                self.action()
                return .undefined
            }
            webRetainClosure(fireClosure)
            timer = JSObject.global.setTimeout!(fireClosure, durationMs)
            return .undefined
        }
        webRetainClosure(downHandler)
        _ = element.addEventListener("pointerdown", downHandler)

        // Cancel on pointerup / pointerleave
        let cancelHandler = JSClosure { _ in
            if timer != .undefined {
                _ = JSObject.global.clearTimeout!(timer)
                timer = .undefined
            }
            return .undefined
        }
        webRetainClosure(cancelHandler)
        _ = element.addEventListener("pointerup", cancelHandler)
        _ = element.addEventListener("pointerleave", cancelHandler)

        // Prevent context menu if long press fired
        let contextHandler = JSClosure { event in
            if fired {
                _ = event[0].preventDefault()
            }
            return .undefined
        }
        webRetainClosure(contextHandler)
        _ = element.addEventListener("contextmenu", contextHandler)

        // Make element interactive
        element.style.setProperty("touch-action", "none")
        element.style.setProperty("user-select", "none")
        element.style.setProperty("-webkit-user-select", "none")

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

        let moveHandler = JSClosure { event in
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
        webRetainClosure(moveHandler)

        let upHandler = JSClosure { event in
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
        webRetainClosure(upHandler)

        let downHandler = JSClosure { event in
            let e = event[0]
            startX = e.clientX.number!
            startY = e.clientY.number!
            dragging = false
            _ = JSObject.global.document.addEventListener("pointermove", moveHandler)
            _ = JSObject.global.document.addEventListener("pointerup", upHandler)
            return .undefined
        }
        webRetainClosure(downHandler)
        _ = element.addEventListener("pointerdown", downHandler)

        // Prevent default drag behavior
        element.style.setProperty("touch-action", "none")
        element.style.setProperty("user-select", "none")
        element.style.setProperty("-webkit-user-select", "none")

        return element
    }
}

extension SwiftOpenUI.Button: WebRenderable {
    public func webCreateElement() -> JSValue {
        let button = document.createElement("button")
        button.style = "padding: 6px 12px; cursor: pointer;"

        // Render label content
        let labelElement = webRenderView(label)
        _ = button.appendChild(labelElement)

        // Wire up action
        let handler = JSClosure { _ in
            self.action()
            return .undefined
        }
        webRetainClosure(handler)
        button.onclick = .object(handler)

        return button
    }
}

extension SwiftOpenUI.Color: WebRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = .string("background-color: \(cssColor); width: 100%; height: 100%; min-height: 20px;")
        return div
    }

    var cssColor: String {
        "rgba(\(Int(red * 255)), \(Int(green * 255)), \(Int(blue * 255)), \(alpha))"
    }
}

// MARK: - Container views

extension VStack: WebRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = .string("display: flex; flex-direction: column; gap: \(spacing)px; align-items: \(cssAlignment);")

        for child in webRenderChildren(content) {
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
}

extension HStack: WebRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = .string("display: flex; flex-direction: row; gap: \(spacing)px; align-items: \(cssAlignment);")

        for child in webRenderChildren(content) {
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
}

extension ZStack: WebRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        div.style = "display: grid; place-items: center;"

        for child in webRenderChildren(content) {
            // All children stack in the same grid cell
            child.style.object?.gridArea = "1 / 1"
            _ = div.appendChild(child)
        }
        return div
    }
}

extension Group: WebRenderable, WebMultiChildRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        for child in webRenderChildren() {
            _ = div.appendChild(child)
        }
        return div
    }

    public func webRenderChildren() -> [JSValue] {
        BackendWeb.webRenderChildren(content)
    }
}

extension ForEach: WebRenderable, WebMultiChildRenderable {
    public func webCreateElement() -> JSValue {
        let div = document.createElement("div")
        for child in webRenderChildren() {
            _ = div.appendChild(child)
        }
        return div
    }

    public func webRenderChildren() -> [JSValue] {
        data.map { item in
            let view = content(item)
            return webRenderView(view)
        }
    }
}

// MARK: - Modifier views

extension PaddedView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let padding = "padding: \(top)px \(trailing)px \(bottom)px \(leading)px;"
        let wrapper = document.createElement("div")
        wrapper.style = .string(padding)
        _ = wrapper.appendChild(child)
        return wrapper
    }
}

extension FrameView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        var styles = [String]()
        if let w = width { styles.append("width: \(w)px") }
        if let h = height { styles.append("height: \(h)px") }
        if let minW = minWidth { styles.append("min-width: \(minW)px") }
        if let maxW = maxWidth { styles.append("max-width: \(maxW == .infinity ? 99999 : maxW)px") }
        if let minH = minHeight { styles.append("min-height: \(minH)px") }
        if let maxH = maxHeight { styles.append("max-height: \(maxH == .infinity ? 99999 : maxH)px") }

        let wrapper = document.createElement("div")
        wrapper.style = .string(styles.joined(separator: "; ") + ";")
        _ = wrapper.appendChild(child)
        return wrapper
    }
}

extension ForegroundColorView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let css = "color: \(color.cssColor);"
        let wrapper = document.createElement("div")
        wrapper.style = .string(css)
        _ = wrapper.appendChild(child)
        return wrapper
    }
}

extension BackgroundView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let css = "background-color: \(color.cssColor);"
        let wrapper = document.createElement("div")
        wrapper.style = .string(css)
        _ = wrapper.appendChild(child)
        return wrapper
    }
}

extension FontModifiedView: WebRenderable {
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

extension BorderView: WebRenderable {
    public func webCreateElement() -> JSValue {
        let child = webRenderView(content)
        let css = "border: \(width)px solid \(color.cssColor);"
        let wrapper = document.createElement("div")
        wrapper.style = .string(css)
        _ = wrapper.appendChild(child)
        return wrapper
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

// MARK: - TupleView rendering

extension TupleView2: WebMultiChildRenderable {
    public func webRenderChildren() -> [JSValue] {
        [webRenderView(v0), webRenderView(v1)]
    }
}

extension TupleView3: WebMultiChildRenderable {
    public func webRenderChildren() -> [JSValue] {
        [webRenderView(v0), webRenderView(v1), webRenderView(v2)]
    }
}

extension TupleView4: WebMultiChildRenderable {
    public func webRenderChildren() -> [JSValue] {
        [webRenderView(v0), webRenderView(v1), webRenderView(v2), webRenderView(v3)]
    }
}

extension TupleView5: WebMultiChildRenderable {
    public func webRenderChildren() -> [JSValue] {
        [webRenderView(v0), webRenderView(v1), webRenderView(v2), webRenderView(v3), webRenderView(v4)]
    }
}

extension TupleView6: WebMultiChildRenderable {
    public func webRenderChildren() -> [JSValue] {
        [webRenderView(v0), webRenderView(v1), webRenderView(v2), webRenderView(v3), webRenderView(v4), webRenderView(v5)]
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
