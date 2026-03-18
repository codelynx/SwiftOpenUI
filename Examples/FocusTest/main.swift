import SwiftOpenUI
import ExamplesShared
#if canImport(BackendGTK4)
import BackendGTK4
#endif
#if canImport(BackendWin32)
import BackendWin32
#endif

struct FocusTestApp: App {
    var body: some Scene {
        WindowGroup("Focus Preservation Test") {
            FocusTestView()
        }
    }
}

#if canImport(BackendGTK4)
GTK4Backend().run(FocusTestApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(FocusTestApp.self)
#elseif os(macOS)
print("FocusTest: Use apple/Examples.xcodeproj on macOS, or run on Linux/Windows.")
#else
print("FocusTest: No backend available on this platform.")
#endif
