import SwiftOpenUI

/// Android rendering backend for SwiftOpenUI.
/// Renders the view tree to a JSON RenderNode tree, which the Kotlin
/// host decodes and applies to Android Views.
public struct AndroidBackend: RenderBackend {
    public init() {}

    public func run<A: App>(_ appType: A.Type) {
        // On Android, the Kotlin host drives the lifecycle.
        // This is a no-op — rendering is triggered via JNI.
        fatalError("AndroidBackend.run() should not be called directly. Use JNI entry points.")
    }
}

/// Render an App's view tree to a JSON string for the Kotlin host.
public func androidRenderAppToJSON<A: App>(_ appType: A.Type) -> String {
    let instance = A()
    let scene = instance.body
    return androidRenderSceneToJSON(scene)
}

/// Render a Scene to JSON. Walks until it finds a WindowGroup.
private func androidRenderSceneToJSON<S: Scene>(_ scene: S) -> String {
    if let windowGroup = scene as? AndroidSceneRenderable {
        return windowGroup.androidRenderToJSON()
    }
    if S.Body.self != Never.self {
        return androidRenderSceneToJSON(scene.body)
    }
    return "{}"
}

/// Protocol for scenes that can produce a render tree.
protocol AndroidSceneRenderable {
    func androidRenderToJSON() -> String
}

extension WindowGroup: AndroidSceneRenderable {
    func androidRenderToJSON() -> String {
        let rootNode = androidRenderView(content)
        let wrapper = RenderNode(type: "window")
        wrapper.props["title"] = title
        wrapper.children = [rootNode]
        return renderNodeToJSON(wrapper)
    }
}
