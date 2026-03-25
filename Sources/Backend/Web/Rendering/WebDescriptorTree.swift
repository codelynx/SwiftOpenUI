import SwiftOpenUI

// MARK: - Descriptor kinds and property types

/// Leaf-first Web descriptor kinds for the descriptor-first invalidation path.
public enum WebDescriptorKind: Equatable {
    case background
    case border
    case composite
    case divider
    case font
    case text
    case color
    case frame
    case foregroundColor
    case hStack
    case padding
    case slider
    case spacer
    case vStack
    case zStack
}

public struct WebTextDescriptor: Equatable {
    public let content: String
}

public struct WebColorDescriptor: Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double

    public init(red: Double, green: Double, blue: Double, opacity: Double) {
        self.red = red; self.green = green; self.blue = blue; self.opacity = opacity
    }
}

public struct WebSliderDescriptor: Equatable {
    public let value: Double
    public let range: ClosedRange<Double>
    public let step: Double
}

public enum WebAlignmentDescriptor: String, Equatable {
    case topLeading, top, topTrailing
    case leading, center, trailing
    case bottomLeading, bottom, bottomTrailing
}

public struct WebPaddingDescriptor: Equatable {
    public let top: Int
    public let bottom: Int
    public let leading: Int
    public let trailing: Int
}

public struct WebFrameDescriptor: Equatable {
    public let width: Double?
    public let height: Double?
    public let minWidth: Double?
    public let minHeight: Double?
    public let maxWidth: Double?
    public let maxHeight: Double?
    public let alignment: WebAlignmentDescriptor
}

public struct WebBorderDescriptor: Equatable {
    public let color: WebColorDescriptor
    public let width: Int
}

public enum WebHorizontalAlignmentDescriptor: String, Equatable {
    case leading, center, trailing
}

public enum WebVerticalAlignmentDescriptor: String, Equatable {
    case top, center, bottom
}

public struct WebVStackDescriptor: Equatable {
    public let spacing: Int
    public let alignment: WebHorizontalAlignmentDescriptor
}

public struct WebHStackDescriptor: Equatable {
    public let spacing: Int
    public let alignment: WebVerticalAlignmentDescriptor
}

public struct WebZStackDescriptor: Equatable {
    public let alignment: WebAlignmentDescriptor
}

public struct WebFontDescriptor: Equatable {
    public let font: Font
}

public struct WebIgnoresSafeAreaDescriptor: Equatable {
    public let regionsRawValue: Int
    public let edgesRawValue: Int
}

public enum WebSafeAreaInsetEdgeDescriptor: String, Equatable {
    case top
    case bottom
    case leading
    case trailing
}

public struct WebSafeAreaInsetDescriptor: Equatable {
    public let edge: WebSafeAreaInsetEdgeDescriptor
    public let horizontalAlignment: WebHorizontalAlignmentDescriptor?
    public let verticalAlignment: WebVerticalAlignmentDescriptor?
    public let spacing: Int
}

public struct WebSearchTokenDescriptor: Equatable {
    public let id: String
    public let label: String
}

public struct WebSearchSuggestionDescriptor: Equatable {
    public let id: String
    public let label: String
    public let completion: String?
}

public struct WebSearchScopeDescriptor: Equatable {
    public let id: String
    public let label: String
}

public struct WebSearchableDescriptor: Equatable {
    public let prompt: String
    public let placement: String
    public let isPresented: Bool?
    public let tokens: [WebSearchTokenDescriptor]
    public let tokenMode: String?
    public let suggestions: [WebSearchSuggestionDescriptor]
    public let scopes: [WebSearchScopeDescriptor]
    public let selectedScopeID: String?
}

public struct WebSafeAreaPaddingDescriptor: Equatable {
    public let top: Int
    public let bottom: Int
    public let leading: Int
    public let trailing: Int
}

// MARK: - Descriptor props and node

