import CGTK
import Foundation

/// Native Open / Save file dialogs (`GtkFileDialog`), presented imperatively
/// from a button action — the same imperative style as
/// ``GTK4Backend/openStandaloneWindow(title:width:height:onClose:content:)`` and
/// `GTK4PointerTracking`.
///
/// Both calls are non-blocking: the dialog runs on the GTK main loop and the
/// completion fires later on that same thread with the chosen path, or `nil`
/// when the user cancels. The dialog is parented to the active window by the
/// shim. Call from the UI (GTK main) thread.
public enum GTK4FileDialog {

    /// Present an Open dialog. `completion(path)` runs on the GTK main thread
    /// with the chosen path, or `nil` if cancelled.
    public static func open(title: String? = nil, _ completion: @escaping (String?) -> Void) {
        present(save: false, title: title, suggestedName: nil, completion: completion)
    }

    /// Present a Save dialog pre-filled with `suggestedName`. `completion(path)`
    /// runs on the GTK main thread with the chosen path, or `nil` if cancelled.
    public static func save(title: String? = nil, suggestedName: String, _ completion: @escaping (String?) -> Void) {
        present(save: true, title: title, suggestedName: suggestedName, completion: completion)
    }

    /// Retains the escaping completion across the C async boundary.
    private final class Box {
        let completion: (String?) -> Void
        init(_ completion: @escaping (String?) -> Void) { self.completion = completion }
    }

    // Captures nothing, so it is a valid @convention(c) function pointer. Unpacks
    // the retained box, converts the C path (NULL → nil), and invokes it once.
    private static let trampoline: @convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void = {
        (path: UnsafePointer<CChar>?, user: UnsafeMutableRawPointer?) in
        guard let user: UnsafeMutableRawPointer = user else { return }
        let box: Box = Unmanaged<Box>.fromOpaque(user).takeRetainedValue()
        let result: String? = path.map { (c: UnsafePointer<CChar>) in String(cString: c) }
        box.completion(result)
    }

    private static func present(
        save: Bool,
        title: String?,
        suggestedName: String?,
        completion: @escaping (String?) -> Void
    ) {
        let user: UnsafeMutableRawPointer = Unmanaged.passRetained(Box(completion)).toOpaque()

        func withTitle<T>(_ body: (UnsafePointer<CChar>?) -> T) -> T {
            if let title: String = title { return title.withCString(body) }
            return body(nil)
        }

        if save {
            withTitle { (titlePtr: UnsafePointer<CChar>?) in
                (suggestedName ?? "untitled.swift").withCString { (namePtr: UnsafePointer<CChar>) in
                    gtk_swift_present_save_dialog(titlePtr, namePtr, user, trampoline)
                }
            }
        } else {
            withTitle { (titlePtr: UnsafePointer<CChar>?) in
                gtk_swift_present_open_dialog(titlePtr, user, trampoline)
            }
        }
    }
}
