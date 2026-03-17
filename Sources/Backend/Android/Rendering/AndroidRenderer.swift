import SwiftOpenUI

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
public func androidRenderView<V: View>(_ view: V) -> RenderNode {
    if let renderable = view as? AndroidRenderable {
        return renderable.androidCreateNode()
    }

    // Composite view — recurse through body
    return androidRenderView(view.body)
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

extension VStack: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "vstack")
        node.props["spacing"] = "\(spacing)"
        node.props["alignment"] = "\(alignment)"
        node.children = androidRenderChildren(content)
        return node
    }
}

extension HStack: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "hstack")
        node.props["spacing"] = "\(spacing)"
        node.props["alignment"] = "\(alignment)"
        node.children = androidRenderChildren(content)
        return node
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
        node.children = [androidRenderView(content)]
        return node
    }
}

extension BackgroundView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        let node = RenderNode(type: "backgroundColor")
        node.props["r"] = "\(color.red)"
        node.props["g"] = "\(color.green)"
        node.props["b"] = "\(color.blue)"
        node.props["a"] = "\(color.alpha)"
        node.children = [androidRenderView(content)]
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

extension TupleView2: AndroidMultiChildRenderable {
    public func androidRenderChildren() -> [RenderNode] {
        [androidRenderView(v0), androidRenderView(v1)]
    }
}

extension TupleView3: AndroidMultiChildRenderable {
    public func androidRenderChildren() -> [RenderNode] {
        [androidRenderView(v0), androidRenderView(v1), androidRenderView(v2)]
    }
}

extension TupleView4: AndroidMultiChildRenderable {
    public func androidRenderChildren() -> [RenderNode] {
        [androidRenderView(v0), androidRenderView(v1), androidRenderView(v2), androidRenderView(v3)]
    }
}

extension TupleView5: AndroidMultiChildRenderable {
    public func androidRenderChildren() -> [RenderNode] {
        [androidRenderView(v0), androidRenderView(v1), androidRenderView(v2), androidRenderView(v3), androidRenderView(v4)]
    }
}

extension TupleView6: AndroidMultiChildRenderable {
    public func androidRenderChildren() -> [RenderNode] {
        [androidRenderView(v0), androidRenderView(v1), androidRenderView(v2), androidRenderView(v3), androidRenderView(v4), androidRenderView(v5)]
    }
}

// MARK: - Environment modifier views

extension EnvironmentObjectModifierView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        var env = getCurrentEnvironment()
        env.setObject(object)
        setCurrentEnvironment(env)
        return androidRenderView(content)
    }
}

extension EnvironmentModifierView: AndroidRenderable {
    public func androidCreateNode() -> RenderNode {
        var env = getCurrentEnvironment()
        env[keyPath: keyPath] = value
        setCurrentEnvironment(env)
        return androidRenderView(content)
    }
}
