import JavaScriptKit
import SwiftOpenUI

/// Protocol for scenes that can render into the DOM.
protocol WebWindowRenderable {
    func webRender()
}

extension WindowGroup: WebWindowRenderable {
    func webRender() {
        let document = JSObject.global.document

        // Set page title
        document.title = .string(title)

        // Determine container sizing from WindowGroup properties
        let sizing = windowSizing ?? .automatic
        let hasExplicitSize: Bool
        var containerWidth: Double?
        var containerHeight: Double?

        switch sizing {
        case .size(let w, let h):
            containerWidth = w
            containerHeight = h
            hasExplicitSize = true
        case .content, .contentFixed:
            containerWidth = defaultWindowWidth
            containerHeight = defaultWindowHeight
            hasExplicitSize = containerWidth != nil || containerHeight != nil
        case .automatic:
            containerWidth = defaultWindowWidth
            containerHeight = defaultWindowHeight
            hasExplicitSize = containerWidth != nil || containerHeight != nil
        }

        // Body style: center the container if it has an explicit size
        if hasExplicitSize {
            document.body.style = .string("""
                margin: 0; min-height: 100vh; \
                display: flex; justify-content: center; align-items: flex-start; \
                padding-top: 20px; \
                background: #1a1a1a;
                """)
        } else {
            document.body.style = .string("margin: 0; min-height: 100vh;")
        }

        // Create app container
        let container = document.createElement("div")
        container.id = "app"

        var containerStyles = "font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;"
        if let w = containerWidth {
            containerStyles += " width: \(Int(w))px;"
        }
        if let h = containerHeight {
            containerStyles += " height: \(Int(h))px;"
        }
        if !hasExplicitSize {
            containerStyles += " min-height: 100vh; display: flex; flex-direction: column;"
        } else {
            containerStyles += " overflow: hidden;"
        }
        container.style = .string(containerStyles)

        // Render content into DOM
        let element = webRenderView(content)
        _ = container.appendChild(element)
        _ = document.body.appendChild(container)
    }
}

/// WebAssembly/DOM rendering backend for SwiftOpenUI.
public struct WebBackend: RenderBackend {
    public init() {}

    public func run<A: App>(_ appType: A.Type) {
        let instance = A()
        webRenderScene(instance.body)
    }
}

/// Recursively render a Scene. Terminal scenes (WindowGroup) render directly;
/// composite scenes recurse through their body.
private func webRenderScene<S: Scene>(_ scene: S) {
    if let renderable = scene as? WebWindowRenderable {
        renderable.webRender()
        return
    }
    if S.Body.self != Never.self {
        webRenderScene(scene.body)
    }
}
