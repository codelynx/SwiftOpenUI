import SwiftOpenUI
import ExamplesShared
#if canImport(BackendGTK4)
import BackendGTK4
#endif
#if canImport(BackendWin32)
import BackendWin32
#endif

struct Showcase2App: App {
    var body: some Scene {
        WindowGroup("Showcase 2") {
            Showcase2View()
        }
    }
}

#if canImport(BackendGTK4)
GTK4Backend().run(Showcase2App.self)
#elseif canImport(BackendWin32)
Win32Backend().run(Showcase2App.self)
#elseif os(macOS)
print("Showcase2: Use apple/Examples.xcodeproj on macOS, or run on Linux/Windows.")
#else
print("Showcase2: No backend available on this platform.")
#endif