public enum WebDescriptorProps: Equatable {
    case none
    case background(WebColorDescriptor)
    case border(WebBorderDescriptor)
    case font(WebFontDescriptor)
    case text(WebTextDescriptor)
    case color(WebColorDescriptor)
    case frame(WebFrameDescriptor)
    case foregroundColor(WebColorDescriptor)
    case hStack(WebHStackDescriptor)
    case ignoresSafeArea(WebIgnoresSafeAreaDescriptor)
    case padding(WebPaddingDescriptor)
    case safeAreaInset(WebSafeAreaInsetDescriptor)
    case safeAreaPadding(WebSafeAreaPaddingDescriptor)
    case searchable(WebSearchableDescriptor)
    case slider(WebSliderDescriptor)
    case vStack(WebVStackDescriptor)
    case zStack(WebZStackDescriptor)
}

public struct WebDescriptorNode: Equatable {
    public let kind: WebDescriptorKind
    public let typeName: String
    public let props: WebDescriptorProps
    public let children: [WebDescriptorNode]

    public init(kind: WebDescriptorKind,
                typeName: String,
                props: WebDescriptorProps = .none,
                children: [WebDescriptorNode] = []) {
        self.kind = kind
        self.typeName = typeName
        self.props = props
        self.children = children
    }
}

// MARK: - Identity

/// Structural identity by position. Keyed identity is a later step.
public struct WebDescriptorIdentity: Equatable, Hashable {
    public let path: [Int]

    public init(path: [Int]) {
        self.path = path
    }
}

// MARK: - Identified + retained nodes

public struct WebIdentifiedDescriptorNode: Equatable {
    public let identity: WebDescriptorIdentity
    public let descriptor: WebDescriptorNode
    public let children: [WebIdentifiedDescriptorNode]

    public init(identity: WebDescriptorIdentity,
                descriptor: WebDescriptorNode,
                children: [WebIdentifiedDescriptorNode]) {
        self.identity = identity
        self.descriptor = descriptor
        self.children = children
    }
}

public struct WebRetainedDescriptorNode: Equatable {
    public let identity: WebDescriptorIdentity
    public let descriptor: WebDescriptorNode
    public let children: [WebRetainedDescriptorNode]

    public init(identity: WebDescriptorIdentity,
                descriptor: WebDescriptorNode,
                children: [WebRetainedDescriptorNode]) {
        self.identity = identity
        self.descriptor = descriptor
        self.children = children
    }
}

// MARK: - Retained executor node

public struct WebRetainedExecutorNode: Equatable {
    public let identity: WebDescriptorIdentity
    public let kind: WebDescriptorKind
    public let lastDescriptor: WebDescriptorNode
    public let nativeSlotID: Int?
    public let children: [WebRetainedExecutorNode]

    public init(identity: WebDescriptorIdentity,
                kind: WebDescriptorKind,
                lastDescriptor: WebDescriptorNode,
                nativeSlotID: Int? = nil,
                children: [WebRetainedExecutorNode] = []) {
        self.identity = identity
        self.kind = kind
        self.lastDescriptor = lastDescriptor
        self.nativeSlotID = nativeSlotID
        self.children = children
    }
}

// MARK: - Match

public enum WebDescriptorMatchKind: Equatable {
    case reuse
    case replace
}

public struct WebDescriptorMatch: Equatable {
    public let identity: WebDescriptorIdentity
    public let kind: WebDescriptorMatchKind
    public let oldDescriptor: WebDescriptorNode?
    public let newDescriptor: WebDescriptorNode
    public let children: [WebDescriptorMatch]

    public init(identity: WebDescriptorIdentity,
                kind: WebDescriptorMatchKind,
                oldDescriptor: WebDescriptorNode?,
                newDescriptor: WebDescriptorNode,
                children: [WebDescriptorMatch] = []) {
        self.identity = identity
        self.kind = kind
        self.oldDescriptor = oldDescriptor
        self.newDescriptor = newDescriptor
        self.children = children
    }
}

// MARK: - Plan

public enum WebDescriptorPlanKind: Equatable {
    case create
    case reuse
    case update
    case replace
}

public enum WebDescriptorUpdateIntent: Equatable {
    case none
    case backgroundColor
    case borderStyle
    case colorFill
    case fontStyle
    case frameLayout
    case foregroundColor
    case hStackLayout
    case paddingLayout
    case sliderConfiguration
    case sliderValue
    case textContent
    case vStackLayout
    case zStackLayout
}

