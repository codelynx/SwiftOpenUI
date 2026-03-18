import SwiftOpenUI
import ExamplesShared
#if canImport(BackendGTK4)
import BackendGTK4
#endif
#if canImport(BackendWin32)
import BackendWin32
#endif

struct BasicInteractiveApp: App {
    var body: some Scene {
        WindowGroup("Basic Interactive") {
            BasicInteractiveView()
        }
    }
}

#if canImport(BackendGTK4)
GTK4Backend().run(BasicInteractiveApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(BasicInteractiveApp.self)
#elseif os(macOS)
print("BasicInteractive: Use apple/Examples.xcodeproj on macOS, or run on Linux/Windows.")
#else
print("BasicInteractive: No backend available on this platform.")
#endif
