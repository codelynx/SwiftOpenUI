import WinSDK
import CWin32

/// Win32-local backend node kinds used as lightweight annotations on HWNDs.
/// This keeps the useful identity lesson from the reconcile spike without
/// carrying forward the abandoned retained-tree scaffolding.
public enum Win32HostedNodeKind: String {
    case background
    case border
    case color
    case frame
    case foregroundColor
    case hostContainer
    case hStack
    case padding
    case slider
    case text
    case unknown
    case vStack
    case zStack
}

private let hostedNodeKindPropName: UnsafePointer<WCHAR> = {
    "SwiftUIHostedNodeKind".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

public func markHostedNodeKind(_ hwnd: HWND, _ kind: Win32HostedNodeKind) {
    SetPropW(hwnd, hostedNodeKindPropName, HANDLE(bitPattern: hostedNodeKindCode(kind)))
}

public func hostedNodeKind(of hwnd: HWND) -> Win32HostedNodeKind {
    guard let raw = GetPropW(hwnd, hostedNodeKindPropName) else { return .unknown }
    return hostedNodeKind(from: Int(bitPattern: raw))
}

private func hostedNodeKindCode(_ kind: Win32HostedNodeKind) -> Int {
    switch kind {
    case .background: return 1
    case .border: return 13
    case .color: return 2
    case .frame: return 3
    case .foregroundColor: return 4
    case .hostContainer: return 5
    case .hStack: return 6
    case .padding: return 7
    case .slider: return 8
    case .text: return 9
    case .unknown: return 10
    case .vStack: return 11
    case .zStack: return 12
    }
}

private func hostedNodeKind(from code: Int) -> Win32HostedNodeKind {
    switch code {
    case 1: return .background
    case 2: return .color
    case 13: return .border
    case 3: return .frame
    case 4: return .foregroundColor
    case 5: return .hostContainer
    case 6: return .hStack
    case 7: return .padding
    case 8: return .slider
    case 9: return .text
    case 11: return .vStack
    case 12: return .zStack
    default: return .unknown
    }
}
