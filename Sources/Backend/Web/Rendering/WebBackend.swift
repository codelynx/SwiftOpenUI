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

        // Reset body margins so app fills viewport
        document.body.style = "margin: 0; min-height: 100vh;"

        // Create app container
        let container = document.createElement("div")
        container.id = "app"
        container.style = "font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; min-height: 100vh; display: flex; flex-direction: column;"

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
