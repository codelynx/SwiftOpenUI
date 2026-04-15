import SwiftOpenUI
import Foundation
import CGTK
import CGTKBridge

// MARK: - Descriptor kinds and property types

/// Leaf-first GTK4 descriptor kinds for the descriptor-first invalidation path.
public enum GTK4DescriptorKind: Equatable {
    case animated
    case background
    case border
    case button
    case canvas
    case composite
    case disabled
    case divider
    case offset
    case opacity
    case rotation
    case safeAreaInset
    case safeAreaPadding
    case scale
    case searchable
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

public struct GTK4DisabledDescriptor: Equatable {
    public let isDisabled: Bool
}

public struct GTK4OpacityDescriptor: Equatable {
    public let opacity: Double
}

public struct GTK4OffsetDescriptor: Equatable {
    public let x: Double
    public let y: Double
}

public struct GTK4ScaleDescriptor: Equatable {
    public let scaleX: Double
    public let scaleY: Double
}

public struct GTK4RotationDescriptor: Equatable {
    public let angle: Double
}

public struct GTK4AnimatedDescriptor: Equatable {
    public let curve: String
    public let duration: Double
}

public struct GTK4TextDescriptor: Equatable {
    public let content: String
}

public struct GTK4ColorDescriptor: Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double

    public init(red: Double, green: Double, blue: Double, opacity: Double) {
        self.red = red; self.green = green; self.blue = blue; self.opacity = opacity
    }
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

public struct GTK4BackgroundLayoutDescriptor: Equatable {
    public let alignment: GTK4AlignmentDescriptor
}

public struct GTK4FontDescriptor: Equatable {
    public let font: Font
}

public struct GTK4SafeAreaInsetDescriptor: Equatable {
    public let edge: SafeAreaInsetEdge
    public let alignment: SafeAreaInsetAlignment
    public let spacing: Int
}

public struct GTK4SafeAreaPaddingDescriptor: Equatable {
    public let top: Int
    public let bottom: Int
    public let leading: Int
    public let trailing: Int
}

public struct GTK4SearchableDescriptor: Equatable {
    public let text: String
    public let prompt: String
    public let placement: SearchFieldPlacement
    public let isPresented: Bool?
    public let tokens: [SearchTokenValue]
    public let tokenMode: SearchTokenMode?
    public let suggestions: [SearchSuggestionValue]
    public let suggestionMode: SearchSuggestionMode?
    public let scopes: [SearchScopeValue]
    public let scopeMode: SearchScopeMode?
    public let selectedScopeID: String?
}

public struct GTK4CanvasDescriptor: Equatable {
    public let width: Int
    public let height: Int
}

public final class GTK4CanvasPayload {
    public let width: Int
    public let height: Int
    public let drawHandler: (DrawingContext, Int, Int) -> Void
    public let sizedDrawHandler: ((DrawingContext, CGSize) -> Void)?

    public init(
        width: Int,
        height: Int,
        drawHandler: @escaping (DrawingContext, Int, Int) -> Void,
        sizedDrawHandler: ((DrawingContext, CGSize) -> Void)? = nil
    ) {
        self.width = width
        self.height = height
        self.drawHandler = drawHandler
        self.sizedDrawHandler = sizedDrawHandler
    }
}

// MARK: - Descriptor props and node

public enum GTK4DescriptorProps: Equatable {
    case none
    case disabled(GTK4DisabledDescriptor)
    case background(GTK4ColorDescriptor)
    case backgroundLayout(GTK4BackgroundLayoutDescriptor)
    case border(GTK4BorderDescriptor)
    case canvas(GTK4CanvasDescriptor)
    case font(GTK4FontDescriptor)
    case animated(GTK4AnimatedDescriptor)
    case offset(GTK4OffsetDescriptor)
    case opacity(GTK4OpacityDescriptor)
    case rotation(GTK4RotationDescriptor)
    case scale(GTK4ScaleDescriptor)
    case text(GTK4TextDescriptor)
    case color(GTK4ColorDescriptor)
    case frame(GTK4FrameDescriptor)
    case foregroundColor(GTK4ColorDescriptor)
    case hStack(GTK4HStackDescriptor)
    case padding(GTK4PaddingDescriptor)
    case slider(GTK4SliderDescriptor)
    case vStack(GTK4VStackDescriptor)
    case safeAreaInset(GTK4SafeAreaInsetDescriptor)
    case safeAreaPadding(GTK4SafeAreaPaddingDescriptor)
    case searchable(GTK4SearchableDescriptor)
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

public struct GTK4RetainedExecutorNode {
    public let identity: GTK4DescriptorIdentity
    public let kind: GTK4DescriptorKind
    public let lastDescriptor: GTK4DescriptorNode
    public let nativeSlotID: Int?
    public let canvasPayload: GTK4CanvasPayload?
    public let children: [GTK4RetainedExecutorNode]

