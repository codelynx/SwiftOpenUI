import SwiftOpenUI

// MARK: - Descriptor kinds and property types

/// Leaf-first GTK4 descriptor kinds for the descriptor-first invalidation path.
public enum GTK4DescriptorKind: Equatable {
    case background
    case border
    case composite
    case text
    case color
    case frame
    case foregroundColor
    case hStack
    case padding
    case slider
    case vStack
    case zStack
}

public struct GTK4TextDescriptor: Equatable {
    public let content: String
}

public struct GTK4ColorDescriptor: Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double
}

public struct GTK4SliderDescriptor: Equatable {
    public let value: Double
    public let range: ClosedRange<Double>
    public let step: Double
}

public enum GTK4AlignmentDescriptor: String, Equatable {
    case topLeading, top, topTrailing
    case leading, center, trailing
    case bottomLeading, bottom, bottomTrailing
}

public struct GTK4PaddingDescriptor: Equatable {
    public let top: Int
    public let bottom: Int
    public let leading: Int
    public let trailing: Int
}

public struct GTK4FrameDescriptor: Equatable {
    public let width: Double?
    public let height: Double?
    public let minWidth: Double?
    public let minHeight: Double?
    public let maxWidth: Double?
    public let maxHeight: Double?
    public let alignment: GTK4AlignmentDescriptor
}

public struct GTK4BorderDescriptor: Equatable {
    public let color: GTK4ColorDescriptor
    public let width: Int
}

public enum GTK4HorizontalAlignmentDescriptor: String, Equatable {
    case leading, center, trailing
}

public enum GTK4VerticalAlignmentDescriptor: String, Equatable {
    case top, center, bottom
}

public struct GTK4VStackDescriptor: Equatable {
    public let spacing: Int
    public let alignment: GTK4HorizontalAlignmentDescriptor
}

public struct GTK4HStackDescriptor: Equatable {
    public let spacing: Int
    public let alignment: GTK4VerticalAlignmentDescriptor
}

public struct GTK4ZStackDescriptor: Equatable {
    public let alignment: GTK4AlignmentDescriptor
}

// MARK: - Descriptor props and node

public enum GTK4DescriptorProps: Equatable {
    case none
    case background(GTK4ColorDescriptor)
    case border(GTK4BorderDescriptor)
    case text(GTK4TextDescriptor)
    case color(GTK4ColorDescriptor)
    case frame(GTK4FrameDescriptor)
    case foregroundColor(GTK4ColorDescriptor)
    case hStack(GTK4HStackDescriptor)
    case padding(GTK4PaddingDescriptor)
    case slider(GTK4SliderDescriptor)
    case vStack(GTK4VStackDescriptor)
    case zStack(GTK4ZStackDescriptor)
}

public struct GTK4DescriptorNode: Equatable {
    public let kind: GTK4DescriptorKind
    public let typeName: String
    public let props: GTK4DescriptorProps
    public let children: [GTK4DescriptorNode]

    public init(kind: GTK4DescriptorKind,
                typeName: String,
                props: GTK4DescriptorProps = .none,
                children: [GTK4DescriptorNode] = []) {
        self.kind = kind
        self.typeName = typeName
        self.props = props
        self.children = children
    }
}

// MARK: - Identity

/// Structural identity by position. Keyed identity is a later step.
public struct GTK4DescriptorIdentity: Equatable, Hashable {
    public let path: [Int]

    public init(path: [Int]) {
        self.path = path
    }
}

// MARK: - Identified + retained nodes

public struct GTK4IdentifiedDescriptorNode: Equatable {
    public let identity: GTK4DescriptorIdentity
    public let descriptor: GTK4DescriptorNode
    public let children: [GTK4IdentifiedDescriptorNode]

    public init(identity: GTK4DescriptorIdentity,
                descriptor: GTK4DescriptorNode,
                children: [GTK4IdentifiedDescriptorNode]) {
        self.identity = identity
        self.descriptor = descriptor
        self.children = children
    }
}

public struct GTK4RetainedDescriptorNode: Equatable {
    public let identity: GTK4DescriptorIdentity
    public let descriptor: GTK4DescriptorNode
    public let children: [GTK4RetainedDescriptorNode]

    public init(identity: GTK4DescriptorIdentity,
                descriptor: GTK4DescriptorNode,
                children: [GTK4RetainedDescriptorNode]) {
        self.identity = identity
        self.descriptor = descriptor
        self.children = children
    }
}

// MARK: - Retained executor node