public struct WebDescriptorPlan: Equatable {
    public let identity: WebDescriptorIdentity
    public let kind: WebDescriptorPlanKind
    public let updateIntent: WebDescriptorUpdateIntent
    public let oldDescriptor: WebDescriptorNode?
    public let newDescriptor: WebDescriptorNode
    public let children: [WebDescriptorPlan]

    public init(identity: WebDescriptorIdentity,
                kind: WebDescriptorPlanKind,
                updateIntent: WebDescriptorUpdateIntent = .none,
                oldDescriptor: WebDescriptorNode?,
                newDescriptor: WebDescriptorNode,
                children: [WebDescriptorPlan] = []) {
        self.identity = identity
        self.kind = kind
        self.updateIntent = updateIntent
        self.oldDescriptor = oldDescriptor
        self.newDescriptor = newDescriptor
        self.children = children
    }
}

// MARK: - Executor actions

public enum WebExecutorActionKind: Equatable {
    case create
    case keep
    case update
    case replace
}

public struct WebExecutorAction: Equatable {
    public let identity: WebDescriptorIdentity
    public let kind: WebExecutorActionKind
    public let updateIntent: WebDescriptorUpdateIntent
    public let previousDescriptor: WebDescriptorNode?
    public let currentDescriptor: WebDescriptorNode
    public let previousNode: WebRetainedExecutorNode?
    public let resultingNode: WebRetainedExecutorNode
    public let children: [WebExecutorAction]

    public init(identity: WebDescriptorIdentity,
                kind: WebExecutorActionKind,
                updateIntent: WebDescriptorUpdateIntent = .none,
                previousDescriptor: WebDescriptorNode?,
                currentDescriptor: WebDescriptorNode,
                previousNode: WebRetainedExecutorNode?,
                resultingNode: WebRetainedExecutorNode,
                children: [WebExecutorAction] = []) {
        self.identity = identity
        self.kind = kind
        self.updateIntent = updateIntent
        self.previousDescriptor = previousDescriptor
        self.currentDescriptor = currentDescriptor
        self.previousNode = previousNode
        self.resultingNode = resultingNode
        self.children = children
    }
}

// MARK: - Hook results

public enum WebHookResultKind: Equatable {
    case created
    case updated
    case replaced
    case noOp
}

public struct WebHookResult: Equatable {
    public let identity: WebDescriptorIdentity
    public let kind: WebHookResultKind
    public let updateIntent: WebDescriptorUpdateIntent
    public let currentDescriptor: WebDescriptorNode
    public let previousDescriptor: WebDescriptorNode?
    public let mutationSucceeded: Bool
    public let children: [WebHookResult]

    public init(identity: WebDescriptorIdentity,
                kind: WebHookResultKind,
                updateIntent: WebDescriptorUpdateIntent = .none,
                currentDescriptor: WebDescriptorNode,
                previousDescriptor: WebDescriptorNode? = nil,
                mutationSucceeded: Bool = true,
                children: [WebHookResult] = []) {
        self.identity = identity
        self.kind = kind
        self.updateIntent = updateIntent
        self.currentDescriptor = currentDescriptor
        self.previousDescriptor = previousDescriptor
        self.mutationSucceeded = mutationSucceeded
        self.children = children
    }
}

// MARK: - Describe protocol

/// Protocol for Web views that can produce a descriptor without creating DOM elements.
public protocol WebDescribable {
    func webDescribeNode() -> WebDescriptorNode
}

/// Build a Web-local descriptor tree without creating DOM elements.
public func webDescribeView<V: View>(_ view: V) -> WebDescriptorNode {
    if let describable = view as? WebDescribable {
        return describable.webDescribeNode()
    }
    if let multi = view as? MultiChildView {
        return WebDescriptorNode(
            kind: .composite,
            typeName: "MultiChild",
            children: multi.children.map(webDescribeAnyView)
        )
    }
    if V.Body.self != Never.self {
        return webDescribeAnyView(view.body)
    }
    return WebDescriptorNode(
        kind: .composite,
        typeName: "Opaque"
    )
}

public func webDescribeAnyView(_ view: any View) -> WebDescriptorNode {
    func describe<V: View>(_ value: V) -> WebDescriptorNode { webDescribeView(value) }
    return describe(view)
}

// MARK: - Identify

