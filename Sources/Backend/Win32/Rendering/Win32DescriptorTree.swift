import SwiftOpenUI
import WinSDK
import CWin32

/// Leaf-first Win32 descriptor kinds for the descriptor-first invalidation path.
/// This intentionally starts small and does not attempt to model every Win32
/// wrapper yet.
public enum Win32DescriptorKind: Equatable {
    case background
    case border
    case composite
    case divider
    case font
    case spacer
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

public struct Win32TextDescriptor: Equatable {
    public let content: String
}

public struct Win32ColorDescriptor: Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double
}

public struct Win32SliderDescriptor: Equatable {
    public let value: Double
    public let range: ClosedRange<Double>
    public let step: Double
}

public enum Win32AlignmentDescriptor: String, Equatable {
    case topLeading
    case top
    case topTrailing
    case leading
    case center
    case trailing
    case bottomLeading
    case bottom
    case bottomTrailing
}

public struct Win32PaddingDescriptor: Equatable {
    public let top: Int
    public let bottom: Int
    public let leading: Int
    public let trailing: Int
}

public struct Win32FrameDescriptor: Equatable {
    public let width: Double?
    public let height: Double?
    public let minWidth: Double?
    public let minHeight: Double?
    public let maxWidth: Double?
    public let maxHeight: Double?
    public let alignment: Win32AlignmentDescriptor
}

public struct Win32BorderDescriptor: Equatable {
    public let color: Win32ColorDescriptor
    public let width: Int
}

public struct Win32FontDescriptor: Equatable {
    public let font: Font
}

public enum Win32HorizontalAlignmentDescriptor: String, Equatable {
    case leading
    case center
    case trailing
}

public enum Win32VerticalAlignmentDescriptor: String, Equatable {
    case top
    case center
    case bottom
}

public struct Win32VStackDescriptor: Equatable {
    public let spacing: Int
    public let alignment: Win32HorizontalAlignmentDescriptor
}

public struct Win32HStackDescriptor: Equatable {
    public let spacing: Int
    public let alignment: Win32VerticalAlignmentDescriptor
}

public struct Win32ZStackDescriptor: Equatable {
    public let alignment: Win32AlignmentDescriptor
}

public enum Win32DescriptorProps: Equatable {
    case none
    case background(Win32ColorDescriptor)
    case border(Win32BorderDescriptor)
    case font(Win32FontDescriptor)
    case text(Win32TextDescriptor)
    case color(Win32ColorDescriptor)
    case frame(Win32FrameDescriptor)
    case foregroundColor(Win32ColorDescriptor)
    case hStack(Win32HStackDescriptor)
    case padding(Win32PaddingDescriptor)
    case slider(Win32SliderDescriptor)
    case vStack(Win32VStackDescriptor)
    case zStack(Win32ZStackDescriptor)
}

public struct Win32DescriptorNode: Equatable {
    public let kind: Win32DescriptorKind
    public let typeName: String
    public let props: Win32DescriptorProps
    public let children: [Win32DescriptorNode]

    public init(kind: Win32DescriptorKind,
                typeName: String,
                props: Win32DescriptorProps = .none,
                children: [Win32DescriptorNode] = []) {
        self.kind = kind
        self.typeName = typeName
        self.props = props
        self.children = children
    }
}

/// Structural identity for the current descriptor-first scaffold.
/// This is intentionally position-based for now; keyed identity is a later step.
public struct Win32DescriptorIdentity: Equatable, Hashable {
    public let path: [Int]

    public init(path: [Int]) {
        self.path = path
    }
}

public struct Win32IdentifiedDescriptorNode: Equatable {
    public let identity: Win32DescriptorIdentity
    public let descriptor: Win32DescriptorNode
    public let children: [Win32IdentifiedDescriptorNode]

    public init(identity: Win32DescriptorIdentity,
                descriptor: Win32DescriptorNode,
                children: [Win32IdentifiedDescriptorNode]) {
        self.identity = identity
        self.descriptor = descriptor
        self.children = children
    }
}

