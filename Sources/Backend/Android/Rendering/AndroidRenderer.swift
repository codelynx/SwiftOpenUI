import SwiftOpenUI

// MARK: - Layout measurement

/// Estimator for child view sizes on Android.
/// Since we don't have direct access to Android's measurement APIs during the
/// Swift render pass, we use standard metrics for primitive views.
private struct AndroidLayoutMeasureContext: LayoutMeasureContext {
    let children: [RenderNode]

    func measure(_ subview: LayoutSubview, proposal: ProposedViewSize) -> LayoutMeasurement {
        let node = children[subview.index]
        var size = ViewSize.zero
        var expandsW = false
        var expandsH = false

        switch node.type {
        case "text":
            // Estimate based on standard system font (17pt)
            let content = node.props["content"] ?? ""
            size = ViewSize(width: Double(content.count) * 9.0, height: 22.0)
        case "button":
            // Material3 button standard min size
            size = ViewSize(width: 100.0, height: 48.0)
        case "textfield", "securefield":
            size = ViewSize(width: proposal.width ?? 200.0, height: 56.0)
        case "toggle":
            size = ViewSize(width: proposal.width ?? 200.0, height: 48.0)
        case "spacer":
            expandsW = true
            expandsH = true
        case "divider":
            size = ViewSize(width: proposal.width ?? 1.0, height: 1.0)
        case "color":
            expandsW = true
            expandsH = true
        case "filledShape", "strokedShape":
            expandsW = true
            expandsH = true
        case "vstack", "hstack", "zstack", "group", "padding", "frame":
            // Nested containers take the proposed size if available
            size = ViewSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
            expandsW = true
            expandsH = true
        default:
            size = ViewSize(width: 0, height: 0)
        }

        return LayoutMeasurement(
            size: size,
            expandsToFillWidth: expandsW,
            expandsToFillHeight: expandsH
        )
    }
}

/// Backend-local state for tracking foreground color during the render pass.
/// Used by bare shapes (no .fill()/.stroke()) to determine their color.
private var _androidCurrentForegroundColor: Color?

func androidGetCurrentForegroundColor() -> Color {
    _androidCurrentForegroundColor ?? Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0)
}

func androidSetCurrentForegroundColor(_ color: Color?) {
    _androidCurrentForegroundColor = color
}

// MARK: - Rendering protocol

/// Protocol that views implement (via extensions) to produce RenderNodes.
public protocol AndroidRenderable {
    func androidCreateNode() -> RenderNode
}

/// Protocol for views that provide multiple child RenderNodes.
public protocol AndroidMultiChildRenderable {
    func androidRenderChildren() -> [RenderNode]
}

// MARK: - Rendering dispatch

/// Render any SwiftOpenUI View into a RenderNode tree.
/// Each call pushes a structural path context so node IDs are position-stable.
public func androidRenderView<V: View>(_ view: V) -> RenderNode {
    let typeTag = String(describing: V.self).prefix(32)
    let nodeId = androidPushChild(typeTag: String(typeTag))
    defer { androidPopChild() }

    if let renderable = view as? AndroidRenderable {
        let node = renderable.androidCreateNode()
        if node.id == 0 { node.id = nodeId }
        return node
    }

    // Primitive multi-child views like TupleView have Body = Never.
    // Render them as an explicit group node instead of recursing into body.
    if view is AndroidMultiChildRenderable || view is MultiChildView {
        let node = RenderNode(type: "group")
        node.id = nodeId
        node.children = androidRenderChildren(view)
        return node
    }

    // Composite view — restore cached @State before recursing into body.
    // This enables nested views with @State to persist across rebuilds.
    // Only check views that might have reactive properties (skip known primitives).
    if V.Body.self != Never.self {
        androidRestoreState(view, nodeId: nodeId)
    }

    return androidRenderView(view.body)
}