public struct GTK4RetainedExecutorNode: Equatable {
    public let identity: GTK4DescriptorIdentity
    public let kind: GTK4DescriptorKind
    public let lastDescriptor: GTK4DescriptorNode
    public let nativeSlotID: Int?
    public let children: [GTK4RetainedExecutorNode]

    public init(identity: GTK4DescriptorIdentity,
                kind: GTK4DescriptorKind,
                lastDescriptor: GTK4DescriptorNode,
                nativeSlotID: Int? = nil,
                children: [GTK4RetainedExecutorNode] = []) {
        self.identity = identity
        self.kind = kind
        self.lastDescriptor = lastDescriptor
        self.nativeSlotID = nativeSlotID
        self.children = children
    }
}

// MARK: - Match

public enum GTK4DescriptorMatchKind: Equatable {
    case reuse
    case replace
}

public struct GTK4DescriptorMatch: Equatable {
    public let identity: GTK4DescriptorIdentity
    public let kind: GTK4DescriptorMatchKind
    public let oldDescriptor: GTK4DescriptorNode?
    public let newDescriptor: GTK4DescriptorNode
    public let children: [GTK4DescriptorMatch]

    public init(identity: GTK4DescriptorIdentity,
                kind: GTK4DescriptorMatchKind,
                oldDescriptor: GTK4DescriptorNode?,
                newDescriptor: GTK4DescriptorNode,
                children: [GTK4DescriptorMatch] = []) {
        self.identity = identity
        self.kind = kind
        self.oldDescriptor = oldDescriptor
        self.newDescriptor = newDescriptor
        self.children = children
    }
}

// MARK: - Plan

public enum GTK4DescriptorPlanKind: Equatable {
    case create
    case reuse
    case update
    case replace
}

public enum GTK4DescriptorUpdateIntent: Equatable {
    case none
    case backgroundColor
    case borderStyle
    case colorFill
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

public struct GTK4DescriptorPlan: Equatable {
    public let identity: GTK4DescriptorIdentity
    public let kind: GTK4DescriptorPlanKind
    public let updateIntent: GTK4DescriptorUpdateIntent
    public let oldDescriptor: GTK4DescriptorNode?
    public let newDescriptor: GTK4DescriptorNode
    public let children: [GTK4DescriptorPlan]

    public init(identity: GTK4DescriptorIdentity,
                kind: GTK4DescriptorPlanKind,
                updateIntent: GTK4DescriptorUpdateIntent = .none,
                oldDescriptor: GTK4DescriptorNode?,
                newDescriptor: GTK4DescriptorNode,
                children: [GTK4DescriptorPlan] = []) {
        self.identity = identity
        self.kind = kind
        self.updateIntent = updateIntent
        self.oldDescriptor = oldDescriptor
        self.newDescriptor = newDescriptor
        self.children = children
    }
}

// MARK: - Executor actions

public enum GTK4ExecutorActionKind: Equatable {
    case create
    case keep
    case update
    case replace
}

public struct GTK4ExecutorAction: Equatable {
    public let identity: GTK4DescriptorIdentity
    public let kind: GTK4ExecutorActionKind
    public let updateIntent: GTK4DescriptorUpdateIntent
    public let previousDescriptor: GTK4DescriptorNode?
    public let currentDescriptor: GTK4DescriptorNode
    public let previousNode: GTK4RetainedExecutorNode?
    public let resultingNode: GTK4RetainedExecutorNode
    public let children: [GTK4ExecutorAction]

