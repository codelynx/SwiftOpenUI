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

// MARK: - Button action registry

/// Maps stable node IDs (Int64) to button action closures.
/// Cleared at the start of each render pass, populated during rendering.
public var androidButtonActions: [Int64: () -> Void] = [:]

/// Maps stable node IDs (Int64) to text field bindings.
/// Cleared at the start of each render pass, populated during rendering.
public var androidTextBindings: [Int64: Binding<String>] = [:]

/// Maps stable node IDs (Int64) to toggle bindings.
/// Cleared at the start of each render pass, populated during rendering.
public var androidToggleBindings: [Int64: Binding<Bool>] = [:]

/// Maps stable node IDs (Int64) to slider bindings.
/// Cleared at the start of each render pass, populated during rendering.
public var androidSliderBindings: [Int64: Binding<Double>] = [:]

/// Maps stable node IDs (Int64) to drag gesture handlers.
/// Cleared at the start of each render pass, populated during rendering.
public var androidDragHandlers: [Int64: AndroidDragHandler] = [:]

/// Drag gesture handler with onChanged and onEnded callbacks.
public struct AndroidDragHandler {
    public let minimumDistance: Double
    public let onChanged: ((DragGestureValue) -> Void)?
    public let onEnded: ((DragGestureValue) -> Void)?
}

/// Closure that updates a FocusState when the platform reports a focus change.
/// The Bool parameter is true for focus gained, false for focus lost.
public typealias FocusChangeHandler = (Bool) -> Void

/// Maps stable node IDs (Int64) to focus change handlers.
/// Cleared at the start of each render pass, populated during rendering.
public var androidFocusHandlers: [Int64: FocusChangeHandler] = [:]

/// Structural state cache — persists @State values across renders for nested views.
/// Maps node ID → array of AnyStateStorage (one per @State property, in Mirror order).
/// NOT cleared per render pass — this is the persistence mechanism.
public var androidStateCache: [Int64: [AnyStateStorage]] = [:]

/// The current ViewHost during a render pass, used to wire @State on nested views.
public weak var androidCurrentHost: AnyViewHost?

/// Set to true during rebuild when programmatic focus was cleared to nil.
/// The root window node emits a clearFocus prop so Compose dismisses focus.
public var androidShouldClearFocus: Bool = false

/// Counter for generating structural node IDs during a render pass.
/// Uses FNV-1a-inspired hashing of the path components.
private var _idPathStack: [Int64] = [0]  // root hash
private var _idChildCounters: [Int] = [0]

/// Begin a new render pass — clears action registry and resets ID generation.
public func androidBeginRenderPass() {
    androidButtonActions.removeAll()
    androidTextBindings.removeAll()
    androidToggleBindings.removeAll()
    androidSliderBindings.removeAll()
    androidDragHandlers.removeAll()
    androidFocusHandlers.removeAll()
    _idPathStack = [0]
    _idChildCounters = [0]
}

/// Push a child context for ID generation.
/// Call before rendering a child; the type tag differentiates sibling types.
public func androidPushChild(typeTag: String) -> Int64 {
    let index = _idChildCounters[_idChildCounters.count - 1]
    _idChildCounters[_idChildCounters.count - 1] = index + 1

    // FNV-1a-inspired hash combining parent hash + type + index
    let parentHash = _idPathStack.last ?? 0
    var hash: Int64 = parentHash &* 16777619
    for byte in typeTag.utf8 {
        hash ^= Int64(byte)
        hash = hash &* 16777619
    }
    hash ^= Int64(index)
    hash = hash &* 16777619

    _idPathStack.append(hash)
    _idChildCounters.append(0)
    return hash
}

/// Pop the current child context after rendering.
public func androidPopChild() {
    _idPathStack.removeLast()
    _idChildCounters.removeLast()
}

/// Get the current node's ID (top of the path stack).
public func androidCurrentNodeId() -> Int64 {
    _idPathStack.last ?? 0
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