/// Restore cached @State values for a view and wire storages to the current host.
private func androidRestoreState<V: View>(_ view: V, nodeId: Int64) {
    let mirror = Mirror(reflecting: view)
    let providers = mirror.children.compactMap { $0.value as? AnyStateStorageProvider }
    guard !providers.isEmpty else { return }

    // Restore cached values into freshly-created storages
    if let cached = androidStateCache[nodeId], cached.count == providers.count {
        for (provider, old) in zip(providers, cached) {
            provider.anyStorage.restoreValue(from: old)
        }
    }

    // Cache the current storages for next render
    androidStateCache[nodeId] = providers.map { $0.anyStorage }

    // Wire to the current host so setValue triggers rebuild
    if let host = androidCurrentHost {
        for provider in providers {
            provider.anyStorage.host = host
        }
    }
}

/// Render children from a view.
public func androidRenderChildren<V: View>(_ view: V) -> [RenderNode] {
    if let multi = view as? AndroidMultiChildRenderable {
        return multi.androidRenderChildren()
    }
    if let multi = view as? MultiChildView {
        return multi.children.map { child in
            func render<C: View>(_ c: C) -> RenderNode { androidRenderView(c) }
            return render(child)
        }
    }
    return [androidRenderView(view)]
}

/// Render an existential (any View).
public func androidRenderAnyView(_ view: any View) -> RenderNode {
    func render<V: View>(_ v: V) -> RenderNode { androidRenderView(v) }
    return render(view)
}

// MARK: - Primitive views

extension Text: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "text")
        node.props["content"] = content
        return node
    }
}

extension EmptyView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        RenderNode(type: "empty")
    }
}

extension Spacer: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        RenderNode(type: "spacer")
    }
}

extension SwiftOpenUI.Divider: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        RenderNode(type: "divider")
    }
}

extension SwiftOpenUI.Button: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "button")
        // node.id is set by androidRenderView dispatch
        // Register action closure — id will be assigned after return
        // We need the id now, so read it from the current path stack
        let nodeId = androidCurrentNodeId()
        androidButtonActions[nodeId] = action
        // Render label to get text content
        let labelNode = androidRenderView(label)
        if labelNode.type == "text", let text = labelNode.props["content"] {
            node.props["label"] = text
        } else {
            // Complex label — nest it
            node.children = [labelNode]
        }
        return node
    }
}

extension SwiftOpenUI.TextField: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "textfield")
        node.props["placeholder"] = title
        node.props["text"] = text.wrappedValue
        let nodeId = androidCurrentNodeId()
        androidTextBindings[nodeId] = text
        return node
    }
}

extension SecureField: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "securefield")
        node.props["placeholder"] = placeholder
        node.props["text"] = text.wrappedValue
        let nodeId = androidCurrentNodeId()
        androidTextBindings[nodeId] = text
        return node
    }
}

extension TextEditor: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "texteditor")
        node.props["text"] = text.wrappedValue
        let nodeId = androidCurrentNodeId()
        androidTextBindings[nodeId] = text
        return node
    }
}

// TODO: Support inherited environment .disabled()
extension Toggle: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "toggle")
        node.props["label"] = label
        node.props["isOn"] = isOn.wrappedValue ? "true" : "false"
        let nodeId = androidCurrentNodeId()
        androidToggleBindings[nodeId] = isOn
        return node
    }
}

extension Slider: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "slider")
        node.props["value"] = "\(value.wrappedValue)"
        node.props["min"] = "\(range.lowerBound)"
        node.props["max"] = "\(range.upperBound)"
        node.props["step"] = "\(step)"
        let nodeId = androidCurrentNodeId()
        androidSliderBindings[nodeId] = value
        return node
    }
}

extension ProgressView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "progressview")
        if let val = value {
            let progress = max(0.0, min(1.0, val / total))
            node.props["progress"] = "\(progress)"
        }
        return node
    }
}

extension SwiftOpenUI.Color: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "color")
        node.props["r"] = "\(red)"
        node.props["g"] = "\(green)"
        node.props["b"] = "\(blue)"
        node.props["a"] = "\(alpha)"
        return node
    }
}

// MARK: - Container views