    public init(identity: GTK4DescriptorIdentity,
                kind: GTK4DescriptorKind,
                lastDescriptor: GTK4DescriptorNode,
                nativeSlotID: Int? = nil,
                canvasPayload: GTK4CanvasPayload? = nil,
                children: [GTK4RetainedExecutorNode] = []) {
        self.identity = identity
        self.kind = kind
        self.lastDescriptor = lastDescriptor
        self.nativeSlotID = nativeSlotID
        self.canvasPayload = canvasPayload
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
    case animatedTiming
    case backgroundColor
    case borderStyle
    case canvasContent
    case colorFill
    case fontStyle
    case frameLayout
    case foregroundColor
    case hStackLayout
    case offsetTransform
    case opacityValue
    case paddingLayout
    case disabledState
    case rotationTransform
    case safeAreaInsetLayout
    case safeAreaPaddingLayout
    case scaleTransform
    case searchableLayout
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

public struct GTK4ExecutorAction {
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

private final class GTK4CanvasPayloadCollector {
    var payloads: [GTK4CanvasPayload] = []
}

private var gtkCanvasPayloadCollectorKey: pthread_key_t = {
    var key: pthread_key_t = 0
    pthread_key_create(&key, nil)
    return key
}()

public func gtkCollectCanvasPayload(_ payload: GTK4CanvasPayload) {
    guard let raw = pthread_getspecific(gtkCanvasPayloadCollectorKey) else { return }
    let collector = Unmanaged<GTK4CanvasPayloadCollector>.fromOpaque(raw).takeUnretainedValue()
    collector.payloads.append(payload)
}

public func gtkDescribeCapturingCanvasPayloads(
    _ describe: () -> GTK4DescriptorNode
) -> (descriptor: GTK4DescriptorNode, canvasPayloads: [GTK4CanvasPayload]) {
    let collector = GTK4CanvasPayloadCollector()
    let retained = Unmanaged.passRetained(collector)
    let previous = pthread_getspecific(gtkCanvasPayloadCollectorKey)
    pthread_setspecific(gtkCanvasPayloadCollectorKey, retained.toOpaque())
    let descriptor = describe()
    pthread_setspecific(gtkCanvasPayloadCollectorKey, previous)
    retained.release()
    return (descriptor, collector.payloads)
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

public func gtkMakeExecutorTree(
    from node: GTK4IdentifiedDescriptorNode,
    nativeSlotID: Int? = nil,
    canvasPayloadsByIdentity: [GTK4DescriptorIdentity: GTK4CanvasPayload] = [:]
) -> GTK4RetainedExecutorNode {
    GTK4RetainedExecutorNode(
        identity: node.identity,
        kind: node.descriptor.kind,
        lastDescriptor: node.descriptor,
        nativeSlotID: nativeSlotID,
        canvasPayload: canvasPayloadsByIdentity[node.identity],
        children: node.children.map {
            gtkMakeExecutorTree(from: $0, canvasPayloadsByIdentity: canvasPayloadsByIdentity)
        }
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
    let localKind: GTK4DescriptorPlanKind
    if new.descriptor.kind == .canvas {
        localKind = .update
    } else {
        localKind = old.descriptor.props == new.descriptor.props ? .reuse : .update
    }
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
    case .background:
        switch new.props {
        case .background:
            return .backgroundColor
        default:
            return .none
        }
    case .border:        return .borderStyle
    case .canvas:        return .canvasContent
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
    case .animated:      return .animatedTiming
    case .button:        return .none
    case .divider:       return .none
    case .font:          return .fontStyle
    case .offset:        return .offsetTransform
    case .opacity:       return .opacityValue
    case .rotation:      return .rotationTransform
    case .scale:         return .scaleTransform
    case .spacer:        return .none
    case .composite:     return .none
    case .disabled:      return .disabledState
    case .safeAreaInset:   return .safeAreaInsetLayout
    case .safeAreaPadding: return .safeAreaPaddingLayout
    case .searchable:      return .searchableLayout
    }
}

// MARK: - Execute

public func gtkExecuteDescriptorPlan(
    old: GTK4RetainedExecutorNode?,
    plan: GTK4DescriptorPlan,
    canvasPayloadsByIdentity: [GTK4DescriptorIdentity: GTK4CanvasPayload] = [:]
) -> GTK4ExecutorAction {
    switch plan.kind {
    case .create:
        let childActions = plan.children.map {
            gtkExecuteDescriptorPlan(old: nil, plan: $0, canvasPayloadsByIdentity: canvasPayloadsByIdentity)
        }
        let node = GTK4RetainedExecutorNode(
            identity: plan.identity, kind: plan.newDescriptor.kind,
            lastDescriptor: plan.newDescriptor,
            canvasPayload: canvasPayloadsByIdentity[plan.identity],
            children: childActions.map(\.resultingNode))
        return GTK4ExecutorAction(
            identity: plan.identity, kind: .create,
            previousDescriptor: nil, currentDescriptor: plan.newDescriptor,
            previousNode: nil, resultingNode: node, children: childActions)

    case .replace:
        let childActions = plan.children.map {
            gtkExecuteDescriptorPlan(old: nil, plan: $0, canvasPayloadsByIdentity: canvasPayloadsByIdentity)
        }
        let node = GTK4RetainedExecutorNode(
            identity: plan.identity, kind: plan.newDescriptor.kind,
            lastDescriptor: plan.newDescriptor,
            canvasPayload: canvasPayloadsByIdentity[plan.identity],
            children: childActions.map(\.resultingNode))
        return GTK4ExecutorAction(
            identity: plan.identity, kind: .replace,
            previousDescriptor: old?.lastDescriptor ?? plan.oldDescriptor,
            currentDescriptor: plan.newDescriptor,
            previousNode: old, resultingNode: node, children: childActions)

    case .reuse, .update:
        let childActions = zip(old?.children ?? [], plan.children).map { oldChild, childPlan in
            gtkExecuteDescriptorPlan(
                old: oldChild,
                plan: childPlan,
                canvasPayloadsByIdentity: canvasPayloadsByIdentity
            )
        }
        let node = GTK4RetainedExecutorNode(
            identity: plan.identity, kind: plan.newDescriptor.kind,
            lastDescriptor: plan.newDescriptor, nativeSlotID: old?.nativeSlotID,
            canvasPayload: canvasPayloadsByIdentity[plan.identity] ?? old?.canvasPayload,
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

/// Check if a plan tree contains only reuse + supported in-place updates.
/// Opaque composites (Body = Never, no describable conformance) with no
/// described children are rejected — their child content is not captured
/// in the descriptor, so we can't prove nothing changed inside.
public func gtkCanApplyTextColorHostMutation(plan: GTK4DescriptorPlan) -> Bool {
    switch plan.kind {
    case .create, .replace:
        return false
    case .reuse:
        if plan.newDescriptor.kind == .composite && plan.children.isEmpty {
            return false
        }
        return plan.children.allSatisfy(gtkCanApplyTextColorHostMutation)
    case .update:
        guard plan.updateIntent == .textContent || plan.updateIntent == .colorFill
                || plan.updateIntent == .canvasContent
                || plan.updateIntent == .sliderValue
                || plan.updateIntent == .paddingLayout else {
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
    case .canvasContent:
        return gtkCanvasContentHook(action: action, performMutation: performMutation)
    case .sliderValue:
        return gtkSliderValueHook(action: action, performMutation: performMutation)
    case .paddingLayout:
        return gtkPaddingLayoutHook(action: action, performMutation: performMutation)
    case .animatedTiming, .backgroundColor, .borderStyle, .fontStyle, .frameLayout, .foregroundColor,
         .disabledState, .hStackLayout, .offsetTransform, .opacityValue, .rotationTransform, .scaleTransform,
         .safeAreaInsetLayout, .safeAreaPaddingLayout, .searchableLayout, .sliderConfiguration,
         .vStackLayout, .zStackLayout, .none:
        // Descriptive only — no real mutation for these intents yet
        return gtkUpdatedHookResult(action: action, intent: action.updateIntent,
                                     performMutation: performMutation)
    }
}

private func gtkCanvasContentHook(action: GTK4ExecutorAction,
                                   performMutation: Bool) -> GTK4HookResult {
    var mutationSucceeded = true
    if performMutation,
       let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID,
       let payload = action.resultingNode.canvasPayload ?? action.previousNode?.canvasPayload {
        mutationSucceeded = gtkSetCanvasContent(slotID: slotID, payload: payload)
    } else if performMutation {
        mutationSucceeded = false
    }
    return gtkUpdatedHookResult(action: action, intent: .canvasContent,
                                 performMutation: performMutation,
                                 mutationSucceeded: mutationSucceeded)
}

private func gtkTextContentHook(action: GTK4ExecutorAction,
                                 performMutation: Bool) -> GTK4HookResult {
    var mutationSucceeded = true
    if performMutation,
       case let .text(textDesc) = action.currentDescriptor.props,
       let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID {
        mutationSucceeded = gtkSetTextContent(slotID: slotID, text: textDesc.content)
    } else if performMutation {
        mutationSucceeded = false
    }
    return gtkUpdatedHookResult(action: action, intent: .textContent,
                                 performMutation: performMutation,
                                 mutationSucceeded: mutationSucceeded)
}

private func gtkColorFillHook(action: GTK4ExecutorAction,
                               performMutation: Bool) -> GTK4HookResult {
    var mutationSucceeded = true
    if performMutation,
       case let .color(colorDesc) = action.currentDescriptor.props,
       let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID {
        mutationSucceeded = gtkSetColorFill(slotID: slotID, color: colorDesc)
    } else if performMutation {
        mutationSucceeded = false
    }
    return gtkUpdatedHookResult(action: action, intent: .colorFill,
                                 performMutation: performMutation,
                                 mutationSucceeded: mutationSucceeded)
}

private func gtkSliderValueHook(action: GTK4ExecutorAction,
                                 performMutation: Bool) -> GTK4HookResult {
    var mutationSucceeded = true
    if performMutation,
       case let .slider(sliderDesc) = action.currentDescriptor.props,
       let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID {
        mutationSucceeded = gtkSetSliderValue(slotID: slotID, value: sliderDesc.value)
    } else if performMutation {
        mutationSucceeded = false
    }
    return gtkUpdatedHookResult(action: action, intent: .sliderValue,
                                 performMutation: performMutation,
                                 mutationSucceeded: mutationSucceeded)
}

private func gtkPaddingLayoutHook(action: GTK4ExecutorAction,
                                   performMutation: Bool) -> GTK4HookResult {
    var mutationSucceeded = true
    if performMutation,
       case let .padding(paddingDesc) = action.currentDescriptor.props,
       let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID {
        mutationSucceeded = gtkSetPadding(slotID: slotID, padding: paddingDesc)
    } else if performMutation {
        mutationSucceeded = false
    }
    let childResults = action.children.map { gtkApplyHookInternal(action: $0, performMutation: performMutation) }
    return GTK4HookResult(
        identity: action.identity, kind: .updated,
        updateIntent: .paddingLayout,
        currentDescriptor: action.currentDescriptor,
        previousDescriptor: action.previousDescriptor,
        mutationSucceeded: mutationSucceeded && childResults.allSatisfy(gtkHookMutationSucceeded),
        children: childResults)
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

// MARK: - Hosted-node kind tagging

/// Kinds of hosted native widgets that support in-place mutation.
public enum GTK4HostedNodeKind: String {
    case text
    case color
    case canvas
    case slider
    case padding
    case unknown
}

private let gtkHostedKindKey = "gtk-swift-hosted-kind"

/// Tag a GTK widget with its hosted kind during render.
public func gtkMarkHostedNodeKind(_ widget: UnsafeMutablePointer<GtkWidget>,
                                   kind: GTK4HostedNodeKind) {
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    // Store the kind string as a static pointer (no allocation needed)
    switch kind {
    case .text:
        g_object_set_data(gobject, gtkHostedKindKey, UnsafeMutableRawPointer(mutating: gtkHostedKindTextPtr))
    case .color:
        g_object_set_data(gobject, gtkHostedKindKey, UnsafeMutableRawPointer(mutating: gtkHostedKindColorPtr))
    case .canvas:
        g_object_set_data(gobject, gtkHostedKindKey, UnsafeMutableRawPointer(mutating: gtkHostedKindCanvasPtr))
    case .slider:
        g_object_set_data(gobject, gtkHostedKindKey, UnsafeMutableRawPointer(mutating: gtkHostedKindSliderPtr))
    case .padding:
        g_object_set_data(gobject, gtkHostedKindKey, UnsafeMutableRawPointer(mutating: gtkHostedKindPaddingPtr))
    case .unknown:
        break
    }
}

/// Read the hosted kind from a tagged GTK widget.
public func gtkHostedNodeKind(of widget: UnsafeMutablePointer<GtkWidget>) -> GTK4HostedNodeKind {
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    guard let raw = g_object_get_data(gobject, gtkHostedKindKey) else { return .unknown }
    if raw == UnsafeMutableRawPointer(mutating: gtkHostedKindTextPtr) { return .text }
    if raw == UnsafeMutableRawPointer(mutating: gtkHostedKindColorPtr) { return .color }
    if raw == UnsafeMutableRawPointer(mutating: gtkHostedKindCanvasPtr) { return .canvas }
    if raw == UnsafeMutableRawPointer(mutating: gtkHostedKindSliderPtr) { return .slider }
    if raw == UnsafeMutableRawPointer(mutating: gtkHostedKindPaddingPtr) { return .padding }
    return .unknown
}

// Static pointers for kind comparison (avoids string allocation per check)
private let gtkHostedKindTextPtr: UnsafePointer<CChar> = {
    let p = UnsafeMutablePointer<CChar>.allocate(capacity: 1)
    p.pointee = 1
    return UnsafePointer(p)
}()

private let gtkHostedKindColorPtr: UnsafePointer<CChar> = {
    let p = UnsafeMutablePointer<CChar>.allocate(capacity: 1)
    p.pointee = 2
    return UnsafePointer(p)
}()

private let gtkHostedKindCanvasPtr: UnsafePointer<CChar> = {
    let p = UnsafeMutablePointer<CChar>.allocate(capacity: 1)
    p.pointee = 5
    return UnsafePointer(p)
}()

private let gtkHostedKindSliderPtr: UnsafePointer<CChar> = {
    let p = UnsafeMutablePointer<CChar>.allocate(capacity: 1)
    p.pointee = 3
    return UnsafePointer(p)
}()

private let gtkHostedKindPaddingPtr: UnsafePointer<CChar> = {
    let p = UnsafeMutablePointer<CChar>.allocate(capacity: 1)
    p.pointee = 4
    return UnsafePointer(p)
}()

/// Map descriptor kind to hosted kind (nil = not supported for mutation).
public func gtkHostedKindForDescriptor(_ kind: GTK4DescriptorKind) -> GTK4HostedNodeKind? {
    switch kind {
    case .text: return .text
    case .color: return .color
    case .canvas: return .canvas
    case .slider: return .slider
    case .padding: return .padding
    default: return nil
    }
}

// MARK: - Native slot ID

/// Convert a GTK widget pointer to an integer slot ID for storage.
public func gtkNativeSlotID(for widget: UnsafeMutablePointer<GtkWidget>) -> Int {
    Int(bitPattern: UnsafeRawPointer(widget))
}

/// Convert a slot ID back to a GTK widget pointer. Caller must verify liveness.
public func gtkWidgetFromSlotID(_ slotID: Int) -> UnsafeMutablePointer<GtkWidget>? {
    guard slotID != 0 else { return nil }
    return UnsafeMutablePointer<GtkWidget>(bitPattern: slotID)
}

// MARK: - Native slot capture

/// Walk the rebuilt GTK widget tree (DFS), collecting hosted text/color widgets.
/// Matches against descriptor tree leaves by validating hosted kind == descriptor kind.
public func gtkCaptureSupportedNativeSlots(
    from widgetRoot: UnsafeMutablePointer<GtkWidget>,
    descriptorRoot: GTK4IdentifiedDescriptorNode,
    executorRoot: GTK4RetainedExecutorNode
) -> GTK4RetainedExecutorNode {
    let supportedDescriptors = gtkCollectSupportedLeafDescriptors(from: descriptorRoot)
    var supportedWidgets: [UnsafeMutablePointer<GtkWidget>] = []
    gtkCollectSupportedHostedWidgets(from: widgetRoot, into: &supportedWidgets)

    guard supportedDescriptors.count == supportedWidgets.count else {
        return executorRoot
    }

    var slotsByIdentity: [GTK4DescriptorIdentity: Int] = [:]
    for (entry, widget) in zip(supportedDescriptors, supportedWidgets) {
        guard let expectedKind = gtkHostedKindForDescriptor(entry.kind),
              gtkHostedNodeKind(of: widget) == expectedKind else {
            return executorRoot
        }
        slotsByIdentity[entry.identity] = gtkNativeSlotID(for: widget)
    }

    return gtkAssignNativeSlots(executorRoot, slotsByIdentity: slotsByIdentity)
}

private func gtkCollectSupportedLeafDescriptors(
    from node: GTK4IdentifiedDescriptorNode
) -> [(identity: GTK4DescriptorIdentity, kind: GTK4DescriptorKind)] {
    var result: [(identity: GTK4DescriptorIdentity, kind: GTK4DescriptorKind)] = []
    if gtkHostedKindForDescriptor(node.descriptor.kind) != nil {
        result.append((identity: node.identity, kind: node.descriptor.kind))
    }
    for child in node.children {
        result.append(contentsOf: gtkCollectSupportedLeafDescriptors(from: child))
    }
    return result
}

private func gtkCollectSupportedHostedWidgets(
    from widget: UnsafeMutablePointer<GtkWidget>,
    into result: inout [UnsafeMutablePointer<GtkWidget>]
) {
    let kind = gtkHostedNodeKind(of: widget)
    if kind == .text || kind == .color || kind == .canvas || kind == .slider || kind == .padding {
        result.append(widget)
    }
    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        gtkCollectSupportedHostedWidgets(from: c, into: &result)
        child = gtk_widget_get_next_sibling(c)
    }
}

public func gtkAssignNativeSlots(
    _ node: GTK4RetainedExecutorNode,
    slotsByIdentity: [GTK4DescriptorIdentity: Int]
) -> GTK4RetainedExecutorNode {
    GTK4RetainedExecutorNode(
        identity: node.identity,
        kind: node.kind,
        lastDescriptor: node.lastDescriptor,
        nativeSlotID: slotsByIdentity[node.identity] ?? node.nativeSlotID,
        canvasPayload: node.canvasPayload,
        children: node.children.map { gtkAssignNativeSlots($0, slotsByIdentity: slotsByIdentity) }
    )
}

// MARK: - Slot validation

/// Check that all update/keep actions in the tree have valid native slots
/// for supported kinds (text/color/slider). Returns false if any supported leaf
/// has a nil or dead slot.
public func gtkAllSlotsValid(action: GTK4ExecutorAction) -> Bool {
    switch action.kind {
    case .update:
        if action.updateIntent == .textContent || action.updateIntent == .colorFill
            || action.updateIntent == .canvasContent
            || action.updateIntent == .sliderValue
            || action.updateIntent == .paddingLayout {
            guard let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID,
                  let widget = gtkWidgetFromSlotID(slotID),
                  gtk_swift_is_widget(widget) != 0 else {
                return false
            }
        }
    case .keep, .create, .replace:
        break
    }
    return action.children.allSatisfy(gtkAllSlotsValid)
}

// MARK: - GTK mutation helpers

/// Set text content on a hosted GtkLabel widget in place.
public func gtkSetTextContent(slotID: Int, text: String) -> Bool {
    guard let widget = gtkWidgetFromSlotID(slotID) else { return false }
    guard gtk_swift_is_widget(widget) != 0 else { return false }
    gtk_swift_label_set_text(widget, text)
    return true
}

/// Replace background color CSS on a hosted Color widget in place.
/// Uses a single replaceable CSS provider stored on the widget,
/// avoiding CSS provider accumulation from repeated applyCSSToWidget calls.
private let gtkColorProviderKey = "gtk-swift-color-provider"

public func gtkSetColorFill(slotID: Int, color: GTK4ColorDescriptor) -> Bool {
    guard let widget = gtkWidgetFromSlotID(slotID) else { return false }
    guard gtk_swift_is_widget(widget) != 0 else { return false }

    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    let className = "gtk-swift-color-\(gtkNativeSlotID(for: widget))"
    let css = String(format: ".%@ { background-color: rgba(%d, %d, %d, %.3f); }",
                     className,
                     Int(color.red * 255), Int(color.green * 255),
                     Int(color.blue * 255), color.opacity)

    // Reuse or create a single CSS provider scoped to this widget's class
    if let existingRaw = g_object_get_data(gobject, gtkColorProviderKey) {
        let provider = UnsafeMutableRawPointer(existingRaw)
            .assumingMemoryBound(to: GtkCssProvider.self)
        gtk_css_provider_load_from_string(provider, css)
    } else {
        gtk_widget_add_css_class(widget, className)

        let provider = gtk_css_provider_new()!
        gtk_css_provider_load_from_string(provider, css)
        let display = gtk_widget_get_display(widget)!
        gtk_swift_add_css_provider_to_display(display, provider, UInt32(GTK_STYLE_PROVIDER_PRIORITY_USER))

        g_object_set_data_full(gobject, gtkColorProviderKey, gpointer(provider), { userData in
            g_object_unref(userData)
        })
    }

    return true
}

/// Set slider value on a hosted GtkScale widget in place.
public func gtkSetSliderValue(slotID: Int, value: Double) -> Bool {
    guard let widget = gtkWidgetFromSlotID(slotID) else { return false }
    guard gtk_swift_is_widget(widget) != 0 else { return false }
    let range = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GtkRange.self)
    gtk_range_set_value(range, value)
    return true
}

private let gtkCanvasDrawBoxKey = "gtk-swift-canvas-draw-box"

public func gtkSetCanvasContent(slotID: Int, payload: GTK4CanvasPayload) -> Bool {
    guard let widget = gtkWidgetFromSlotID(slotID) else { return false }
    guard gtk_swift_is_widget(widget) != 0 else { return false }
    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    guard let raw = g_object_get_data(gobject, gtkCanvasDrawBoxKey) else { return false }

    let box = Unmanaged<SizedDrawClosureBox>.fromOpaque(raw).takeUnretainedValue()
    box.closure = payload.drawHandler
    box.sizedClosure = payload.sizedDrawHandler

    if payload.width > 0 {
        gtk_swift_drawing_area_set_content_width(widget, gint(payload.width))
    }
    if payload.height > 0 {
        gtk_swift_drawing_area_set_content_height(widget, gint(payload.height))
    }
    gtk_widget_set_hexpand(widget, payload.width <= 0 ? 1 : 0)
    gtk_widget_set_vexpand(widget, payload.height <= 0 ? 1 : 0)
    gtk_widget_queue_draw(widget)
    return true
}

public func gtkCanvasPayloadsByIdentity(
    descriptorRoot: GTK4IdentifiedDescriptorNode,
    payloads: [GTK4CanvasPayload]
) -> [GTK4DescriptorIdentity: GTK4CanvasPayload] {
    let identities = gtkCollectCanvasDescriptorIdentities(from: descriptorRoot)
    guard identities.count == payloads.count else { return [:] }

    var result: [GTK4DescriptorIdentity: GTK4CanvasPayload] = [:]
    for (identity, payload) in zip(identities, payloads) {
        result[identity] = payload
    }
    return result
}

private func gtkCollectCanvasDescriptorIdentities(
    from node: GTK4IdentifiedDescriptorNode
) -> [GTK4DescriptorIdentity] {
    var result: [GTK4DescriptorIdentity] = []
    if node.descriptor.kind == .canvas {
        result.append(node.identity)
    }
    for child in node.children {
        result.append(contentsOf: gtkCollectCanvasDescriptorIdentities(from: child))
    }
    return result
}

/// Update CSS padding on a hosted PaddedView wrapper widget in place.
private let gtkPaddingProviderKey = "gtk-swift-padding-provider"

public func gtkSetPadding(slotID: Int, padding: GTK4PaddingDescriptor) -> Bool {
    guard let widget = gtkWidgetFromSlotID(slotID) else { return false }
    guard gtk_swift_is_widget(widget) != 0 else { return false }

    let gobject = UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GObject.self)
    let className = "gtk-swift-padding-\(gtkNativeSlotID(for: widget))"
    let css = """
        .\(className) {
            padding-top: \(padding.top)px;
            padding-bottom: \(padding.bottom)px;
            padding-left: \(padding.leading)px;
            padding-right: \(padding.trailing)px;
        }
        """

    if let existingRaw = g_object_get_data(gobject, gtkPaddingProviderKey) {
        let provider = UnsafeMutableRawPointer(existingRaw)
            .assumingMemoryBound(to: GtkCssProvider.self)
        gtk_css_provider_load_from_string(provider, css)
    } else {
        gtk_widget_add_css_class(widget, className)

        let provider = gtk_css_provider_new()!
        gtk_css_provider_load_from_string(provider, css)
        let display = gtk_widget_get_display(widget)!
        gtk_swift_add_css_provider_to_display(display, provider, UInt32(GTK_STYLE_PROVIDER_PRIORITY_USER))

        g_object_set_data_full(gobject, gtkPaddingProviderKey, gpointer(provider), { userData in
            g_object_unref(userData)
        })
    }

    return true
}
