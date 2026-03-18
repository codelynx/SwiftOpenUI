import SwiftOpenUI
import ExamplesShared
#if canImport(BackendGTK4)
import BackendGTK4
#endif
#if canImport(BackendWin32)
import BackendWin32
#endif

struct CounterApp: App {
    var body: some Scene {
        WindowGroup("Counter") {
            CounterView()
        }
    }
}

#if canImport(BackendGTK4)
GTK4Backend().run(CounterApp.self)
#elseif canImport(BackendWin32)
Win32Backend().run(CounterApp.self)
#elseif os(macOS)
print("Counter: Use apple/Examples.xcodeproj on macOS, or run on Linux/Windows.")
#else
print("Counter: No backend available on this platform.")
#endif