public struct Win32RetainedDescriptorNode: Equatable {
    public let identity: Win32DescriptorIdentity
    public let descriptor: Win32DescriptorNode
    public let children: [Win32RetainedDescriptorNode]

    public init(identity: Win32DescriptorIdentity,
                descriptor: Win32DescriptorNode,
                children: [Win32RetainedDescriptorNode]) {
        self.identity = identity
        self.descriptor = descriptor
        self.children = children
    }
}

public struct Win32RetainedExecutorNode: Equatable {
    public let identity: Win32DescriptorIdentity
    public let kind: Win32DescriptorKind
    public let lastDescriptor: Win32DescriptorNode
    public let nativeSlotID: Int?
    public let children: [Win32RetainedExecutorNode]

    public init(identity: Win32DescriptorIdentity,
                kind: Win32DescriptorKind,
                lastDescriptor: Win32DescriptorNode,
                nativeSlotID: Int? = nil,
                children: [Win32RetainedExecutorNode] = []) {
        self.identity = identity
        self.kind = kind
        self.lastDescriptor = lastDescriptor
        self.nativeSlotID = nativeSlotID
        self.children = children
    }
}

public enum Win32DescriptorMatchKind: Equatable {
    case reuse
    case replace
}

public struct Win32DescriptorMatch: Equatable {
    public let identity: Win32DescriptorIdentity
    public let kind: Win32DescriptorMatchKind
    public let oldDescriptor: Win32DescriptorNode?
    public let newDescriptor: Win32DescriptorNode
    public let children: [Win32DescriptorMatch]

    public init(identity: Win32DescriptorIdentity,
                kind: Win32DescriptorMatchKind,
                oldDescriptor: Win32DescriptorNode?,
                newDescriptor: Win32DescriptorNode,
                children: [Win32DescriptorMatch] = []) {
        self.identity = identity
        self.kind = kind
        self.oldDescriptor = oldDescriptor
        self.newDescriptor = newDescriptor
        self.children = children
    }
}

public enum Win32DescriptorPlanKind: Equatable {
    case create
    case reuse
    case update
    case replace
}

public enum Win32DescriptorUpdateIntent: Equatable {
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

public struct Win32DescriptorPlan: Equatable {
    public let identity: Win32DescriptorIdentity
    public let kind: Win32DescriptorPlanKind
    public let updateIntent: Win32DescriptorUpdateIntent
    public let oldDescriptor: Win32DescriptorNode?
    public let newDescriptor: Win32DescriptorNode
    public let children: [Win32DescriptorPlan]

    public init(identity: Win32DescriptorIdentity,
                kind: Win32DescriptorPlanKind,
                updateIntent: Win32DescriptorUpdateIntent = .none,
                oldDescriptor: Win32DescriptorNode?,
                newDescriptor: Win32DescriptorNode,
                children: [Win32DescriptorPlan] = []) {
        self.identity = identity
        self.kind = kind
        self.updateIntent = updateIntent
        self.oldDescriptor = oldDescriptor
        self.newDescriptor = newDescriptor
        self.children = children
    }
}

public enum Win32ExecutorActionKind: Equatable {
    case create
    case keep
    case update
    case replace
}

public struct Win32ExecutorAction: Equatable {
    public let identity: Win32DescriptorIdentity
    public let kind: Win32ExecutorActionKind
    public let updateIntent: Win32DescriptorUpdateIntent
    public let previousDescriptor: Win32DescriptorNode?
    public let currentDescriptor: Win32DescriptorNode
    public let previousNode: Win32RetainedExecutorNode?
    public let resultingNode: Win32RetainedExecutorNode
    public let children: [Win32ExecutorAction]

