import SwiftOpenUI
import ExamplesShared
#if canImport(BackendGTK4)
import BackendGTK4
#endif
#if canImport(BackendWin32)
import BackendWin32
#endif

struct LayoutApp: App {
    var body: some Scene {
        WindowGroup("05 - Layout") {
            LayoutRootView()
        }
    }
}

#if canImport(BackendGTK4)
GTK4Backend().run(LayoutApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(LayoutApp.self)
#elseif os(macOS)
print("Layout: Use apple/Examples.xcodeproj on macOS, or run on Linux/Windows.")
#else
print("Layout: No backend available on this platform.")
#endif