private func androidCanUsePrecisionLayout(_ children: [RenderNode]) -> Bool {
    // Only use precision layout if all children have reliable intrinsic measurement estimations.
    // If any child is expanding (Spacer, Color) or unknown, fall back to Compose.
    let allowlist: Set<String> = ["text", "button", "divider"]
    for node in children {
        if !allowlist.contains(node.type) {
            return false
        }
    }
    return true
}

extension VStack: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "vstack")
        let spacingValue = resolveStackSpacing(spacing)
        node.props["spacing"] = "\(spacingValue)"
        node.props["alignment"] = "\(alignment)"
        node.children = androidRenderChildren(content)

        // Precision Layout: compute absolute positions for children if safe
        if androidCanUsePrecisionLayout(node.children) {
            applyPrecisionVStackLayout(node: node, spacing: Double(spacingValue), alignment: alignment)
        }

        return node
    }
}

extension HStack: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "hstack")
        let spacingValue = resolveStackSpacing(spacing)
        node.props["spacing"] = "\(spacingValue)"
        node.props["alignment"] = "\(alignment)"
        node.children = androidRenderChildren(content)

        // Precision Layout: compute absolute positions for children if safe
        if androidCanUsePrecisionLayout(node.children) {
            applyPrecisionHStackLayout(node: node, spacing: Double(spacingValue), alignment: alignment)
        }

        return node
    }
}

private func applyPrecisionVStackLayout(node: RenderNode, spacing: Double, alignment: HorizontalAlignment) {
    let context = AndroidLayoutMeasureContext(children: node.children)
    let result = computeVStackLayout(
        subviews: node.children.indices.map(LayoutSubview.init(index:)),
        context: context,
        spacing: spacing,
        alignment: alignment
    )
    
    // Set container size
    node.layout = ["width": result.containerSize.width, "height": result.containerSize.height]
    
    // Set child absolute offsets
    for (child, placement) in zip(node.children, result.childPlacements) {
        child.layout = [
            "x": placement.origin.x,
            "y": placement.origin.y,
            "width": placement.size.width,
            "height": placement.size.height
        ]
    }
}

private func applyPrecisionHStackLayout(node: RenderNode, spacing: Double, alignment: VerticalAlignment) {
    let context = AndroidLayoutMeasureContext(children: node.children)
    let result = computeHStackLayout(
        subviews: node.children.indices.map(LayoutSubview.init(index:)),
        context: context,
        spacing: spacing,
        alignment: alignment
    )
    
    // Set container size
    node.layout = ["width": result.containerSize.width, "height": result.containerSize.height]
    
    // Set child absolute offsets
    for (child, placement) in zip(node.children, result.childPlacements) {
        child.layout = [
            "x": placement.origin.x,
            "y": placement.origin.y,
            "width": placement.size.width,
            "height": placement.size.height
        ]
    }
}

extension ZStack: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "zstack")
        node.children = androidRenderChildren(content)
        return node
    }
}

extension Group: AndroidRenderable, AndroidMultiChildRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "group")
        node.children = androidRenderChildren()
        return node
    }

    public func androidRenderChildren() -> [RenderNode] {
        BackendAndroid.androidRenderChildren(content)
    }
}

extension ForEach: AndroidRenderable, AndroidMultiChildRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "group")
        node.children = androidRenderChildren()
        return node
    }

    public func androidRenderChildren() -> [RenderNode] {
        data.map { item in
            let view = content(item)
            return androidRenderView(view)
        }
    }
}

extension ScrollView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "scrollview")
        if axes == [.horizontal, .vertical] {
            node.props["axis"] = "both"
        } else {
            node.props["axis"] = axes.contains(.horizontal) ? "horizontal" : "vertical"
        }
        node.children = [androidRenderView(content)]
        return node
    }
}

extension List: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "list")
        node.children = androidRenderChildren(content)
        return node
    }
}

// MARK: - Modifier views

extension PaddedView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "padding")
        node.props["top"] = "\(top)"
        node.props["bottom"] = "\(bottom)"
        node.props["leading"] = "\(leading)"
        node.props["trailing"] = "\(trailing)"
        node.children = [androidRenderView(content)]
        return node
    }
}

