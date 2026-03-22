import JavaScriptKit
import SwiftOpenUI

// MARK: - Slot table (per-host)

/// Per-host slot table mapping integer IDs to live DOM elements.
/// Each WebViewHost owns its own table so rebuilding one host
/// does not invalidate slots for unrelated hosts.
class WebSlotTable {
    private var slots: [Int: JSValue] = [:]
    private var nextID: Int = 1

    func register(_ element: JSValue) -> Int {
        let id = nextID
        nextID += 1
        slots[id] = element
        return id
    }

    func resolve(_ slotID: Int) -> JSValue? {
        slots[slotID]
    }

    func clear() {
        slots.removeAll()
    }
}

/// The currently active slot table, set by the host performing a rebuild or slot capture.
var _webCurrentSlotTable: WebSlotTable?

/// Register a DOM element in the current host's slot table.
func webRegisterSlot(_ element: JSValue) -> Int {
    guard let table = _webCurrentSlotTable else { return 0 }
    return table.register(element)
}

/// Resolve a slot ID from the current host's slot table.
func webResolveSlot(_ slotID: Int) -> JSValue? {
    _webCurrentSlotTable?.resolve(slotID)
}

// MARK: - Native slot capture

/// Walk the rebuilt DOM tree (DFS), collecting hosted text/color elements.
/// Matches against descriptor tree leaves by validating hosted kind == descriptor kind.
public func webCaptureSupportedNativeSlots(
    from container: JSValue,
    descriptorRoot: WebIdentifiedDescriptorNode,
    executorRoot: WebRetainedExecutorNode
) -> WebRetainedExecutorNode {
    let supportedDescriptors = webCollectSupportedLeafDescriptors(from: descriptorRoot)
    var supportedElements: [JSValue] = []
    webCollectSupportedHostedElements(from: container, into: &supportedElements)

    guard supportedDescriptors.count == supportedElements.count else {
        return executorRoot
    }

    var slotsByIdentity: [WebDescriptorIdentity: Int] = [:]
    for (entry, element) in zip(supportedDescriptors, supportedElements) {
        guard let expectedKind = webHostedKindForDescriptor(entry.kind),
              webHostedNodeKind(of: element) == expectedKind else {
            return executorRoot
        }
        slotsByIdentity[entry.identity] = webRegisterSlot(element)
    }

    return webAssignNativeSlots(executorRoot, slotsByIdentity: slotsByIdentity)
}

/// DFS walk of DOM children collecting elements with data-hosted-kind attribute.
private func webCollectSupportedHostedElements(
    from element: JSValue,
    into result: inout [JSValue]
) {
    let kind = webHostedNodeKind(of: element)
    if kind == .text || kind == .color || kind == .slider
        || kind == .background || kind == .foregroundColor || kind == .padding {
        result.append(element)
    }

    guard let obj = element.object else { return }
    let childrenVal = obj.children
    let length = Int(childrenVal.length.number ?? 0)
    for i in 0..<length {
        webCollectSupportedHostedElements(from: childrenVal[i], into: &result)
    }
}

// MARK: - Slot validation

/// Check that all update actions with supported intents have valid, live slots.
public func webAllSlotsValid(action: WebExecutorAction) -> Bool {
    switch action.kind {
    case .update:
        if action.updateIntent == .textContent || action.updateIntent == .colorFill
            || action.updateIntent == .sliderValue
            || action.updateIntent == .backgroundColor
            || action.updateIntent == .foregroundColor
            || action.updateIntent == .paddingLayout {
            guard let slotID = action.resultingNode.nativeSlotID ?? action.previousNode?.nativeSlotID,
                  let element = webResolveSlot(slotID) else {
                return false
            }
            // Verify element is still in the DOM
            guard let obj = element.object else { return false }
            let parent = obj.parentNode
            if parent.isNull || parent.isUndefined {
                return false
            }
        }
    case .keep, .create, .replace:
        break
    }
    return action.children.allSatisfy(webAllSlotsValid)
}

// MARK: - Hook mutation (real DOM changes)

