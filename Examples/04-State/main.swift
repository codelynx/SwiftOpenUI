import SwiftOpenUI
import ExamplesShared
#if canImport(BackendGTK4)
import BackendGTK4
#endif
#if canImport(BackendWin32)
import BackendWin32
#endif

struct StateApp: App {
    var body: some Scene {
        WindowGroup("04 - State") {
            StateDemoRootView()
        }
    }
}

#if canImport(BackendGTK4)
GTK4Backend().run(StateApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(StateApp.self)
#elseif os(macOS)
print("StateDemo: Use apple/Examples.xcodeproj on macOS, or run on Linux/Windows.")
#else
print("State: No backend available on this platform.")
#endif