extension FrameView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "frame")
        if let w = width { node.props["width"] = "\(w)" }
        if let h = height { node.props["height"] = "\(h)" }
        node.children = [androidRenderView(content)]
        return node
    }
}

extension ForegroundColorView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "foregroundColor")
        node.props["r"] = "\(color.red)"
        node.props["g"] = "\(color.green)"
        node.props["b"] = "\(color.blue)"
        node.props["a"] = "\(color.alpha)"
        
        let prev = _androidCurrentForegroundColor
        androidSetCurrentForegroundColor(color)
        node.children = [androidRenderView(content)]
        androidSetCurrentForegroundColor(prev)
        
        return node
    }
}

extension BackgroundView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        if let color = background as? Color {
            let node = RenderNode(type: "backgroundColor")
            node.props["r"] = "\(color.red)"
            node.props["g"] = "\(color.green)"
            node.props["b"] = "\(color.blue)"
            node.props["a"] = "\(color.alpha)"
            node.children = [androidRenderView(content)]
            return node
        }

        let node = RenderNode(type: "zstack")
        node.children = [androidRenderView(background), androidRenderView(content)]
        return node
    }
}

extension FontModifiedView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "font")
        switch font {
        case .largeTitle: node.props["size"] = "34"; node.props["weight"] = "bold"
        case .title:      node.props["size"] = "28"; node.props["weight"] = "bold"
        case .title2:     node.props["size"] = "22"; node.props["weight"] = "bold"
        case .title3:     node.props["size"] = "20"; node.props["weight"] = "semibold"
        case .headline:   node.props["size"] = "17"; node.props["weight"] = "semibold"
        case .subheadline: node.props["size"] = "15"; node.props["weight"] = "normal"
        case .body:       node.props["size"] = "17"; node.props["weight"] = "normal"
        case .callout:    node.props["size"] = "16"; node.props["weight"] = "normal"
        case .footnote:   node.props["size"] = "13"; node.props["weight"] = "normal"
        case .caption:    node.props["size"] = "12"; node.props["weight"] = "normal"
        case .caption2:   node.props["size"] = "11"; node.props["weight"] = "normal"
        case .custom(let size, let weight, _):
            node.props["size"] = "\(size)"
            switch weight {
            case .bold: node.props["weight"] = "bold"
            case .semibold: node.props["weight"] = "semibold"
            case .light: node.props["weight"] = "light"
            default: node.props["weight"] = "normal"
            }
        }
        node.children = [androidRenderView(content)]
        return node
    }
}

extension BorderView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "border")
        node.props["r"] = "\(color.red)"
        node.props["g"] = "\(color.green)"
        node.props["b"] = "\(color.blue)"
        node.props["width"] = "\(width)"
        node.children = [androidRenderView(content)]
        return node
    }
}

// MARK: - Focus modifier views

extension FocusedView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = androidRenderView(content)

        // Tell Kotlin whether this node should have focus
        node.props["focused"] = focusState.wrappedValue ? "true" : "false"

        // Register handler under the CHILD node's ID — that's what Kotlin
        // sees and sends back via nativeOnFocusChange.
        let storage = focusState.storage
        androidFocusHandlers[node.id] = { hasFocus in
            // Use setValue (not setProgrammatic) — platform-originated,
            // should NOT trigger rebuild to avoid losing focus
            storage.setValue(hasFocus)
        }

        return node
    }
}

extension FocusedEqualsView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = androidRenderView(content)

        // Tell Kotlin whether this node should have focus
        let isFocused = focusState.storage.value == value
        node.props["focused"] = isFocused ? "true" : "false"

        // Register handler under the CHILD node's ID
        let storage = focusState.storage
        let matchValue = value
        androidFocusHandlers[node.id] = { hasFocus in
            if hasFocus {
                storage.setValue(matchValue)
            } else {
                // Only clear if still this value
                if storage.value == matchValue {
                    storage.setValue(nil)
                }
            }
        }

        return node
    }
}

// MARK: - Navigation views

/// Destination registry for Android type-based path navigation.
private class AndroidDestinationRegistry {
    private var factories: [(type: Any.Type, factory: (AnyHashable) -> RenderNode?)] = []

