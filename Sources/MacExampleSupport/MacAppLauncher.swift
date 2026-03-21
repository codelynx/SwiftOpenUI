#if os(macOS)
import AppKit
import Foundation
import SwiftUI

private let launchLoggingEnabled: Bool = {
    guard let value = ProcessInfo.processInfo.environment["SWIFT_OPENUI_MAC_LAUNCH_LOG"]?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    else { return false }
    return value == "1" || value == "true" || value == "yes" || value == "on"
}()

private func launchLog(_ message: String) {
    guard launchLoggingEnabled else { return }
    let uptime = String(format: "%.3f", ProcessInfo.processInfo.systemUptime)
    guard let data = "[MacAppLauncher +\(uptime)s] \(message)\n".data(using: .utf8) else { return }
    FileHandle.standardError.write(data)
}

private func describeWindow(_ window: NSWindow?) -> String {
    guard let window else { return "nil" }
    let title = window.title.isEmpty ? "<untitled>" : window.title.replacingOccurrences(of: "\"", with: "\\\"")
    return "window#\(window.windowNumber) title=\"\(title)\" visible=\(window.isVisible) key=\(window.isKeyWindow) main=\(window.isMainWindow) mini=\(window.isMiniaturized)"
}

private func describeAppState() -> String {
    let app = NSApplication.shared
    return "active=\(app.isActive) hidden=\(app.isHidden) policy=\(app.activationPolicy().rawValue) windows=\(app.windows.count) key=\(describeWindow(app.keyWindow)) main=\(describeWindow(app.mainWindow))"
}

private final class LaunchObserver {
    private var didFrontWindow = false
    private var observers: [NSObjectProtocol] = []

    init() {
        observeAppNotification(NSApplication.willFinishLaunchingNotification, label: "willFinishLaunching")
        observeAppNotification(NSApplication.didFinishLaunchingNotification, label: "didFinishLaunching") { [weak self] in
            self?.scheduleFrontmostAttempt(remainingAttempts: 10)
        }
        observeAppNotification(NSApplication.didBecomeActiveNotification, label: "didBecomeActive")
        observeAppNotification(NSApplication.didResignActiveNotification, label: "didResignActive")

        observeWindowNotification(NSWindow.didBecomeMainNotification, label: "didBecomeMain", frontsWindow: true)
        observeWindowNotification(NSWindow.didBecomeKeyNotification, label: "didBecomeKey")
        observeWindowNotification(NSWindow.didExposeNotification, label: "didExpose", frontsWindow: true)
        observeWindowNotification(NSWindow.didResignMainNotification, label: "didResignMain")
        observeWindowNotification(NSWindow.didResignKeyNotification, label: "didResignKey")
        observeWindowNotification(NSWindow.willCloseNotification, label: "willClose") { [weak self] _ in
            self?.terminateIfNoUsableWindows(reason: "willClose")
        }

        launchLog("observer installed \(describeAppState())")
    }

    private func observeAppNotification(
        _ name: NSNotification.Name,
        label: String,
        action: (() -> Void)? = nil
    ) {
        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: NSApplication.shared,
            queue: .main
        ) { _ in
            launchLog("app callback \(label) \(describeAppState())")
            action?()
        }
        observers.append(observer)
    }

    private func observeWindowNotification(
        _ name: NSNotification.Name,
        label: String,
        frontsWindow: Bool = false,
        action: ((NSWindow?) -> Void)? = nil
    ) {
        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let window = note.object as? NSWindow
            launchLog("window callback \(label) \(describeWindow(window)) \(describeAppState())")
            action?(window)
            guard frontsWindow, let self, !self.didFrontWindow, let window else { return }
            self.bringToFront(window, reason: label)
        }
        observers.append(observer)
    }

    private func scheduleFrontmostAttempt(remainingAttempts: Int) {
        guard remainingAttempts > 0, !didFrontWindow else {
            if remainingAttempts == 0 {
                launchLog("retry loop exhausted \(describeAppState())")
            }
            return
        }
        launchLog("scheduleFrontmostAttempt remaining=\(remainingAttempts) \(describeAppState())")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, !self.didFrontWindow else { return }
            let candidate = self.frontCandidateWindow()
            launchLog("retry fired remaining=\(remainingAttempts) candidate=\(describeWindow(candidate)) \(describeAppState())")
            if let candidate {
                self.bringToFront(candidate, reason: "retry remaining=\(remainingAttempts)")
            } else {
                self.scheduleFrontmostAttempt(remainingAttempts: remainingAttempts - 1)
            }
        }
    }

    private func frontCandidateWindow() -> NSWindow? {
        let app = NSApplication.shared
        return app.windows.first(where: isUsableWindow(_:))
            ?? app.mainWindow
            ?? app.keyWindow
            ?? app.windows.first
    }

    private func isUsableWindow(_ window: NSWindow) -> Bool {
        !window.isMiniaturized && !window.isExcludedFromWindowsMenu
    }

    private func bringToFront(_ window: NSWindow, reason: String) {
        launchLog("bringToFront start reason=\(reason) target=\(describeWindow(window)) \(describeAppState())")
        didFrontWindow = true
        launchLog("calling NSApplication.activate(ignoringOtherApps: true)")
        NSApplication.shared.activate(ignoringOtherApps: true)
        launchLog("after activate \(describeAppState())")
        launchLog("calling window.makeKeyAndOrderFront(nil) on \(describeWindow(window))")
        window.makeKeyAndOrderFront(nil)
        launchLog("after makeKeyAndOrderFront target=\(describeWindow(window)) \(describeAppState())")
        launchLog("calling window.orderFrontRegardless() on \(describeWindow(window))")
        window.orderFrontRegardless()
        launchLog("after orderFrontRegardless target=\(describeWindow(window)) \(describeAppState())")
        DispatchQueue.main.async {
            launchLog("next runloop after bringToFront target=\(describeWindow(window)) \(describeAppState())")
        }
    }

    private func terminateIfNoUsableWindows(reason: String) {
        DispatchQueue.main.async {
            let remaining = NSApplication.shared.windows.filter(self.isUsableWindow(_:))
            launchLog("terminate check reason=\(reason) remaining=\(remaining.count) \(describeAppState())")
            guard remaining.isEmpty else { return }
            launchLog("calling NSApplication.terminate(nil)")
            NSApplication.shared.terminate(nil)
        }
    }

    deinit {
        launchLog("deinit observer")
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

private var launchObserver: LaunchObserver?

public enum MacAppLauncher {
    public static func run<A: App>(_ app: A.Type) {
        launchLog("run(app: \(String(describing: app))) start \(describeAppState())")
        NSApplication.shared.setActivationPolicy(.regular)
        launchLog("after setActivationPolicy(.regular) \(describeAppState())")
        launchObserver = LaunchObserver()
        app.main()
    }
}
#endif