    public init(identity: Win32DescriptorIdentity,
                kind: Win32ExecutorActionKind,
                updateIntent: Win32DescriptorUpdateIntent = .none,
                previousDescriptor: Win32DescriptorNode?,
                currentDescriptor: Win32DescriptorNode,
                previousNode: Win32RetainedExecutorNode?,
                resultingNode: Win32RetainedExecutorNode,
                children: [Win32ExecutorAction] = []) {
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

public enum Win32HookResultKind: Equatable {
    case created
    case updated
    case replaced
    case noOp
}

public struct Win32HookResult: Equatable {
    public let identity: Win32DescriptorIdentity
    public let kind: Win32HookResultKind
    public let updateIntent: Win32DescriptorUpdateIntent
    public let currentDescriptor: Win32DescriptorNode
    public let previousDescriptor: Win32DescriptorNode?
    public let mutationSucceeded: Bool
    public let children: [Win32HookResult]

    public init(identity: Win32DescriptorIdentity,
                kind: Win32HookResultKind,
                updateIntent: Win32DescriptorUpdateIntent = .none,
                currentDescriptor: Win32DescriptorNode,
                previousDescriptor: Win32DescriptorNode? = nil,
                mutationSucceeded: Bool = true,
                children: [Win32HookResult] = []) {
        self.identity = identity
        self.kind = kind
        self.updateIntent = updateIntent
        self.currentDescriptor = currentDescriptor
        self.previousDescriptor = previousDescriptor
        self.mutationSucceeded = mutationSucceeded
        self.children = children
    }
}

public protocol WinDescribable {
    func winDescribeNode() -> Win32DescriptorNode
}

/// Build a Win32-local descriptor tree without creating HWNDs.
public func winDescribeView<V: View>(_ view: V) -> Win32DescriptorNode {
    if let describable = view as? WinDescribable {
        return describable.winDescribeNode()
    }

    if let multi = view as? MultiChildView {
        return Win32DescriptorNode(
            kind: .composite,
            typeName: String(describing: type(of: view)),
            children: multi.children.map(winDescribeAnyView)
        )
    }

    if V.Body.self != Never.self {
        return winDescribeAnyView(view.body)
    }

    return Win32DescriptorNode(
        kind: .composite,
        typeName: String(describing: type(of: view))
    )
}

public func winDescribeAnyView(_ view: any View) -> Win32DescriptorNode {
    func describe<V: View>(_ value: V) -> Win32DescriptorNode { winDescribeView(value) }
    return describe(view)
}

public func winIdentifyDescriptorTree(_ descriptor: Win32DescriptorNode) -> Win32IdentifiedDescriptorNode {
    identifyDescriptorTree(descriptor, path: [])
}

public func winRetainDescriptorTree(_ node: Win32IdentifiedDescriptorNode) -> Win32RetainedDescriptorNode {
    Win32RetainedDescriptorNode(
        identity: node.identity,
        descriptor: node.descriptor,
        children: node.children.map(winRetainDescriptorTree)
    )
}

public func winMakeExecutorTree(from node: Win32IdentifiedDescriptorNode,
                                nativeSlotID: Int? = nil) -> Win32RetainedExecutorNode {
    Win32RetainedExecutorNode(
        identity: node.identity,
        kind: node.descriptor.kind,
        lastDescriptor: node.descriptor,
        nativeSlotID: nativeSlotID,
        children: node.children.map { winMakeExecutorTree(from: $0, nativeSlotID: nil) }
    )
}

public func winCaptureSupportedNativeSlots(from hwndRoot: HWND,
                                           descriptorRoot: Win32IdentifiedDescriptorNode,
                                           executorRoot: Win32RetainedExecutorNode) -> Win32RetainedExecutorNode {
    let supportedDescriptors = winCollectSupportedLeafDescriptors(from: descriptorRoot)
    var supportedWindows: [HWND] = []
    winCollectSupportedHostedWindows(from: hwndRoot, into: &supportedWindows)

    guard supportedDescriptors.count == supportedWindows.count else {
        return executorRoot
    }

    var slotsByIdentity: [Win32DescriptorIdentity: Int] = [:]
    for (descriptorEntry, hwnd) in zip(supportedDescriptors, supportedWindows) {
        guard winHostedNodeKind(for: descriptorEntry.kind) == hostedNodeKind(of: hwnd) else {
            return executorRoot
        }
        slotsByIdentity[descriptorEntry.identity] = winNativeSlotID(for: hwnd)
    }

    return winAssignNativeSlots(executorRoot, slotsByIdentity: slotsByIdentity)
}

public func winCanApplyTextColorHostMutation(plan: Win32DescriptorPlan) -> Bool {
    switch plan.kind {
    case .create, .replace:
        return false
    case .reuse:
        // Reject opaque composites with no described children — can't prove
        // nothing changed inside them (matching GTK4 pattern)
        if plan.newDescriptor.kind == .composite && plan.children.isEmpty {
            return false
        }
        return plan.children.allSatisfy(winCanApplyTextColorHostMutation)
    case .update:
        // Host gate stays narrow: textContent + colorFill only.
        // Other intents (sliderValue, paddingLayout, fontStyle) are recognized
        // by the descriptor layer but NOT eligible for the narrow mutation path
        // until real Win32 mutation hooks exist for them.
        guard plan.updateIntent == .textContent || plan.updateIntent == .colorFill else {
            return false
        }
        return plan.children.allSatisfy(winCanApplyTextColorHostMutation)
    }
}

/// Compare a retained descriptor tree against a newly described tree.
/// Current rule: reuse requires the same structural position, kind, type,
/// and child count. This is intentionally strict until keyed identity exists.
public func winMatchDescriptorTree(old: Win32RetainedDescriptorNode,
                                   new: Win32IdentifiedDescriptorNode) -> Win32DescriptorMatch {
    guard canReuseDescriptorNode(old: old, new: new) else {
        return Win32DescriptorMatch(
            identity: new.identity,
            kind: .replace,
            oldDescriptor: old.descriptor,
            newDescriptor: new.descriptor
        )
    }

    return Win32DescriptorMatch(
        identity: new.identity,
        kind: .reuse,
        oldDescriptor: old.descriptor,
        newDescriptor: new.descriptor,
        children: zip(old.children, new.children).map(winMatchDescriptorTree)
    )
}

/// Convert retained/new descriptor trees into explicit create/update/reuse/replace
/// decisions without touching runtime Win32 rebuild behavior yet.
public func winPlanDescriptorTree(old: Win32RetainedDescriptorNode?,
                                  new: Win32IdentifiedDescriptorNode) -> Win32DescriptorPlan {
    guard let old else {
        return Win32DescriptorPlan(
            identity: new.identity,
            kind: .create,
            updateIntent: .none,
            oldDescriptor: nil,
            newDescriptor: new.descriptor,
            children: new.children.map { winPlanDescriptorTree(old: nil, new: $0) }
        )
    }

    guard canReuseDescriptorNode(old: old, new: new) else {
        return Win32DescriptorPlan(
            identity: new.identity,
            kind: .replace,
            updateIntent: .none,
            oldDescriptor: old.descriptor,
            newDescriptor: new.descriptor,
            children: new.children.map { winPlanDescriptorTree(old: nil, new: $0) }
        )
    }

    let childPlans = zip(old.children, new.children).map { oldChild, newChild in
        winPlanDescriptorTree(old: oldChild, new: newChild)
    }
    let localKind: Win32DescriptorPlanKind = old.descriptor.props == new.descriptor.props ? .reuse : .update
    let updateIntent: Win32DescriptorUpdateIntent =
        localKind == .update ? winUpdateIntent(old: old.descriptor, new: new.descriptor) : .none

    return Win32DescriptorPlan(
        identity: new.identity,
        kind: localKind,
        updateIntent: updateIntent,
        oldDescriptor: old.descriptor,
        newDescriptor: new.descriptor,
        children: childPlans
    )
}

/// Convert a descriptor plan into backend-local executor actions and an updated
/// retained executor tree. This remains pure data; no HWND work happens here.
public func winExecuteDescriptorPlan(old: Win32RetainedExecutorNode?,
                                     plan: Win32DescriptorPlan) -> Win32ExecutorAction {
    switch plan.kind {
    case .create:
        let childActions = plan.children.map { childPlan in
            winExecuteDescriptorPlan(old: nil, plan: childPlan)
        }
        let resultingNode = Win32RetainedExecutorNode(
            identity: plan.identity,
            kind: plan.newDescriptor.kind,
            lastDescriptor: plan.newDescriptor,
            nativeSlotID: nil,
            children: childActions.map(\.resultingNode)
        )
        return Win32ExecutorAction(
            identity: plan.identity,
            kind: .create,
            previousDescriptor: nil,
            currentDescriptor: plan.newDescriptor,
            previousNode: nil,
            resultingNode: resultingNode,
            children: childActions
        )

    case .replace:
        let childActions = plan.children.map { childPlan in
            winExecuteDescriptorPlan(old: nil, plan: childPlan)
        }
        let resultingNode = Win32RetainedExecutorNode(
            identity: plan.identity,
            kind: plan.newDescriptor.kind,
            lastDescriptor: plan.newDescriptor,
            nativeSlotID: nil,
            children: childActions.map(\.resultingNode)
        )
        return Win32ExecutorAction(
            identity: plan.identity,
            kind: .replace,
            previousDescriptor: old?.lastDescriptor ?? plan.oldDescriptor,
            currentDescriptor: plan.newDescriptor,
            previousNode: old,
            resultingNode: resultingNode,
            children: childActions
        )

    case .reuse, .update:
        let childActions = zip(old?.children ?? [], plan.children).map { oldChild, childPlan in
            winExecuteDescriptorPlan(old: oldChild, plan: childPlan)
        }
        let resultingNode = Win32RetainedExecutorNode(
            identity: plan.identity,
            kind: plan.newDescriptor.kind,
            lastDescriptor: plan.newDescriptor,
            nativeSlotID: old?.nativeSlotID,
            children: childActions.map(\.resultingNode)
        )
        return Win32ExecutorAction(
            identity: plan.identity,
            kind: plan.kind == .update ? .update : .keep,
            updateIntent: plan.updateIntent,
            previousDescriptor: old?.lastDescriptor ?? plan.oldDescriptor,
            currentDescriptor: plan.newDescriptor,
            previousNode: old,
            resultingNode: resultingNode,
            children: childActions
        )
    }
}

/// Dispatch backend-local executor actions into Win32-specific hook results.
/// This remains detached from live HWND mutation; the hook layer is descriptive.
public func winApplyHook(action: Win32ExecutorAction) -> Win32HookResult {
    winApplyHook(action: action, performMutation: false)
}

/// Apply hook dispatch and perform the narrow set of real Win32 mutations that
/// are explicitly implemented for this isolated slice.
/// Validate that all update actions have live native HWNDs before mutation.
/// Mirrors GTK4's gtkAllSlotsValid — prevents writing to destroyed HWNDs.
public func winAllSlotsValid(action: Win32ExecutorAction) -> Bool {
    switch action.kind {
    case .update:
        if action.updateIntent == .textContent || action.updateIntent == .colorFill {
            guard let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID,
                  let hwnd = HWND(bitPattern: slotID),
                  IsWindow(hwnd) else {
                return false
            }
        }
    case .keep, .create, .replace:
        break
    }
    return action.children.allSatisfy(winAllSlotsValid)
}

public func winApplyHookMutation(action: Win32ExecutorAction) -> Win32HookResult {
    winApplyHook(action: action, performMutation: true)
}

public func winHookMutationSucceeded(_ result: Win32HookResult) -> Bool {
    result.mutationSucceeded && result.children.allSatisfy(winHookMutationSucceeded)
}

public func winNativeSlotID(for hwnd: HWND) -> Int {
    Int(bitPattern: hwnd)
}

public func winSetTextContent(hwnd: HWND, text: String) -> Bool {
    let wideText = Array(text.utf16) + [0]
    let result = wideText.withUnsafeBufferPointer { buffer in
        SetWindowTextW(hwnd, buffer.baseAddress)
    }
    return result
}

public func winSetTextContent(nativeSlotID: Int, text: String) -> Bool {
    guard let hwnd = HWND(bitPattern: nativeSlotID) else { return false }
    return winSetTextContent(hwnd: hwnd, text: text)
}

private func winApplyHook(action: Win32ExecutorAction,
                          performMutation: Bool) -> Win32HookResult {
    switch action.kind {
    case .create:
        return winApplyCreateHook(action: action, performMutation: performMutation)
    case .keep:
        return winApplyKeepHook(action: action, performMutation: performMutation)
    case .update:
        switch action.updateIntent {
        case .backgroundColor:
            return winApplyBackgroundColorHook(action: action, performMutation: performMutation)
        case .borderStyle:
            return winApplyBorderStyleHook(action: action, performMutation: performMutation)
        case .colorFill:
            return winApplyColorFillHook(action: action, performMutation: performMutation)
        case .frameLayout:
            return winApplyFrameLayoutHook(action: action, performMutation: performMutation)
        case .foregroundColor:
            return winApplyForegroundColorHook(action: action, performMutation: performMutation)
        case .hStackLayout:
            return winApplyHStackLayoutHook(action: action, performMutation: performMutation)
        case .paddingLayout:
            return winApplyPaddingLayoutHook(action: action, performMutation: performMutation)
        case .sliderConfiguration:
            return winApplySliderConfigurationHook(action: action, performMutation: performMutation)
        case .sliderValue:
            return winApplySliderValueHook(action: action, performMutation: performMutation)
        case .textContent:
            return winApplyTextContentHook(action: action, performMutation: performMutation)
        case .vStackLayout:
            return winApplyVStackLayoutHook(action: action, performMutation: performMutation)
        case .zStackLayout:
            return winApplyZStackLayoutHook(action: action, performMutation: performMutation)
        case .fontStyle:
            return winApplyFontStyleHook(action: action, performMutation: performMutation)
        case .none:
            return winApplyKeepHook(action: action, performMutation: performMutation)
        }
    case .replace:
        return winApplyReplaceHook(action: action, performMutation: performMutation)
    }
}

public func winColorDescriptor(_ color: Color) -> Win32ColorDescriptor {
    Win32ColorDescriptor(
        red: color.red,
        green: color.green,
        blue: color.blue,
        opacity: color.alpha
    )
}

public func winAlignmentDescriptor(_ alignment: Alignment) -> Win32AlignmentDescriptor {
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

public func winHorizontalAlignmentDescriptor(_ alignment: HorizontalAlignment) -> Win32HorizontalAlignmentDescriptor {
    switch alignment {
    case .leading: return .leading
    case .center: return .center
    case .trailing: return .trailing
    }
}

public func winVerticalAlignmentDescriptor(_ alignment: VerticalAlignment) -> Win32VerticalAlignmentDescriptor {
    switch alignment {
    case .top: return .top
    case .center: return .center
    case .bottom: return .bottom
    }
}

private func identifyDescriptorTree(_ descriptor: Win32DescriptorNode,
                                    path: [Int]) -> Win32IdentifiedDescriptorNode {
    Win32IdentifiedDescriptorNode(
        identity: Win32DescriptorIdentity(path: path),
        descriptor: descriptor,
        children: descriptor.children.enumerated().map { index, child in
            identifyDescriptorTree(child, path: path + [index])
        }
    )
}

private func winCollectSupportedLeafDescriptors(
    from node: Win32IdentifiedDescriptorNode
) -> [(identity: Win32DescriptorIdentity, kind: Win32DescriptorKind)] {
    var result: [(identity: Win32DescriptorIdentity, kind: Win32DescriptorKind)] = []
    if winHostedNodeKind(for: node.descriptor.kind) != nil {
        result.append((identity: node.identity, kind: node.descriptor.kind))
    }
    for child in node.children {
        result.append(contentsOf: winCollectSupportedLeafDescriptors(from: child))
    }
    return result
}

private func winCollectSupportedHostedWindows(from hwnd: HWND, into result: inout [HWND]) {
    if winSupportsNativeSlotCapture(hostedNodeKind(of: hwnd)) {
        result.append(hwnd)
    }

    var child = GetWindow(hwnd, UINT(GW_CHILD))
    while let current = child {
        winCollectSupportedHostedWindows(from: current, into: &result)
        child = GetWindow(current, UINT(GW_HWNDNEXT))
    }
}

private func winAssignNativeSlots(_ node: Win32RetainedExecutorNode,
                                  slotsByIdentity: [Win32DescriptorIdentity: Int]) -> Win32RetainedExecutorNode {
    Win32RetainedExecutorNode(
        identity: node.identity,
        kind: node.kind,
        lastDescriptor: node.lastDescriptor,
        nativeSlotID: slotsByIdentity[node.identity],
        children: node.children.map { winAssignNativeSlots($0, slotsByIdentity: slotsByIdentity) }
    )
}

private func winHostedNodeKind(for descriptorKind: Win32DescriptorKind) -> Win32HostedNodeKind? {
    switch descriptorKind {
    case .text:
        return .text
    case .color:
        return .color
    default:
        return nil
    }
}

private func winSupportsNativeSlotCapture(_ kind: Win32HostedNodeKind) -> Bool {
    switch kind {
    case .text, .color:
        return true
    default:
        return false
    }
}

private func canReuseDescriptorNode(old: Win32RetainedDescriptorNode,
                                    new: Win32IdentifiedDescriptorNode) -> Bool {
    let sameIdentity = old.identity == new.identity
    let sameNodeType = old.descriptor.kind == new.descriptor.kind
    let sameChildCount = old.children.count == new.children.count
    return sameIdentity && sameNodeType && sameChildCount
}

private func winUpdateIntent(old: Win32DescriptorNode,
                             new: Win32DescriptorNode) -> Win32DescriptorUpdateIntent {
    guard old.kind == new.kind else { return .none }

    switch new.kind {
    case .background:
        return .backgroundColor
    case .border:
        return .borderStyle
    case .color:
        return .colorFill
    case .frame:
        return .frameLayout
    case .foregroundColor:
        return .foregroundColor
    case .hStack:
        return .hStackLayout
    case .padding:
        return .paddingLayout
    case .slider:
        guard case let .slider(oldSlider) = old.props,
              case let .slider(newSlider) = new.props else {
            return .sliderConfiguration
        }
        return oldSlider.range == newSlider.range && oldSlider.step == newSlider.step
            ? .sliderValue
            : .sliderConfiguration
    case .text:
        return .textContent
    case .vStack:
        return .vStackLayout
    case .zStack:
        return .zStackLayout
    case .composite:
        return .none
    case .divider:
        return .none
    case .font:
        return .fontStyle
    case .spacer:
        return .none
    }
}

private func winApplyCreateHook(action: Win32ExecutorAction,
                                performMutation: Bool) -> Win32HookResult {
    let childResults = action.children.map { winApplyHook(action: $0, performMutation: performMutation) }
    return Win32HookResult(
        identity: action.identity,
        kind: .created,
        currentDescriptor: action.currentDescriptor,
        mutationSucceeded: childResults.allSatisfy(winHookMutationSucceeded),
        children: childResults
    )
}

private func winApplyKeepHook(action: Win32ExecutorAction,
                              performMutation: Bool) -> Win32HookResult {
    let childResults = action.children.map { winApplyHook(action: $0, performMutation: performMutation) }
    return Win32HookResult(
        identity: action.identity,
        kind: .noOp,
        currentDescriptor: action.currentDescriptor,
        previousDescriptor: action.previousDescriptor,
        mutationSucceeded: childResults.allSatisfy(winHookMutationSucceeded),
        children: childResults
    )
}

private func winApplyReplaceHook(action: Win32ExecutorAction,
                                 performMutation: Bool) -> Win32HookResult {
    let childResults = action.children.map { winApplyHook(action: $0, performMutation: performMutation) }
    return Win32HookResult(
        identity: action.identity,
        kind: .replaced,
        currentDescriptor: action.currentDescriptor,
        previousDescriptor: action.previousDescriptor,
        mutationSucceeded: childResults.allSatisfy(winHookMutationSucceeded),
        children: childResults
    )
}

private func winApplyTextContentHook(action: Win32ExecutorAction,
                                     performMutation: Bool) -> Win32HookResult {
    var mutationSucceeded = true
    if performMutation,
       case let .text(textDescriptor) = action.currentDescriptor.props,
       let nativeSlotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID {
        mutationSucceeded = winSetTextContent(nativeSlotID: nativeSlotID, text: textDescriptor.content)
    } else if performMutation {
        mutationSucceeded = false
    }
    return winUpdatedHookResult(
        action: action,
        intent: .textContent,
        performMutation: performMutation,
        mutationSucceeded: mutationSucceeded
    )
}

private func winApplyColorFillHook(action: Win32ExecutorAction,
                                   performMutation: Bool) -> Win32HookResult {
    var mutationSucceeded = true
    if performMutation,
       case let .color(colorDescriptor) = action.currentDescriptor.props,
       let nativeSlotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID {
        mutationSucceeded = winSetColorFill(nativeSlotID: nativeSlotID, color: colorDescriptor)
    } else if performMutation {
        mutationSucceeded = false
    }
    return winUpdatedHookResult(
        action: action,
        intent: .colorFill,
        performMutation: performMutation,
        mutationSucceeded: mutationSucceeded
    )
}

private func winApplySliderValueHook(action: Win32ExecutorAction,
                                     performMutation: Bool) -> Win32HookResult {
    winUpdatedHookResult(action: action, intent: .sliderValue, performMutation: performMutation)
}

private func winApplySliderConfigurationHook(action: Win32ExecutorAction,
                                             performMutation: Bool) -> Win32HookResult {
    winUpdatedHookResult(action: action, intent: .sliderConfiguration, performMutation: performMutation)
}

private func winApplyFrameLayoutHook(action: Win32ExecutorAction,
                                     performMutation: Bool) -> Win32HookResult {
    winUpdatedHookResult(action: action, intent: .frameLayout, performMutation: performMutation)
}

private func winApplyHStackLayoutHook(action: Win32ExecutorAction,
                                      performMutation: Bool) -> Win32HookResult {
    winUpdatedHookResult(action: action, intent: .hStackLayout, performMutation: performMutation)
}

private func winApplyVStackLayoutHook(action: Win32ExecutorAction,
                                      performMutation: Bool) -> Win32HookResult {
    winUpdatedHookResult(action: action, intent: .vStackLayout, performMutation: performMutation)
}

private func winApplyZStackLayoutHook(action: Win32ExecutorAction,
                                      performMutation: Bool) -> Win32HookResult {
    winUpdatedHookResult(action: action, intent: .zStackLayout, performMutation: performMutation)
}

private func winApplyPaddingLayoutHook(action: Win32ExecutorAction,
                                       performMutation: Bool) -> Win32HookResult {
    winUpdatedHookResult(action: action, intent: .paddingLayout, performMutation: performMutation)
}

private func winApplyFontStyleHook(action: Win32ExecutorAction,
                                    performMutation: Bool) -> Win32HookResult {
    winUpdatedHookResult(action: action, intent: .fontStyle, performMutation: performMutation)
}

private func winApplyBackgroundColorHook(action: Win32ExecutorAction,
                                         performMutation: Bool) -> Win32HookResult {
    winUpdatedHookResult(action: action, intent: .backgroundColor, performMutation: performMutation)
}

private func winApplyForegroundColorHook(action: Win32ExecutorAction,
                                         performMutation: Bool) -> Win32HookResult {
    winUpdatedHookResult(action: action, intent: .foregroundColor, performMutation: performMutation)
}

private func winApplyBorderStyleHook(action: Win32ExecutorAction,
                                     performMutation: Bool) -> Win32HookResult {
    winUpdatedHookResult(action: action, intent: .borderStyle, performMutation: performMutation)
}

private func winUpdatedHookResult(action: Win32ExecutorAction,
                                  intent: Win32DescriptorUpdateIntent,
                                  performMutation: Bool,
                                  mutationSucceeded: Bool = true) -> Win32HookResult {
    let childResults = action.children.map { winApplyHook(action: $0, performMutation: performMutation) }
    return Win32HookResult(
        identity: action.identity,
        kind: .updated,
        updateIntent: intent,
        currentDescriptor: action.currentDescriptor,
        previousDescriptor: action.previousDescriptor,
        mutationSucceeded: mutationSucceeded && childResults.allSatisfy(winHookMutationSucceeded),
        children: childResults
    )
}