public func webIdentifyDescriptorTree(_ descriptor: WebDescriptorNode) -> WebIdentifiedDescriptorNode {
    webIdentifyNode(descriptor, path: [])
}

private func webIdentifyNode(_ descriptor: WebDescriptorNode,
                              path: [Int]) -> WebIdentifiedDescriptorNode {
    WebIdentifiedDescriptorNode(
        identity: WebDescriptorIdentity(path: path),
        descriptor: descriptor,
        children: descriptor.children.enumerated().map { index, child in
            webIdentifyNode(child, path: path + [index])
        }
    )
}

// MARK: - Retain

public func webRetainDescriptorTree(_ node: WebIdentifiedDescriptorNode) -> WebRetainedDescriptorNode {
    WebRetainedDescriptorNode(
        identity: node.identity,
        descriptor: node.descriptor,
        children: node.children.map(webRetainDescriptorTree)
    )
}

public func webMakeExecutorTree(from node: WebIdentifiedDescriptorNode,
                                nativeSlotID: Int? = nil) -> WebRetainedExecutorNode {
    WebRetainedExecutorNode(
        identity: node.identity,
        kind: node.descriptor.kind,
        lastDescriptor: node.descriptor,
        nativeSlotID: nativeSlotID,
        children: node.children.map { webMakeExecutorTree(from: $0) }
    )
}

// MARK: - Match

public func webMatchDescriptorTree(old: WebRetainedDescriptorNode,
                                    new: WebIdentifiedDescriptorNode) -> WebDescriptorMatch {
    guard webCanReuseNode(old: old, new: new) else {
        return WebDescriptorMatch(
            identity: new.identity,
            kind: .replace,
            oldDescriptor: old.descriptor,
            newDescriptor: new.descriptor
        )
    }
    return WebDescriptorMatch(
        identity: new.identity,
        kind: .reuse,
        oldDescriptor: old.descriptor,
        newDescriptor: new.descriptor,
        children: zip(old.children, new.children).map(webMatchDescriptorTree)
    )
}

private func webCanReuseNode(old: WebRetainedDescriptorNode,
                              new: WebIdentifiedDescriptorNode) -> Bool {
    old.identity == new.identity
        && old.descriptor.kind == new.descriptor.kind
        && old.children.count == new.children.count
}

// MARK: - Plan

public func webPlanDescriptorTree(old: WebRetainedDescriptorNode?,
                                   new: WebIdentifiedDescriptorNode) -> WebDescriptorPlan {
    guard let old else {
        return WebDescriptorPlan(
            identity: new.identity,
            kind: .create,
            oldDescriptor: nil,
            newDescriptor: new.descriptor,
            children: new.children.map { webPlanDescriptorTree(old: nil, new: $0) }
        )
    }

    guard webCanReuseNode(old: old, new: new) else {
        return WebDescriptorPlan(
            identity: new.identity,
            kind: .replace,
            oldDescriptor: old.descriptor,
            newDescriptor: new.descriptor,
            children: new.children.map { webPlanDescriptorTree(old: nil, new: $0) }
        )
    }

    let childPlans = zip(old.children, new.children).map { oldChild, newChild in
        webPlanDescriptorTree(old: oldChild, new: newChild)
    }
    let localKind: WebDescriptorPlanKind = old.descriptor.props == new.descriptor.props ? .reuse : .update
    let updateIntent: WebDescriptorUpdateIntent =
        localKind == .update ? webUpdateIntent(old: old.descriptor, new: new.descriptor) : .none

    return WebDescriptorPlan(
        identity: new.identity,
        kind: localKind,
        updateIntent: updateIntent,
        oldDescriptor: old.descriptor,
        newDescriptor: new.descriptor,
        children: childPlans
    )
}

private func webUpdateIntent(old: WebDescriptorNode,
                              new: WebDescriptorNode) -> WebDescriptorUpdateIntent {
    guard old.kind == new.kind else { return .none }
    switch new.kind {
    case .background:    return .backgroundColor
    case .border:        return .borderStyle
    case .color:         return .colorFill
    case .frame:         return .frameLayout
    case .foregroundColor: return .foregroundColor
    case .hStack:        return .hStackLayout
    case .padding:       return .paddingLayout
    case .slider:
        guard case let .slider(oldSlider) = old.props,
              case let .slider(newSlider) = new.props else {
            return .sliderConfiguration
        }
        return oldSlider.range == newSlider.range && oldSlider.step == newSlider.step
            ? .sliderValue : .sliderConfiguration
    case .text:          return .textContent
    case .vStack:        return .vStackLayout
    case .zStack:        return .zStackLayout
    case .divider:       return .none
    case .font:          return .fontStyle
    case .spacer:        return .none
    case .composite:     return .none
    }
}