    func register<V: Hashable>(for type: V.Type, factory: @escaping (V) -> RenderNode?) {
        factories.append((type: V.self, factory: { value in
            guard let typed = value.base as? V else { return nil }
            return factory(typed)
        }))
    }

    func resolve(_ value: AnyHashable) -> RenderNode? {
        for entry in factories {
            if let result = entry.factory(value) {
                return result
            }
        }
        return nil
    }
}

/// Current Android navigation context during rendering.
private var _androidNavRegistry: AndroidDestinationRegistry?
/// Navigation push/pop actions stored for button handlers.
private var _androidNavPushAction: ((AnyHashable) -> Void)?
private var _androidNavPopAction: (() -> Void)?

extension NavigationStack: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let registry = AndroidDestinationRegistry()
        let prevRegistry = _androidNavRegistry
        _androidNavRegistry = registry

        var rootTitle = "Home"
        if let titled = content as? NavigationTitled {
            rootTitle = titled.navigationTitle
        }

        // Wire NavigateAction into environment
        let prevEnv = getCurrentEnvironment()
        var env = prevEnv

        // Path-aware: if pathBinding exists, render resolved destinations
        var currentPathElements: [AnyHashable] = []
        if let path = pathBinding?.wrappedValue, !path.isEmpty {
            currentPathElements = path.elements
        }

        // Set up push/pop actions that modify the path binding
        let binding = pathBinding
        _androidNavPushAction = { value in
            guard var path = binding?.wrappedValue else { return }
            path.append(value)
            binding?.wrappedValue = path
        }
        _androidNavPopAction = {
            guard var path = binding?.wrappedValue, !path.isEmpty else { return }
            path.removeLast()
            binding?.wrappedValue = path
        }

        env.navigate = NavigateAction(
            push: { value in _androidNavPushAction?(value) },
            pop: { _androidNavPopAction?() },
            popToRoot: {
                guard var path = binding?.wrappedValue else { return }
                path.removeLast(path.count)
                binding?.wrappedValue = path
            }
        )
        setCurrentEnvironment(env)

        // Render root content (this also registers destination factories)
        let rootContent = androidRenderView(content)

        // Build the navigation node
        let node = RenderNode(type: "navigationStack")
        node.props["title"] = rootTitle

        if !currentPathElements.isEmpty, let lastValue = currentPathElements.last,
           let destNode = registry.resolve(lastValue) {
            // Show resolved destination with back button
            node.props["showBack"] = "true"
            node.props["destTitle"] = "\(lastValue)"
            node.children = [destNode]

            // Register a back action
            let backNodeId = androidPushChild(typeTag: "navBack")
            androidPopChild()
            node.props["backNodeId"] = "\(backNodeId)"
            androidButtonActions[backNodeId] = {
                _androidNavPopAction?()
            }
        } else {
            // Show root content
            node.children = [rootContent]
        }

        setCurrentEnvironment(prevEnv)
        _androidNavRegistry = prevRegistry
        return node
    }
}

extension NavigationLink: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "navigationLink")
        node.props["title"] = title
        let labelNode = androidRenderView(labelView)
        if !label.isEmpty {
            node.props["label"] = label
        } else if labelNode.type == "text", let text = labelNode.props["content"] {
            node.props["label"] = text
        } else {
            node.children = [labelNode]
        }

        // Register action that pushes the destination
        let nodeId = androidCurrentNodeId()
        let dest = destination
        androidButtonActions[nodeId] = {
            // For static destinations (no path), re-render is handled by
            // the NavigationStack detecting the path change
            _androidNavPushAction?(AnyHashable(title))
        }
        // Also register the destination in the registry under the title
        let linkTitle = self.title
        _androidNavRegistry?.register(for: String.self) { [dest] value -> RenderNode? in
            guard value == linkTitle else { return nil }
            return androidRenderView(dest())
        }

        return node
    }
}

extension TitledView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = androidRenderView(content)
        node.props["navigationTitle"] = navigationTitle
        return node
    }
}

