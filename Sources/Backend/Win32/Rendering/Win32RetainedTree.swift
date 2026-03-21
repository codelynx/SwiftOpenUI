import WinSDK
import CWin32

/// Local invalidation outcomes for Win32 retained-node updates.
public enum Win32NodeUpdateResult {
    case noChange
    case needsRepaint
    case needsRelayout
    case replaceSubtree
}

/// Win32-local node kinds used by the retained render tree.
public enum Win32HostedNodeKind: String {
    case hostContainer
    case subtree
    case unknown
}

/// Lightweight backend-local description of the desired hosted subtree.
public struct Win32DesiredNode {
    public let kind: Win32HostedNodeKind
    public let debugName: String?
    public let children: [Win32DesiredNode]

    public init(kind: Win32HostedNodeKind,
                debugName: String? = nil,
                children: [Win32DesiredNode] = []) {
        self.kind = kind
        self.debugName = debugName
        self.children = children
    }
}

/// Retained Win32 node that can later participate in local reconciliation.
public final class Win32HostedNode {
    public let kind: Win32HostedNodeKind
    public var ownedHwnd: HWND?
    public var children: [Win32HostedNode]
    public var desiredNode: Win32DesiredNode
    public var updateHook: ((Win32DesiredNode) -> Win32NodeUpdateResult)?

    public init(kind: Win32HostedNodeKind,
                ownedHwnd: HWND?,
                children: [Win32HostedNode] = [],
                desiredNode: Win32DesiredNode,
                updateHook: ((Win32DesiredNode) -> Win32NodeUpdateResult)? = nil) {
        self.kind = kind
        self.ownedHwnd = ownedHwnd
        self.children = children
        self.desiredNode = desiredNode
        self.updateHook = updateHook
    }
}

/// Current render output for a hosted Win32 subtree.
public struct Win32BuiltTree {
    public let desiredRoot: Win32DesiredNode
    public let retainedRoot: Win32HostedNode?

    public init(desiredRoot: Win32DesiredNode, retainedRoot: Win32HostedNode?) {
        self.desiredRoot = desiredRoot
        self.retainedRoot = retainedRoot
    }

    public var rootHwnd: HWND? {
        retainedRoot?.ownedHwnd
    }
}

public func makeWin32HostedSubtree(rootHwnd: HWND?,
                                   kind: Win32HostedNodeKind = .subtree,
                                   debugName: String? = nil) -> Win32BuiltTree {
    let desiredRoot = Win32DesiredNode(kind: kind, debugName: debugName)
    let retainedRoot = Win32HostedNode(
        kind: kind,
        ownedHwnd: rootHwnd,
        desiredNode: desiredRoot
    )
    return Win32BuiltTree(desiredRoot: desiredRoot, retainedRoot: retainedRoot)
}
