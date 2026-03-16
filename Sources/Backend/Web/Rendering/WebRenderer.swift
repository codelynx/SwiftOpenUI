import JavaScriptKit
import SwiftOpenUI

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