// MARK: - Execute

public func webExecuteDescriptorPlan(old: WebRetainedExecutorNode?,
                                      plan: WebDescriptorPlan) -> WebExecutorAction {
    switch plan.kind {
    case .create:
        let childActions = plan.children.map { webExecuteDescriptorPlan(old: nil, plan: $0) }
        let node = WebRetainedExecutorNode(
            identity: plan.identity, kind: plan.newDescriptor.kind,
            lastDescriptor: plan.newDescriptor, children: childActions.map(\.resultingNode))
        return WebExecutorAction(
            identity: plan.identity, kind: .create,
            previousDescriptor: nil, currentDescriptor: plan.newDescriptor,
            previousNode: nil, resultingNode: node, children: childActions)

    case .replace:
        let childActions = plan.children.map { webExecuteDescriptorPlan(old: nil, plan: $0) }
        let node = WebRetainedExecutorNode(
            identity: plan.identity, kind: plan.newDescriptor.kind,
            lastDescriptor: plan.newDescriptor, children: childActions.map(\.resultingNode))
        return WebExecutorAction(
            identity: plan.identity, kind: .replace,
            previousDescriptor: old?.lastDescriptor ?? plan.oldDescriptor,
            currentDescriptor: plan.newDescriptor,
            previousNode: old, resultingNode: node, children: childActions)

    case .reuse, .update:
        let childActions = zip(old?.children ?? [], plan.children).map { oldChild, childPlan in
            webExecuteDescriptorPlan(old: oldChild, plan: childPlan)
        }
        let node = WebRetainedExecutorNode(
            identity: plan.identity, kind: plan.newDescriptor.kind,
            lastDescriptor: plan.newDescriptor, nativeSlotID: old?.nativeSlotID,
            children: childActions.map(\.resultingNode))
        return WebExecutorAction(
            identity: plan.identity, kind: plan.kind == .update ? .update : .keep,
            updateIntent: plan.updateIntent,
            previousDescriptor: old?.lastDescriptor ?? plan.oldDescriptor,
            currentDescriptor: plan.newDescriptor,
            previousNode: old, resultingNode: node, children: childActions)
    }
}

// MARK: - Hook (descriptive dispatch)

public func webApplyHook(action: WebExecutorAction) -> WebHookResult {
    webApplyHookInternal(action: action, performMutation: false)
}

public func webHookMutationSucceeded(_ result: WebHookResult) -> Bool {
    result.mutationSucceeded && result.children.allSatisfy(webHookMutationSucceeded)
}

/// Check if a plan tree contains only reuse + supported in-place updates.
/// Opaque composites (Body = Never, no describable conformance) with no
/// described children are rejected — their child content is not captured
/// in the descriptor, so we can't prove nothing changed inside.
public func webCanApplyTextColorHostMutation(plan: WebDescriptorPlan) -> Bool {
    switch plan.kind {
    case .create, .replace:
        return false
    case .reuse:
        if plan.newDescriptor.kind == .composite && plan.children.isEmpty {
            return false
        }
        return plan.children.allSatisfy(webCanApplyTextColorHostMutation)
    case .update:
        guard plan.updateIntent == .textContent || plan.updateIntent == .colorFill
                || plan.updateIntent == .sliderValue
                || plan.updateIntent == .backgroundColor
                || plan.updateIntent == .foregroundColor
                || plan.updateIntent == .paddingLayout else {
            return false
        }
        return plan.children.allSatisfy(webCanApplyTextColorHostMutation)
    }
}

func webApplyHookInternal(action: WebExecutorAction,
                           performMutation: Bool) -> WebHookResult {
    switch action.kind {
    case .create:
        return webCreateHook(action: action, performMutation: performMutation)
    case .keep:
        return webKeepHook(action: action, performMutation: performMutation)
    case .update:
        return webUpdateHook(action: action, performMutation: performMutation)
    case .replace:
        return webReplaceHook(action: action, performMutation: performMutation)
    }
}