extension NavigationDestinationModifier: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        // Register destination factory in current navigation context
        if let registry = _androidNavRegistry {
            registry.register(for: dataType) { value -> RenderNode? in
                androidRenderView(self.destination(value))
            }
        }
        return androidRenderView(content)
    }
}

// MARK: - Presentation modifier views

extension SheetModifierView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = androidRenderView(content)
        
        if isPresented.wrappedValue {
            let sheetNode = RenderNode(type: "sheet")
            let nodeId = androidPushChild(typeTag: "sheet")
            sheetNode.id = nodeId
            sheetNode.children = [androidRenderView(sheetContent)]
            androidPopChild()
            
            // Register a dismissal action
            let binding = isPresented
            let userDismiss = onDismiss
            androidButtonActions[nodeId] = {
                binding.wrappedValue = false
                userDismiss?()
            }
            
            node.children.append(sheetNode)
        }
        
        return node
    }
}

extension ItemSheetModifierView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = androidRenderView(content)
        
        if let val = item.wrappedValue {
            let sheetNode = RenderNode(type: "sheet")
            let nodeId = androidPushChild(typeTag: "sheet")
            sheetNode.id = nodeId
            sheetNode.children = [androidRenderView(sheetContent(val))]
            androidPopChild()
            
            let binding = item
            let userDismiss = onDismiss
            androidButtonActions[nodeId] = {
                binding.wrappedValue = nil
                userDismiss?()
            }
            
            node.children.append(sheetNode)
        }
        
        return node
    }
}

extension AlertModifierView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = androidRenderView(content)
        
        if isPresented.wrappedValue {
            let alertNode = RenderNode(type: "alert")
            let nodeId = androidPushChild(typeTag: "alert")
            alertNode.id = nodeId
            alertNode.props["title"] = title
            alertNode.props["message"] = message
            
            // Register dismissal action for clicking outside
            let binding = isPresented
            androidButtonActions[nodeId] = {
                binding.wrappedValue = false
            }
            
            // Serialize buttons
            for (index, button) in buttons.enumerated() {
                let btnNode = RenderNode(type: "alertButton")
                let btnId = androidPushChild(typeTag: "alertBtn\(index)")
                btnNode.id = btnId
                btnNode.props["label"] = button.label
                btnNode.props["role"] = "\(button.role)"
                
                // Register button action (includes dismissal)
                let action = button.action
                androidButtonActions[btnId] = {
                    binding.wrappedValue = false
                    action()
                }
                
                alertNode.children.append(btnNode)
                androidPopChild()
            }
            
            androidPopChild()
            node.children.append(alertNode)
        }
        
        return node
    }
}

// MARK: - Gesture views

// MARK: - Shape rendering

private func androidRenderBareShape<S: Shape>(_ shape: S) -> RenderNode {
    let fg = androidGetCurrentForegroundColor()
    let node = RenderNode(type: "filledShape")
    node.props["r"] = "\(fg.red)"
    node.props["g"] = "\(fg.green)"
    node.props["b"] = "\(fg.blue)"
    node.props["a"] = "\(fg.alpha)"
    androidDescribeShape(shape, into: node)
    return node
}

private func androidDescribeShape<S: Shape>(_ shape: S, into node: RenderNode) {
    if shape is Circle {
        node.props["shapeType"] = "circle"
    } else if shape is Rectangle {
        node.props["shapeType"] = "rectangle"
    } else if let rr = shape as? RoundedRectangle {
        node.props["shapeType"] = "roundedRectangle"
        node.props["cornerRadius"] = "\(rr.cornerRadius)"
    } else if shape is Capsule {
        node.props["shapeType"] = "capsule"
    } else if shape is Ellipse {
        node.props["shapeType"] = "ellipse"
    }
}

extension Circle: AndroidRenderable {
    public func androidCreateNode() -> RenderNode { androidRenderBareShape(self) }
}

extension Rectangle: AndroidRenderable {
    public func androidCreateNode() -> RenderNode { androidRenderBareShape(self) }
}