/// Apply real DOM mutations for text/color update actions.
public func webApplyHookMutation(action: WebExecutorAction) -> WebHookResult {
    webApplyHookInternal(action: action, performMutation: true)
}

// MARK: - DOM mutation helpers

/// Set text content on a hosted DOM element in place.
func webSetTextContentDOM(slotID: Int, text: String) -> Bool {
    guard let element = webResolveSlot(slotID),
          let obj = element.object else { return false }
    let parent = obj.parentNode
    guard !parent.isNull && !parent.isUndefined else { return false }
    obj.textContent = .string(text)
    return true
}

/// Update only the backgroundColor property on a hosted Color DOM element.
/// Preserves all other inline styles (e.g. grid-area set by ZStack).
func webSetColorFillDOM(slotID: Int, color: WebColorDescriptor) -> Bool {
    guard let element = webResolveSlot(slotID),
          let obj = element.object else { return false }
    let parent = obj.parentNode
    guard !parent.isNull && !parent.isUndefined else { return false }
    let rgba = "rgba(\(Int(color.red * 255)), \(Int(color.green * 255)), \(Int(color.blue * 255)), \(color.opacity))"
    guard let style = obj.style.object else { return false }
    style.backgroundColor = .string(rgba)
    return true
}

/// Set slider value on a hosted input[range] DOM element in place.
func webSetSliderValueDOM(slotID: Int, value: Double) -> Bool {
    guard let element = webResolveSlot(slotID),
          let obj = element.object else { return false }
    let parent = obj.parentNode
    guard !parent.isNull && !parent.isUndefined else { return false }
    obj.value = .string("\(value)")
    return true
}

/// Set background color on a hosted BackgroundView wrapper DOM element.
/// Updates only backgroundColor, preserving other inline styles (display, flex).
func webSetBackgroundColorDOM(slotID: Int, color: WebColorDescriptor) -> Bool {
    guard let element = webResolveSlot(slotID),
          let obj = element.object else { return false }
    let parent = obj.parentNode
    guard !parent.isNull && !parent.isUndefined else { return false }
    let rgba = "rgba(\(Int(color.red * 255)), \(Int(color.green * 255)), \(Int(color.blue * 255)), \(color.opacity))"
    guard let style = obj.style.object else { return false }
    style.backgroundColor = .string(rgba)
    return true
}

/// Set foreground color on a hosted ForegroundColorView wrapper DOM element.
func webSetForegroundColorDOM(slotID: Int, color: WebColorDescriptor) -> Bool {
    guard let element = webResolveSlot(slotID),
          let obj = element.object else { return false }
    let parent = obj.parentNode
    guard !parent.isNull && !parent.isUndefined else { return false }
    let rgba = "rgba(\(Int(color.red * 255)), \(Int(color.green * 255)), \(Int(color.blue * 255)), \(color.opacity))"
    guard let style = obj.style.object else { return false }
    style.color = .string(rgba)
    return true
}

/// Set padding on a hosted PaddedView wrapper DOM element.
func webSetPaddingDOM(slotID: Int, padding: WebPaddingDescriptor) -> Bool {
    guard let element = webResolveSlot(slotID),
          let obj = element.object else { return false }
    let parent = obj.parentNode
    guard !parent.isNull && !parent.isUndefined else { return false }
    guard let style = obj.style.object else { return false }
    style.padding = .string("\(padding.top)px \(padding.trailing)px \(padding.bottom)px \(padding.leading)px")
    return true
}

// MARK: - Wire mutation implementations

/// Call this once at startup to wire the real DOM mutation functions
/// into the pure pipeline's mutation stubs.
func webInstallMutationHooks() {
    _webSetTextContentImpl = webSetTextContentDOM
    _webSetColorFillImpl = webSetColorFillDOM
    _webSetSliderValueImpl = webSetSliderValueDOM
    _webSetBackgroundColorImpl = webSetBackgroundColorDOM
    _webSetForegroundColorImpl = webSetForegroundColorDOM
    _webSetPaddingImpl = webSetPaddingDOM
}