private func webUpdateHook(action: WebExecutorAction,
                            performMutation: Bool) -> WebHookResult {
    switch action.updateIntent {
    case .textContent:
        return webTextContentHook(action: action, performMutation: performMutation)
    case .colorFill:
        return webColorFillHook(action: action, performMutation: performMutation)
    case .sliderValue:
        return webSliderValueHook(action: action, performMutation: performMutation)
    case .backgroundColor:
        return webBackgroundColorHook(action: action, performMutation: performMutation)
    case .foregroundColor:
        return webForegroundColorHook(action: action, performMutation: performMutation)
    case .paddingLayout:
        return webPaddingLayoutHook(action: action, performMutation: performMutation)
    case .borderStyle, .fontStyle, .frameLayout,
         .hStackLayout, .sliderConfiguration,
         .vStackLayout, .zStackLayout, .none:
        // Descriptive only — no real mutation for these intents yet
        return webUpdatedHookResult(action: action, intent: action.updateIntent,
                                     performMutation: performMutation)
    }
}

private func webTextContentHook(action: WebExecutorAction,
                                 performMutation: Bool) -> WebHookResult {
    var mutationSucceeded = true
    if performMutation,
       case let .text(textDesc) = action.currentDescriptor.props,
       let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID {
        mutationSucceeded = webSetTextContent(slotID: slotID, text: textDesc.content)
    } else if performMutation {
        mutationSucceeded = false
    }
    return webUpdatedHookResult(action: action, intent: .textContent,
                                 performMutation: performMutation,
                                 mutationSucceeded: mutationSucceeded)
}

private func webColorFillHook(action: WebExecutorAction,
                               performMutation: Bool) -> WebHookResult {
    var mutationSucceeded = true
    if performMutation,
       case let .color(colorDesc) = action.currentDescriptor.props,
       let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID {
        mutationSucceeded = webSetColorFill(slotID: slotID, color: colorDesc)
    } else if performMutation {
        mutationSucceeded = false
    }
    return webUpdatedHookResult(action: action, intent: .colorFill,
                                 performMutation: performMutation,
                                 mutationSucceeded: mutationSucceeded)
}

private func webSliderValueHook(action: WebExecutorAction,
                                 performMutation: Bool) -> WebHookResult {
    var mutationSucceeded = true
    if performMutation,
       case let .slider(sliderDesc) = action.currentDescriptor.props,
       let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID {
        mutationSucceeded = webSetSliderValue(slotID: slotID, value: sliderDesc.value)
    } else if performMutation {
        mutationSucceeded = false
    }
    return webUpdatedHookResult(action: action, intent: .sliderValue,
                                 performMutation: performMutation,
                                 mutationSucceeded: mutationSucceeded)
}

private func webBackgroundColorHook(action: WebExecutorAction,
                                     performMutation: Bool) -> WebHookResult {
    var mutationSucceeded = true
    if performMutation,
       case let .background(colorDesc) = action.currentDescriptor.props,
       let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID {
        mutationSucceeded = webSetBackgroundColor(slotID: slotID, color: colorDesc)
    } else if performMutation {
        mutationSucceeded = false
    }
    let childResults = action.children.map { webApplyHookInternal(action: $0, performMutation: performMutation) }
    return WebHookResult(
        identity: action.identity, kind: .updated,
        updateIntent: .backgroundColor,
        currentDescriptor: action.currentDescriptor,
        previousDescriptor: action.previousDescriptor,
        mutationSucceeded: mutationSucceeded && childResults.allSatisfy(webHookMutationSucceeded),
        children: childResults)
}

private func webForegroundColorHook(action: WebExecutorAction,
                                     performMutation: Bool) -> WebHookResult {
    var mutationSucceeded = true
    if performMutation,
       case let .foregroundColor(colorDesc) = action.currentDescriptor.props,
       let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID {
        mutationSucceeded = webSetForegroundColor(slotID: slotID, color: colorDesc)
    } else if performMutation {
        mutationSucceeded = false
    }
    let childResults = action.children.map { webApplyHookInternal(action: $0, performMutation: performMutation) }
    return WebHookResult(
        identity: action.identity, kind: .updated,
        updateIntent: .foregroundColor,
        currentDescriptor: action.currentDescriptor,
        previousDescriptor: action.previousDescriptor,
        mutationSucceeded: mutationSucceeded && childResults.allSatisfy(webHookMutationSucceeded),
        children: childResults)
}