    public init(identity: GTK4DescriptorIdentity,
                kind: GTK4ExecutorActionKind,
                updateIntent: GTK4DescriptorUpdateIntent = .none,
                previousDescriptor: GTK4DescriptorNode?,
                currentDescriptor: GTK4DescriptorNode,
                previousNode: GTK4RetainedExecutorNode?,
                resultingNode: GTK4RetainedExecutorNode,
                children: [GTK4ExecutorAction] = []) {
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

public enum GTK4HookResultKind: Equatable {
    case created
    case updated
    case replaced
    case noOp
}

public struct GTK4HookResult: Equatable {
    public let identity: GTK4DescriptorIdentity
    public let kind: GTK4HookResultKind
    public let updateIntent: GTK4DescriptorUpdateIntent
    public let currentDescriptor: GTK4DescriptorNode
    public let previousDescriptor: GTK4DescriptorNode?
    public let mutationSucceeded: Bool
    public let children: [GTK4HookResult]

    public init(identity: GTK4DescriptorIdentity,
                kind: GTK4HookResultKind,
                updateIntent: GTK4DescriptorUpdateIntent = .none,
                currentDescriptor: GTK4DescriptorNode,
                previousDescriptor: GTK4DescriptorNode? = nil,
                mutationSucceeded: Bool = true,
                children: [GTK4HookResult] = []) {
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

/// Protocol for GTK4 views that can produce a descriptor without creating widgets.
public protocol GTKDescribable {
    func gtkDescribeNode() -> GTK4DescriptorNode
}

/// Build a GTK4-local descriptor tree without creating widgets.
public func gtkDescribeView<V: View>(_ view: V) -> GTK4DescriptorNode {
    if let describable = view as? GTKDescribable {
        return describable.gtkDescribeNode()
    }
    if let multi = view as? MultiChildView {
        return GTK4DescriptorNode(
            kind: .composite,
            typeName: String(describing: type(of: view)),
            children: multi.children.map(gtkDescribeAnyView)
        )
    }
    if V.Body.self != Never.self {
        return gtkDescribeAnyView(view.body)
    }
    return GTK4DescriptorNode(
        kind: .composite,
        typeName: String(describing: type(of: view))
    )
}

public func gtkDescribeAnyView(_ view: any View) -> GTK4DescriptorNode {
    func describe<V: View>(_ value: V) -> GTK4DescriptorNode { gtkDescribeView(value) }
    return describe(view)
}

// MARK: - Identify

public func gtkIdentifyDescriptorTree(_ descriptor: GTK4DescriptorNode) -> GTK4IdentifiedDescriptorNode {
    gtkIdentifyNode(descriptor, path: [])
}

private func gtkIdentifyNode(_ descriptor: GTK4DescriptorNode,
                              path: [Int]) -> GTK4IdentifiedDescriptorNode {
    GTK4IdentifiedDescriptorNode(
        identity: GTK4DescriptorIdentity(path: path),
        descriptor: descriptor,
        children: descriptor.children.enumerated().map { index, child in
            gtkIdentifyNode(child, path: path + [index])
        }
    )
}

// MARK: - Retain

public func gtkRetainDescriptorTree(_ node: GTK4IdentifiedDescriptorNode) -> GTK4RetainedDescriptorNode {
    GTK4RetainedDescriptorNode(
        identity: node.identity,
        descriptor: node.descriptor,
        children: node.children.map(gtkRetainDescriptorTree)
    )
}

public func gtkMakeExecutorTree(from node: GTK4IdentifiedDescriptorNode,
                                nativeSlotID: Int? = nil) -> GTK4RetainedExecutorNode {
    GTK4RetainedExecutorNode(
        identity: node.identity,
        kind: node.descriptor.kind,
        lastDescriptor: node.descriptor,
        nativeSlotID: nativeSlotID,
        children: node.children.map { gtkMakeExecutorTree(from: $0) }
    )
}

// MARK: - Match

public func gtkMatchDescriptorTree(old: GTK4RetainedDescriptorNode,
                                    new: GTK4IdentifiedDescriptorNode) -> GTK4DescriptorMatch {
    guard gtkCanReuseNode(old: old, new: new) else {
        return GTK4DescriptorMatch(
            identity: new.identity,
            kind: .replace,
            oldDescriptor: old.descriptor,
            newDescriptor: new.descriptor
        )
    }
    return GTK4DescriptorMatch(
        identity: new.identity,
        kind: .reuse,
        oldDescriptor: old.descriptor,
        newDescriptor: new.descriptor,
        children: zip(old.children, new.children).map(gtkMatchDescriptorTree)
    )
}

private func gtkCanReuseNode(old: GTK4RetainedDescriptorNode,
                              new: GTK4IdentifiedDescriptorNode) -> Bool {
    old.identity == new.identity
        && old.descriptor.kind == new.descriptor.kind
        && old.children.count == new.children.count
}

// MARK: - Plan

public func gtkPlanDescriptorTree(old: GTK4RetainedDescriptorNode?,
                                   new: GTK4IdentifiedDescriptorNode) -> GTK4DescriptorPlan {
    guard let old else {
        return GTK4DescriptorPlan(
            identity: new.identity,
            kind: .create,
            oldDescriptor: nil,
            newDescriptor: new.descriptor,
            children: new.children.map { gtkPlanDescriptorTree(old: nil, new: $0) }
        )
    }

    guard gtkCanReuseNode(old: old, new: new) else {
        return GTK4DescriptorPlan(
            identity: new.identity,
            kind: .replace,
            oldDescriptor: old.descriptor,
            newDescriptor: new.descriptor,
            children: new.children.map { gtkPlanDescriptorTree(old: nil, new: $0) }
        )
    }

    let childPlans = zip(old.children, new.children).map { oldChild, newChild in
        gtkPlanDescriptorTree(old: oldChild, new: newChild)
    }
    let localKind: GTK4DescriptorPlanKind = old.descriptor.props == new.descriptor.props ? .reuse : .update
    let updateIntent: GTK4DescriptorUpdateIntent =
        localKind == .update ? gtkUpdateIntent(old: old.descriptor, new: new.descriptor) : .none

    return GTK4DescriptorPlan(
        identity: new.identity,
        kind: localKind,
        updateIntent: updateIntent,
        oldDescriptor: old.descriptor,
        newDescriptor: new.descriptor,
        children: childPlans
    )
}

private func gtkUpdateIntent(old: GTK4DescriptorNode,
                              new: GTK4DescriptorNode) -> GTK4DescriptorUpdateIntent {
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
    case .composite:     return .none
    }
}

// MARK: - Execute

public func gtkExecuteDescriptorPlan(old: GTK4RetainedExecutorNode?,
                                      plan: GTK4DescriptorPlan) -> GTK4ExecutorAction {
    switch plan.kind {
    case .create:
        let childActions = plan.children.map { gtkExecuteDescriptorPlan(old: nil, plan: $0) }
        let node = GTK4RetainedExecutorNode(
            identity: plan.identity, kind: plan.newDescriptor.kind,
            lastDescriptor: plan.newDescriptor, children: childActions.map(\.resultingNode))
        return GTK4ExecutorAction(
            identity: plan.identity, kind: .create,
            previousDescriptor: nil, currentDescriptor: plan.newDescriptor,
            previousNode: nil, resultingNode: node, children: childActions)

    case .replace:
        let childActions = plan.children.map { gtkExecuteDescriptorPlan(old: nil, plan: $0) }
        let node = GTK4RetainedExecutorNode(
            identity: plan.identity, kind: plan.newDescriptor.kind,
            lastDescriptor: plan.newDescriptor, children: childActions.map(\.resultingNode))
        return GTK4ExecutorAction(
            identity: plan.identity, kind: .replace,
            previousDescriptor: old?.lastDescriptor ?? plan.oldDescriptor,
            currentDescriptor: plan.newDescriptor,
            previousNode: old, resultingNode: node, children: childActions)

    case .reuse, .update:
        let childActions = zip(old?.children ?? [], plan.children).map { oldChild, childPlan in
            gtkExecuteDescriptorPlan(old: oldChild, plan: childPlan)
        }
        let node = GTK4RetainedExecutorNode(
            identity: plan.identity, kind: plan.newDescriptor.kind,
            lastDescriptor: plan.newDescriptor, nativeSlotID: old?.nativeSlotID,
            children: childActions.map(\.resultingNode))
        return GTK4ExecutorAction(
            identity: plan.identity, kind: plan.kind == .update ? .update : .keep,
            updateIntent: plan.updateIntent,
            previousDescriptor: old?.lastDescriptor ?? plan.oldDescriptor,
            currentDescriptor: plan.newDescriptor,
            previousNode: old, resultingNode: node, children: childActions)
    }
}

// MARK: - Hook (descriptive dispatch)

public func gtkApplyHook(action: GTK4ExecutorAction) -> GTK4HookResult {
    gtkApplyHookInternal(action: action, performMutation: false)
}

public func gtkApplyHookMutation(action: GTK4ExecutorAction) -> GTK4HookResult {
    gtkApplyHookInternal(action: action, performMutation: true)
}

public func gtkHookMutationSucceeded(_ result: GTK4HookResult) -> Bool {
    result.mutationSucceeded && result.children.allSatisfy(gtkHookMutationSucceeded)
}

/// Check if a plan tree contains only reuse + textContent/colorFill updates.
public func gtkCanApplyTextColorHostMutation(plan: GTK4DescriptorPlan) -> Bool {
    switch plan.kind {
    case .create, .replace:
        return false
    case .reuse:
        return plan.children.allSatisfy(gtkCanApplyTextColorHostMutation)
    case .update:
        guard plan.updateIntent == .textContent || plan.updateIntent == .colorFill else {
            return false
        }
        return plan.children.allSatisfy(gtkCanApplyTextColorHostMutation)
    }
}

private func gtkApplyHookInternal(action: GTK4ExecutorAction,
                                   performMutation: Bool) -> GTK4HookResult {
    switch action.kind {
    case .create:
        return gtkCreateHook(action: action, performMutation: performMutation)
    case .keep:
        return gtkKeepHook(action: action, performMutation: performMutation)
    case .update:
        return gtkUpdateHook(action: action, performMutation: performMutation)
    case .replace:
        return gtkReplaceHook(action: action, performMutation: performMutation)
    }
}

private func gtkUpdateHook(action: GTK4ExecutorAction,
                            performMutation: Bool) -> GTK4HookResult {
    switch action.updateIntent {
    case .textContent:
        return gtkTextContentHook(action: action, performMutation: performMutation)
    case .colorFill:
        return gtkColorFillHook(action: action, performMutation: performMutation)
    case .backgroundColor, .borderStyle, .frameLayout, .foregroundColor,
         .hStackLayout, .paddingLayout, .sliderConfiguration, .sliderValue,
         .vStackLayout, .zStackLayout, .none:
        // Descriptive only — no real mutation for these intents yet
        return gtkUpdatedHookResult(action: action, intent: action.updateIntent,
                                     performMutation: performMutation)
    }
}

private func gtkTextContentHook(action: GTK4ExecutorAction,
                                 performMutation: Bool) -> GTK4HookResult {
    // Real GTK mutation will be wired in step 5 (host integration).
    // For now, descriptive only.
    return gtkUpdatedHookResult(action: action, intent: .textContent,
                                 performMutation: performMutation)
}

private func gtkColorFillHook(action: GTK4ExecutorAction,
                               performMutation: Bool) -> GTK4HookResult {
    // Real GTK mutation will be wired in step 5 (host integration).
    // For now, descriptive only.
    return gtkUpdatedHookResult(action: action, intent: .colorFill,
                                 performMutation: performMutation)
}

private func gtkCreateHook(action: GTK4ExecutorAction,
                            performMutation: Bool) -> GTK4HookResult {
    let childResults = action.children.map { gtkApplyHookInternal(action: $0, performMutation: performMutation) }
    return GTK4HookResult(
        identity: action.identity, kind: .created,
        currentDescriptor: action.currentDescriptor,
        mutationSucceeded: childResults.allSatisfy(gtkHookMutationSucceeded),
        children: childResults)
}

private func gtkKeepHook(action: GTK4ExecutorAction,
                          performMutation: Bool) -> GTK4HookResult {
    let childResults = action.children.map { gtkApplyHookInternal(action: $0, performMutation: performMutation) }
    return GTK4HookResult(
        identity: action.identity, kind: .noOp,
        currentDescriptor: action.currentDescriptor,
        previousDescriptor: action.previousDescriptor,
        mutationSucceeded: childResults.allSatisfy(gtkHookMutationSucceeded),
        children: childResults)
}

private func gtkReplaceHook(action: GTK4ExecutorAction,
                             performMutation: Bool) -> GTK4HookResult {
    let childResults = action.children.map { gtkApplyHookInternal(action: $0, performMutation: performMutation) }
    return GTK4HookResult(
        identity: action.identity, kind: .replaced,
        currentDescriptor: action.currentDescriptor,
        previousDescriptor: action.previousDescriptor,
        mutationSucceeded: childResults.allSatisfy(gtkHookMutationSucceeded),
        children: childResults)
}

private func gtkUpdatedHookResult(action: GTK4ExecutorAction,
                                   intent: GTK4DescriptorUpdateIntent,
                                   performMutation: Bool,
                                   mutationSucceeded: Bool = true) -> GTK4HookResult {
    let childResults = action.children.map { gtkApplyHookInternal(action: $0, performMutation: performMutation) }
    return GTK4HookResult(
        identity: action.identity, kind: .updated,
        updateIntent: intent,
        currentDescriptor: action.currentDescriptor,
        previousDescriptor: action.previousDescriptor,
        mutationSucceeded: mutationSucceeded && childResults.allSatisfy(gtkHookMutationSucceeded),
        children: childResults)
}

// MARK: - Alignment helpers

public func gtkAlignmentDescriptor(_ alignment: Alignment) -> GTK4AlignmentDescriptor {
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

public func gtkHorizontalAlignmentDescriptor(_ alignment: HorizontalAlignment) -> GTK4HorizontalAlignmentDescriptor {
    switch alignment {
    case .leading: return .leading
    case .center: return .center
    case .trailing: return .trailing
    }
}

public func gtkVerticalAlignmentDescriptor(_ alignment: VerticalAlignment) -> GTK4VerticalAlignmentDescriptor {
    switch alignment {
    case .top: return .top
    case .center: return .center
    case .bottom: return .bottom
    }
}

public func gtkColorDescriptor(_ color: Color) -> GTK4ColorDescriptor {
    GTK4ColorDescriptor(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
}