extension RoundedRectangle: AndroidRenderable {
    public func androidCreateNode() -> RenderNode { androidRenderBareShape(self) }
}

extension Capsule: AndroidRenderable {
    public func androidCreateNode() -> RenderNode { androidRenderBareShape(self) }
}

extension Ellipse: AndroidRenderable {
    public func androidCreateNode() -> RenderNode { androidRenderBareShape(self) }
}

extension FilledShape: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "filledShape")
        node.props["r"] = "\(color.red)"
        node.props["g"] = "\(color.green)"
        node.props["b"] = "\(color.blue)"
        node.props["a"] = "\(color.alpha)"
        androidDescribeShape(shape, into: node)
        return node
    }
}

extension StrokedShape: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "strokedShape")
        node.props["r"] = "\(color.red)"
        node.props["g"] = "\(color.green)"
        node.props["b"] = "\(color.blue)"
        node.props["a"] = "\(color.alpha)"
        node.props["lineWidth"] = "\(style.lineWidth)"
        androidDescribeShape(shape, into: node)
        return node
    }
}

extension ClipShapeView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "clipShape")
        androidDescribeShape(shape, into: node)
        node.children = [androidRenderView(content)]
        return node
    }
}

extension TapGestureView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = androidRenderView(content)
        node.props["onTap"] = "true"
        node.props["tapCount"] = "\(count)"
        androidButtonActions[node.id] = action
        return node
    }
}

extension LongPressGestureView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = androidRenderView(content)
        node.props["onLongPress"] = "true"
        androidButtonActions[node.id] = action
        return node
    }
}

extension DragGestureView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = androidRenderView(content)
        node.props["onDrag"] = "true"
        node.props["dragMinDist"] = "\(minimumDistance)"
        androidDragHandlers[node.id] = AndroidDragHandler(
            minimumDistance: minimumDistance,
            onChanged: onChanged,
            onEnded: onEnded
        )
        return node
    }
}

// MARK: - Animation modifier views

extension OpacityView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "opacity")
        node.props["value"] = "\(opacity)"
        node.children = [androidRenderView(content)]
        return node
    }
}

extension OffsetView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "offset")
        node.props["x"] = "\(x)"
        node.props["y"] = "\(y)"
        node.children = [androidRenderView(content)]
        return node
    }
}

extension ScaleEffectView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "scaleEffect")
        node.props["scaleX"] = "\(scaleX)"
        node.props["scaleY"] = "\(scaleY)"
        node.children = [androidRenderView(content)]
        return node
    }
}

extension AnimatedView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        androidRenderView(content)
    }
}

// MARK: - Type-erased / conditional views

extension AnyView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        androidRenderAnyView(wrapped)
    }
}

extension _ConditionalView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        switch self {
        case .trueContent(let view): return androidRenderView(view)
        case .falseContent(let view): return androidRenderView(view)
        }
    }
}

extension Optional: AndroidRenderable where Wrapped: View {
    public func androidCreateNode() -> RenderNode {
        switch self {
        case .some(let view): return androidRenderView(view)
        case .none: return RenderNode(type: "empty")
        }
    }
}

// MARK: - TupleView rendering

extension TupleView: AndroidMultiChildRenderable {
    public func androidRenderChildren() -> [RenderNode] {
        children.map(androidRenderAnyView)
    }
}

// MARK: - Environment modifier views

extension EnvironmentObjectModifierView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let prev = getCurrentEnvironment()
        var env = prev
        env.setObject(object)
        setCurrentEnvironment(env)
        let node = androidRenderView(content)
        setCurrentEnvironment(prev)
        return node
    }
}

extension EnvironmentObservableModifierView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let prev = getCurrentEnvironment()
        var env = prev
        env.setObject(object)
        setCurrentEnvironment(env)
        let node = androidRenderView(content)
        setCurrentEnvironment(prev)
        return node
    }
}

extension EnvironmentModifierView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let prev = getCurrentEnvironment()
        var env = prev
        env[keyPath: keyPath] = value
        setCurrentEnvironment(env)
        let node = androidRenderView(content)
        setCurrentEnvironment(prev)
        return node
    }
}
