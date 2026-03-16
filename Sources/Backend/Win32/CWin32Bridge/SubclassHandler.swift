import WinSDK
import CWin32

/// Manages per-control message handling via SetWindowSubclass.
///
/// This is the Win32 equivalent of GTK4's signal connections.
/// Each SubclassHandler attaches to an HWND and routes messages
/// to Swift closures. Cleanup happens on WM_NCDESTROY.
public class SubclassHandler {
    /// Closure called for WM_COMMAND notifications (button clicks, etc.)
    public var onCommand: (() -> Void)?

    /// Closure called when text changes (EN_CHANGE for Edit controls)
    public var onTextChanged: ((String) -> Void)?

    /// Closure called for custom messages
    public var onMessage: ((UINT, WPARAM, LPARAM) -> LRESULT?)?

    /// Unique subclass ID for this handler.
    public let subclassID: UINT_PTR

    /// The HWND this handler is attached to.
    public internal(set) var hwnd: HWND?

    private static var nextID: UINT_PTR = 1

    /// Attach a subclass handler to an HWND.
    public init(hwnd: HWND) {
        self.hwnd = hwnd
        self.subclassID = SubclassHandler.nextID
        SubclassHandler.nextID += 1

        let retained = Unmanaged.passRetained(self).toOpaque()
        win32_SetWindowSubclass(
            hwnd,
            subclassProc,
            subclassID,
            DWORD_PTR(UInt(bitPattern: retained))
        )
    }

    /// Remove the subclass.
    public func remove() {
        guard let hwnd = hwnd else { return }
        win32_RemoveWindowSubclass(hwnd, subclassProc, subclassID)
        self.hwnd = nil
    }

    deinit {
        remove()
    }
}

/// The C-callable subclass procedure.
private let subclassProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    let handler = Unmanaged<SubclassHandler>.fromOpaque(
        UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
    ).takeUnretainedValue()

    switch uMsg {
    case UINT(WM_COMMAND):
        let notifyCode = win32_HIWORD(DWORD_PTR(wParam))
        if notifyCode == WORD(EN_CHANGE) {
            if let onTextChanged = handler.onTextChanged, let hwnd = hwnd {
                let length = GetWindowTextLengthW(hwnd)
                if length > 0 {
                    let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(length) + 1)
                    defer { buffer.deallocate() }
                    GetWindowTextW(hwnd, buffer, length + 1)
                    let text = String(decodingCString: buffer, as: UTF16.self)
                    onTextChanged(text)
                } else {
                    onTextChanged("")
                }
            }
        } else {
            handler.onCommand?()
        }
        return win32_DefSubclassProc(hwnd!, uMsg, wParam, lParam)

    case UINT(WM_NCDESTROY):
        let result = win32_DefSubclassProc(hwnd!, uMsg, wParam, lParam)
        handler.hwnd = nil
        Unmanaged<SubclassHandler>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        return result

    default:
        if let onMessage = handler.onMessage {
            if let result = onMessage(uMsg, wParam, lParam) {
                return result
            }
        }
        return win32_DefSubclassProc(hwnd!, uMsg, wParam, lParam)
    }
}