private func webPaddingLayoutHook(action: WebExecutorAction,
                                   performMutation: Bool) -> WebHookResult {
    var mutationSucceeded = true
    if performMutation,
       case let .padding(paddingDesc) = action.currentDescriptor.props,
       let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID {
        mutationSucceeded = webSetPadding(slotID: slotID, padding: paddingDesc)
    } else if performMutation {
        mutationSucceeded = false
    }
    let childResults = action.children.map { webApplyHookInternal(action: $0, performMutation: performMutation) }
    return WebHookResult(
        identity: action.identity, kind: .updated,
        updateIntent: .paddingLayout,
        currentDescriptor: action.currentDescriptor,
        previousDescriptor: action.previousDescriptor,
        mutationSucceeded: mutationSucceeded && childResults.allSatisfy(webHookMutationSucceeded),
        children: childResults)
}

private func webCreateHook(action: WebExecutorAction,
                            performMutation: Bool) -> WebHookResult {
    let childResults = action.children.map { webApplyHookInternal(action: $0, performMutation: performMutation) }
    return WebHookResult(
        identity: action.identity, kind: .created,
        currentDescriptor: action.currentDescriptor,
        mutationSucceeded: childResults.allSatisfy(webHookMutationSucceeded),
        children: childResults)
}

private func webKeepHook(action: WebExecutorAction,
                          performMutation: Bool) -> WebHookResult {
    let childResults = action.children.map { webApplyHookInternal(action: $0, performMutation: performMutation) }
    return WebHookResult(
        identity: action.identity, kind: .noOp,
        currentDescriptor: action.currentDescriptor,
        previousDescriptor: action.previousDescriptor,
        mutationSucceeded: childResults.allSatisfy(webHookMutationSucceeded),
        children: childResults)
}

private func webReplaceHook(action: WebExecutorAction,
                             performMutation: Bool) -> WebHookResult {
    let childResults = action.children.map { webApplyHookInternal(action: $0, performMutation: performMutation) }
    return WebHookResult(
        identity: action.identity, kind: .replaced,
        currentDescriptor: action.currentDescriptor,
        previousDescriptor: action.previousDescriptor,
        mutationSucceeded: childResults.allSatisfy(webHookMutationSucceeded),
        children: childResults)
}

private func webUpdatedHookResult(action: WebExecutorAction,
                                   intent: WebDescriptorUpdateIntent,
                                   performMutation: Bool,
                                   mutationSucceeded: Bool = true) -> WebHookResult {
    let childResults = action.children.map { webApplyHookInternal(action: $0, performMutation: performMutation) }
    return WebHookResult(
        identity: action.identity, kind: .updated,
        updateIntent: intent,
        currentDescriptor: action.currentDescriptor,
        previousDescriptor: action.previousDescriptor,
        mutationSucceeded: mutationSucceeded && childResults.allSatisfy(webHookMutationSucceeded),
        children: childResults)
}

// MARK: - Alignment helpers

public func webAlignmentDescriptor(_ alignment: Alignment) -> WebAlignmentDescriptor {
    switch alignment {
    case .topLeading: return .topLeading
    case .top: return .top
    case .topTrailing: return .topTrailing
    case .leading: return .leading
    case .center: return .center
    case .trailing: return .trailing
    case .bottomLeading: return .bottomLeading
    case .bottom: return .bottom
    case .bottomTrailing: return .bottomTrailing
    }
}

public func webHorizontalAlignmentDescriptor(_ alignment: HorizontalAlignment) -> WebHorizontalAlignmentDescriptor {
    switch alignment {
    case .leading: return .leading
    case .center: return .center
    case .trailing: return .trailing
    }
}

public func webVerticalAlignmentDescriptor(_ alignment: VerticalAlignment) -> WebVerticalAlignmentDescriptor {
    switch alignment {
    case .top: return .top
    case .center: return .center
    case .bottom: return .bottom
    }
}

