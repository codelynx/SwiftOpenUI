import SwiftOpenUI
import ExamplesShared
#if canImport(BackendGTK4)
import BackendGTK4
#endif
#if canImport(BackendWin32)
import BackendWin32
#endif

struct ButtonsApp: App {
    var body: some Scene {
        WindowGroup("03 - Buttons") {
            ButtonsView()
        }
    }
}

#if canImport(BackendGTK4)
GTK4Backend().run(ButtonsApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(ButtonsApp.self)
#elseif os(macOS)
print("Buttons: Use apple/Examples.xcodeproj on macOS, or run on Linux/Windows.")
#else
print("Buttons: No backend available on this platform.")
#endif