public func webColorDescriptor(_ color: Color) -> WebColorDescriptor {
    WebColorDescriptor(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
}

// MARK: - Hosted-node kind

/// Kinds of hosted native elements that support in-place mutation.
public enum WebHostedNodeKind: String {
    case text
    case color
    case slider
    case background
    case foregroundColor
    case padding
    case unknown
}

/// Map descriptor kind to hosted kind (nil = not supported for mutation).
public func webHostedKindForDescriptor(_ kind: WebDescriptorKind) -> WebHostedNodeKind? {
    switch kind {
    case .text: return .text
    case .color: return .color
    case .slider: return .slider
    case .background: return .background
    case .foregroundColor: return .foregroundColor
    case .padding: return .padding
    default: return nil
    }
}

// MARK: - Native slot helpers (pure, no JavaScriptKit)

/// Collect descriptor leaves that have a supported hosted kind (text/color).
public func webCollectSupportedLeafDescriptors(
    from node: WebIdentifiedDescriptorNode
) -> [(identity: WebDescriptorIdentity, kind: WebDescriptorKind)] {
    var result: [(identity: WebDescriptorIdentity, kind: WebDescriptorKind)] = []
    if webHostedKindForDescriptor(node.descriptor.kind) != nil {
        result.append((identity: node.identity, kind: node.descriptor.kind))
    }
    for child in node.children {
        result.append(contentsOf: webCollectSupportedLeafDescriptors(from: child))
    }
    return result
}

/// Rebuild executor tree with slot IDs from a lookup table.
public func webAssignNativeSlots(
    _ node: WebRetainedExecutorNode,
    slotsByIdentity: [WebDescriptorIdentity: Int]
) -> WebRetainedExecutorNode {
    WebRetainedExecutorNode(
        identity: node.identity,
        kind: node.kind,
        lastDescriptor: node.lastDescriptor,
        nativeSlotID: slotsByIdentity[node.identity] ?? node.nativeSlotID,
        children: node.children.map { webAssignNativeSlots($0, slotsByIdentity: slotsByIdentity) }
    )
}

// MARK: - Mutation stubs (overridden by WebDescriptorMutation.swift)

/// Set text content on a hosted DOM element. Default stub returns false.
/// The real implementation in WebDescriptorMutation.swift resolves via slot table.
var _webSetTextContentImpl: (Int, String) -> Bool = { _, _ in false }

/// Set color fill on a hosted DOM element. Default stub returns false.
var _webSetColorFillImpl: (Int, WebColorDescriptor) -> Bool = { _, _ in false }

func webSetTextContent(slotID: Int, text: String) -> Bool {
    _webSetTextContentImpl(slotID, text)
}

func webSetColorFill(slotID: Int, color: WebColorDescriptor) -> Bool {
    _webSetColorFillImpl(slotID, color)
}

/// Set slider value on a hosted DOM element. Default stub returns false.
var _webSetSliderValueImpl: (Int, Double) -> Bool = { _, _ in false }

func webSetSliderValue(slotID: Int, value: Double) -> Bool {
    _webSetSliderValueImpl(slotID, value)
}

/// Set background color on a hosted wrapper DOM element. Default stub returns false.
var _webSetBackgroundColorImpl: (Int, WebColorDescriptor) -> Bool = { _, _ in false }

func webSetBackgroundColor(slotID: Int, color: WebColorDescriptor) -> Bool {
    _webSetBackgroundColorImpl(slotID, color)
}

/// Set foreground color on a hosted wrapper DOM element. Default stub returns false.
var _webSetForegroundColorImpl: (Int, WebColorDescriptor) -> Bool = { _, _ in false }

func webSetForegroundColor(slotID: Int, color: WebColorDescriptor) -> Bool {
    _webSetForegroundColorImpl(slotID, color)
}

/// Set padding on a hosted wrapper DOM element. Default stub returns false.
var _webSetPaddingImpl: (Int, WebPaddingDescriptor) -> Bool = { _, _ in false }

func webSetPadding(slotID: Int, padding: WebPaddingDescriptor) -> Bool {
    _webSetPaddingImpl(slotID, padding)
}
